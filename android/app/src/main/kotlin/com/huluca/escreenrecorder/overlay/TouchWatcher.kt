package com.huluca.escreenrecorder.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.os.SystemClock
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager

/**
 * Hears every touch on the screen while a clean recording runs, with NO action from the person: no
 * corner to press, no shaking. It is a 1 x 1 px invisible window that does not take focus or touches
 * ([WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL]) but asks to be told about touches that land
 * OUTSIDE it ([WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH]); Android then calls
 * [MotionEvent.ACTION_OUTSIDE] once for each touch that goes down anywhere else. Nothing is drawn, so
 * nothing reaches the recording, and only the time (and the place, when Android passes it) of a touch is
 * kept: never what was on screen or typed.
 *
 * Android hides the place of touches that go to another app from a window like this one, so [onTouch]
 * often gets x/y of -1: the time is what is reliable. The editor finds the place from the picture.
 */
class TouchWatcher(
    private val ctx: Context,
    /** time of the touch (SystemClock.uptimeMillis) and its screen position, or -1 when hidden. */
    private val onTouch: (uptimeMs: Long, x: Float, y: Float) -> Unit,
) {
    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var view: View? = null

    fun show() {
        if (view != null) return
        val v = object : View(ctx) {
            override fun onTouchEvent(e: MotionEvent): Boolean {
                if (e.actionMasked == MotionEvent.ACTION_OUTSIDE) {
                    // Zero is how a hidden position arrives.
                    val hidden = e.rawX == 0f && e.rawY == 0f
                    onTouch(e.eventTime, if (hidden) -1f else e.rawX, if (hidden) -1f else e.rawY)
                }
                return false
            }
        }
        val lp = WindowManager.LayoutParams(
            1, 1,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        try {
            wm.addView(v, lp)
            view = v
        } catch (e: Exception) {
            android.util.Log.w("TouchWatcher", "cannot add the window", e)
        }
    }

    fun hide() {
        val v = view ?: return
        try { wm.removeView(v) } catch (_: Exception) {}
        view = null
    }
}
