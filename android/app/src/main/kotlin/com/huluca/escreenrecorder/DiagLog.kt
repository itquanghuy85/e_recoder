package com.huluca.escreenrecorder

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * A short diagnostic trail of the save path (service -> bus -> channel -> Flutter -> screen), kept in
 * the app's own files (`files/diag.log`, ~256 KB, older half dropped). Some phones (ColorOS) hide an
 * app's logcat lines, so this file is the one place that always tells what happened after Stop.
 * Read on a debug build with `adb shell run-as com.huluca.escreenrecorder cat files/diag.log`.
 * Holds no user content: event names, counts, content URIs.
 */
object DiagLog {
    private const val MAX_BYTES = 256 * 1024
    @Volatile private var file: File? = null
    private val fmt = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)

    fun init(ctx: Context) {
        if (file == null) file = File(ctx.applicationContext.filesDir, "diag.log")
    }

    @Synchronized
    fun log(tag: String, msg: String) {
        try { Log.w("ESR/$tag", msg) } catch (_: RuntimeException) {} // plain JVM tests have no Log
        val f = file ?: return
        try {
            if (f.length() > MAX_BYTES) {
                val keep = f.readText().takeLast(MAX_BYTES / 2)
                f.writeText(keep)
            }
            f.appendText("${fmt.format(Date())} [$tag] $msg\n")
        } catch (_: Exception) {
            // A diagnostic that cannot be written must never break recording.
        }
    }
}
