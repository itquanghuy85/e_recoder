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

    @Test fun windowStaysInsideTheFrame() {
        val (_, cx, cy) = ZoomMath.at(listOf(z), 3000)
        assertEquals(0.75f, cx, eps)
        assertEquals(0.25f, cy, eps)
    }
}
