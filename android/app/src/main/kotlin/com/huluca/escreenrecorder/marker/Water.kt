package com.huluca.escreenrecorder.marker

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.SweepGradient
import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.sin

/**
 * The "water" look shared by every marker: a colour is never flat but a small gradient (pale
 * highlight, body, deep shade, shifted a little in hue like light through water), surfaces get a
 * glossy highlight, and a slow loop of expanding rings and travelling shine keeps them alive.
 *
 * Everything animated is a pure function of [phaseMs] (time since the take) and repeats every
 * [PERIOD_MS], so the live overlay, the editor preview (pre-rendered phases) and the exported
 * video all show the same motion.
 */
internal object Water {
    const val PERIOD_MS = 1400f

    class Tint(val light: Int, val mid: Int, val deep: Int)

    fun tint(color: Int): Tint {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        val a = Color.alpha(color)
        // Near-black: a deep sea blue instead of a dead grey.
        if (hsv[2] < 0.25f) return Tint(withA(0xFF6E86B0.toInt(), a), color, withA(0xFF05122B.toInt(), a))
        // Near-white / grey: the pale blue of shallow water.
        if (hsv[1] < 0.12f) return Tint(color, color, withA(0xFF8EC4EA.toInt(), a))
        fun hsvColor(h: Float, s: Float, v: Float) =
            Color.HSVToColor(a, floatArrayOf((h + 360f) % 360f, s.coerceIn(0f, 1f), v.coerceIn(0f, 1f)))
        // Warm colours (red, orange, amber) deepen toward crimson; the rest toward the cooler side,
        // so greens turn teal, cyans blue and blues violet: the way colour shifts in water.
        val warm = hsv[0] < 75f || hsv[0] > 345f
        val shift = if (warm) -22f else 24f
        val light = mix(hsvColor(hsv[0] - shift * 0.4f, hsv[1] * 0.5f, hsv[2] + 0.2f), 0xFFFFFFFF.toInt(), 0.18f)
        val deep = hsvColor(hsv[0] + shift, hsv[1] + 0.12f, hsv[2] * 0.62f)
        return Tint(withA(light, a), color, deep)
    }

