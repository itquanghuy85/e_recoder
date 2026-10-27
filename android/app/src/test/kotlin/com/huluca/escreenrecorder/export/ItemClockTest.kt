package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Test

class ItemClockTest {
    @Test fun measuresFromTheFirstFrameOfTheSegment() {
        // The second segment of a sequence starts at ~3 s of sequence time.
        val c = ItemClock(clipStartMs = 3000)
        assertEquals(3000L, c.sourceMs(3_013_333))
        assertEquals(3500L, c.sourceMs(3_513_333))
    }

    @Test fun firstSegmentStartsAtItsClipStart() {
        val c = ItemClock(clipStartMs = 0)
        assertEquals(0L, c.sourceMs(0))
        assertEquals(1000L, c.sourceMs(1_000_000))
    }
}
