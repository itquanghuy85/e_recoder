package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SegmentPlanTest {
    private fun seg(start: Long, end: Long, speed: Float, speedEnd: Float? = null, freeze: Long = 0) =
        SegmentSpec(start, end, speed, speedEnd = speedEnd, freezeMs = freeze)

    @Test fun constantSpeedIsOnePart() {
        val p = SegmentPlan.parts(seg(1000, 5000, 2f))
        assertEquals(1, p.size)
        assertEquals(2000L, p[0].outLenMs)
        assertEquals(4000L, p[0].playEndMs)
    }

    // Golden values shared with segment_model_test.dart (goldenTests).
    @Test fun rampLengthsMatchDart() {
        assertEquals(3695L, SegmentPlan.outLengthMs(seg(0, 8000, 1f, 4f)))
        assertEquals(5543L, SegmentPlan.outLengthMs(seg(1000, 7000, 0.5f, 2f)))
    }

    @Test fun rampPartsCoverTheClipExactlyAndSpeedUp() {
        val s = seg(0, 8000, 1f, 4f)
        val parts = SegmentPlan.parts(s)
        assertEquals(SegmentPlan.RAMP_STEPS, parts.size)
        assertEquals(0L, parts.first().playStartMs)
        assertEquals(8000L, parts.last().playEndMs)
        for (i in 1 until parts.size) {
            assertEquals(parts[i - 1].playEndMs, parts[i].playStartMs)
            assertTrue(parts[i].speed > parts[i - 1].speed)
        }
        // piece lengths add up to the segment's output length within rounding
        val sum = parts.sumOf { it.outLenMs }
        assertTrue(Math.abs(sum - SegmentPlan.outLengthMs(s)) <= SegmentPlan.RAMP_STEPS)
    }

    @Test fun stillLastsItsFreezeLength() {
        assertEquals(2500L, SegmentPlan.outLengthMs(seg(3000, 3001, 1f, freeze = 2500)))
    }

    @Test fun gainFollowsVolumeAndFades() {
        assertEquals(0f, SegmentPlan.gainAt(0.5f, 1000, 1000, 0, 4000), 1e-6f)
        assertEquals(0.25f, SegmentPlan.gainAt(0.5f, 1000, 1000, 500, 4000), 1e-6f)
        assertEquals(0.5f, SegmentPlan.gainAt(0.5f, 1000, 1000, 2000, 4000), 1e-6f)
        assertEquals(0.25f, SegmentPlan.gainAt(0.5f, 1000, 1000, 3500, 4000), 1e-6f)
    }

    @Test fun transitionLooksMatchDartGoldens() {
        val a = TransitionLook.of("dipWhite", 0.25f, true)
        assertEquals(0.15625f, a.mul, 1e-6f)
        assertEquals(0.84375f, a.add, 1e-6f)
        assertEquals(-1.0f, TransitionLook.of("slideLeft", 0.5f, false).dx, 1e-6f)
        val z = TransitionLook.of("zoom", 0.5f, true)
        assertEquals(1.25f, z.scale, 1e-6f)
        assertEquals(0.5f, z.mul, 1e-6f)
    }

    @Test fun lookAroundACutIsNormalAwayFromIt() {
        val tr = SegmentTransitions("dipBlack", 400, "slideLeft", 400)
        assertTrue(tr.lookAt(2000, 5000).isNone)
        assertTrue(tr.lookAt(0, 5000).mul < 0.01f)
        assertTrue(tr.lookAt(4999, 5000).dx < -1.9f)
    }
}
