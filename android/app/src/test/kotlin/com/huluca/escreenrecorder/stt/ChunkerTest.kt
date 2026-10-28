package com.huluca.escreenrecorder.stt

import java.util.Random
import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChunkerTest {
    private val rate = Chunker.RATE
    private val rnd = Random(3)

    private fun silence(sec: Double) =
        ShortArray((sec * rate).toInt()) { (rnd.nextGaussian() * 60).toInt().toShort() } // about -55 dBFS

    private fun speech(sec: Double): ShortArray {
        val n = (sec * rate).toInt()
        return ShortArray(n) { i ->
            // a voice-like tone whose loudness swells and falls a few times a second
            val env = 0.5 + 0.5 * sin(2 * PI * 3 * i / rate)
            (6000 * (0.3 + 0.7 * env) * sin(2 * PI * 220 * i / rate)).toInt().toShort()
        }
    }

    private fun cat(vararg parts: ShortArray): ShortArray {
        val out = ShortArray(parts.sumOf { it.size })
        var o = 0
        for (p in parts) { p.copyInto(out, o); o += p.size }
        return out
    }

    private fun ms(samples: Int) = samples * 1000L / rate

    @Test fun findsEachPhraseAtItsPlace() {
        val pcm = cat(silence(1.0), speech(1.5), silence(1.0), speech(0.8), silence(1.0))
        val spans = Chunker.split(pcm)
        assertEquals(2, spans.size)
        // first phrase: 1.0 s .. 2.5 s (with a little padding either side)
        assertTrue(ms(spans[0].start) in 800L..1000L)
        assertTrue(ms(spans[0].end) in 2500L..2800L)
        assertTrue(ms(spans[1].start) in 3350L..3550L)
        assertTrue(ms(spans[1].end) in 4300L..4600L)
    }

    @Test fun aShortPauseDoesNotSplitAPhrase() {
        val pcm = cat(silence(0.5), speech(1.0), silence(0.25), speech(1.0), silence(0.5))
        assertEquals(1, Chunker.split(pcm).size)
    }

    @Test fun silenceHasNoSpeechAndABlipIsIgnored() {
        assertFalse(Chunker.hasSpeech(silence(5.0)))
        assertFalse(Chunker.hasSpeech(cat(silence(1.0), speech(0.1), silence(1.0))))
        assertTrue(Chunker.hasSpeech(cat(silence(1.0), speech(0.6), silence(1.0))))
        assertTrue(Chunker.split(ShortArray(0)).isEmpty())
    }

    @Test fun veryLongSpeechIsCutIntoPhrasesOfALimitedLength() {
        val pcm = cat(silence(0.5), speech(45.0), silence(0.5))
        val spans = Chunker.split(pcm)
        assertTrue(spans.size >= 3)
        for (s in spans) assertTrue(ms(s.end - s.start) <= Chunker.MAX_SPAN_MS + 400)
        for (i in 1 until spans.size) assertTrue(spans[i].start >= spans[i - 1].end)
    }

    @Test fun phrasesNeverOverlapAndStayInside() {
        val pcm = cat(speech(0.7), silence(0.5), speech(0.7), silence(0.5), speech(0.7))
        val spans = Chunker.split(pcm)
        assertEquals(3, spans.size)
        assertTrue(spans.first().start >= 0)
        assertTrue(spans.last().end <= pcm.size)
        for (i in 1 until spans.size) assertTrue(spans[i].start >= spans[i - 1].end)
    }

    @Test fun aNoisyRoomIsNotSpeech() {
        val loudRoom = ShortArray(rate * 5) { (rnd.nextGaussian() * 400).toInt().toShort() } // about -38 dBFS, steady
        // steady noise is the floor itself: nothing stands out of it
        assertFalse(Chunker.hasSpeech(loudRoom))
    }
}
