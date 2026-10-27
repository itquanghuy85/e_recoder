package com.huluca.escreenrecorder.export

import android.graphics.Matrix
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.RgbMatrix
import java.nio.ByteBuffer
import kotlin.math.roundToInt

/**
 * Volume and linear fades for one piece of a segment (16-bit PCM). Placed AFTER the speed processor, so
 * the samples it counts are output samples and its time is output time. [offsetMs] is where this piece
 * starts inside the segment's output, so the fades run across the whole segment even when a speed ramp
 * has cut it into several clips.
 */
@UnstableApi
class GainAudioProcessor(
    private val volume: Float,
    private val fadeInMs: Long,
    private val fadeOutMs: Long,
    private val segmentOutLenMs: Long,
    private val offsetMs: Long,
    /** Output time at which this clip's first sample sounds (for ducking under a voice-over). */
    private val absStartMs: Long = 0,
    /** Voice-over spans [startOutMs, endOutMs] that lower this track (music only). */
    private val duck: List<LongArray> = emptyList(),
) : BaseAudioProcessor() {
    private var frames = 0L
    private var gain = 1f

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        return inputAudioFormat
    }

    override fun onFlush() {
        frames = 0
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val size = inputBuffer.remaining()
        if (size == 0) return
        val out = replaceOutputBuffer(size)
        val channels = inputAudioFormat.channelCount
        val rate = inputAudioFormat.sampleRate
        while (inputBuffer.remaining() >= 2 * channels) {
            // The gain changes slowly: recompute it every 256 frames.
            if (frames % 256 == 0L) {
                val t = offsetMs + frames * 1000 / rate
                gain = SegmentPlan.gainAt(volume, fadeInMs, fadeOutMs, t, segmentOutLenMs)
                if (duck.isNotEmpty()) gain *= AudioDuck.factor(absStartMs + frames * 1000 / rate, duck)
            }
            for (c in 0 until channels) {
                val v = (inputBuffer.short * gain).roundToInt().coerceIn(-32768, 32767)
                out.putShort(v.toShort())
            }
            frames++
        }
        out.flip()
    }
}

/** Slide / zoom part of a transition (the picture's shift and scale around the cut). */
@UnstableApi
class TransitionShift(
    private val transitions: SegmentTransitions,
    private val clock: ItemClock,
    private val segmentOutLenMs: Long,
    private val offsetMs: Long,
) : MatrixTransformation {
    override fun getMatrix(presentationTimeUs: Long): Matrix {
        val t = offsetMs + clock.elapsedMs(presentationTimeUs)
        val look = transitions.lookAt(t, segmentOutLenMs)
        val m = Matrix()
        if (look.scale != 1f) m.postScale(look.scale, look.scale)
        if (look.dx != 0f || look.dy != 0f) m.postTranslate(look.dx, look.dy)
        return m
    }
}

/**
 * Colour part of a transition (dip to black / white, zoom fade) and, in the same pass, a fixed colour
 * adjustment of the whole video. Column-major 4x4: rgb' = M * (r, g, b, 1).
 */
@UnstableApi
class LookColor(
    private val transitions: SegmentTransitions,
    private val clock: ItemClock,
    private val segmentOutLenMs: Long,
    private val offsetMs: Long,
    /** Fixed colour adjustment (null = none), column-major 4x4. */
    private val base: FloatArray? = null,
) : RgbMatrix {
    override fun getMatrix(presentationTimeUs: Long, useHdr: Boolean): FloatArray {
        val t = offsetMs + clock.elapsedMs(presentationTimeUs)
        val look = transitions.lookAt(t, segmentOutLenMs)
        val m = base?.copyOf() ?: identity()
        if (look.mul != 1f || look.add != 0f) {
            // Fade after the adjustment: scale rgb by mul, then add.
            for (col in 0..3) for (row in 0..2) m[col * 4 + row] *= look.mul
            m[12] += look.add
            m[13] += look.add
            m[14] += look.add
        }
        return m
    }

    companion object {
        fun identity() = floatArrayOf(1f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 1f)
    }
}

/** Music level while a voice-over speaks. Mirror of AudioTrack.duckFactor in audio_track.dart. */
object AudioDuck {
    const val LEVEL = 0.3f
    const val RAMP_MS = 250f

    fun factor(outMs: Long, ranges: List<LongArray>): Float {
        var f = 1f
        for (r in ranges) {
            val a = r[0]
            val b = r[1]
            val k = when {
                outMs in a..b -> LEVEL
                outMs < a && a - outMs < RAMP_MS -> 1 - (1 - LEVEL) * (1 - (a - outMs) / RAMP_MS)
                outMs > b && outMs - b < RAMP_MS -> 1 - (1 - LEVEL) * (1 - (outMs - b) / RAMP_MS)
                else -> continue
            }
            if (k < f) f = k
        }
        return f
    }
}