    fun withA(color: Int, alpha: Int) = Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    fun scaleA(color: Int, k: Float) =
        Color.argb((Color.alpha(color) * k.coerceIn(0f, 1f)).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    fun mix(a: Int, b: Int, t: Float): Int {
        val k = t.coerceIn(0f, 1f)
        fun m(x: Int, y: Int) = (x + (y - x) * k).toInt()
        return Color.argb(m(Color.alpha(a), Color.alpha(b)), m(Color.red(a), Color.red(b)), m(Color.green(a), Color.green(b)), m(Color.blue(a), Color.blue(b)))
    }

    /** 0..1 position in the loop, [offset] shifts it by a fraction of a period. */
    fun loop(phaseMs: Float, offset: Float = 0f): Float {
        val x = phaseMs / PERIOD_MS + offset
        return x - kotlin.math.floor(x)
    }

    fun breathe(phaseMs: Float) = sin(2.0 * PI * loop(phaseMs)).toFloat()

    private fun paint() = Paint(Paint.ANTI_ALIAS_FLAG)

    /** A soft pool of colour under a tap: radial fade from the body colour to nothing. */
    fun pool(c: Canvas, t: Tint, radius: Float, alpha: Float) {
        val p = paint()
        p.shader = RadialGradient(
            0f, 0f, radius,
            intArrayOf(scaleA(t.light, 0.42f * alpha), scaleA(t.mid, 0.2f * alpha), scaleA(t.deep, 0f)),
            floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawCircle(0f, 0f, radius, p)
    }

    /**
     * Rings that start at the centre, widen and fade as they spread, like a drop on still water.
     * Each ring is stroked with a sweep gradient that slowly turns, so the shine travels around it.
     */
    fun rings(
        c: Canvas, t: Tint, halo: Int, phaseMs: Float,
        count: Int = 3, r0: Float = 6f, r1: Float = 38f, widthMax: Float = 3.6f, alpha: Float = 1f,
    ) {
        for (k in 0 until count) {
            val f = loop(phaseMs, k.toFloat() / count)
            val r = r0 + (r1 - r0) * easeOut(f)
            val a = (1f - f).pow(0.9f) * alpha
            if (a < 0.02f) continue
            val w = widthMax * (1f - 0.55f * f) + 0.9f
            val hp = paint().apply { style = Paint.Style.STROKE; strokeWidth = w + 3.2f; color = scaleA(halo, 0.5f * a) }
            c.drawCircle(0f, 0f, r, hp)
            val sp = paint().apply { style = Paint.Style.STROKE; strokeWidth = w; strokeCap = Paint.Cap.ROUND }
            sp.shader = SweepGradient(
                0f, 0f,
                intArrayOf(scaleA(t.light, a), scaleA(t.deep, a), scaleA(t.mid, a), scaleA(t.light, a)),
                floatArrayOf(0f, 0.35f, 0.7f, 1f),
            ).also { sh ->
                val m = Matrix()
                m.setRotate(360f * loop(phaseMs, k * 0.31f))
                sh.setLocalMatrix(m)
            }
            c.drawCircle(0f, 0f, r, sp)
        }
    }

    /** A glossy ball: radial gradient with an off-centre highlight and a small specular dot. */
    fun sphere(c: Canvas, t: Tint, cx: Float, cy: Float, r: Float, alpha: Float = 1f) {
        val p = paint()
        p.shader = RadialGradient(
            cx - r * 0.35f, cy - r * 0.4f, r * 1.5f,
            intArrayOf(scaleA(t.light, alpha), scaleA(t.mid, alpha), scaleA(t.deep, alpha)),
            floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawCircle(cx, cy, r, p)
        val spec = paint().apply { color = Color.argb((190 * alpha).toInt(), 255, 255, 255) }
        c.drawCircle(cx - r * 0.5f, cy - r * 0.56f, r * 0.15f, spec)
    }

    /**
     * A gradient for a stroke or shape running from ([x0], [y0]) to ([x1], [y1]): deep at the ends,
     * pale in the middle, and the pale band travels along the line as [phaseMs] advances.
     */
    fun flowing(t: Tint, x0: Float, y0: Float, x1: Float, y1: Float, phaseMs: Float, alpha: Float = 1f): Shader {
        val dx = x1 - x0
        val dy = y1 - y0
        val g = LinearGradient(
            x0, y0, x1, y1,
            intArrayOf(scaleA(t.deep, alpha), scaleA(t.mid, alpha), scaleA(t.light, alpha), scaleA(t.mid, alpha), scaleA(t.deep, alpha)),
            floatArrayOf(0f, 0.3f, 0.5f, 0.7f, 1f), Shader.TileMode.MIRROR,
        )
        val m = Matrix()
        m.setTranslate(dx * (loop(phaseMs) * 2f - 1f) * 0.5f, dy * (loop(phaseMs) * 2f - 1f) * 0.5f)
        g.setLocalMatrix(m)
        return g
    }

    /** Sweep gradient for outlines (frames), rotating slowly. */
    fun turning(t: Tint, cx: Float, cy: Float, phaseMs: Float, alpha: Float = 1f): Shader {
        val g = SweepGradient(
            cx, cy,
            intArrayOf(scaleA(t.mid, alpha), scaleA(t.light, alpha), scaleA(t.deep, alpha), scaleA(t.mid, alpha)),
            floatArrayOf(0f, 0.3f, 0.7f, 1f),
        )
        val m = Matrix()
        m.setRotate(360f * loop(phaseMs), cx, cy)
        g.setLocalMatrix(m)
        return g
    }

    private fun easeOut(t: Float) = 1f - (1f - t.coerceIn(0f, 1f)).pow(2)
}
