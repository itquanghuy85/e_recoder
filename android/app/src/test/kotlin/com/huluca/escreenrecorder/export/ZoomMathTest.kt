package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Test

/** Same vectors as `zoom math` in test/editor_controller_test.dart. */
class ZoomMathTest {
    private val z = ZoomClip(fx = 0.9f, fy = 0.1f, scale = 2f, startMs = 1000, endMs = 5000)
    private val eps = 1e-5f

    @Test fun noZoomOutsideTheClip() {
        assertEquals(1f, ZoomMath.at(listOf(z), 500).first, eps)
        assertEquals(1f, ZoomMath.at(listOf(z), 5200).first, eps)
    }

    @Test fun rampsAndHolds() {
        assertEquals(1f, ZoomMath.at(listOf(z), 1000).first, eps)
        assertEquals(2f, ZoomMath.at(listOf(z), 3000).first, eps)
        val early = ZoomMath.at(listOf(z), 1175).first
        assert(early > 1f && early < 2f)
    }

    @Test fun rampSpeedIsAdjustable() {
        val slow = ZoomClip(0.5f, 0.5f, 2f, 0, 6000, inMs = 2000, outMs = 100)
        assertEquals(1.5f, ZoomMath.at(listOf(slow), 1000).first, eps)
        assertEquals(1.5f, ZoomMath.at(listOf(slow), 5950).first, eps)
        val instant = ZoomClip(0.5f, 0.5f, 2f, 0, 6000, inMs = 0, outMs = 0)
        assertEquals(2f, ZoomMath.at(listOf(instant), 1).first, eps)
        val tight = ZoomClip(0.5f, 0.5f, 2f, 0, 1000, inMs = 2000, outMs = 2000)
        assertEquals(2f, ZoomMath.at(listOf(tight), 500).first, eps)
    }

    @Test fun windowStaysInsideTheFrame() {
        val (_, cx, cy) = ZoomMath.at(listOf(z), 3000)
        assertEquals(0.75f, cx, eps)
        assertEquals(0.25f, cy, eps)
    }
}
