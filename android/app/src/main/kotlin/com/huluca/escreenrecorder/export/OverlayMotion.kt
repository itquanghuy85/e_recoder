package com.huluca.escreenrecorder.export

import kotlin.math.max
import kotlin.math.min

/** State of an overlay at one instant. Mirror of motionAt in overlay_motion.dart: keep both in step. */
data class MotionState(val x: Float, val y: Float, val scale: Float, val alpha: Float) {
    val visible get() = alpha > 0.002f && scale > 0.001f
}

object OverlayMotion {
    private val HIDDEN = MotionState(0f, 0f, 0f, 0f)

    fun ease(kind: String, t: Float): Float {
        val x = t.coerceIn(0f, 1f)
        return when (kind) {
            "linear" -> x
            "easeIn" -> x * x
            "easeOut" -> 1 - (1 - x) * (1 - x)
            else -> x * x * (3 - 2 * x)
        }
    }

    /** [t]: time into the overlay's life, which is [lifeMs] long. */
    fun at(m: MotionSpec, x: Float, y: Float, scale: Float, opacity: Float, t: Long, lifeMs: Long): MotionState {
        if (t < 0 || t > lifeMs) return HIDDEN
        var px = x
        var py = y
        var ps = scale
        var pa = opacity
        val hasKey = m.endX != null || m.endY != null || m.endScale != null || m.endOpacity != null
        if (hasKey && lifeMs > 0) {
            val k = ease(m.ease, t.toFloat() / lifeMs)
            px = x + ((m.endX ?: x) - x) * k
            py = y + ((m.endY ?: y) - y) * k
            ps = scale + ((m.endScale ?: scale) - scale) * k
            pa = opacity + ((m.endOpacity ?: opacity) - opacity) * k
        }
        val ms = max(1L, min(m.enterExitMs, lifeMs / 2))
        fun phase(kind: String, u: Float, entering: Boolean) {
            val q = ease("easeOut", u)
            val away = 1 - q
            val sign = if (entering) 1f else -1f
            when (kind) {
                "none" -> {}
                "fade" -> pa *= q
                "pop" -> { pa *= q; ps *= 0.6f + 0.4f * q }
                "slideUp" -> { py += sign * 0.08f * away; pa *= q }
                "slideDown" -> { py -= sign * 0.08f * away; pa *= q }
                "slideLeft" -> { px += sign * 0.08f * away; pa *= q }
                "slideRight" -> { px -= sign * 0.08f * away; pa *= q }
            }
        }
        if (t < ms) phase(m.enter, t.toFloat() / ms, true)
        if (lifeMs - t < ms) phase(m.exit, (lifeMs - t).toFloat() / ms, false)
        return MotionState(px, py, ps, pa.coerceIn(0f, 1f))
    }
}
