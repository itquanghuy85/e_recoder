package com.huluca.escreenrecorder

import android.os.Handler
import android.os.Looper

/** Recording configuration, parsed from the Flutter `start` call. */
data class RecConfig(
    val width: Int,
    val height: Int,
    val dpi: Int,
    val fps: Int,
    val bitrate: Int,
    val mic: Boolean,
    val system: Boolean,
    val countdownSec: Int,
    val floatingBar: Boolean,
    val markerHoldMs: Long = 2500,
    val markerAutoExit: Boolean = true,
    /** Pause between placing a marker and handing touches back to the app underneath. */
    val markerExitDelayMs: Long = 900,
    val markerColor: Int = 0xFFFF3B30.toInt(),
    val markerThickness: Float = 5f,
    val markerTool: String = "finger",
    /** "dot" = small corner dot, markers drawn live; "clean" = nothing on screen, markers added in the editor. */
    val markMode: String = "dot",
    /** 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right. */
    val markCorner: Int = 2,
    val armShake: Boolean = false,
) {
    val clean get() = markMode == "clean"

    val wantsAudio get() = mic || system

    companion object {
        fun fromMap(m: Map<*, *>) = RecConfig(
            width = (m["width"] as Number).toInt(),
            height = (m["height"] as Number).toInt(),
            dpi = (m["dpi"] as Number).toInt(),
            fps = (m["fps"] as Number).toInt(),
            bitrate = (m["bitrate"] as Number).toInt(),
            mic = m["mic"] as Boolean,
            system = m["system"] as Boolean,
            countdownSec = (m["countdown"] as Number).toInt(),
            floatingBar = m["floatingBar"] as Boolean,
            markerHoldMs = ((m["markerHoldMs"] as? Number)?.toLong() ?: 2500L).coerceIn(500L, 10_000L),
            markerAutoExit = m["markerAutoExit"] as? Boolean ?: true,
            markerExitDelayMs = ((m["markerExitDelayMs"] as? Number)?.toLong() ?: 900L).coerceIn(0L, 5000L),
            markerColor = (m["markerColor"] as? Number)?.toInt() ?: 0xFFFF3B30.toInt(),
            markerThickness = (m["markerThickness"] as? Number)?.toFloat() ?: 5f,
            markerTool = m["markerTool"] as? String ?: "finger",
            markMode = m["markMode"] as? String ?: "dot",
            markCorner = (m["markCorner"] as? Number)?.toInt() ?: 2,
            armShake = m["armShake"] as? Boolean ?: false,
        )
    }
}

/** Process-wide channel between the service and the (optional) Flutter activity. */
object RecorderBus {
    const val IDLE = "idle"
    const val COUNTDOWN = "countdown"
    const val RECORDING = "recording"
    const val PAUSED = "paused"
    const val SAVING = "saving"

    @Volatile var phase: String = IDLE
    @Volatile var elapsedMs: Long = 0
    @Volatile var sink: ((Map<String, Any?>) -> Unit)? = null
    @Volatile var pendingConfig: RecConfig? = null

    private val main = Handler(Looper.getMainLooper())

    fun snapshot(): Map<String, Any?> =
        mapOf("type" to "state", "phase" to phase, "elapsedMs" to elapsedMs)

    fun changePhase(p: String) {
        phase = p
        emit(snapshot())
    }

    fun emit(event: Map<String, Any?>) {
        main.post { sink?.invoke(event) }
    }

    fun error(code: String, message: String) =
        emit(mapOf("type" to "error", "code" to code, "message" to message))
}
