package com.huluca.escreenrecorder.export

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Shader
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import com.huluca.escreenrecorder.marker.MarkerRenderer
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/** Bitmaps for text, cover, shape and image clips. Shared by the editor preview and the export. */
object OverlayRenderers {
    class Rendered(val bitmap: Bitmap, val wPx: Int, val hPx: Int)

    private fun typefaceFor(font: String, bold: Boolean): Typeface {
        val style = if (bold) Typeface.BOLD else Typeface.NORMAL
        return when (font) {
            "sans" -> Typeface.create(Typeface.SANS_SERIF, style)
            "condensed" -> Typeface.create("sans-serif-condensed", style)
            "serif" -> Typeface.create(Typeface.SERIF, style)
            "mono" -> Typeface.create(Typeface.MONOSPACE, style)
            "cursive" -> Typeface.create("cursive", style)
            else -> if (bold) MarkerRenderer.typeface else Typeface.DEFAULT
        }
    }

    /** Text with an optional outline, shadow and background box. Anchor is the bitmap centre. */
    fun renderText(clip: TextClip, frameW: Int): Rendered {
        val u = frameW / 360f
        val size = clip.sizeU * u
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = clip.color or 0xFF000000.toInt()
            textSize = size
            typeface = typefaceFor(clip.font, clip.bold)
            textAlign = Paint.Align.LEFT
        }
        val halo = Paint(fill).apply {
            style = Paint.Style.STROKE
            strokeWidth = max(2f, size * 0.16f)
            strokeJoin = Paint.Join.ROUND
            color = MarkerRenderer.haloColor(clip.color)
        }
        val lines = clip.text.split('\n').ifEmpty { listOf("") }
        val lineH = size * 1.2f
        val haloPad = if (clip.outline) halo.strokeWidth else 0f
        val shadowR = if (clip.shadow) size * 0.12f else 0f
        val boxPad = if (clip.box != null) size * 0.35f else 0f
        val fxPad = when (clip.fx) {
            "glow" -> size * 0.45f
            "extrude" -> size * 0.12f
            "glitch" -> size * 0.07f
            "sticker" -> size * 0.3f
            "hollow" -> size * 0.06f
            else -> 0f
        }
        val pad = haloPad + boxPad + shadowR * 2 + fxPad + 4f * u
        val widths = lines.map { fill.measureText(it) }
        val textW = widths.max()
        val w = ceil(textW + pad * 2).toInt().coerceAtLeast(8)
        val h = ceil(lineH * lines.size + pad * 2).toInt().coerceAtLeast(8)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        if (clip.box != null) {
            val bp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = clip.box }
            val inset = pad - boxPad - shadowR
            c.drawRoundRect(RectF(inset, inset, w - inset, h - inset), size * 0.3f, size * 0.3f, bp)
        }
        if (clip.shadow) fill.setShadowLayer(shadowR, shadowR * 0.5f, shadowR * 0.7f, 0xAA000000.toInt())
        lines.forEachIndexed { i, line ->
            val lw = widths[i]
            val x = when (clip.align) {
                "left" -> pad
                "right" -> w - pad - lw
                else -> (w - lw) / 2f
            }
            val y = pad + lineH * i + size * 0.95f
            if (clip.outline) c.drawText(line, x, y, halo)
            drawFx(c, clip, fill, line, x, y, size)
        }
        return Rendered(bmp, w, h)
    }

    /**
     * One caption cue rendered at rest (no per-word reveal yet), drawn with [style] only.
     *
     * Like [renderText], the bitmap is anchored at its centre and [Rendered.wPx]/[Rendered.hPx] tell
     * the caller how big it is, so this function does not position anything: the caller places the
     * bitmap (Dart preview and the export both already do this for text). [CaptionStyle.x] /
     * [CaptionStyle.y] are therefore ignored here, and no `frameH` is needed.
     *
     * [frameW] is used only to convert U units to pixels and to wrap lines. A null [style] falls back
     * to [CaptionStyle] defaults. Text effects use the style's own colour/width/blur/radius; the
     * `drawFx` presets are for [TextClip.fx] only and are not used here.
     */
    fun renderCue(cue: CaptionCue, style: CaptionStyle?, frameW: Int): Rendered {
        val st = style ?: CaptionStyle()
        val u = frameW / 360f
        val size = st.sizeU * u
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = st.color
            textSize = size
            typeface = typefaceFor(st.fontId, true)
            textAlign = Paint.Align.LEFT
        }
        val outlineW = if (st.outlineColor != null && st.outlineWidth > 0f) st.outlineWidth * u else 0f
        val shadowR = if (st.shadowColor != null && st.shadowBlur > 0f) st.shadowBlur * u else 0f
        val boxPad = if (st.boxColor != null) size * 0.35f else 0f
        val padding = 4f * u + outlineW + shadowR * 2f + boxPad
        val maxW = (frameW - padding * 2f).coerceAtLeast(size)

        val lines = wrapCueText(cue.text, maxW, fill)
        val lineH = size * 1.2f
        val widths = lines.map { fill.measureText(it) }
        val textW = widths.maxOrNull() ?: 0f
        val w = ceil(textW + padding * 2f).toInt().coerceAtLeast(8)
        val h = ceil(lineH * lines.size + padding * 2f).toInt().coerceAtLeast(8)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        if (st.boxColor != null) {
            val inset = (padding - boxPad - shadowR).coerceAtLeast(0f)
            val bp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = st.boxColor }
            val r = st.boxRadius * u
            c.drawRoundRect(RectF(inset, inset, w - inset, h - inset), r, r, bp)
        }
        val halo = if (outlineW > 0f) {
            Paint(fill).apply {
                setStyle(Paint.Style.STROKE)
                strokeWidth = outlineW
                strokeJoin = Paint.Join.ROUND
                color = st.outlineColor ?: 0xFF000000.toInt()
            }
        } else {
            null
        }
        if (shadowR > 0f) {
            fill.setShadowLayer(shadowR, shadowR * 0.5f, shadowR * 0.7f, st.shadowColor ?: 0xFF000000.toInt())
        }
        lines.forEachIndexed { i, line ->
            val lw = widths[i]
            val x = when (st.align) {
                "left" -> padding
                "right" -> w - padding - lw
                else -> (w - lw) / 2f
            }
            val y = padding + lineH * i + size * 0.95f
            if (halo != null) c.drawText(line, x, y, halo)
            c.drawText(line, x, y, fill)
        }
        return Rendered(bmp, w, h)
    }

    /** Splits [text] into lines no wider than [maxWidth] px, measuring words with [paint]. */
    private fun wrapCueText(text: String, maxWidth: Float, paint: Paint): List<String> {
        val out = mutableListOf<String>()
        for (para in text.split('\n')) {
            val words = para.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
            if (words.isEmpty()) {
                out.add("")
                continue
            }
            val sb = StringBuilder()
            var lineW = 0f
            for (word in words) {
                val wordW = paint.measureText(word)
                val spaceW = if (sb.isEmpty()) 0f else paint.measureText(" ")
                if (sb.isNotEmpty() && lineW + spaceW + wordW > maxWidth) {
                    out.add(sb.toString())
                    sb.setLength(0)
                    sb.append(word)
                    lineW = wordW
                } else {
                    if (sb.isNotEmpty()) {
                        sb.append(' ')
                        lineW += spaceW
                    }
                    sb.append(word)
                    lineW += wordW
                }
            }
            out.add(sb.toString())
        }
        return out.ifEmpty { listOf("") }
    }

    private fun scaleRgb(color: Int, f: Float): Int {
        val r = (((color shr 16) and 0xFF) * f).toInt().coerceIn(0, 255)
        val g = (((color shr 8) and 0xFF) * f).toInt().coerceIn(0, 255)
        val b = ((color and 0xFF) * f).toInt().coerceIn(0, 255)
        return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
    }

    /** One line of text in the look [TextClip.fx] asks for; "none" is the plain fill. */
    private fun drawFx(c: Canvas, clip: TextClip, fill: Paint, line: String, x: Float, y: Float, size: Float) {
        val base = clip.color or 0xFF000000.toInt()
        when (clip.fx) {
            "glow" -> {
                val g = Paint(fill).apply { setShadowLayer(size * 0.4f, 0f, 0f, base) }
                c.drawText(line, x, y, g)
                c.drawText(line, x, y, g)
                val core = Paint(fill).apply { color = 0xFFFFFFFF.toInt(); clearShadowLayer() }
                core.alpha = 200
                c.drawText(line, x, y, core)
            }
            "gradient" -> {
                val p = Paint(fill).apply {
                    shader = LinearGradient(x, y - size * 0.85f, x, y + size * 0.12f, base, 0xFFFF5F6D.toInt(), Shader.TileMode.CLAMP)
                }
                c.drawText(line, x, y, p)
            }
            "extrude" -> {
                val step = max(1f, size * 0.018f)
                val depth = 6
                val dark = Paint(fill).apply { color = scaleRgb(base, 0.45f); clearShadowLayer() }
                for (k in depth downTo 1) c.drawText(line, x + k * step, y + k * step, dark)
                c.drawText(line, x, y, fill)
            }
            "hollow" -> {
                val p = Paint(fill).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = max(2f, size * 0.06f)
                    strokeJoin = Paint.Join.ROUND
                    clearShadowLayer()
                }
                c.drawText(line, x, y, p)
            }
            "glitch" -> {
                val g = size * 0.045f
                val cyan = Paint(fill).apply { color = 0xFF00E5FF.toInt(); clearShadowLayer() }
                val red = Paint(fill).apply { color = 0xFFFF2D55.toInt(); clearShadowLayer() }
                c.drawText(line, x - g, y, cyan)
                c.drawText(line, x + g, y, red)
                c.drawText(line, x, y, fill)
            }
            "sticker" -> {
                val edge = Paint(fill).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = size * 0.26f
                    strokeJoin = Paint.Join.ROUND
                    color = 0xFFFFFFFF.toInt()
                    setShadowLayer(size * 0.1f, 0f, size * 0.05f, 0x88000000.toInt())
                }
                c.drawText(line, x, y, edge)
                val inner = Paint(fill).apply { clearShadowLayer() }
                c.drawText(line, x, y, inner)
            }
            else -> c.drawText(line, x, y, fill)
        }
    }

    /** A solid rounded block that hides what is under it. */
    fun renderCover(clip: CoverClip, frameW: Int, frameH: Int): Rendered {
        val u = frameW / 360f
        val w = max(8, ((clip.x1 - clip.x0) * frameW).toInt())
        val h = max(8, ((clip.y1 - clip.y0) * frameH).toInt())
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = clip.color or 0xFF000000.toInt() }
        c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), 6f * u, 6f * u, p)
        return Rendered(bmp, w, h)
    }

    /** A drawn shape or a callout bubble. The bitmap is centred on the shape's centre. */
    fun renderShape(clip: ShapeClip, frameW: Int, frameH: Int): Rendered {
        val u = frameW / 360f
        val stroke = max(1f, clip.strokeU * u)
        val bw = clip.w * frameW
        val bh = clip.h * frameH
        val tailDx = clip.tailX * frameW
        val tailDy = clip.tailY * frameH
        // Symmetric bounds so the bitmap centre is the shape centre; bubbles also need room for the tail.
        val halfW = (if (clip.kind == "bubble") max(bw / 2, abs(tailDx)) else bw / 2) + stroke * 2 + 2
        val halfH = (if (clip.kind == "bubble") max(bh / 2, abs(tailDy)) else bh / 2) + stroke * 2 + 2
        val w = max(8, ceil(halfW * 2).toInt())
        val h = max(8, ceil(halfH * 2).toInt())
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val cx = w / 2f
        val cy = h / 2f
        val col = clip.color or 0xFF000000.toInt()
        val strokeP = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = stroke; color = col
            strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
        }
        val fillP = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL; color = col }
        val rect = RectF(cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2)
        when (clip.kind) {
            "ellipse" -> c.drawOval(rect, if (clip.filled) fillP else strokeP)
            "line" -> c.drawLine(rect.left, rect.top, rect.right, rect.bottom, strokeP)
            "arrow" -> {
                val x0 = rect.left
                val y0 = rect.top
                val x1 = rect.right
                val y1 = rect.bottom
                c.drawLine(x0, y0, x1, y1, strokeP)
                val ang = atan2(y1 - y0, x1 - x0)
                val head = stroke * 4.5f
                for (side in intArrayOf(-1, 1)) {
                    val a = ang + Math.PI.toFloat() + side * 0.5f
                    c.drawLine(x1, y1, x1 + head * cos(a), y1 + head * sin(a), strokeP)
                }
            }
            "bubble" -> {
                val r = bh * 0.25f
                val path = Path()
                path.addRoundRect(rect, r, r, Path.Direction.CW)
                // tail: a triangle from the nearest edge point to the tip
                val tipX = cx + tailDx
                val tipY = cy + tailDy
                val baseX = tipX.coerceIn(rect.left + r, rect.right - r)
                val baseY = if (tipY > cy) rect.bottom else rect.top
                val half = max(stroke * 2f, bh * 0.14f)
                val tail = Path().apply {
                    moveTo(baseX - half, baseY)
                    lineTo(tipX, tipY)
                    lineTo(baseX + half, baseY)
                    close()
                }
                path.op(tail, Path.Op.UNION)
                c.drawPath(path, fillP.apply { color = if (clip.filled || clip.text.isNotEmpty()) 0xFFFFFFFF.toInt() else col })
                c.drawPath(path, strokeP)
                if (clip.text.isNotEmpty()) {
                    val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = clip.textColor or 0xFF000000.toInt()
                        typeface = MarkerRenderer.typeface
                        textAlign = Paint.Align.CENTER
                        textSize = bh * 0.42f
                    }
                    // shrink to fit the bubble
                    val tw = tp.measureText(clip.text)
                    if (tw > bw * 0.88f) tp.textSize *= bw * 0.88f / tw
                    c.drawText(clip.text, cx, cy + tp.textSize * 0.35f, tp)
                }
            }
            else -> c.drawRoundRect(rect, 4f * u, 4f * u, if (clip.filled) fillP else strokeP)
        }
        return Rendered(bmp, w, h)
    }

    /** A picture from the phone, scaled to [widthPx] wide (height follows its shape). */
    fun loadImage(path: String, widthPx: Int): Rendered {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        require(bounds.outWidth > 0) { "unreadable image" }
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= widthPx) sample *= 2
        val raw = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IllegalStateException("image decode failed")
        val w = max(2, widthPx)
        val h = max(2, (raw.height.toLong() * w / raw.width).toInt())
        val bmp = if (raw.width == w) raw else Bitmap.createScaledBitmap(raw, w, h, true).also { raw.recycle() }
        return Rendered(bmp, bmp.width, bmp.height)
    }
}
