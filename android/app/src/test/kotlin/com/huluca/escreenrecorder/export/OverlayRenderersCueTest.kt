package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Draws real Android bitmaps, so it needs Robolectric instead of the plain JVM stubs. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class OverlayRenderersCueTest {
    private fun cue(text: String) = CaptionCue(text = text, startMs = 0L, endMs = 1_000L)

    @Test
    fun `one line cue renders a bitmap`() {
        val r = OverlayRenderers.renderCue(cue("xin chào"), CaptionStyle(), 1080)
        assertNotNull(r.bitmap)
        assertTrue(r.wPx > 0)
        assertTrue(r.hPx > 0)
    }

    @Test
    fun `a long cue wraps to more lines than one line`() {
        val one = OverlayRenderers.renderCue(cue("một dòng"), CaptionStyle(), 1080)
        val many = OverlayRenderers.renderCue(cue("đây là một câu rất dài ".repeat(10)), CaptionStyle(), 1080)
        assertTrue(many.hPx > one.hPx)
    }

    @Test
    fun `a null style uses defaults`() {
        val r = OverlayRenderers.renderCue(cue("mặc định"), null, 1080)
        assertNotNull(r.bitmap)
        assertTrue(r.wPx > 0)
    }

    @Test
    fun `default style matches the Dart model`() {
        val s = CaptionStyle()
        assertEquals("barlow", s.fontId)
        assertEquals(22f, s.sizeU, 0f)
        assertEquals(0xFFFFFFFF.toInt(), s.color)
        assertNull(s.outlineColor)
        assertEquals(0f, s.outlineWidth, 0f)
        assertNull(s.shadowColor)
        assertEquals(0f, s.shadowBlur, 0f)
        assertNull(s.boxColor)
        assertEquals(0f, s.boxRadius, 0f)
        assertEquals("center", s.align)
        assertEquals(0.5f, s.x, 0f)
        assertEquals(0.85f, s.y, 0f)
        assertEquals(RevealMode.wordByWord, s.revealMode)
        assertNull(s.templateId)
    }
}
