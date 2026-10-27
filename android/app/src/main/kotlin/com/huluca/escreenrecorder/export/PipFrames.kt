package com.huluca.escreenrecorder.export

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import androidx.media3.common.OverlaySettings
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.StaticOverlaySettings
import java.io.File

/**
 * Picture-in-picture video, kept inside the ordinary one-sequence pipeline: the small video is sampled to
 * a few JPEG frames per second once, and an overlay shows the frame for the current output time.
 * (Compositing a second video sequence would need a second decoder at the same time, which weak phones do
 * not have to spare.) Frames are cut from an all-key-frame copy, so sampling is fast.
 */
@UnstableApi
class PipFrames(private val ctx: Context) {
    companion object {
        const val FPS = 15
        const val MAX_SHORT_SIDE = 480
    }

    class Result(val dir: File, val frames: Int)

    private val main = Handler(Looper.getMainLooper())
    private val intraCopy = IntraCopy(ctx)
    @Volatile private var cancelled = false

    fun cancel() {
        cancelled = true
        intraCopy.cancel()
    }

    /** Main thread in, main thread out. */
    fun prepare(pip: PipClip, outDir: File, progress: (Float) -> Unit, done: (Result?, String?) -> Unit) {
        cancelled = false
        outDir.deleteRecursively()
        outDir.mkdirs()
        val intra = File(outDir, "intra.mp4")
        intraCopy.make(
            "file://" + pip.path, pip.trimStartMs, pip.trimStartMs + pip.playMs, pip.pxW, pip.pxH,
            MAX_SHORT_SIDE, FPS, intra,
            progress = { p -> progress(p * 0.6f) },
            done = { err ->
                if (err != null) {
                    done(null, err)
                } else {
                    Thread({
                        var result: Result? = null
                        var error: String? = null
                        try {
                            result = extract(intra, outDir, pip.playMs) { p -> main.post { progress(0.6f + p * 0.4f) } }
                        } catch (e: Exception) {
                            error = e.javaClass.simpleName + ": " + e.message
                        } finally {
                            intra.delete()
                        }
                        main.post { if (cancelled) done(null, "cancelled") else done(result, error) }
                    }, "esr-pip").start()
                }
            },
        )
    }

    private fun extract(intra: File, outDir: File, playMs: Long, progress: (Float) -> Unit): Result {
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(intra.absolutePath)
            val frames = maxOf(1, (playMs * FPS / 1000).toInt())
            var last: Bitmap? = null
            for (i in 0 until frames) {
                if (cancelled) break
                val bmp = mmr.getFrameAtTime(i * 1_000_000L / FPS, MediaMetadataRetriever.OPTION_CLOSEST) ?: last ?: continue
                File(outDir, "f%05d.jpg".format(i)).outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 82, it) }
                if (last != null && last !== bmp) last.recycle()
                last = bmp
                if (i % 6 == 0) progress(i.toFloat() / frames)
            }
            last?.recycle()
            return Result(outDir, frames)
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
    }
}

/**
 * A small picture or video frame shown between [startOutMs, endOutMs] of the OUTPUT timeline. The effect
 * that carries it sits after the speed change, so its clock measures output time inside the clip;
 * [itemOutStartMs] is where that clip starts in the whole video.
 */
@UnstableApi
class PipOverlay(
    private val frame: (index: Int) -> Bitmap,
    private val frameCount: Int,
    private val fps: Int,
    private val x: Float,
    private val y: Float,
    private val opacity: Float,
    private val startOutMs: Long,
    private val endOutMs: Long,
    private val itemOutStartMs: Long,
    private val clock: ItemClock,
) : BitmapOverlay() {
    private fun absOut(t: Long) = itemOutStartMs + clock.elapsedMs(t)

    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        val idx = (((absOut(presentationTimeUs) - startOutMs) * fps) / 1000).toInt().coerceIn(0, frameCount - 1)
        return frame(idx)
    }

    override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
        val t = absOut(presentationTimeUs)
        val on = t in startOutMs..endOutMs
        // a short fade in and out so it does not pop
        val edge = minOf(t - startOutMs, endOutMs - t).coerceAtLeast(0)
        val fade = (edge / 160f).coerceIn(0f, 1f)
        return StaticOverlaySettings.Builder()
            .setBackgroundFrameAnchor(x * 2f - 1f, 1f - y * 2f)
            .setAlphaScale(if (on) opacity * fade else 0f)
            .build()
    }
}

/** Loads JPEG frames from a directory, keeping the last few (the overlay asks for the same one many times). */
class FrameCache(private val dir: File, private val width: Int) {
    private val cache = object : LinkedHashMap<Int, Bitmap>(8, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Int, Bitmap>?) = size > 6
    }

    @Synchronized
    fun get(i: Int): Bitmap = cache.getOrPut(i) {
        val raw = BitmapFactory.decodeFile(File(dir, "f%05d.jpg".format(i)).absolutePath)
            ?: Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        if (raw.width == width || raw.width <= 2) raw
        else Bitmap.createScaledBitmap(raw, width, maxOf(2, (raw.height.toLong() * width / raw.width).toInt()), true).also { raw.recycle() }
    }
}
