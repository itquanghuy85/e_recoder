package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/** Golden values shared with test/pro_model_test.dart: the preview and the exporter must move overlays the same way. */
class OverlayMotionTest {
    private fun at(m: MotionSpec, t: Long, life: Long = 3000) = OverlayMotion.at(m, 0.5f, 0.5f, 1f, 1f, t, life)

    @Test fun fadeInAndOut() {
        val m = MotionSpec.FADE
        assertEquals(0f, at(m, 0).alpha, 1e-6f)
        assertEquals(0.75f, at(m, 110).alpha, 1e-5f)
        assertEquals(1f, at(m, 1500).alpha, 1e-6f)
        assertEquals(0.75f, at(m, 2890).alpha, 1e-5f)
        assertFalse(at(m, 3001).visible)
    }

    @Test fun popGrowsFromSixtyPercent() {
        val s = at(MotionSpec(enter = "pop", exit = "none"), 110)
        assertEquals(0.9f, s.scale, 1e-5f)
        assertEquals(0.75f, s.alpha, 1e-5f)
    }

    @Test fun slideUpEntersBelow() {
        val s = at(MotionSpec(enter = "slideUp", exit = "none"), 0)
        assertEquals(0.58f, s.y, 1e-6f)
        assertEquals(0f, s.alpha, 1e-6f)
    }

    @Test fun keyframeMovesAcrossLife() {
        val m = MotionSpec(endX = 0.9f, ease = "linear", enter = "none", exit = "none")
        assertEquals(0.7f, at(m, 500, 1000).x, 1e-6f)
        assertEquals(0.5f, at(m, 0, 1000).x, 1e-6f)
        assertEquals(0.9f, at(m, 1000, 1000).x, 1e-6f)
    }

    @Test fun duckFactorMatchesDart() {
        val r = listOf(longArrayOf(1000, 3000))
        assertEquals(0.3f, AudioDuck.factor(2000, r), 1e-6f)
        assertEquals(0.3f, AudioDuck.factor(1000, r), 1e-6f)
        assertEquals(0.65f, AudioDuck.factor(875, r), 1e-6f)
        assertEquals(1f, AudioDuck.factor(700, r), 1e-6f)
        assertEquals(0.65f, AudioDuck.factor(3125, r), 1e-6f)
        assertEquals(1f, AudioDuck.factor(3300, r), 1e-6f)
    }
}
