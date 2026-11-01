package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Which cue shows when, and the 50 ms reveal steps the export overlay draws. */
class CueFramesTest {
    private val cues = listOf(
        CaptionCue("a", 1_000L, 2_000L),
        CaptionCue("b", 2_000L, 3_000L),
        CaptionCue("c", 5_000L, 6_000L),
    )

    @Test
    fun `a cue shows from its start and not at its end`() {
        assertEquals(-1, CueFrames.activeIndex(cues, 999L))
        assertEquals(0, CueFrames.activeIndex(cues, 1_000L))
        assertEquals(0, CueFrames.activeIndex(cues, 1_999L))
        assertEquals(1, CueFrames.activeIndex(cues, 2_000L))
    }

    @Test
    fun `gaps and the time after the last cue show nothing`() {
        assertEquals(-1, CueFrames.activeIndex(cues, 3_500L))
        assertEquals(-1, CueFrames.activeIndex(cues, 6_000L))
        assertEquals(-1, CueFrames.activeIndex(emptyList(), 100L))
    }

    @Test
    fun `reveal time is rounded down to 50 ms steps`() {
        val s = CaptionStyle(revealMode = RevealMode.wordByWord)
        assertEquals(1_000L, CueFrames.revealStep(s, 1_000L))
        assertEquals(1_000L, CueFrames.revealStep(s, 1_049L))
        assertEquals(1_050L, CueFrames.revealStep(s, 1_050L))
        assertEquals(1_050L, CueFrames.revealStep(CaptionStyle(revealMode = RevealMode.karaokeHighlight), 1_099L))
    }

    @Test
    fun `no reveal means the picture does not depend on time`() {
        assertNull(CueFrames.revealStep(CaptionStyle(revealMode = RevealMode.none), 1_234L))
    }

    @Test
    fun `a missing style reveals word by word like the preview`() {
        assertEquals(1_200L, CueFrames.revealStep(null, 1_234L))
    }

    @Test
    fun `only windows that overlap a cue need an overlay`() {
        assertTrue(CueFrames.anyIn(cues, 0L, 1_001L))
        assertFalse(CueFrames.anyIn(cues, 0L, 1_000L))
        assertFalse(CueFrames.anyIn(cues, 3_000L, 5_000L))
        assertTrue(CueFrames.anyIn(cues, 5_999L, 9_000L))
        assertFalse(CueFrames.anyIn(emptyList(), 0L, 9_000L))
    }
}
