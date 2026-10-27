package com.huluca.escreenrecorder.overlay

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.huluca.escreenrecorder.R
import com.huluca.escreenrecorder.marker.MarkerLayer
import com.huluca.escreenrecorder.marker.MarkerRenderer
import com.huluca.escreenrecorder.marker.MarkerTray
import com.huluca.escreenrecorder.marker.MarkerType

/**
 * Expanded control pill, opened by a long press on the corner dot: [rec dot] [timer] [tool]
 * [pause/resume] [stop]. The tool button opens the marker tray under the pill; the service pauses
 * the recording while the tray is open, so the tray never ends up in the video. Tapping the
 * pill body dismisses it. It is an overlay window (it shows in the recording while open).
 */
class ControlBar(
    private val ctx: Context,
    private val listener: Listener,
    private val layer: MarkerLayer?,
) {
    interface Listener {
        fun onPause()
        fun onResume()
        fun onStop()
        /** The tool tray opened or closed (the service pauses the recording while it is open). */
        fun onPickerChanged(open: Boolean)
        /** The user tapped the pill body: hide it. */
        fun onBarDismissed()
    }

    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private lateinit var root: LinearLayout
    private lateinit var pill: LinearLayout
    private lateinit var dot: View
    private lateinit var time: TextView
    private lateinit var markBtn: IconButton
    private lateinit var pauseBtn: IconButton
    private lateinit var stopBtn: IconButton
    private var tray: MarkerTray? = null
    private lateinit var lp: WindowManager.LayoutParams
    private var pulse: ObjectAnimator? = null
    private var paused = false
    private var attached = false
    var pickerOpen = false
        private set

    fun show() {
        if (attached) return
        root = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        pill = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(ctx.dp(14f), 0, ctx.dp(4f), 0)
            background = GradientDrawable().apply {
                setColor(Tokens.SURFACE)
                cornerRadius = ctx.dp(28f).toFloat()
                setStroke(ctx.dp(1f), Tokens.OUTLINE)
            }
        }
        root.addView(pill, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ctx.dp(56f)))

        dot = View(ctx).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Tokens.TALLY) }
        }
        pill.addView(dot, LinearLayout.LayoutParams(ctx.dp(12f), ctx.dp(12f)))

        time = TextView(ctx).apply {
            typeface = ctx.timecodeTypeface()
            textSize = 16f
            setTextColor(Tokens.ON_SURFACE)
            text = formatClock(0)
            setPadding(ctx.dp(10f), 0, ctx.dp(8f), 0)
            minWidth = ctx.dp(56f)
            gravity = Gravity.CENTER_VERTICAL
            contentDescription = ctx.getString(R.string.bar_elapsed, formatClock(0))
        }
        pill.addView(time, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ctx.dp(56f)))

        if (layer != null) {
            markBtn = IconButton(ctx, IconButton.MARK).apply {
                tool = layer.tool
                tint = layer.color
                contentDescription = ctx.getString(R.string.bar_pick_tool)
                setOnClickListener { setPicker(!pickerOpen) }
            }
            pill.addView(markBtn, LinearLayout.LayoutParams(ctx.dp(48f), ctx.dp(48f)))
            tray = MarkerTray(ctx, layer).also { it.visibility = View.GONE }
            root.addView(
                tray,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                    .apply { topMargin = ctx.dp(8f) },
            )
        }

        pauseBtn = IconButton(ctx, IconButton.PAUSE).apply {
            contentDescription = ctx.getString(R.string.bar_pause)
            setOnClickListener { if (paused) listener.onResume() else listener.onPause() }
        }
        stopBtn = IconButton(ctx, IconButton.STOP).apply {
            contentDescription = ctx.getString(R.string.bar_stop)
            setOnClickListener { listener.onStop() }
        }
        pill.addView(pauseBtn, LinearLayout.LayoutParams(ctx.dp(48f), ctx.dp(48f)))
        pill.addView(stopBtn, LinearLayout.LayoutParams(ctx.dp(48f), ctx.dp(48f)))

        lp = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = ctx.dp(16f)
            y = ctx.dp(96f)
        }
        installDrag()
        wm.addView(root, lp)
        attached = true
        startPulse()
    }

    private fun installDrag() {
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        val slop = ctx.dp(8f)
        pill.setOnTouchListener { _, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; moved = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    if (moved || kotlin.math.abs(dx) > slop || kotlin.math.abs(dy) > slop) {
                        moved = true
                        lp.x = startX + dx.toInt(); lp.y = startY + dy.toInt()
                        wm.updateViewLayout(root, lp)
                    }
                }
                MotionEvent.ACTION_UP -> if (!moved) listener.onBarDismissed()
            }
            true
        }
    }

    fun setPicker(open: Boolean) {
        if (!attached || layer == null || pickerOpen == open) return
        pickerOpen = open
        markBtn.active = open
        markBtn.contentDescription = ctx.getString(if (open) R.string.bar_pick_done else R.string.bar_pick_tool)
        tray?.visibility = if (open) View.VISIBLE else View.GONE
        if (open) tray?.refresh()
        wm.updateViewLayout(root, lp)
        listener.onPickerChanged(open)
    }

    /** The tool or colour changed from the tray: redraw the tool button. */
    fun refreshTool() {
        if (!attached || layer == null) return
        markBtn.tool = layer.tool
        markBtn.tint = layer.color
    }

    private fun startPulse() {
        if (ctx.animationsDisabled()) return
        pulse?.cancel()
        pulse = ObjectAnimator.ofFloat(dot, View.ALPHA, 1f, 0.35f).apply {
            duration = 1200
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    fun update(elapsedMs: Long, isPaused: Boolean) {
        if (!attached) return
        val label = formatClock(elapsedMs)
        time.text = label
        time.contentDescription = ctx.getString(R.string.bar_elapsed, label)
        if (isPaused != paused) {
            paused = isPaused
            (dot.background as GradientDrawable).setColor(if (paused) Tokens.CUE else Tokens.TALLY)
            pauseBtn.kind = if (paused) IconButton.PLAY else IconButton.PAUSE
            pauseBtn.contentDescription = ctx.getString(if (paused) R.string.bar_resume else R.string.bar_pause)
            if (paused) { pulse?.cancel(); dot.alpha = 1f } else startPulse()
        }
    }

    val isShown get() = attached

    fun hide() {
        if (!attached) return
        pulse?.cancel()
        try { wm.removeView(root) } catch (_: Exception) {}
        attached = false
        pickerOpen = false
    }
}

/** 48 dp touch target with a hand-drawn glyph (no bitmap assets). */
class IconButton(ctx: Context, kind: Int) : View(ctx) {
    companion object { const val PAUSE = 0; const val PLAY = 1; const val STOP = 2; const val MARK = 3 }

    var kind: Int = kind
        set(v) { field = v; invalidate() }

    var active: Boolean = false
        set(v) { field = v; invalidate() }

    var tool: MarkerType = MarkerType.FINGER
        set(v) { field = v; invalidate() }

    var tint: Int = Tokens.ON_SURFACE
        set(v) { field = v; invalidate() }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Tokens.ON_SURFACE }
    private val activeBg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x334DD6E8 }
    private val activeRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; color = Tokens.KEY; strokeWidth = ctx.dp(1.5f).toFloat()
    }
    private val path = Path()

    init { isClickable = true; isFocusable = true }

    override fun onDraw(c: Canvas) {
        val cx = width / 2f; val cy = height / 2f; val u = width / 48f
        when (kind) {
            PAUSE -> {
                c.drawRoundRect(RectF(cx - 8 * u, cy - 9 * u, cx - 3 * u, cy + 9 * u), 1.5f * u, 1.5f * u, paint)
                c.drawRoundRect(RectF(cx + 3 * u, cy - 9 * u, cx + 8 * u, cy + 9 * u), 1.5f * u, 1.5f * u, paint)
            }
            PLAY -> {
                path.reset()
                path.moveTo(cx - 6 * u, cy - 10 * u); path.lineTo(cx + 10 * u, cy); path.lineTo(cx - 6 * u, cy + 10 * u); path.close()
                c.drawPath(path, paint)
            }
            MARK -> {
                if (active) {
                    val r = RectF(cx - 21 * u, cy - 21 * u, cx + 21 * u, cy + 21 * u)
                    c.drawRoundRect(r, 14 * u, 14 * u, activeBg)
                    c.drawRoundRect(r, 14 * u, 14 * u, activeRing)
                }
                MarkerRenderer.drawIcon(c, tool, cx, cy, 24 * u, if (tint == 0xFF111111.toInt()) Tokens.ON_SURFACE else tint)
            }
            else -> {
                paint.color = Tokens.TALLY
                c.drawRoundRect(RectF(cx - 8 * u, cy - 8 * u, cx + 8 * u, cy + 8 * u), 2.5f * u, 2.5f * u, paint)
                paint.color = Tokens.ON_SURFACE
            }
        }
    }
}
