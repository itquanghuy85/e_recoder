package com.huluca.escreenrecorder.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import com.huluca.escreenrecorder.R

/** Full-screen "3 · 2 · 1" shown before recording. It is removed before the encoder starts. */
class CountdownOverlay(private val ctx: Context) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var root: FrameLayout? = null
    private var cancelled = false

    fun run(seconds: Int, onDone: () -> Unit) {
        if (seconds <= 0) { onDone(); return }
        val number = TextView(ctx).apply {
            typeface = ctx.timecodeTypeface()
            textSize = 64f
            setTextColor(Tokens.ON_SURFACE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Tokens.SURFACE)
                setStroke(ctx.dp(4f), Tokens.CUE)
            }
        }
        val frame = FrameLayout(ctx).also {
            it.addView(number, FrameLayout.LayoutParams(ctx.dp(132f), ctx.dp(132f), Gravity.CENTER))
        }
        val lp = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        )
        wm.addView(frame, lp)
        root = frame
        val animate = !ctx.animationsDisabled()

        fun tick(n: Int) {
            if (cancelled) return
            if (n == 0) {
                remove()
                // Let the overlay window leave the screen before the first captured frame.
                main.postDelayed({ if (!cancelled) onDone() }, 120)
                return
            }
            number.text = n.toString()
            number.contentDescription = ctx.getString(R.string.countdown_desc, n)
            if (animate) {
                number.scaleX = 1.25f; number.scaleY = 1.25f; number.alpha = 0f
                number.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(260).start()
            }
            main.postDelayed({ tick(n - 1) }, 1000)
        }
        tick(seconds)
    }

    fun cancel() {
        cancelled = true
        remove()
    }

    private fun remove() {
        root?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        root = null
    }
}
