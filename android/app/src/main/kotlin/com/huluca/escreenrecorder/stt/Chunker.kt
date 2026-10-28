package com.huluca.escreenrecorder.stt

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** One stretch of speech, in samples of the 16 kHz mono signal ([end] exclusive). */
data class Span(val start: Int, val end: Int)

/**
 * Cuts a recording into stretches of speech at its pauses, so a recogniser gets short phrases and
 * every phrase has its own place in time. Pure and unit tested.
 */
object Chunker {
    const val RATE = 16_000
    private const val FRAME = RATE / 50          // 20 ms
    const val MIN_SPEECH_MS = 250
    const val MAX_SPAN_MS = 18_000
    private const val BRIDGE_MS = 450            // pauses shorter than this stay inside one phrase
    private const val PAD_MS = 150

    /** RMS of each 20 ms frame (0..1). */
    fun frameLevels(pcm: ShortArray): FloatArray {
        val n = pcm.size / FRAME
        return FloatArray(n) { f ->
            var s = 0.0
            val o = f * FRAME
            for (k in 0 until FRAME) { val v = pcm[o + k] / 32768.0; s += v * v }
            sqrt(s / FRAME).toFloat()
        }
    }

    fun split(pcm: ShortArray): List<Span> {
        val levels = frameLevels(pcm)
        if (levels.isEmpty()) return emptyList()
        // Speech is clearly above the room: 2.5x the floor, but never below about -44 dBFS.
        val sorted = levels.sortedArray()
        val floor = sorted[max(0, (sorted.size * 0.2).toInt() - 1)]
        val threshold = max(floor * 2.5f, 0.006f)
        val voiced = BooleanArray(levels.size) { levels[it] > threshold }
        val bridge = BRIDGE_MS / 20
        val minLen = MIN_SPEECH_MS / 20
        val raw = ArrayList<IntArray>() // frame ranges [a, b)
        var i = 0
        while (i < voiced.size) {
            if (!voiced[i]) { i++; continue }
            var a = i
            var b = i
            var gap = 0
            while (i < voiced.size && gap <= bridge) {
                if (voiced[i]) { b = i + 1; gap = 0 } else gap++
                i++
            }
            if (b - a >= minLen) raw.add(intArrayOf(a, b))
        }
        // very long phrases are cut at their quietest moment
        val maxFrames = MAX_SPAN_MS / 20
        val spans = ArrayList<IntArray>()
        for (r in raw) {
            var a = r[0]
            while (r[1] - a > maxFrames) {
                val from = a + maxFrames * 2 / 3
                val to = a + maxFrames
                var cut = from
                for (f in from until to) if (levels[f] < levels[cut]) cut = f
                spans.add(intArrayOf(a, cut))
                a = cut
            }
            spans.add(intArrayOf(a, r[1]))
        }
        val pad = PAD_MS / 20
        return spans.map {
            Span(
                max(0, it[0] - pad) * FRAME,
                min(levels.size, it[1] + pad) * FRAME,
            )
        }.fold(ArrayList<Span>()) { acc, s ->
            // padding must not make two phrases overlap
            val last = acc.lastOrNull()
            acc.add(if (last != null && s.start < last.end) Span(last.end, max(last.end, s.end)) else s)
            acc
        }.filter { it.end - it.start >= RATE / 10 }
    }

    /** True when the signal has any speech-like content at all (a silent video has none). */
    fun hasSpeech(pcm: ShortArray) = split(pcm).isNotEmpty()

    fun peak(pcm: ShortArray): Int {
        var p = 0
        for (v in pcm) p = max(p, abs(v.toInt()))
        return p
    }
}
