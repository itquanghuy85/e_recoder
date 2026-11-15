package com.huluca.escreenrecorder

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.io.File
import java.util.Locale

/**
 * Text to speech with the phone's own engine (no extra library): the text is spoken into a WAV file
 * in the editor's media folder, which the editor then uses as a voice-over track. Preview and export
 * read that file the same way as a recorded voice-over.
 */
object SpeechSynth {
    /** Error codes handed to Flutter. */
    const val NO_ENGINE = "tts_unavailable"
    const val NO_LANG = "tts_no_lang"
    const val FAILED = "tts_failed"

    /**
     * Speaks [text] in [lang] (BCP-47, e.g. "vi", "en") at [rate] (1 = normal) into a new file.
     * [done] gets {path, durationMs} or an error code; it is called once, on a background thread.
     */
    fun toFile(
        ctx: Context,
        text: String,
        lang: String,
        rate: Float,
        pitch: Float,
        done: (Map<String, Any?>?, String?) -> Unit,
    ) {
        val clean = text.trim()
        if (clean.isEmpty()) {
            done(null, FAILED)
            return
        }
        val dir = File(ctx.filesDir, "editor_media").also { it.mkdirs() }
        val out = File(dir, "tts_${System.currentTimeMillis()}.wav")
        var tts: TextToSpeech? = null
        var finished = false
        fun finish(m: Map<String, Any?>?, err: String?) {
            synchronized(this) {
                if (finished) return
                finished = true
            }
            try { tts?.shutdown() } catch (_: Exception) {}
            if (err != null) out.delete()
            done(m, err)
        }
        tts = TextToSpeech(ctx.applicationContext) { status ->
            val engine = tts
            if (status != TextToSpeech.SUCCESS || engine == null) {
                finish(null, NO_ENGINE)
                return@TextToSpeech
            }
            val ok = engine.setLanguage(Locale.forLanguageTag(lang))
            if (ok == TextToSpeech.LANG_MISSING_DATA || ok == TextToSpeech.LANG_NOT_SUPPORTED) {
                finish(null, NO_LANG)
                return@TextToSpeech
            }
            engine.setSpeechRate(rate.coerceIn(0.5f, 2f))
            engine.setPitch(pitch.coerceIn(0.5f, 2f))
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) {
                    val ms = durationMs(out)
                    if (ms <= 0) finish(null, FAILED)
                    else finish(mapOf("path" to out.absolutePath, "durationMs" to ms), null)
                }
                @Deprecated("Deprecated in Java")
                override fun onError(id: String?) = finish(null, FAILED)
                override fun onError(id: String?, code: Int) = finish(null, FAILED)
            })
            val limit = TextToSpeech.getMaxSpeechInputLength()
            val r = engine.synthesizeToFile(clean.take(limit), Bundle(), out, "esr_tts")
            if (r != TextToSpeech.SUCCESS) finish(null, FAILED)
        }
    }

    private fun durationMs(f: File): Long {
        if (!f.exists() || f.length() <= 44) return 0
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(f.absolutePath)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
        } catch (_: Exception) {
            0
        } finally {
            r.release()
        }
    }
}
