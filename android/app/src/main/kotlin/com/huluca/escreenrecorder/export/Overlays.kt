package com.huluca.escreenrecorder.export

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.common.OverlaySettings
import com.huluca.escreenrecorder.marker.MarkerAnim
import com.huluca.escreenrecorder.marker.MarkerRenderer
import com.huluca.escreenrecorder.marker.MarkerType
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Effects inside a Composition receive the presentation time of the whole SEQUENCE, so the second
 * segment starts at ~3000 ms, not 0. The first timestamp an effect sees is its segment's first frame,
 * so everything after is measured from there.
 */
class ItemClock(
    private val clipStartMs: Long,
    /** +1 plays forward in source time, -1 backwards (a reversed clip). */
    private val direction: Int = 1,
    /** A still: every frame shows the same source time. */
    private val fixed: Boolean = false,
) {
    private var firstUs = Long.MIN_VALUE

    /** Milliseconds since this clip's first frame (as seen by the effect). */
    fun elapsedMs(presentationTimeUs: Long): Long {
        if (firstUs == Long.MIN_VALUE) firstUs = presentationTimeUs
        return (presentationTimeUs - firstUs) / 1000
    }

    fun sourceMs(presentationTimeUs: Long): Long {
        val e = elapsedMs(presentationTimeUs)
        return if (fixed) clipStartMs else clipStartMs + direction * e
    }
}

private val EMPTY: Bitmap by lazy { Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888) }

/**
 * Overlay positions are given in the frame of the whole recording; each overlay is built per
 * segment, [clipStartMs] converts the segment-relative presentation time back to source time.
 */
@UnstableApi
class MarkerOverlay(
    private val clip: MarkerClip,
    private val frameW: Int,
    private val frameH: Int,
    private val clock: ItemClock,
) : BitmapOverlay() {
    private val spec = clip.spec
    private val u = frameW / 360f
    private val size: Int
    private var cached: Bitmap? = null
    private var cachedKey = ""
    private val anchorX: Float
    private val anchorY: Float

    init {
        val r = MarkerRenderer.radiusU(spec, frameW.toFloat(), frameH.toFloat())
        val cueExtent = when (spec.type) {
            MarkerType.CIRCLE, MarkerType.RECT -> r * 1.9f
            MarkerType.PEN -> r
            else -> max(r, 100f)
        }
        size = max(16, (cueExtent * u * max(1f, spec.scale * 1.1f) * 2).toInt())
        val a = MarkerRenderer.anchor(spec, frameW.toFloat(), frameH.toFloat())
        anchorX = a.x / frameW
        anchorY = a.y / frameH
    }

    private var lastT = 0L

    private fun frameAt(presentationTimeUs: Long): MarkerAnim.Frame {
        val src = clock.sourceMs(presentationTimeUs)
        var t = src - clip.cueStartMs
        var fadeStart = MarkerAnim.CUE_MS + clip.holdMs
        if (spec.type == MarkerType.PEN) { t += MarkerAnim.CUE_MS; fadeStart += MarkerAnim.CUE_MS }
        lastT = t
        return MarkerAnim.frame(t, fadeStart)
    }

    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        val f = frameAt(presentationTimeUs)
        if (f.bodyAlpha <= 0.002f || f.done) return EMPTY
        // Re-render only when the animation state actually changed (steady hold reuses the bitmap).
        // The water loop moves all the time: quantise it to ~30 fps so frames of one instant share a bitmap.
        val phase = ((lastT - MarkerAnim.CUE_MS).coerceAtLeast(0L) / 33L) * 33L
        val key = "%.3f|%.3f|%.3f|%.3f|%d".format(f.cueProgress, f.bodyAlpha, f.bodyScale, f.press, phase)
        if (key == cachedKey && cached != null) return cached!!
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val cx = size / 2f
        val fw = frameW.toFloat()
        val fh = frameH.toFloat()
        if (f.cueProgress >= 0f) MarkerRenderer.drawCue(c, spec, fw, fh, cx, cx, f.cueProgress)
        MarkerRenderer.drawBody(c, spec, fw, fh, cx, cx, f.bodyAlpha, f.bodyScale, f.press, phase.toFloat())
        cached = bmp
        cachedKey = key
        return bmp
    }

    override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
        val f = frameAt(presentationTimeUs)
        val visible = f.bodyAlpha > 0.002f && !f.done
        return StaticOverlaySettings.Builder()
            .setBackgroundFrameAnchor(anchorX * 2f - 1f, 1f - anchorY * 2f)
            .setAlphaScale(if (visible) 1f else 0f)
            .build()
    }
}

