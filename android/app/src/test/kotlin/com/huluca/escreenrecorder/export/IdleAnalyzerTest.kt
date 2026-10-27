package com.huluca.escreenrecorder.export

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IdleAnalyzerTest {
    private fun frame(v: Int, n: Int = 48 * 84) = IntArray(n) { v }

    @Test fun identicalFramesAreStill() {
        assertTrue(IdleAnalyzer.isStill(frame(120), frame(120)))
    }

    @Test fun compressionNoiseIsStill() {
        val a = frame(120)
        val b = frame(120).also { for (i in it.indices step 7) it[i] += 2 }
        assertTrue(IdleAnalyzer.isStill(a, b))
    }

    @Test fun aSmallButRealChangeIsNotStill() {
        // A button lighting up: ~2% of the pixels change a lot.
        val a = frame(240)
        val b = frame(240).also { for (i in 0 until a.size / 50) it[i] = 40 }
        assertFalse(IdleAnalyzer.isStill(a, b))
    }

    @Test fun aPageChangeIsNotStill() {
        assertFalse(IdleAnalyzer.isStill(frame(240), frame(30)))
    }

    @Test fun differentSizesAreNeverStill() {
        assertFalse(IdleAnalyzer.isStill(frame(1, 10), frame(1, 12)))
    }
}
