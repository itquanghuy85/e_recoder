package com.huluca.escreenrecorder.marker

import kotlin.math.pow

/**
 * "Cue → take" timing. A marker is first CUED (an amber ring contracts onto the target
 * while the marker is a faint ghost), then TAKEN (solid, with a short press pulse), held,
 * and finally faded. The Dart editor mirrors this file in `lib/features/marker/marker_timing.dart`;
 * both are covered by the same test vectors.
 */
object MarkerAnim {
    const val CUE_MS = 500L

    /** Range of the "keep the marker" setting (mirror of MarkerTiming.minHoldMs / maxHoldMs). */
    const val MIN_HOLD_MS = 500L
    const val MAX_HOLD_MS = 10_000L
    const val POP_MS = 140L
    const val PRESS_MS = 260L
    const val FADE_MS = 300L
    const val GHOST_ALPHA = 0.22f

    /**
     * @param cueProgress 0..1 while the cue ring is converging, -1 once the cue is over.
     * @param bodyAlpha   0..1 multiplier for the marker body.
     * @param bodyScale   pop-in scale of the body (1 = rest).
     * @param press       0..1..0 pulse right after the take (finger dips, ripple expands).
     * @param done        true once the marker has fully faded out.
     */
    data class Frame(
        val cueProgress: Float,
        val bodyAlpha: Float,
        val bodyScale: Float,
        val press: Float,
        val done: Boolean,
    )

    /** Standard ease-out cubic. */
    fun easeOut(t: Float): Float = 1f - (1f - t.coerceIn(0f, 1f)).pow(3)

    /** Ease-out with a slight overshoot, used for the pop-in. */
    fun easeOutBack(t: Float): Float {
        val c1 = 1.70158f
        val c3 = c1 + 1f
        val x = t.coerceIn(0f, 1f) - 1f
        return 1f + c3 * x * x * x + c1 * x * x
    }

    /**
     * @param tMs        time since the cue started.
     * @param fadeStartMs when the fade begins (>= CUE_MS); use Long.MAX_VALUE while the marker
     *                    must stay (live annotating).
     */
    fun frame(tMs: Long, fadeStartMs: Long): Frame {
        if (tMs < 0) return Frame(0f, 0f, 1f, 0f, false)
        val fadeStart = maxOf(fadeStartMs, CUE_MS)
        var fade = 1f
        var done = false
        if (fadeStart != Long.MAX_VALUE && tMs > fadeStart) {
            fade = 1f - ((tMs - fadeStart).toFloat() / FADE_MS).coerceIn(0f, 1f)
            done = tMs >= fadeStart + FADE_MS
        }
        if (tMs < CUE_MS) {
            val p = easeOut(tMs.toFloat() / CUE_MS)
            return Frame(p, GHOST_ALPHA * fade, 1f, 0f, done)
        }
        val since = tMs - CUE_MS
        val pop = easeOutBack(since.toFloat() / POP_MS)
        val scale = 0.88f + 0.12f * pop
        val pressT = (since.toFloat() / PRESS_MS).coerceIn(0f, 1f)
        val press = if (pressT >= 1f) 0f else kotlin.math.sin(Math.PI * pressT).toFloat()
        return Frame(-1f, fade, scale, press, done)
    }
}
