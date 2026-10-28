package com.huluca.escreenrecorder.marker

import android.content.Context
import android.graphics.Canvas
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import com.huluca.escreenrecorder.RecConfig
import com.huluca.escreenrecorder.overlay.animationsDisabled
import kotlin.math.atan2
import kotlin.math.hypot

/**
 * Full-screen overlay that draws markers and, in annotate mode, takes touches to place them.
 *
 * Outside annotate mode the window is not touchable, so taps reach the app underneath. That is
 * the whole point of the "point mode": place the marker (it cues in and holds), leave annotate
 * mode, then press the real target while the viewer already knows where to look.
 */
class MarkerLayer(
    private val ctx: Context,
    cfg: RecConfig,
    private val listener: Listener,
    /** False in "clean" mode: touches are captured but nothing is drawn into the recording. */
    private val drawLive: Boolean = true,
    /** Recording clock (ms of video so far); used to stamp markers placed in clean mode. */
    private val clock: (() -> Long)? = null,
    /** Called when a marker is finished: its spec and the video time it was placed at. */
    private val onPlaced: ((MarkerSpec, Long) -> Unit)? = null,
) {
    interface Listener {
        fun onAnnotateChanged(on: Boolean)
        fun onCountChanged(count: Int)
        fun onToolChanged() {}
    }

    private class Live(val spec: MarkerSpec, val placedAt: Long) {
        var placedClockMs = 0L
        var releasedAt = -1L
        var undoneAt = -1L
    }

    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private val markers = ArrayList<Live>()
    private lateinit var view: LayerView
    private lateinit var lp: WindowManager.LayoutParams
    private var attached = false

    var annotating = false
        private set
    var tool: MarkerType = MarkerType.of(cfg.markerTool)
        set(v) { field = v; listener.onToolChanged() }
    var color: Int = cfg.markerColor
        set(v) { field = v; listener.onToolChanged() }
    var thickness: Float = cfg.markerThickness
    private val holdMs = cfg.markerHoldMs.coerceIn(MarkerAnim.MIN_HOLD_MS, MarkerAnim.MAX_HOLD_MS)
    private val exitDelayMs = cfg.markerExitDelayMs
    private val autoExit = cfg.markerAutoExit || !drawLive
    private var nextNumber = 1

    private val exitRunnable = Runnable { setAnnotating(false) }

    /** Redraws once every marker has had its time, so an idle overlay never keeps a stale frame. */
    private val sweepRunnable = Runnable { if (attached) view.invalidate() }

    fun show() {
        if (attached) return
        view = LayerView(ctx)
        lp = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
        wm.addView(view, lp)
        attached = true
    }

    /** Clean mode: capture the next touch, give up after [timeoutMs] without one. */
    fun arm(timeoutMs: Long) {
        if (!attached) return
        setAnnotating(true)
        main.removeCallbacks(exitRunnable)
        main.postDelayed(exitRunnable, timeoutMs)
    }

    fun hide() {
        if (!attached) return
        main.removeCallbacks(exitRunnable)
        main.removeCallbacks(sweepRunnable)
        try { wm.removeView(view) } catch (_: Exception) {}
        attached = false
        markers.clear()
    }

    fun setAnnotating(on: Boolean) {
        if (!attached || annotating == on) return
        annotating = on
        main.removeCallbacks(exitRunnable)
        lp.flags = if (on) lp.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        else lp.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        wm.updateViewLayout(view, lp)
        if (!on) {
            // Safety net: a marker whose touch never reported its release still gets its time now.
            val now = SystemClock.uptimeMillis()
            markers.forEach { if (it.releasedAt < 0) release(it, now) }
        }
        listener.onAnnotateChanged(on)
        view.invalidate()
    }

    /**
     * Starts a marker's hold timer: it stays [holdMs] from now, then fades out and goes, whatever the
     * person does next (stay in point mode, switch page or app). The sweep guarantees a last redraw.
     */
    private fun release(m: Live, now: Long) {
        m.releasedAt = now
        main.postDelayed(sweepRunnable, holdMs + MarkerAnim.FADE_MS + 100)
    }

    fun undo() {
        val last = markers.lastOrNull { it.undoneAt < 0 } ?: return
        last.undoneAt = SystemClock.uptimeMillis()
        if (last.spec.type == MarkerType.NUMBER && nextNumber > 1) nextNumber--
        listener.onCountChanged(markers.count { it.undoneAt < 0 })
        view.invalidate()
    }

    fun clear() {
        val now = SystemClock.uptimeMillis()
        markers.forEach { if (it.undoneAt < 0) it.undoneAt = now }
        nextNumber = 1
        listener.onCountChanged(0)
        view.invalidate()
    }

    // ---- drawing --------------------------------------------------------------------------

    private inner class LayerView(c: Context) : View(c) {
        private var active: Live? = null
        private var downX = 0f
        private var downY = 0f
        private var dragged = false
        private var pinchBaseDist = 0f
        private var pinchBaseAngle = 0f
        private var pinchBaseScale = 1f
        private var pinchBaseRot = 0f

        private fun u() = width / 360f

        override fun onDraw(c: Canvas) {
            if (!drawLive) return
            val now = SystemClock.uptimeMillis()
            val w = width.toFloat()
            val h = height.toFloat()
            val motion = !ctx.animationsDisabled()
            val it = markers.iterator()
            var animating = false
            while (it.hasNext()) {
                val m = it.next()
                var t = now - m.placedAt
                var fadeStart = if (m.releasedAt < 0) Long.MAX_VALUE else m.releasedAt - m.placedAt + holdMs
                if (m.spec.type == MarkerType.PEN) { // pens draw instantly: skip the cue
                    t += MarkerAnim.CUE_MS
                    if (fadeStart != Long.MAX_VALUE) fadeStart += MarkerAnim.CUE_MS
                }
                val f = MarkerAnim.frame(t, fadeStart)
                val phaseMs = if (motion) (t - MarkerAnim.CUE_MS).coerceAtLeast(0L).toFloat() else 0f
                var undo = 1f
                if (m.undoneAt >= 0) undo = 1f - ((now - m.undoneAt) / 140f).coerceIn(0f, 1f)
                if (f.done || undo <= 0f) { it.remove(); continue }
                animating = true
                val a = MarkerRenderer.anchor(m.spec, w, h)
                if (f.cueProgress >= 0f) MarkerRenderer.drawCue(c, m.spec, w, h, a.x, a.y, f.cueProgress)
                MarkerRenderer.drawBody(c, m.spec, w, h, a.x, a.y, f.bodyAlpha * undo, f.bodyScale, f.press, phaseMs)
            }
            if (animating) postInvalidateOnAnimation()
        }

        // ---- gestures ---------------------------------------------------------------------

        override fun onTouchEvent(e: MotionEvent): Boolean {
            if (!annotating) return false
            val w = width.toFloat()
            val h = height.toFloat()
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    main.removeCallbacks(exitRunnable)
                    downX = e.x; downY = e.y; dragged = false
                    active = place(e.x / w, e.y / h)
                }
                MotionEvent.ACTION_POINTER_DOWN -> if (e.pointerCount == 2 && drawLive) beginPinch(e)
                MotionEvent.ACTION_MOVE -> {
                    val a = active ?: return true
                    if (e.pointerCount >= 2) { if (drawLive) updatePinch(e, a) }
                    else {
                        if (hypot(e.x - downX, e.y - downY) > ctx.resources.displayMetrics.density * 8) dragged = true
                        drag(a, e.x / w, e.y / h)
                    }
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    // After a pinch, further single-finger moves must not drag the marker.
                    dragged = true
                    pinchBaseDist = 0f
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val a = active
                    if (a != null && !dragged) finishTap(a)
                    if (a != null && a.releasedAt < 0) release(a, SystemClock.uptimeMillis())
                    if (a != null && e.actionMasked == MotionEvent.ACTION_UP) onPlaced?.invoke(a.spec, a.placedClockMs)
                    if (a != null && !drawLive) markers.remove(a)
                    active = null
                    listener.onCountChanged(markers.count { it.undoneAt < 0 })
                    if (autoExit && (tool != MarkerType.PEN || !drawLive) && e.actionMasked == MotionEvent.ACTION_UP) {
                        main.postDelayed(exitRunnable, if (drawLive) exitDelayMs else 150)
                    }
                }
            }
            invalidate()
            return true
        }

        private fun place(fx: Float, fy: Float): Live {
            val spec = MarkerSpec(tool, color = color, x0 = fx, y0 = fy, x1 = fx, y1 = fy, thickness = thickness)
            if (tool == MarkerType.PEN) spec.points = mutableListOf(fx, fy)
            if (tool == MarkerType.NUMBER) spec.number = nextNumber++
            val live = Live(spec, SystemClock.uptimeMillis())
            live.placedClockMs = clock?.invoke() ?: 0L
            markers.add(live)
            return live
        }

        private fun drag(a: Live, fx: Float, fy: Float) {
            val s = a.spec
            when (s.type) {
                MarkerType.FINGER, MarkerType.RIPPLE, MarkerType.NUMBER -> { s.x0 = fx; s.y0 = fy; s.x1 = fx; s.y1 = fy }
                MarkerType.ARROW -> { s.x1 = fx; s.y1 = fy }
                MarkerType.CIRCLE, MarkerType.RECT -> { s.x1 = fx; s.y1 = fy }
                MarkerType.PEN -> { s.points.add(fx); s.points.add(fy) }
            }
        }

        /** A tap (no drag) on a two-point tool gets a sensible default size. */
        private fun finishTap(a: Live) {
            val s = a.spec
            val w = width.toFloat()
            val h = height.toFloat()
            val un = u()
            when (s.type) {
                MarkerType.ARROW -> { // head at the tap, tail up-left... pointing from lower-right
                    s.x0 = s.x1 + 52f * un / w
                    s.y0 = s.y1 + 52f * un / h
                }
                MarkerType.CIRCLE -> {
                    s.x0 = s.x1 - 38f * un / w; s.x1 = s.x1 + 38f * un / w
                    s.y0 = s.y1 - 38f * un / h; s.y1 = s.y1 + 38f * un / h
                }
                MarkerType.RECT -> {
                    s.x0 = s.x1 - 46f * un / w; s.x1 = s.x1 + 46f * un / w
                    s.y0 = s.y1 - 30f * un / h; s.y1 = s.y1 + 30f * un / h
                }
                else -> Unit
            }
        }

        // For circle/rect/arrow the first touch is the start corner/tail; a drag moves (x1, y1).
        private fun beginPinch(e: MotionEvent) {
            // Two fingers landing together mean "adjust the previous marker", not "place another":
            // drop the marker the first finger just created and pinch the one before it.
            val fresh = active
            if (fresh != null && !dragged && SystemClock.uptimeMillis() - fresh.placedAt < 250) {
                val prev = markers.lastOrNull { it !== fresh && it.undoneAt < 0 }
                if (prev != null) {
                    markers.remove(fresh)
                    if (fresh.spec.type == MarkerType.NUMBER && nextNumber > 1) nextNumber--
                    active = prev
                }
            }
            val a = active ?: return
            pinchBaseDist = hypot(e.getX(0) - e.getX(1), e.getY(0) - e.getY(1))
            pinchBaseAngle = Math.toDegrees(atan2((e.getY(1) - e.getY(0)).toDouble(), (e.getX(1) - e.getX(0)).toDouble())).toFloat()
            pinchBaseScale = a.spec.scale
            pinchBaseRot = a.spec.rotationDeg
            dragged = true
        }

        private fun updatePinch(e: MotionEvent, a: Live) {
            if (pinchBaseDist < 1f) { beginPinch(e); return }
            val d = hypot(e.getX(0) - e.getX(1), e.getY(0) - e.getY(1))
            val ang = Math.toDegrees(atan2((e.getY(1) - e.getY(0)).toDouble(), (e.getX(1) - e.getX(0)).toDouble())).toFloat()
            a.spec.scale = (pinchBaseScale * d / pinchBaseDist).coerceIn(0.4f, 4f)
            a.spec.rotationDeg = pinchBaseRot + (ang - pinchBaseAngle)
        }
    }
}
