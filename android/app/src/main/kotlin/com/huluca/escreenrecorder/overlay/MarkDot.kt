package com.huluca.escreenrecorder.overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import com.huluca.escreenrecorder.R
import com.huluca.escreenrecorder.marker.MarkerRenderer
import com.huluca.escreenrecorder.marker.MarkerType
import kotlin.math.abs

/**
 * The only thing left on screen while recording in "dot" mode: a small disc in a corner showing the
 * tool chosen beforehand. Tap it, then touch the spot you are about to press (the marker cues in),
 * then press for real. A long press opens the full control pill; dragging moves the dot.
 */
class MarkDot(
    private val ctx: Context,
    private val corner: Int,
    private val listener: Listener,
) {
    interface Listener {
        fun onDotTap()
        fun onDotLongPress()
    }

    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private lateinit var view: DotView
    private lateinit var lp: WindowManager.LayoutParams
    private var attached = false

    var tool: MarkerType = MarkerType.FINGER
        set(v) { field = v; if (attached) view.invalidate() }
    var tint: Int = 0xFFFF3B30.toInt()
        set(v) { field = v; if (attached) view.invalidate() }
    var active: Boolean = false
        set(v) {
            field = v
            if (!attached) return
            view.contentDescription = ctx.getString(if (v) R.string.bar_mark_off else R.string.bar_mark_on)
            view.invalidate()
        }

    fun show() {
        if (attached) return
        val size = ctx.dp(SIZE_DP)
        view = DotView(ctx)
        lp = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            val right = corner == 1 || corner == 3
            val bottom = corner == 2 || corner == 3
            gravity = (if (bottom) Gravity.BOTTOM else Gravity.TOP) or (if (right) Gravity.END else Gravity.START)
            x = ctx.dp(6f)
            y = ctx.dp(if (bottom) 132f else 96f)
        }
        wm.addView(view, lp)
        attached = true
    }

    fun hide() {
        if (!attached) return
        main.removeCallbacksAndMessages(null)
        try { wm.removeView(view) } catch (_: Exception) {}
        attached = false
    }

    private inner class DotView(c: Context) : View(c) {
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Tokens.SURFACE }
        private val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; color = Tokens.OUTLINE; strokeWidth = ctx.dp(1f).toFloat()
        }
        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; color = Tokens.KEY; strokeWidth = ctx.dp(2f).toFloat()
        }
        private var downRawX = 0f
        private var downRawY = 0f
        private var startX = 0
        private var startY = 0
        private var moved = false
        private var longFired = false
        private val slop = ctx.dp(8f)
        private val longPress = Runnable {
            if (!moved) {
                longFired = true
                performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                listener.onDotLongPress()
            }
        }

        init {
            isClickable = true
            isFocusable = true
            contentDescription = ctx.getString(R.string.bar_mark_on)
            alpha = IDLE_ALPHA
        }

        override fun onDraw(c: Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            val r = ctx.dp(DISC_DP) / 2f
            c.drawCircle(cx, cy, r, fill)
            c.drawCircle(cx, cy, r, edge)
            if (active) c.drawCircle(cx, cy, r + ctx.dp(2f), ring)
            val icon = if (tint == 0xFF111111.toInt()) Tokens.ON_SURFACE else tint
            MarkerRenderer.drawIcon(c, tool, cx, cy, r * 1.15f, icon)
        }

        override fun onTouchEvent(e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = e.rawX; downRawY = e.rawY; startX = lp.x; startY = lp.y
                    moved = false; longFired = false
                    alpha = 1f
                    main.postDelayed(longPress, 550)
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downRawX
                    val dy = e.rawY - downRawY
                    if (moved || abs(dx) > slop || abs(dy) > slop) {
                        moved = true
                        main.removeCallbacks(longPress)
                        // x grows toward the screen centre for END gravity, y toward the centre for BOTTOM.
                        val right = corner == 1 || corner == 3
                        val bottom = corner == 2 || corner == 3
                        lp.x = startX + (if (right) -dx else dx).toInt()
                        lp.y = startY + (if (bottom) -dy else dy).toInt()
                        wm.updateViewLayout(this, lp)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    main.removeCallbacks(longPress)
                    if (!moved && !longFired) {
                        performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                        listener.onDotTap()
                    }
                    alpha = IDLE_ALPHA
                }
                MotionEvent.ACTION_CANCEL -> {
                    main.removeCallbacks(longPress)
                    alpha = IDLE_ALPHA
                }
            }
            return true
        }

        override fun performClick(): Boolean { listener.onDotTap(); return true }
    }

    private companion object {
        const val SIZE_DP = 48f
        const val DISC_DP = 34f
        const val IDLE_ALPHA = 0.72f
    }
}
