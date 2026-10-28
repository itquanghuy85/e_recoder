package com.huluca.escreenrecorder.marker

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import com.huluca.escreenrecorder.R
import com.huluca.escreenrecorder.overlay.Tokens
import com.huluca.escreenrecorder.overlay.dp

/**
 * The marker tool panel shown under the control bar while annotate mode is on:
 * tools, colours, stroke size, undo and clear. Every target is at least 44 dp.
 */
class MarkerTray(private val ctx: Context, private val layer: MarkerLayer) : LinearLayout(ctx) {
    private val tools = ArrayList<ToolButton>()
    private val colors = ArrayList<ColorDot>()
    private val sizes = ArrayList<SizeButton>()

    init {
        orientation = VERTICAL
        setPadding(ctx.dp(6f), ctx.dp(6f), ctx.dp(6f), ctx.dp(6f))
        background = GradientDrawable().apply {
            setColor(Tokens.SURFACE)
            cornerRadius = ctx.dp(20f).toFloat()
            setStroke(ctx.dp(1f), Tokens.OUTLINE)
        }

        val toolOrder = listOf(
            MarkerType.FINGER to R.string.tool_finger, MarkerType.RIPPLE to R.string.tool_ripple,
            MarkerType.ARROW to R.string.tool_arrow, MarkerType.CIRCLE to R.string.tool_circle,
            MarkerType.RECT to R.string.tool_rect, MarkerType.PEN to R.string.tool_pen,
            MarkerType.NUMBER to R.string.tool_number,
        )
        addView(row().also { r ->
            toolOrder.forEach { (type, label) ->
                val b = ToolButton(ctx, type).apply {
                    contentDescription = ctx.getString(label)
                    setOnClickListener { layer.tool = type; refresh() }
                }
                tools.add(b); r.addView(b, LayoutParams(ctx.dp(44f), ctx.dp(44f)))
            }
        })

        val palette = intArrayOf(
            0xFFFF3B30.toInt(), 0xFFFFC02E.toInt(), 0xFF2BE37A.toInt(), 0xFF2DD4F0.toInt(),
            0xFFFF4FA3.toInt(), 0xFFFFFFFF.toInt(), 0xFF111111.toInt(),
        )
        val names = intArrayOf(
            R.string.color_red, R.string.color_amber, R.string.color_green, R.string.color_cyan,
            R.string.color_magenta, R.string.color_white, R.string.color_black,
        )
        addView(row().also { r ->
            palette.forEachIndexed { i, col ->
                val d = ColorDot(ctx, col).apply {
                    contentDescription = ctx.getString(names[i])
                    setOnClickListener { layer.color = col; refresh() }
                }
                colors.add(d); r.addView(d, LayoutParams(ctx.dp(44f), ctx.dp(44f)))
            }
        })

        addView(row().also { r ->
            listOf(3f to R.string.size_thin, 5f to R.string.size_medium, 8f to R.string.size_thick).forEach { (u, label) ->
                val b = SizeButton(ctx, u).apply {
                    contentDescription = ctx.getString(label)
                    setOnClickListener { layer.thickness = u; refresh() }
                }
                sizes.add(b); r.addView(b, LayoutParams(ctx.dp(56f), ctx.dp(44f)))
            }
            r.addView(View(ctx), LayoutParams(0, 1, 1f))
            r.addView(ActionButton(ctx, ActionButton.UNDO).apply {
                contentDescription = ctx.getString(R.string.action_undo)
                setOnClickListener { layer.undo() }
            }, LayoutParams(ctx.dp(44f), ctx.dp(44f)))
            r.addView(ActionButton(ctx, ActionButton.CLEAR).apply {
                contentDescription = ctx.getString(R.string.action_clear)
                setOnClickListener { layer.clear() }
            }, LayoutParams(ctx.dp(44f), ctx.dp(44f)))
        })
        refresh()
    }

    private fun row() = LinearLayout(ctx).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    fun refresh() {
        tools.forEach { it.selectedTool = it.type == layer.tool; it.tint = layer.color; it.invalidate() }
        colors.forEach { it.selectedColor = it.color == layer.color; it.invalidate() }
        sizes.forEach { it.selectedSize = it.units == layer.thickness; it.tint = layer.color; it.invalidate() }
    }
}

