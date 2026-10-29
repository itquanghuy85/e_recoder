package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TouchScanTest {
    private val w = TouchScan.W
    private val h = TouchScan.H

    private fun blank(v: Int = 40) = IntArray(w * h) { v }

    private fun disc(f: IntArray, cx: Int, cy: Int, r: Int, v: Int) {
        for (y in cy - r..cy + r) for (x in cx - r..cx + r) {
            if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r && x in 0 until w && y in 0 until h) f[y * w + x] = v
        }
    }

    @Test
    fun aRoundSpotThatAppearsIsFoundWithItsPlace() {
        val a = blank()
        val b = blank()
        disc(b, 54, 120, 6, 220)
        val p = TouchScan.patch(a, b)
        assertNotNull(p)
        assertEquals(0.5, p!![0], 0.03)
        assertEquals(0.5, p[1], 0.03)
    }

    @Test
    fun aPageChangeIsNotASpot() {
        val a = blank()
        val b = blank(200)
        assertNull(TouchScan.patch(a, b))
    }

    @Test
    fun aLongBarIsNotASpot() {
        val a = blank()
        val b = blank()
        for (x in 10..90) for (y in 100..104) b[y * w + x] = 230
        assertNull(TouchScan.patch(a, b))
    }

    @Test
    fun twoSeparateChangesAreNotOneSpot() {
        val a = blank()
        val b = blank()
        disc(b, 20, 40, 5, 230)
        disc(b, 80, 200, 5, 230)
        assertNull(TouchScan.patch(a, b))
    }

    @Test
    fun aSpotThatStaysIsOneTapAndOneThatTravelsIsASwipe() {
        val tap = TouchScan.chain(listOf(Triple(1000L, 0.5, 0.5), Triple(1500L, 0.5, 0.5)))
        assertEquals(1, tap.size)
        assertEquals(0.0, tap[0].dist, 0.001)
        val drag = TouchScan.chain(
            listOf(Triple(1000L, 0.5, 0.8), Triple(1125L, 0.5, 0.6), Triple(1250L, 0.5, 0.4), Triple(1375L, 0.5, 0.2)),
        )
        assertEquals(1, drag.size)
        assertTrue(drag[0].dist > 0.5)
    }

    @Test
    fun spotsFarApartInTimeAreSeparateTouches() {
        val t = TouchScan.chain(listOf(Triple(1000L, 0.5, 0.5), Triple(5000L, 0.5, 0.5)))
        assertEquals(2, t.size)
    }

    @Test
    fun aChangeAfterAStillStretchIsAPress() {
        val f = MutableList(30) { 0.0 }
        f[12] = 0.4
        f[13] = 0.3
        val c = TouchScan.changes(f)
        assertEquals(listOf(12 * TouchScan.STEP_MS), c)
    }

    @Test
    fun continuousMotionGivesNoPresses() {
        val f = List(40) { 0.3 }
        assertTrue(TouchScan.changes(f).isEmpty())
    }
}
