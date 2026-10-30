package com.huluca.escreenrecorder.stt

import android.content.Context
import android.net.Uri
import androidx.annotation.RequiresApi
import com.huluca.escreenrecorder.export.AudioDecode
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * The one speech-to-text job: the sound of the video is decoded, cut into phrases at its pauses
 * ([Chunker]), and every phrase goes through the on-device recogniser ([SpeechToText]). The app asks
 * for progress with [status]; the result is a list of {startMs, endMs, text} in the video's own time.
 */
@RequiresApi(33)
object SttJob {
    private const val MAX_SOUND_MS = 30 * 60_000L

    @Volatile private var state = "idle" // idle | preparing | running | done | error | cancelled
    @Volatile private var done = 0
    @Volatile private var total = 0
    @Volatile private var error = ""
    @Volatile private var cancelled = false
    private val pieces = Collections.synchronizedList(ArrayList<Map<String, Any>>())

    fun status(): Map<String, Any> = mapOf(
        "state" to state, "done" to done, "total" to total, "error" to error,
        "pieces" to synchronized(pieces) { ArrayList(pieces) },
    )

    fun cancel() { cancelled = true }

    fun start(ctx: Context, uri: String, lang: String) {
        if (state == "preparing" || state == "running") return
        state = "preparing"; done = 0; total = 0; error = ""; cancelled = false; pieces.clear()
        val app = ctx.applicationContext
        Thread {
            try {
                val pcm = AudioDecode.decode(MAX_SOUND_MS) { ex ->
                    val u = Uri.parse(uri)
                    try {
                        ex.setDataSource(app, u, null)
                    } catch (e: Exception) {
                        // Some providers refuse the uri form but hand out a file descriptor.
                        app.contentResolver.openFileDescriptor(u, "r")!!.use { ex.setDataSource(it.fileDescriptor) }
                    }
                }
                val mono = AudioDecode.toMono16k(pcm)
                val spans = Chunker.split(mono)
                android.util.Log.i("SttJob", "decoded ${mono.size / 16000.0} s, ${spans.size} phrases, peak ${Chunker.peak(mono)}")
                if (spans.isEmpty()) { error = "no_speech"; state = "error"; return@Thread }
                total = spans.size
                state = "running"
                val stt = SpeechToText(app)
                val dir = File(app.cacheDir, "stt").apply { mkdirs() }
                for ((i, sp) in spans.withIndex()) {
                    if (cancelled) { state = "cancelled"; return@Thread }
                    val f = File(dir, "chunk_$i.pcm")
                    FileOutputStream(f).use { out ->
                        val bb = ByteBuffer.allocate((sp.end - sp.start) * 2).order(ByteOrder.LITTLE_ENDIAN)
                        for (k in sp.start until sp.end) bb.putShort(mono[k])
                        out.write(bb.array())
                    }
                    val latch = CountDownLatch(1)
                    var text: String? = null
                    stt.recognize(f, lang) { text = it; latch.countDown() }
                    latch.await(70, TimeUnit.SECONDS)
                    f.delete()
                    // Only sizes are logged, never what was said.
                    android.util.Log.i("SttJob", "phrase $i ${sp.start / 16}..${sp.end / 16} ms -> ${text?.length ?: 0} chars")
                    text?.let {
                        pieces.add(
                            mapOf(
                                "startMs" to sp.start * 1000L / Chunker.RATE,
                                "endMs" to sp.end * 1000L / Chunker.RATE,
                                "text" to it,
                            ),
                        )
                    }
                    done = i + 1
                }
                state = "done"
            } catch (e: AudioDecode.NoSound) {
                error = "no_audio"; state = "error"
            } catch (e: Exception) {
                android.util.Log.w("SttJob", "failed", e)
                error = e.message ?: "error"; state = "error"
            }
        }.also { it.isDaemon = true }.start()
    }
}
