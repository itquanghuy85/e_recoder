package com.huluca.escreenrecorder.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import com.huluca.escreenrecorder.R

/**
 * An invisible touch target in a screen corner (clean mode). Nothing is drawn, so nothing reaches the
 * recording; a touch arms the marker layer for the next touch. Add it BEFORE the marker layer so
 * the armed layer sits above it.
 */
class HotCorner(
    private val ctx: Context,
    private val corner: Int,
    private val onArm: () -> Unit,
) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var view: View? = null

    fun show() {
        if (view != null) return
        val v = object : View(ctx) {
            override fun onTouchEvent(e: MotionEvent): Boolean {
                if (e.actionMasked == MotionEvent.ACTION_DOWN) onArm()
                return true
            }

            override fun performClick(): Boolean { onArm(); return true }
        }.apply {
            isClickable = true
            contentDescription = ctx.getString(R.string.hot_corner_desc)
        }
        val size = ctx.dp(SIZE_DP)
        val lp = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            val right = corner == 1 || corner == 3
            val bottom = corner == 2 || corner == 3
            gravity = (if (bottom) Gravity.BOTTOM else Gravity.TOP) or (if (right) Gravity.END else Gravity.START)
            x = 0
            y = ctx.dp(if (bottom) 24f else 72f)
        }
        wm.addView(v, lp)
        view = v
    }

    fun hide() {
        val v = view ?: return
        try { wm.removeView(v) } catch (_: Exception) {}
        view = null
    }

    private companion object { const val SIZE_DP = 56f }
}
