package com.huluca.escreenrecorder.export

import java.util.Random
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.sin
import kotlin.math.sqrt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DspTest {
    private val rate = 8000

    private fun rms(x: FloatArray, from: Int, to: Int): Double {
        var s = 0.0
        for (i in from until to) s += x[i] * x[i]
        return sqrt(s / (to - from))
    }

    private fun db(a: Double, b: Double) = 20 * log10(a / b)

    /** 0.8 s of noise, then 1.6 s of a 440 Hz tone over the same noise. */
    private fun noisyVoice(): FloatArray {
        val r = Random(7)
        return FloatArray((2.4 * rate).toInt()) { i ->
            val noise = (r.nextGaussian() * 0.03).toFloat()
            val tone = if (i >= 0.8 * rate) (0.3 * sin(2 * PI * 440 * i / rate)).toFloat() else 0f
            noise + tone
        }
    }

    @Test fun fftRoundTrip() {
        val re = DoubleArray(64) { sin(it * 0.3) + 0.2 * it }
        val im = DoubleArray(64)
        val copy = re.copyOf()
        Dsp.fft(re, im, false)
        Dsp.fft(re, im, true)
        for (i in re.indices) assertEquals(copy[i], re[i], 1e-9)
    }

    @Test fun fftFindsTheTone() {
        val n = 1024
        val re = DoubleArray(n) { sin(2 * PI * 64 * it / n) }
        val im = DoubleArray(n)
        Dsp.fft(re, im, false)
        val mags = DoubleArray(n / 2) { Math.hypot(re[it], im[it]) }
        assertEquals(64, mags.indices.maxByOrNull { mags[it] })
    }

    @Test fun noiseReductionQuietsTheNoiseAndKeepsTheVoice() {
        val x = noisyVoice()
        val before = rms(x, 1000, 5000)
        val strong = Dsp.denoise(x, "strong")
        val light = Dsp.denoise(x, "light")
        val s = rms(strong, 1000, 5000)
        val l = rms(light, 1000, 5000)
        // pause: strong takes the noise down by well over 10 dB, light by less
        assertTrue("strong ${db(s, before)} dB", db(s, before) < -10)
        assertTrue("light ${db(l, before)} dB", db(l, before) < -3)
        assertTrue("light is gentler than strong", l > s)
        // speech part: the tone survives within 2 dB
        val tone = rms(x, 8000, 17000)
        assertEquals(0.0, db(rms(strong, 8000, 17000), tone), 2.0)
        assertEquals(0.0, db(rms(light, 8000, 17000), tone), 1.5)
        assertEquals(x.size, strong.size)
        assertTrue(strong.all { it.isFinite() })
    }

    @Test fun noiseReductionOffChangesNothing() {
        val x = noisyVoice()
        assertEquals(x.toList(), Dsp.denoise(x, "off").toList())
        assertNull(Dsp.denoiseParams("off"))
        assertNotNull(Dsp.denoiseParams("light"))
    }

    @Test fun veryShortSoundIsLeftAlone() {
        val x = FloatArray(500) { 0.1f }
        assertEquals(x.toList(), Dsp.denoise(x, "strong").toList())
    }

    @Test fun echoRepeatsAfter280ms() {
        val x = FloatArray(rate) { if (it == 0) 1f else 0f }
        val y = Dsp.echo(x, rate)
        val d = (rate * 0.28).toInt()
        assertEquals(1f, y[0], 1e-6f)
        assertEquals(0.42f, y[d], 1e-6f)
        assertEquals(0.42f * 0.42f, y[2 * d], 1e-6f)
    }

    @Test fun reverbAddsATailAndKeepsTheDirectSound() {
        val x = FloatArray(rate) { if (it == 0) 1f else 0f }
        val y = Dsp.reverb(x, rate)
        assertTrue(y[0] > 0.4f)
        assertTrue("a tail after 100 ms", rms(y, (0.1 * rate).toInt(), (0.4 * rate).toInt()) > 1e-4)
        assertTrue(y.all { it.isFinite() })
    }

    @Test fun robotChangesTheSoundButNotTheLength() {
        val x = FloatArray(rate) { (0.4 * sin(2 * PI * 200 * it / rate)).toFloat() }
        val y = Dsp.robot(x, rate)
        assertEquals(x.size, y.size)
        assertTrue(rms(y, 0, y.size) > 0.05)
        assertTrue(x.indices.any { abs(x[it] - y[it]) > 0.05f })
        assertTrue(y.all { it.isFinite() })
    }

    @Test fun limiterNeverClipsAndNeverDistorts() {
        val a = floatArrayOf(0.5f, 1.5f, -0.75f)
        Dsp.limit(arrayOf(a))
        assertTrue(a.all { abs(it) <= 0.97f + 1e-6f })
        assertEquals(1.5f / 0.5f, a[1] / a[0], 1e-4f) // same shape, only quieter
        val quiet = floatArrayOf(0.2f, -0.3f)
        Dsp.limit(arrayOf(quiet))
        assertEquals(listOf(0.2f, -0.3f), quiet.toList())
    }

    @Test fun pitchRatios() {
        assertEquals(1f, VoiceFxMath.pitchOf("none"), 0f)
        assertEquals(1f, VoiceFxMath.pitchOf("robot"), 0f)
        assertTrue(VoiceFxMath.pitchOf("deep") < 1f)
        assertTrue(VoiceFxMath.pitchOf("high") in 1.1f..1.4f)
        assertTrue(VoiceFxMath.pitchOf("chipmunk") > VoiceFxMath.pitchOf("high"))
        assertTrue(VoiceFxMath.isKnown("reverb"))
        assertTrue(!VoiceFxMath.isKnown("laser"))
    }
}
