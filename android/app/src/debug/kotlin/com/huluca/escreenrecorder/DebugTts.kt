package com.huluca.escreenrecorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.io.File
import java.util.Locale

/**
 * Debug builds only. `adb shell am broadcast -n com.huluca.escreenrecorder/.DebugTts
 * -a com.huluca.escreenrecorder.DEBUG_TTS --es text "..." --es lang vi-VN --es out tts_vi_1.wav`
 * writes the spoken text to files/<out>; files/<out>.done holds "ok" or the reason it failed.
 */
class DebugTts : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: return
        val lang = intent.getStringExtra("lang") ?: "vi-VN"
        val out = File(ctx.filesDir, intent.getStringExtra("out") ?: "tts.wav")
        val done = File(ctx.filesDir, out.name + ".done")
        done.delete()
        val pending = goAsync()
        var tts: TextToSpeech? = null
        fun finish(msg: String) {
            done.writeText(msg)
            try { tts?.shutdown() } catch (_: Exception) {}
            pending.finish()
        }
        tts = TextToSpeech(ctx.applicationContext) { status ->
            if (status != TextToSpeech.SUCCESS) { finish("init failed $status"); return@TextToSpeech }
            val r = tts!!.setLanguage(Locale.forLanguageTag(lang))
            if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                finish("language $lang not available ($r)"); return@TextToSpeech
            }
            tts!!.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) = finish("ok")
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) = finish("error")
            })
            val rc = tts!!.synthesizeToFile(text, Bundle(), out, "u1")
            if (rc != TextToSpeech.SUCCESS) finish("synthesize failed $rc")
        }
    }
}
