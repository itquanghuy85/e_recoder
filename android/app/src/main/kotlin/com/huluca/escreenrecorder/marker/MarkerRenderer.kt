package com.huluca.escreenrecorder.marker

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.graphics.PathParser
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * The single place where markers are drawn: live overlay, editor previews and export all call
 * this. Everything is laid out in "u" units (frame width / 360) so a marker looks the same on a
 * 720 px and a 1440 px recording.
 *
 * Every shape is drawn twice: a wider halo of the opposite luminance, then the colour on top,
 * so markers stay legible over light and dark app content alike.
 */
object MarkerRenderer {
    const val CUE_COLOR = 0xFFFFB938.toInt()
    private const val HALO_U = 2.4f
    private const val FINGER_SIZE_U = 66f
    private const val FINGER_VIEWBOX = 24f
    private const val FINGER_TIP_X = 11.5f
    private const val FINGER_TIP_Y = 5f

    @Volatile var typeface: Typeface = Typeface.DEFAULT_BOLD

    // Material "touch_app" glyph (Apache-2.0): a pointing hand with a tap ring around the tip.
    private val fingerPath: Path by lazy {
        PathParser.createPathFromPathData(
            "M9 11.24V7.5C9 6.12 10.12 5 11.5 5S14 6.12 14 7.5v3.74c1.21-.81 2-2.18 2-3.74C16 5.01 13.99 3 11.5 3S7 5.01 7 7.5c0 1.56.79 2.93 2 3.74zm9.84 4.63l-4.54-2.26c-.17-.07-.35-.11-.54-.11H13v-6c0-.83-.67-1.5-1.5-1.5S10 6.67 10 7.5v10.74l-3.43-.72c-.08-.01-.15-.03-.24-.03-.31 0-.59.13-.79.33l-.79.8 4.94 4.94c.27.27.65.44 1.06.44h6.79c.75 0 1.33-.55 1.44-1.28l.75-5.27c.01-.07.02-.14.02-.2 0-.62-.38-1.16-.91-1.38z",
        )
    }

