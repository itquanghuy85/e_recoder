package com.huluca.escreenrecorder.export

import android.graphics.Bitmap
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Progressive reveal of a cue: how much ink is drawn at different playhead times. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class OverlayRenderersRevealTest {
    private val cue = CaptionCue(
        text = "one two three",
        startMs = 1_000L,
        endMs = 4_000L,
        words = listOf(
            WordTiming("one", 1_000L, 2_000L),
            WordTiming("two", 2_000L, 3_000L),
            WordTiming("three", 3_000L, 4_000L),
        ),
    )

    private fun style(mode: RevealMode) = CaptionStyle(revealMode = mode)

    /** Pixels that are fully opaque: the text fill, not the soft edge or a dimmed fill. */
    private fun solid(b: Bitmap): Int {
        var n = 0
        for (y in 0 until b.height) for (x in 0 until b.width) {
            if ((b.getPixel(x, y) ushr 24) == 0xFF) n++
        }
        return n
    }

    private fun ink(mode: RevealMode, t: Long?) =
        solid(OverlayRenderers.renderCue(cue, style(mode), 1080, t).bitmap)

    @Test
    fun `no time draws the whole cue`() {
        assertEquals(ink(RevealMode.none, null), ink(RevealMode.wordByWord, null))
    }

    @Test
    fun `none mode ignores the time`() {
        assertEquals(ink(RevealMode.none, null), ink(RevealMode.none, 1_000L))
    }

    @Test
    fun `word by word adds ink word by word`() {
        val before = ink(RevealMode.wordByWord, 500L)
        val one = ink(RevealMode.wordByWord, 1_500L)
        val two = ink(RevealMode.wordByWord, 2_500L)
        val all = ink(RevealMode.wordByWord, 3_500L)
        assertEquals(0, before)
        assertTrue(one in 1 until two)
        assertTrue(two < all)
        assertEquals(ink(RevealMode.none, null), all)
    }

    @Test
    fun `bitmap size does not change while revealing`() {
        val a = OverlayRenderers.renderCue(cue, style(RevealMode.wordByWord), 1080, 500L)
        val b = OverlayRenderers.renderCue(cue, style(RevealMode.wordByWord), 1080, 3_900L)
        assertEquals(a.wPx, b.wPx)
        assertEquals(a.hPx, b.hPx)
    }

    @Test
    fun `char by char grows inside one word`() {
        val early = ink(RevealMode.charByChar, 3_100L)
        val late = ink(RevealMode.charByChar, 3_800L)
        assertTrue(early in 1 until late)
        assertEquals(ink(RevealMode.none, null), ink(RevealMode.charByChar, 4_000L))
    }

    @Test
    fun `karaoke fills the words left to right and ends full`() {
        val start = ink(RevealMode.karaokeHighlight, 1_000L)
        val mid = ink(RevealMode.karaokeHighlight, 2_500L)
        val end = ink(RevealMode.karaokeHighlight, 4_000L)
        assertTrue(start < mid)
        assertTrue(mid < end)
        assertEquals(ink(RevealMode.none, null), end)
    }

    @Test
    fun `words that do not match the text are spread evenly`() {
        val typed = CaptionCue(text = "a b c d", startMs = 0L, endMs = 4_000L)
        val times = OverlayRenderers.cueTokenTimes(typed, 4)
        assertEquals(listOf(0L to 1_000L, 1_000L to 2_000L, 2_000L to 3_000L, 3_000L to 4_000L), times)
    }

    @Test
    fun `shown characters share the word span equally`() {
        assertEquals(0, OverlayRenderers.shownChars(4, 100L, 500L, 50L))
        assertEquals(1, OverlayRenderers.shownChars(4, 100L, 500L, 100L))
        assertEquals(3, OverlayRenderers.shownChars(4, 100L, 500L, 350L))
        assertEquals(4, OverlayRenderers.shownChars(4, 100L, 500L, 500L))
    }
}
