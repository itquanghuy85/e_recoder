package com.huluca.escreenrecorder

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import android.os.Looper

/** A saved recording must reach Flutter exactly once, whether it was listening or not. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RecorderBusSavedTest {
    private fun saved(uri: String) = mapOf<String, Any?>("type" to "saved", "uri" to uri, "name" to "ESR_1.mp4")

    @After
    fun clear() {
        RecorderBus.sink = null
        RecorderBus.takeLastSaved()
    }

    @Test
    fun `saved while nobody listens is kept and taken exactly once`() {
        RecorderBus.sink = null
        RecorderBus.emit(saved("content://a"))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("content://a", RecorderBus.takeLastSaved()?.get("uri"))
        assertNull(RecorderBus.takeLastSaved())
    }

    @Test
    fun `saved delivered live is not replayed later`() {
        val got = mutableListOf<Map<String, Any?>>()
        RecorderBus.sink = { got += it }
        RecorderBus.emit(saved("content://b"))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, got.size)
        assertNull(RecorderBus.takeLastSaved())
    }

    @Test
    fun `other events do not touch the saved replay`() {
        RecorderBus.sink = null
        RecorderBus.emit(saved("content://c"))
        RecorderBus.emit(mapOf("type" to "error", "code" to "x", "message" to "y"))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("content://c", RecorderBus.recentSaved()?.get("uri"))
    }
}