    fun haloColor(color: Int): Int {
        val lum = 0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)
        return if (lum > 150) 0xFF111111.toInt() else 0xFFFFFFFF.toInt()
    }

    private fun fill(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL; this.color = color
    }

    private fun stroke(color: Int, width: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; this.color = color; strokeWidth = width
        strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }

    /** Anchor of the marker (the point rotation and scale pivot around), in frame pixels. */
    fun anchor(s: MarkerSpec, w: Float, h: Float): PointF = when (s.type) {
        MarkerType.ARROW -> PointF(s.x1 * w, s.y1 * h)
        MarkerType.CIRCLE, MarkerType.RECT -> PointF((s.x0 + s.x1) / 2 * w, (s.y0 + s.y1) / 2 * h)
        MarkerType.PEN -> {
            val b = penBounds(s)
            PointF((b.centerX()) * w, b.centerY() * h)
        }
        else -> PointF(s.x0 * w, s.y0 * h)
    }

    private fun penBounds(s: MarkerSpec): RectF {
        val p = s.points
        if (p.size < 2) return RectF(s.x0, s.y0, s.x0, s.y0)
        var l = p[0]; var t = p[1]; var r = p[0]; var b = p[1]
        var i = 0
        while (i + 1 < p.size) {
            l = min(l, p[i]); r = max(r, p[i]); t = min(t, p[i + 1]); b = max(b, p[i + 1]); i += 2
        }
        return RectF(l, t, r, b)
    }

    /** Conservative half-size of the marker in u units (before spec.scale), for bitmap bounds. */
    fun radiusU(s: MarkerSpec, w: Float, h: Float): Float {
        val u = w / 360f
        val halo = HALO_U * 2 + s.thickness
        return when (s.type) {
            MarkerType.FINGER -> 78f
            MarkerType.RIPPLE -> 36f + halo
            MarkerType.NUMBER -> 22f + halo
            MarkerType.ARROW -> hypot((s.x0 - s.x1) * w, (s.y0 - s.y1) * h) / u + 14f + halo
            MarkerType.CIRCLE, MarkerType.RECT ->
                hypot(abs(s.x1 - s.x0) * w, abs(s.y1 - s.y0) * h) / (2 * u) + halo + 10f
            MarkerType.PEN -> {
                val b = penBounds(s)
                hypot((b.width() * w), (b.height() * h)) / (2 * u) + halo + 4f
            }
        }
    }

    /**
     * Draws the marker body with its anchor at ([ax], [ay]) on [c].
     * [alpha] multiplies the marker's own opacity; [bodyScale] is the pop-in scale;
     * [press] (0..1) is the take pulse.
     */
    fun drawBody(
        c: Canvas, s: MarkerSpec, w: Float, h: Float, ax: Float, ay: Float,
        alpha: Float = 1f, bodyScale: Float = 1f, press: Float = 0f, phaseMs: Float = 0f,
    ) {
        val total = (alpha * s.opacity).coerceIn(0f, 1f)
        if (total <= 0.004f) return
        val u = w / 360f
        val k = s.scale * bodyScale
        val layer = if (total < 0.999f) c.saveLayerAlpha(null, (total * 255).toInt()) else -1
        c.save()
        c.translate(ax, ay)
        c.rotate(s.rotationDeg)
        c.scale(u * k, u * k)
        val halo = haloColor(s.color)
        val haloPaintColor = Color.argb(150, Color.red(halo), Color.green(halo), Color.blue(halo))
        val t = s.thickness
        val tint = Water.tint(s.color)
        when (s.type) {
            MarkerType.FINGER -> drawFinger(c, tint, halo, press, phaseMs)
            MarkerType.RIPPLE -> drawRipple(c, tint, haloPaintColor, t, press, phaseMs)
            MarkerType.NUMBER -> drawNumber(c, s, tint, halo, phaseMs)
            MarkerType.ARROW -> drawArrow(c, s, tint, w, h, u, haloPaintColor, t, phaseMs)
            MarkerType.CIRCLE, MarkerType.RECT -> drawFrame(c, s, tint, w, h, u, haloPaintColor, t, phaseMs)
            MarkerType.PEN -> drawPen(c, s, tint, w, h, u, haloPaintColor, t, phaseMs)
        }
        c.restore()
        if (layer >= 0) c.restoreToCount(layer)
    }

    private fun drawFinger(c: Canvas, tint: Water.Tint, halo: Int, press: Float, phaseMs: Float) {
        // Water under the fingertip: a pool and rings spreading from the touch point.
        Water.pool(c, tint, 40f, 1f)
        Water.rings(c, tint, halo, phaseMs, count = 2, r0 = 8f, r1 = 36f, widthMax = 2.8f, alpha = 0.9f)
        val sc = FINGER_SIZE_U / FINGER_VIEWBOX * (1f - 0.1f * press)
        c.save()
        c.scale(sc, sc)
        c.translate(-FINGER_TIP_X, -FINGER_TIP_Y)
        // Outline first (halo), then the gradient fill and a glossy highlight clipped to the hand.
        c.drawPath(fingerPath, stroke(Color.argb(170, Color.red(halo), Color.green(halo), Color.blue(halo)), HALO_U * 2 / sc))
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                6f, 3f, 19f, 24f,
                intArrayOf(tint.light, tint.mid, tint.deep), floatArrayOf(0f, 0.45f, 1f), Shader.TileMode.CLAMP,
            )
        }
        c.drawPath(fingerPath, body)
        c.save()
        c.clipPath(fingerPath)
        val shine = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                7f, 3f, 15f, 12f,
                intArrayOf(Color.argb(150, 255, 255, 255), Color.argb(0, 255, 255, 255)), null, Shader.TileMode.CLAMP,
            )
        }
        c.drawOval(RectF(6f, 2f, 17f, 11f), shine)
        c.restore()
        c.restore()
    }

    private fun drawRipple(c: Canvas, tint: Water.Tint, haloColor: Int, t: Float, press: Float, phaseMs: Float) {
        // A drop on still water: a soft pool, rings that keep spreading, a glossy droplet at the centre.
        val grow = 1f + 0.3f * press
        c.save()
        c.scale(grow, grow)
        Water.pool(c, tint, 40f, 1f)
        Water.rings(c, tint, haloColor, phaseMs, count = 3, r0 = 8f, r1 = 44f, widthMax = 3f + t * 0.4f)
        c.restore()
        c.drawCircle(0f, 0f, 8.6f, fill(withAlpha(haloColor, 0.9f)))
        Water.sphere(c, tint, 0f, 0f, 7f)
    }

    private fun drawNumber(c: Canvas, s: MarkerSpec, tint: Water.Tint, halo: Int, phaseMs: Float) {
        val r = 17f * (1f + 0.025f * Water.breathe(phaseMs))
        Water.rings(c, tint, haloColor(s.color).let { Color.argb(150, Color.red(it), Color.green(it), Color.blue(it)) },
            phaseMs, count = 2, r0 = 19f, r1 = 33f, widthMax = 2.2f, alpha = 0.75f)
        c.drawCircle(0f, 0f, r, stroke(Color.argb(170, Color.red(halo), Color.green(halo), Color.blue(halo)), HALO_U * 2))
        Water.sphere(c, tint, 0f, 0f, r)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = haloColor(s.color) // text contrasts with the fill
            textAlign = Paint.Align.CENTER
            typeface = this@MarkerRenderer.typeface
            textSize = if (s.number >= 10) 17f else 22f
        }
        val y = -(p.ascent() + p.descent()) / 2f
        c.drawText(s.number.toString(), 0f, y, p)
    }

    private fun drawArrow(c: Canvas, s: MarkerSpec, tint: Water.Tint, w: Float, h: Float, u: Float, haloColor: Int, t: Float, phaseMs: Float) {
        var tx = (s.x0 - s.x1) * w / u
        var ty = (s.y0 - s.y1) * h / u
        var len = hypot(tx, ty)
        if (len < 6f) { tx = -40f; ty = 40f; len = hypot(tx, ty) }
        val dx = tx / len
        val dy = ty / len
        // The arrow nods toward its target, so the eye is pulled to the right spot.
        val nod = -4f * (0.5f + 0.5f * Water.breathe(phaseMs))
        c.translate(dx * nod, dy * nod)
        val headLen = min(max(22f, t * 4.2f), len * 0.85f)
        val headHalf = max(13f, t * 2.7f)
        val bx = dx * headLen
        val by = dy * headLen
        val px = -dy
        val py = dx
        val head = Path().apply {
            moveTo(0f, 0f)
            lineTo(bx + px * headHalf, by + py * headHalf)
            lineTo(bx - px * headHalf, by - py * headHalf)
            close()
        }
        val shaft = Path().apply { moveTo(tx, ty); lineTo(bx, by) }
        // halo
        c.drawPath(shaft, stroke(haloColor, t + HALO_U * 2))
        c.drawPath(head, stroke(haloColor, HALO_U * 2))
        // colour: the pale band flows along the shaft toward the head
        val flow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = t; strokeCap = Paint.Cap.ROUND
            shader = Water.flowing(tint, tx, ty, 0f, 0f, phaseMs)
        }
        c.drawPath(shaft, flow)
        val headPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                bx, by, 0f, 0f, intArrayOf(tint.mid, tint.light, tint.mid), floatArrayOf(0f, 0.6f, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        c.drawPath(head, headPaint)
        c.drawPath(head, stroke(tint.deep, 1.5f))
    }

    private fun drawFrame(c: Canvas, s: MarkerSpec, tint: Water.Tint, w: Float, h: Float, u: Float, haloColor: Int, t: Float, phaseMs: Float) {
        val ex = max(abs(s.x1 - s.x0) * w / (2 * u), 6f)
        val ey = max(abs(s.y1 - s.y0) * h / (2 * u), 6f)
        val rect = RectF(-ex, -ey, ex, ey)
        val corner = min(8f, min(ex, ey))
        val path = Path().apply {
            if (s.type == MarkerType.CIRCLE) addOval(rect, Path.Direction.CW)
            else addRoundRect(rect, corner, corner, Path.Direction.CW)
        }
        // Water inside the frame: a faint gradient that drifts, a soft glow and a turning shine on the edge.
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = Water.flowing(tint, -ex, -ey, ex, ey, phaseMs, alpha = 0.2f)
        }
        c.drawPath(path, body)
        c.drawPath(path, stroke(Water.scaleA(tint.light, 0.22f), t + 7f))
        c.drawPath(path, stroke(haloColor, t + HALO_U * 2))
        val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = t; strokeJoin = Paint.Join.ROUND
            shader = Water.turning(tint, 0f, 0f, phaseMs)
        }
        c.drawPath(path, edge)
    }

    private fun drawPen(c: Canvas, s: MarkerSpec, tint: Water.Tint, w: Float, h: Float, u: Float, haloColor: Int, t: Float, phaseMs: Float) {
        val p = s.points
        val b = penBounds(s)
        val cx = b.centerX()
        val cy = b.centerY()
        fun lx(i: Int) = (p[i] - cx) * w / u
        fun ly(i: Int) = (p[i + 1] - cy) * h / u
        if (p.size < 4) {
            c.drawCircle(0f, 0f, t / 2 + HALO_U, fill(haloColor))
            Water.sphere(c, tint, 0f, 0f, t / 2 + 1f)
            return
        }
        val path = Path()
        path.moveTo(lx(0), ly(0))
        var i = 2
        while (i + 3 < p.size) {
            val mx = (lx(i) + lx(i + 2)) / 2
            val my = (ly(i) + ly(i + 2)) / 2
            path.quadTo(lx(i), ly(i), mx, my)
            i += 2
        }
        path.lineTo(lx(p.size - 2), ly(p.size - 2))
        c.drawPath(path, stroke(haloColor, t + HALO_U * 2))
        val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = t; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
            shader = Water.flowing(tint, lx(0), ly(0), lx(p.size - 2), ly(p.size - 2), phaseMs)
        }
        c.drawPath(path, ink)
    }

    /** The converging "cue" ring (or contracting outline for frames) at progress 0..1. */
    fun drawCue(c: Canvas, s: MarkerSpec, w: Float, h: Float, ax: Float, ay: Float, progress: Float) {
        val u = w / 360f
        val k = s.scale
        val p = progress.coerceIn(0f, 1f)
        val a = (0.25f + 0.75f * p) * s.opacity.coerceIn(0.4f, 1f)
        val halo = withAlpha(haloColor(CUE_COLOR), 0.55f * a)
        val ring = withAlpha(CUE_COLOR, a)
        c.save()
        c.translate(ax, ay)
        c.rotate(s.rotationDeg)
        c.scale(u * k, u * k)
        when (s.type) {
            MarkerType.CIRCLE, MarkerType.RECT -> {
                val f = 1f + 0.7f * (1f - p)
                val ex = max(abs(s.x1 - s.x0) * w / (2 * u), 6f) * f
                val ey = max(abs(s.y1 - s.y0) * h / (2 * u), 6f) * f
                val rect = RectF(-ex, -ey, ex, ey)
                val path = Path().apply {
                    if (s.type == MarkerType.CIRCLE) addOval(rect, Path.Direction.CW)
                    else addRoundRect(rect, 8f * f, 8f * f, Path.Direction.CW)
                }
                c.drawPath(path, stroke(halo, 3f + HALO_U * 2))
                c.drawPath(path, cueStroke(ring, p, 3f))
            }
            MarkerType.PEN -> Unit
            else -> {
                val base = when (s.type) {
                    MarkerType.FINGER -> 28f
                    MarkerType.RIPPLE -> 32f
                    MarkerType.NUMBER -> 20f
                    else -> 22f
                }
                val r = base * (1f + 1.9f * (1f - p))
                c.drawCircle(0f, 0f, r, stroke(halo, 3f + HALO_U * 2))
                c.drawCircle(0f, 0f, r, cueStroke(ring, p, 3f))
            }
        }
        c.restore()
    }

    /** The amber cue ring, as a sweep gradient that spins while it contracts. */
    private fun cueStroke(ring: Int, progress: Float, width: Float): Paint {
        val t = Water.tint(CUE_COLOR)
        val a = Color.alpha(ring) / 255f
        return Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = width; strokeCap = Paint.Cap.ROUND
            shader = Water.turning(t, 0f, 0f, progress * Water.PERIOD_MS * 1.5f, a)
        }
    }

    private fun withAlpha(color: Int, a: Float): Int =
        Color.argb((Color.alpha(color) * a.coerceIn(0f, 1f)).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    /** Small glyph for tool buttons: drawn centred in a [size] px square at ([cx], [cy]). */
    fun drawIcon(c: Canvas, type: MarkerType, cx: Float, cy: Float, size: Float, color: Int) {
        val s = size / 24f
        c.save()
        c.translate(cx, cy)
        c.scale(s, s)
        val sw = 2.2f
        when (type) {
            MarkerType.FINGER -> {
                c.translate(-FINGER_VIEWBOX / 2, -FINGER_VIEWBOX / 2)
                c.drawPath(fingerPath, fill(color))
            }
            MarkerType.RIPPLE -> {
                c.drawCircle(0f, 0f, 3f, fill(color))
                c.drawCircle(0f, 0f, 7f, stroke(color, sw))
                c.drawCircle(0f, 0f, 11f, stroke(withAlpha(color, 0.55f), sw))
            }
            MarkerType.ARROW -> {
                val head = Path().apply { moveTo(-9f, 9f); lineTo(1f, -1f) }
                c.drawPath(head, stroke(color, sw + 0.6f))
                val tri = Path().apply { moveTo(9f, -9f); lineTo(-1f, -7f); lineTo(7f, 1f); close() }
                c.drawPath(tri, fill(color))
            }
            MarkerType.CIRCLE -> c.drawOval(RectF(-10f, -10f, 10f, 10f), stroke(color, sw))
            MarkerType.RECT -> c.drawRoundRect(RectF(-10f, -8f, 10f, 8f), 3f, 3f, stroke(color, sw))
            MarkerType.PEN -> {
                val p = Path().apply {
                    moveTo(-10f, 6f)
                    cubicTo(-6f, -10f, -2f, 10f, 2f, -2f)
                    cubicTo(4f, -7f, 8f, -6f, 10f, -8f)
                }
                c.drawPath(p, stroke(color, sw + 0.4f))
            }
            MarkerType.NUMBER -> {
                c.drawCircle(0f, 0f, 10.5f, fill(color))
                val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.color = haloColor(color); textAlign = Paint.Align.CENTER
                    typeface = this@MarkerRenderer.typeface; textSize = 14f
                }
                c.drawText("1", 0f, -(p.ascent() + p.descent()) / 2f, p)
            }
        }
        c.restore()
    }

    /**
     * Renders the marker body alone into a square bitmap sized to its bounds, for the editor.
     * The anchor sits at the bitmap centre; [Rendered.halfPx] tells the caller how far it extends.
     */
    class Rendered(val bitmap: Bitmap, val halfPx: Float)

    fun renderBody(s: MarkerSpec, frameW: Int, frameH: Int, withCueGhost: Boolean = false, phaseMs: Float = 0f): Rendered {
        val w = frameW.toFloat()
        val h = frameH.toFloat()
        val u = w / 360f
        val half = radiusU(s, w, h) * u * max(1f, s.scale * 1.1f)
        val size = max(8, (half * 2).toInt())
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawBody(canvas, s, w, h, size / 2f, size / 2f, phaseMs = phaseMs)
        if (withCueGhost) drawCue(canvas, s, w, h, size / 2f, size / 2f, 0f)
        return Rendered(bmp, size / 2f)
    }
}
