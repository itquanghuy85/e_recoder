package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** [TouchScan.locateWith]: one decoded window per touch gives the place and the moment the page changed. */
class TouchLocateWindowTest {
    private val w = TouchScan.W
    private val h = TouchScan.H

    private fun frame(ms: Long, bg: Int = 40, key: Boolean = false, page: Boolean = false): LumaDecoder.Frame {
        val l = IntArray(w * h) { if (page) 230 else bg }
        if (key) for (y in 150..169) for (x in 30..59) l[y * w + x] = 200
        return LumaDecoder.Frame(ms, l, w, h)
    }

    @Test
    fun `a key that lights up after the touch is the place, a new page is the change`() {
        // touch at 1000: still before, the key lights at 1250, the page changes at 1900
        val frames = (0L..4000L step 33).map { ms ->
            frame(ms, key = ms in 1250..1400, page = ms >= 1900)
        }
        val asked = mutableListOf<Pair<Long, Long>>()
        val src = TouchScan.WindowSource { a, b ->
            asked += a to b
            frames.filter { it.ms in a..b }
        }
        val r = TouchScan.locateWith(src, listOf(1000L)).single()
        assertEquals(45.0 / w, r["x"] as Double, 0.03)
        assertEquals(160.0 / h, r["y"] as Double, 0.03)
        val change = r["changeMs"] as Long
        assertTrue("change at $change", change in 1900L..1950L)
        // One window per touch, covering the reaction and the change scan.
        assertEquals(1, asked.size)
        assertTrue(asked[0].first <= 910 && asked[0].second >= 1680)
    }

    @Test
    fun `nothing reacts gives no place, no change, but the touch is still listed`() {
        val frames = (0L..5000L step 33).map { frame(it) }
        val r = TouchScan.locateWith(
            TouchScan.WindowSource { a, b -> frames.filter { it.ms in a..b } },
            listOf(2000L, 800L),
        )
        assertEquals(listOf(2000L, 800L), r.map { it["tMs"] })
        assertEquals(-1.0, r[0]["x"] as Double, 0.0)
        assertEquals(-1L, r[0]["changeMs"])
    }

    @Test(expected = IllegalStateException::class)
    fun `a decoder that gives no frames falls back (the caller reads frame by frame)`() {
        TouchScan.locateWith(TouchScan.WindowSource { _, _ -> emptyList() }, listOf(1000L))
    }
}
