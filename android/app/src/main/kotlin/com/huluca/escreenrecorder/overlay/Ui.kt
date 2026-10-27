package com.huluca.escreenrecorder.overlay

import android.content.Context
import android.graphics.Typeface
import android.provider.Settings

/** Native copy of the Flutter tokens in lib/theme/app_tokens.dart (dark scheme). */
object Tokens {
    const val SURFACE = 0xF2181E29.toInt()
    const val OUTLINE = 0xFF2A3345.toInt()
    const val ON_SURFACE = 0xFFE8ECF3.toInt()
    const val TALLY = 0xFFFF5A52.toInt()
    const val CUE = 0xFFFFB938.toInt()
    const val KEY = 0xFF4DD6E8.toInt()
}

fun Context.dp(v: Float): Int = (v * resources.displayMetrics.density + 0.5f).toInt()

/** Timecode face shipped with the Flutter assets, so native overlays match the app. */
fun Context.timecodeTypeface(): Typeface = try {
    Typeface.createFromAsset(assets, "flutter_assets/assets/fonts/BarlowSemiCondensed-SemiBold.ttf")
} catch (_: Exception) {
    Typeface.DEFAULT_BOLD
}

/** True when the user turned animations off (Remove animations / reduce motion). */
fun Context.animationsDisabled(): Boolean = try {
    Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
} catch (_: Exception) {
    false
}

fun formatClock(ms: Long): String {
    val s = ms / 1000
    val h = s / 3600
    val m = (s % 3600) / 60
    val sec = s % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, sec) else "%02d:%02d".format(m, sec)
}
