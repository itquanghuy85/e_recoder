package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/** Parsing of the Dart `texts` payload into [TextClip], including the caption fields. */
class ExportJobParseTest {
    private fun base(): MutableMap<String, Any?> = mutableMapOf(
        "text" to "hi", "color" to 0xFFFFFFFF, "sizeU" to 20.0, "x" to 0.5, "y" to 0.5,
        "startMs" to 0, "endMs" to 5000,
    )

    private fun cueMap(text: String, start: Int, end: Int) = mapOf(
        "text" to text, "startMs" to start, "endMs" to end,
        "words" to listOf(
            mapOf("text" to "a", "startMs" to start, "endMs" to start + 100),
            mapOf("text" to "b", "startMs" to start + 100, "endMs" to end),
        ),
    )

    @Test
    fun `full cues and caption style parse`() {
        val m = base()
        m["cues"] = listOf(cueMap("a b", 0, 1000), cueMap("c d", 1000, 2000))
        m["captionStyle"] = mapOf(
            "fontId" to "inter", "bold" to false, "sizeU" to 30.5, "color" to 0xFF112233,
            "outlineColor" to 0xFF000000, "outlineWidth" to 2.0, "shadowColor" to 0x80000000,
            "shadowBlur" to 4.0, "boxColor" to 0xFFFF0000, "boxRadius" to 8.0, "align" to "left",
            "x" to 0.3, "y" to 0.7, "revealMode" to "charByChar", "templateId" to "t1",
        )
        val t = ExportJob.parseText(m)
        val cues = t.cues!!
        assertEquals(2, cues.size)
        assertEquals("c d", cues[1].text)
        assertEquals(1000L, cues[1].startMs)
        assertEquals(2, cues[0].words.size)
        assertEquals(WordTiming("b", 100L, 1000L), cues[0].words[1])
        val s = t.captionStyle!!
        assertEquals("inter", s.fontId)
        assertEquals(false, s.bold)
        assertEquals(30.5f, s.sizeU, 0f)
        assertEquals(0xFF112233.toInt(), s.color)
        assertEquals(0xFF000000.toInt(), s.outlineColor)
        assertEquals(0x80000000.toInt(), s.shadowColor)
        assertEquals(0xFFFF0000.toInt(), s.boxColor)
        assertEquals(8f, s.boxRadius, 0f)
        assertEquals("left", s.align)
        assertEquals(0.3f, s.x, 0f)
        assertEquals(RevealMode.charByChar, s.revealMode)
        assertEquals("t1", s.templateId)
    }

    @Test
    fun `missing cues stay null`() {
        val m = base()
        m["cues"] = null
        assertNull(ExportJob.parseText(m).cues)
        assertNull(ExportJob.parseText(base()).cues)
    }

    @Test
    fun `missing caption style stays null`() {
        assertNull(ExportJob.parseText(base()).captionStyle)
    }

    @Test
    fun `cue with empty words parses`() {
        val m = base()
        m["cues"] = listOf(mapOf("text" to "x", "startMs" to 0, "endMs" to 500, "words" to emptyList<Any>()))
        val c = ExportJob.parseText(m).cues!!
        assertEquals(1, c.size)
        assertEquals(0, c[0].words.size)
    }

    @Test
    fun `unknown reveal mode falls back to word by word`() {
        val m = base()
        m["captionStyle"] = mapOf("revealMode" to "invalid")
        assertEquals(RevealMode.wordByWord, ExportJob.parseText(m).captionStyle!!.revealMode)
    }

    @Test
    fun `integer size is widened to float`() {
        val m = base()
        m["captionStyle"] = mapOf("sizeU" to 30)
        val s = ExportJob.parseText(m).captionStyle
        assertNotNull(s)
        assertEquals(30f, s!!.sizeU, 0f)
    }
}
