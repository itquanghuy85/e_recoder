package com.huluca.escreenrecorder.marker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Same vectors as test/marker_timing_test.dart — the two implementations must agree. */
class MarkerAnimTest {
    private val never = Long.MAX_VALUE
    private val eps = 1e-5f

    @Test fun beforeCueNothingShows() {
        val f = MarkerAnim.frame(-5, never)
        assertEquals(0f, f.bodyAlpha, eps)
        assertFalse(f.done)
    }

    @Test fun cueConvergesAndBodyIsGhost() {
        val s = MarkerAnim.frame(0, never)
        assertEquals(0f, s.cueProgress, eps)
        assertEquals(MarkerAnim.GHOST_ALPHA, s.bodyAlpha, eps)
        assertEquals(0.875f, MarkerAnim.frame(250, never).cueProgress, eps)
    }

    @Test fun takeIsSolidWithPressPulse() {
        val take = MarkerAnim.frame(500, never)
        assertEquals(-1f, take.cueProgress, eps)
        assertEquals(1f, take.bodyAlpha, eps)
        assertEquals(0f, take.press, eps)
        assertEquals(1f, MarkerAnim.frame(630, never).press, eps)
        assertEquals(0f, MarkerAnim.frame(900, never).press, eps)
    }

    @Test fun popOvershootsThenSettles() {
        assertTrue(MarkerAnim.frame(570, never).bodyScale > 0.88f)
        assertEquals(1f, MarkerAnim.frame(640, never).bodyScale, eps)
    }

    @Test fun fadeFollowsTheHold() {
        val fadeStart = 500L + 2500L
        assertEquals(1f, MarkerAnim.frame(fadeStart, fadeStart).bodyAlpha, eps)
        val half = MarkerAnim.frame(fadeStart + 150, fadeStart)
        assertEquals(0.5f, half.bodyAlpha, eps)
        assertFalse(half.done)
        val end = MarkerAnim.frame(fadeStart + 300, fadeStart)
        assertEquals(0f, end.bodyAlpha, eps)
        assertTrue(end.done)
    }

    @Test fun fadeNeverStartsBeforeCueEnds() {
        assertEquals(MarkerAnim.GHOST_ALPHA, MarkerAnim.frame(100, 0).bodyAlpha, eps)
    }
}
