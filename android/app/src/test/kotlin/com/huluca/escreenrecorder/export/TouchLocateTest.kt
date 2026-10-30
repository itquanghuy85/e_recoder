package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Finding where a touch was from how the picture reacted (synthetic frames, 108 x 240 like the scan). */
class TouchLocateTest {
    private val w = TouchScan.W
    private val h = TouchScan.H

    private fun frame(bg: Int = 40) = IntArray(w * h) { bg }

    private fun IntArray.fill(x0: Int, y0: Int, x1: Int, y1: Int, v: Int) {
        for (y in y0..y1) for (x in x0..x1) this[y * w + x] = v
    }

    @Test
    fun `a button that lights up is found at its middle`() {
        val a = frame()
        val b = frame().also { it.fill(30, 150, 59, 169, 200) } // a 30 x 20 button
        val p = TouchScan.reaction(a, b)
        assertNotNull(p)
        assertEquals((30 + 59 + 1) / 2.0 / w, p!![0], 0.02)
        assertEquals((150 + 169 + 1) / 2.0 / h, p[1], 0.02)
    }

    @Test
    fun `the biggest changed area wins over a small fleck elsewhere`() {
        val a = frame()
        val b = frame().also {
            it.fill(60, 40, 89, 69, 220) // 30 x 30
            it.fill(5, 5, 7, 7, 220) // a clock tick
        }
        val p = TouchScan.reaction(a, b)!!
        assertEquals(75.0 / w, p[0], 0.02)
        assertEquals(55.0 / h, p[1], 0.02)
    }

    @Test
    fun `a whole page change has no place`() {
        val a = frame()
        val b = frame(200) // everything changed
        assertNull(TouchScan.reaction(a, b))
    }

    @Test
    fun `a big part of the screen changing is a page, not a press`() {
        val a = frame()
        val b = frame().also { it.fill(0, 0, w - 1, h / 2, 220) } // half the screen
        assertNull(TouchScan.reaction(a, b))
    }

    @Test
    fun `nothing changing, or only a few pixels, has no place`() {
        val a = frame()
        assertNull(TouchScan.reaction(a, frame()))
        val b = frame().also { it.fill(10, 10, 14, 14, 220) } // 25 pixels
        val p = TouchScan.reaction(a, frame().also { it[5 * w + 5] = 250 })
        assertNull(p)
        // 25 pixels is above the noise floor: it is a (tiny) reaction
        assertNotNull(TouchScan.reaction(a, b))
    }

    @Test
    fun `frames of different sizes have no place`() {
        assertNull(TouchScan.reaction(IntArray(10), IntArray(12)))
    }

    @Test
    fun `a round show-taps spot is found by the dot rule first`() {
        val a = frame()
        val b = frame().also { it.fill(40, 100, 51, 111, 255) } // a 12 x 12 round-ish spot
        val dot = TouchScan.patch(a, b)
        assertNotNull(dot)
        assertTrue(dot!![0] in 0.35..0.5)
    }
}
