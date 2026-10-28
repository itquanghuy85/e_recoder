package com.huluca.escreenrecorder.stt

import android.content.Context
import android.content.Intent
import androidx.annotation.RequiresApi
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.io.File

/**
 * Speech to text with the recognizer that is part of Android (API 33+): ON DEVICE ONLY. It is created
 * with [SpeechRecognizer.createOnDeviceSpeechRecognizer], which never sends audio to a server, and
 * its audio comes from a file we hand over (not from the microphone). Nothing is bundled, so the app
 * does not grow; a language pack may have to be downloaded by the system once.
 */
@RequiresApi(33)
class SpeechToText(private val ctx: Context) {
    private val main = Handler(Looper.getMainLooper())

    /** True when this phone has an on-device recognizer at all. */
    fun available(): Boolean = SpeechRecognizer.isOnDeviceRecognitionAvailable(ctx)

    /** For each language tag: "installed", "downloadable" or "unsupported". */
    fun support(langs: List<String>, done: (Map<String, String>) -> Unit) {
        if (!available()) { done(langs.associateWith { "unsupported" }); return }
        main.post {
            val rec = SpeechRecognizer.createOnDeviceSpeechRecognizer(ctx)
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            var answered = false
            fun finish(map: Map<String, String>) {
                if (answered) return
                answered = true
                try { rec.destroy() } catch (_: Exception) {}
                done(map)
            }
            main.postDelayed({ finish(langs.associateWith { "unsupported" }) }, 8000)
            rec.checkRecognitionSupport(intent, ctx.mainExecutor, object : RecognitionSupportCallback {
                override fun onSupportResult(s: RecognitionSupport) {
                    // "vi-VN" is also served by a pack that is listed as plain "vi".
                    fun has(list: List<String>, tag: String) =
                        list.any { it.equals(tag, true) || it.equals(tag.substringBefore('-'), true) }
                    finish(
                        langs.associateWith { tag ->
                            when {
                                has(s.installedOnDeviceLanguages, tag) -> "installed"
                                has(s.supportedOnDeviceLanguages, tag) || has(s.pendingOnDeviceLanguages, tag) -> "downloadable"
                                else -> "unsupported"
                            }
                        },
                    )
                }

                override fun onError(error: Int) = finish(langs.associateWith { "unsupported" })
            })
        }
    }

    /** Asks the system to download the pack of [lang]; progress is seen by asking [support] again. */
    fun download(lang: String) {
        if (!available()) return
        main.post {
            val rec = SpeechRecognizer.createOnDeviceSpeechRecognizer(ctx)
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            try { rec.triggerModelDownload(intent) } catch (_: Exception) {}
            main.postDelayed({ try { rec.destroy() } catch (_: Exception) {} }, 3000)
        }
    }

    /**
     * Recognises one PCM file (16 kHz, mono, 16-bit) and returns the best text, or null.
     * Must be called from any thread; [done] is called on the main thread.
     */
    fun recognize(pcm: File, lang: String, done: (String?) -> Unit) {
        main.post {
            val rec = SpeechRecognizer.createOnDeviceSpeechRecognizer(ctx)
            val fd = ParcelFileDescriptor.open(pcm, ParcelFileDescriptor.MODE_READ_ONLY)
            var finished = false
            var lastPartial: String? = null
            fun finish(text: String?) {
                if (finished) return
                finished = true
                try { rec.destroy() } catch (_: Exception) {}
                try { fd.close() } catch (_: Exception) {}
                done(text)
            }
            // A recogniser that never answers must not hang the whole job.
            main.postDelayed({ finish(null) }, 60_000)
            rec.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    android.util.Log.w("SttJob", "recogniser error $error")
                    finish(lastPartial)
                }
                // With a file as the audio source this recogniser gives its text as partial results and
                // ends with an empty final bundle: the newest partial text is the answer then.
                override fun onPartialResults(partialResults: Bundle?) {
                    partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()?.trim()?.takeIf { it.isNotEmpty() }?.let { lastPartial = it }
                }
                override fun onEvent(eventType: Int, params: Bundle?) {}
                override fun onResults(results: Bundle?) {
                    val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    finish(list?.firstOrNull()?.trim()?.takeIf { it.isNotEmpty() } ?: lastPartial)
                }
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, fd)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, android.media.AudioFormat.ENCODING_PCM_16BIT)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16000)
            try { rec.startListening(intent) } catch (_: Exception) { finish(null) }
        }
    }
}
