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

    @Test
    fun `a page that moves right as the finger lands is a swipe, a tap is not`() {
        // Swipe at 1000: the page scrolls (stripes shift every frame) from 1030 on.
        val scroll = (0L..3000L step 33).map { ms ->
            val off = if (ms >= 1030) ((ms - 1030) / 33).toInt() * 7 else 0
            LumaDecoder.Frame(ms, IntArray(w * h) { i -> if (((i / w) + off) % 20 < 10) 220 else 40 }, w, h)
        }
        val s = TouchScan.locateWith(TouchScan.WindowSource { a, b -> scroll.filter { it.ms in a..b } }, listOf(1000L)).single()
        assertTrue("swipe dist ${s["dist"]}", (s["dist"] as Double) >= 0.05)
        // Tap at 1000: key lights at 1250, page changes at 1900.
        val tap = (0L..4000L step 33).map { ms -> frame(ms, key = ms in 1250..1400, page = ms >= 1900) }
        val r = TouchScan.locateWith(TouchScan.WindowSource { a, b -> tap.filter { it.ms in a..b } }, listOf(1000L)).single()
        assertEquals(0.0, r["dist"] as Double, 0.0)
    }

    @Test
    fun `the first edge of a new page sliding in is not the place`() {
        // No ripple: at 1220 a band at the top changes (the new page's bar), by 1300 the whole page has.
        val frames = (0L..4000L step 33).map { ms ->
            val l = IntArray(w * h) { 40 }
            if (ms >= 1220) for (y in 20..40) for (x in 0 until w) l[y * w + x] = 220
            if (ms >= 1300) for (i in l.indices) l[i] = 220
            LumaDecoder.Frame(ms, l, w, h)
        }
        val r = TouchScan.locateWith(TouchScan.WindowSource { a, b -> frames.filter { it.ms in a..b } }, listOf(1000L)).single()
        assertEquals(-1.0, r["x"] as Double, 0.0)
    }

    @Test(expected = IllegalStateException::class)
    fun `a decoder that gives no frames falls back (the caller reads frame by frame)`() {
        TouchScan.locateWith(TouchScan.WindowSource { _, _ -> emptyList() }, listOf(1000L))
    }
}
