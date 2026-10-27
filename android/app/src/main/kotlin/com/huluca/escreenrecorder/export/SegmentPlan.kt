package com.huluca.escreenrecorder.export

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToLong

/**
 * One constant-speed piece of a segment. A speed ramp becomes [RAMP_STEPS] pieces (each its own clip
 * in the sequence), which keeps every piece on the well-trodden constant-speed path of the encoder.
 *
 * All times are milliseconds. [playStartMs]/[playEndMs] are offsets along the PLAYING direction of the
 * segment (0 .. source length); for a reversed segment they index the reversed copy of the clip.
 */
data class Part(
    val playStartMs: Long,
    val playEndMs: Long,
    val speed: Float,
    /** Where this piece starts inside the segment's output (ms). */
    val outOffsetMs: Long,
    val outLenMs: Long,
)

/** The look of one frame during a transition. Mirror of TransitionLook in segment.dart. */
data class TransitionLook(
    val mul: Float = 1f,
    val add: Float = 0f,
    val dx: Float = 0f,
    val dy: Float = 0f,
    val scale: Float = 1f,
) {
    val isNone get() = mul == 1f && add == 0f && dx == 0f && dy == 0f && scale == 1f

    companion object {
        val NONE = TransitionLook()

        private fun smooth(x: Float): Float {
            val t = x.coerceIn(0f, 1f)
            return t * t * (3 - 2 * t)
        }

        /** [u]: 0 = at the cut, 1 = a normal picture again. */
        fun of(kind: String, u: Float, incoming: Boolean): TransitionLook {
            val q = smooth(u)
            val away = 1 - q
            return when (kind) {
                "dipBlack" -> TransitionLook(mul = q)
                "dipWhite" -> TransitionLook(mul = q, add = away)
                "slideLeft", "slideRight", "slideUp", "slideDown" -> {
                    val mx = when (kind) { "slideLeft" -> -1f; "slideRight" -> 1f; else -> 0f }
                    val my = when (kind) { "slideUp" -> 1f; "slideDown" -> -1f; else -> 0f }
                    val s = (if (incoming) -1f else 1f) * away * 2
                    TransitionLook(dx = mx * s, dy = my * s)
                }
                "zoom" -> TransitionLook(mul = q, scale = 1 + away * 0.5f)
                else -> NONE
            }
        }

        fun strongest(a: TransitionLook, b: TransitionLook): TransitionLook {
            if (a.isNone) return b
            if (b.isNone) return a
            return if (a.mul <= b.mul && kotlin.math.abs(a.dx) + kotlin.math.abs(a.dy) >= kotlin.math.abs(b.dx) + kotlin.math.abs(b.dy)) a else b
        }
    }
}

/** Transition around one segment: what the picture does at the start and at the end of the segment. */
data class SegmentTransitions(
    val inKind: String?,
    val inHalfMs: Long,
    val outKind: String?,
    val outHalfMs: Long,
) {
    /** [localOutMs]: output time inside the segment; [outLenMs]: the segment's output length. */
    fun lookAt(localOutMs: Long, outLenMs: Long): TransitionLook {
        var look = TransitionLook.NONE
        if (inKind != null && inHalfMs > 0 && localOutMs < inHalfMs) {
            look = TransitionLook.of(inKind, localOutMs.toFloat() / inHalfMs, true)
        }
        if (outKind != null && outHalfMs > 0 && outLenMs - localOutMs < outHalfMs) {
            look = TransitionLook.strongest(
                look,
                TransitionLook.of(outKind, (outLenMs - localOutMs).toFloat() / outHalfMs, false),
            )
        }
        return look
    }

    companion object { val NONE = SegmentTransitions(null, 0, null, 0) }
}

object SegmentPlan {
    const val RAMP_STEPS = 24

    /** Speed of ramp step [k] (same formula as Segment._stepSpeed in segment.dart). */
    fun stepSpeed(speed: Float, speedEnd: Float, k: Int): Float =
        speed + (speedEnd - speed) * (k + 0.5f) / RAMP_STEPS

    fun isRamp(seg: SegmentSpec) =
        seg.freezeMs <= 0 && seg.speedEnd != null && kotlin.math.abs(seg.speedEnd - seg.speed) > 0.01f

    /** Pieces of a normal (non-still) segment in play order. */
    fun parts(seg: SegmentSpec): List<Part> {
        val len = max(0L, seg.endMs - seg.startMs)
        if (!isRamp(seg)) {
            val out = (len / seg.speed).roundToLong()
            return listOf(Part(0, len, seg.speed, 0, out))
        }
        val step = len.toDouble() / RAMP_STEPS
        val list = ArrayList<Part>(RAMP_STEPS)
        var outAcc = 0.0
        for (k in 0 until RAMP_STEPS) {
            val a = (step * k).roundToLong()
            val b = if (k == RAMP_STEPS - 1) len else (step * (k + 1)).roundToLong()
            val v = stepSpeed(seg.speed, seg.speedEnd!!, k)
            val out = (b - a) / v.toDouble()
            list.add(Part(a, b, v, outAcc.roundToLong(), out.roundToLong()))
            outAcc += out
        }
        return list
    }

    /** Output length of a segment (ms): a still lasts [SegmentSpec.freezeMs]. */
    fun outLengthMs(seg: SegmentSpec): Long {
        if (seg.freezeMs > 0) return seg.freezeMs
        val len = max(0L, seg.endMs - seg.startMs).toDouble()
        if (!isRamp(seg)) return (len / seg.speed).roundToLong()
        val step = len / RAMP_STEPS
        var out = 0.0
        for (k in 0 until RAMP_STEPS) out += step / stepSpeed(seg.speed, seg.speedEnd!!, k)
        return out.roundToLong()
    }

    /** Audio gain at [outOffsetMs] of a segment [outLenMs] long (volume and linear fades). */
    fun gainAt(volume: Float, fadeInMs: Long, fadeOutMs: Long, outOffsetMs: Long, outLenMs: Long): Float {
        var g = volume
        if (fadeInMs > 0 && outOffsetMs < fadeInMs) g *= (outOffsetMs.toFloat() / fadeInMs).coerceIn(0f, 1f)
        val left = outLenMs - outOffsetMs
        if (fadeOutMs > 0 && left < fadeOutMs) g *= (left.toFloat() / fadeOutMs).coerceIn(0f, 1f)
        return g
    }

    /** Index of the ramp step at play offset [p] (for tests and the preview parity check). */
    fun stepAt(lengthMs: Long, p: Double): Int =
        min(RAMP_STEPS - 1, max(0, floor(p / lengthMs * RAMP_STEPS).toInt()))
}