private val selectionFill = 0x334DD6E8

class ToolButton(ctx: Context, val type: MarkerType) : View(ctx) {
    var selectedTool = false
    var tint = 0xFFFF3B30.toInt()
    private val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = selectionFill }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; color = Tokens.KEY; strokeWidth = ctx.dp(1.5f).toFloat()
    }

    init { isClickable = true; isFocusable = true }

    override fun onDraw(c: Canvas) {
        val w = width.toFloat()
        val r = RectF(w * 0.06f, w * 0.06f, w * 0.94f, w * 0.94f)
        if (selectedTool) {
            c.drawRoundRect(r, w * 0.26f, w * 0.26f, bg)
            c.drawRoundRect(r, w * 0.26f, w * 0.26f, ring)
        }
        MarkerRenderer.drawIcon(c, type, w / 2, height / 2f, w * 0.52f, if (tint == 0xFF111111.toInt()) Tokens.ON_SURFACE else tint)
    }
}

class ColorDot(ctx: Context, val color: Int) : View(ctx) {
    var selectedColor = false
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = this@ColorDot.color }
    private val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; this.color = Tokens.OUTLINE; strokeWidth = ctx.dp(1f).toFloat()
    }
    private val sel = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; this.color = Tokens.KEY; strokeWidth = ctx.dp(2f).toFloat()
    }

    init { isClickable = true; isFocusable = true }

    override fun onDraw(c: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val r = width * 0.3f
        c.drawCircle(cx, cy, r, fill)
        c.drawCircle(cx, cy, r, edge)
        if (selectedColor) c.drawCircle(cx, cy, r + ctx().dp(3.5f), sel)
    }

    private fun ctx() = context
}

class SizeButton(ctx: Context, val units: Float) : View(ctx) {
    var selectedSize = false
    var tint = 0xFFFF3B30.toInt()
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeCap = Paint.Cap.ROUND }
    private val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = selectionFill }

    init { isClickable = true; isFocusable = true }

    override fun onDraw(c: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        if (selectedSize) c.drawRoundRect(RectF(w * 0.08f, h * 0.1f, w * 0.92f, h * 0.9f), h * 0.3f, h * 0.3f, bg)
        line.color = if (tint == 0xFF111111.toInt()) Tokens.ON_SURFACE else tint
        line.strokeWidth = units * context.resources.displayMetrics.density * 0.9f
        c.drawLine(w * 0.28f, h / 2, w * 0.72f, h / 2, line)
    }
}

class ActionButton(ctx: Context, val kind: Int) : View(ctx) {
    companion object { const val UNDO = 0; const val CLEAR = 1 }

    private val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; color = Tokens.ON_SURFACE; strokeWidth = ctx.dp(2f).toFloat()
        strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }

    init { isClickable = true; isFocusable = true }

    override fun onDraw(c: Canvas) {
        val s = width / 24f
        c.save()
        c.translate(width / 2f, height / 2f)
        c.scale(s * 0.5f, s * 0.5f)
        p.strokeWidth = 2.2f
        if (kind == UNDO) {
            val path = Path().apply {
                moveTo(-8f, -3f); lineTo(-8f, -9f); moveTo(-8f, -3f); lineTo(-2f, -3f)
                moveTo(-8f, -3f)
                cubicTo(-4f, -9f, 6f, -9f, 9f, -1f)
                cubicTo(11f, 5f, 6f, 10f, 1f, 9f)
            }
            c.drawPath(path, p)
        } else {
            val path = Path().apply {
                moveTo(-8f, -6f); lineTo(8f, -6f)
                moveTo(-3f, -6f); lineTo(-3f, -9f); lineTo(3f, -9f); lineTo(3f, -6f)
                moveTo(-6f, -6f); lineTo(-5f, 9f); lineTo(5f, 9f); lineTo(6f, -6f)
            }
            c.drawPath(path, p)
        }
        c.restore()
    }
}