/** Text / cover bitmap shown between [startMs, endMs] (source time) with short fades. */
@UnstableApi
class TimedBitmapOverlay(
    private val bitmap: Bitmap,
    private val frameW: Int,
    private val frameH: Int,
    private val cx: Float,
    private val cy: Float,
    private val startMs: Long,
    private val endMs: Long,
    private val clock: ItemClock,
    private val fadeMs: Long = 200,
) : BitmapOverlay() {

    private fun alphaAt(presentationTimeUs: Long): Float {
        val t = clock.sourceMs(presentationTimeUs)
        if (t < startMs || t > endMs) return 0f
        val a = min((t - startMs).toFloat() / fadeMs, (endMs - t).toFloat() / fadeMs)
        return a.coerceIn(0f, 1f)
    }

    override fun getBitmap(presentationTimeUs: Long): Bitmap = bitmap

    override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings =
        StaticOverlaySettings.Builder()
            .setBackgroundFrameAnchor(cx * 2f - 1f, 1f - cy * 2f)
            .setAlphaScale(alphaAt(presentationTimeUs))
            .build()
}

/** Pure zoom maths (also unit tested): mirror of lib/features/editor/editor_math.dart. */
object ZoomMath {
    const val RAMP_MS = 350f

    private fun smooth(x: Float): Float {
        val t = x.coerceIn(0f, 1f)
        return t * t * (3 - 2 * t)
    }

    /** Returns (scale, centreX, centreY) with the centre in fractions, clamped inside the frame. */
    fun at(zooms: List<ZoomClip>, tMs: Long): Triple<Float, Float, Float> {
        var s = 1f
        var fx = 0.5f
        var fy = 0.5f
        for (z in zooms) {
            if (tMs < z.startMs || tMs > z.endMs) continue
            val inP = smooth((tMs - z.startMs) / RAMP_MS)
            val outP = smooth((z.endMs - tMs) / RAMP_MS)
            s = 1f + (z.scale - 1f) * min(inP, outP)
            fx = z.fx; fy = z.fy
        }
        if (abs(s - 1f) < 1e-4f) return Triple(1f, 0.5f, 0.5f)
        val half = 0.5f / s
        return Triple(s, fx.coerceIn(half, 1f - half), fy.coerceIn(half, 1f - half))
    }
}

/** Eased zoom toward a focus point. Several clips may exist; they must not overlap. */
@UnstableApi
class ZoomTransformation(private val zooms: List<ZoomClip>, private val clock: ItemClock) : MatrixTransformation {

    override fun getMatrix(presentationTimeUs: Long): Matrix {
        val (s, cx, cy) = ZoomMath.at(zooms, clock.sourceMs(presentationTimeUs))
        val m = Matrix()
        if (s <= 1f) return m
        // NDC: x right, y up, both -1..1. Move the window centre to the middle, then scale.
        m.postTranslate(-(cx * 2f - 1f), -(1f - cy * 2f))
        m.postScale(s, s)
        return m
    }
}

/**
 * Text, image or shape bitmap that moves while shown: keyframe position / size / opacity, enter and exit
 * animation. Times are SOURCE ms; [clock] converts the clip's presentation time to them.
 */
@UnstableApi
class MotionBitmapOverlay(
    private val bitmap: Bitmap,
    private val x: Float,
    private val y: Float,
    private val scale: Float,
    private val opacity: Float,
    private val rotation: Float,
    private val startMs: Long,
    private val endMs: Long,
    private val motion: MotionSpec,
    private val clock: ItemClock,
) : BitmapOverlay() {
    override fun getBitmap(presentationTimeUs: Long): Bitmap = bitmap

    override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
        val t = clock.sourceMs(presentationTimeUs) - startMs
        val st = OverlayMotion.at(motion, x, y, scale, opacity, t, endMs - startMs)
        return StaticOverlaySettings.Builder()
            .setBackgroundFrameAnchor(st.x * 2f - 1f, 1f - st.y * 2f)
            .setScale(st.scale, st.scale)
            .setAlphaScale(if (st.visible) st.alpha else 0f)
            // Media3 turns counter-clockwise; the editor's rotation is clockwise.
            .setRotationDegrees(-rotation)
            .build()
    }
}
