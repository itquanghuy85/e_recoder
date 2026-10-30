package com.huluca.escreenrecorder.export

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max

/**
 * Finds the moments the user touched the screen in a recording, after the fact.
 *
 * "dots": Android's "Show taps" option puts a round spot under every finger, so a touch is a small
 * round patch that appears (and moves, and goes away) while the rest of the picture stays put. It is
 * found by comparing neighbouring frames; the result has a place (x, y as fractions of the frame).
 * "changes": without that option only the moment is known: the screen was still, then changed.
 */
object TouchScan {
    const val W = 108
    const val H = 240
    const val STEP_MS = 125L
    private const val MAX_FRAMES = 1500
    private const val DIFF = 24
    private const val MIN_AREA = 6
    private const val MAX_SIDE = 26
    private const val MIN_FILL = 0.5
    private const val MAX_CHANGED = 0.05
    private const val STILL_FRAMES = 3
    private const val PAGE_CHANGE = 0.02
    private const val MERGE_MS = 1000L

    class Touch(val tMs: Long, var x: Double, var y: Double, var durMs: Long = 0, var dist: Double = 0.0) {
        val startX = x
        val startY = y
        fun toMap(): Map<String, Any?> = mapOf("tMs" to tMs, "x" to x, "y" to y, "durMs" to durMs, "dist" to dist)
    }

    /** The single small round patch that differs between two frames, as fractions of the frame; else null. */
    internal fun patch(a: IntArray, b: IntArray, w: Int = W, h: Int = H): DoubleArray? {
        if (a.size != b.size || a.size != w * h) return null
        val changed = BooleanArray(a.size)
        var n = 0
        for (i in a.indices) if (abs(a[i] - b[i]) > DIFF) { changed[i] = true; n++ }
        if (n < MIN_AREA || n.toDouble() / a.size > MAX_CHANGED) return null
        // Connected patches (4-neighbours); specks of 1-2 pixels are compression noise.
        val seen = BooleanArray(a.size)
        var best: DoubleArray? = null
        var found = 0
        val stack = IntArray(a.size)
        for (s in a.indices) {
            if (!changed[s] || seen[s]) continue
            var sp = 0
            stack[sp++] = s
            seen[s] = true
            var area = 0
            var x0 = w; var x1 = 0; var y0 = h; var y1 = 0
            var sx = 0L; var sy = 0L
            while (sp > 0) {
                val p = stack[--sp]
                val px = p % w
                val py = p / w
                area++
                sx += px; sy += py
                if (px < x0) x0 = px
                if (px > x1) x1 = px
                if (py < y0) y0 = py
                if (py > y1) y1 = py
                if (px > 0 && changed[p - 1] && !seen[p - 1]) { seen[p - 1] = true; stack[sp++] = p - 1 }
                if (px < w - 1 && changed[p + 1] && !seen[p + 1]) { seen[p + 1] = true; stack[sp++] = p + 1 }
                if (py > 0 && changed[p - w] && !seen[p - w]) { seen[p - w] = true; stack[sp++] = p - w }
                if (py < h - 1 && changed[p + w] && !seen[p + w]) { seen[p + w] = true; stack[sp++] = p + w }
            }
            if (area < 3) continue
            found++
            val bw = x1 - x0 + 1
            val bh = y1 - y0 + 1
            val round = bw <= MAX_SIDE && bh <= MAX_SIDE && area >= MIN_AREA &&
                area.toDouble() / (bw * bh) >= MIN_FILL && max(bw, bh).toDouble() / minOf(bw, bh) <= 1.7
            if (round) best = doubleArrayOf((sx.toDouble() / area + 0.5) / w, (sy.toDouble() / area + 0.5) / h)
        }
        return if (found == 1) best else null
    }

    /** Chains patches into touches: patches that follow each other nearby belong to the same finger. */
    internal fun chain(patches: List<Triple<Long, Double, Double>>): List<Touch> {
        val out = ArrayList<Touch>()
        var cur: Touch? = null
        var lastT = 0L
        for ((t, x, y) in patches) {
            val c = cur
            if (c != null && t - lastT <= STEP_MS * 4 && hypot(x - c.x, y - c.y) < 0.25) {
                c.x = x; c.y = y
                c.durMs = t - c.tMs
                c.dist = max(c.dist, hypot(x - c.startX, y - c.startY))
            } else {
                cur = Touch(t, x, y).also { out.add(it) }
            }
            lastT = t
        }
        return out
    }

    /** Moments (ms) where a still picture suddenly changes a lot: a press is the likely cause. */
    internal fun changes(fraction: List<Double>, stepMs: Long = STEP_MS): List<Long> {
        val out = ArrayList<Long>()
        var still = 0
        for (i in fraction.indices) {
            val f = fraction[i]
            if (f >= PAGE_CHANGE) {
                val t = i * stepMs
                if (still >= STILL_FRAMES && (out.isEmpty() || t - out.last() >= MERGE_MS)) out.add(t)
                still = 0
            } else if (f < 0.002) still++ else still = 0
        }
        return out
    }

    fun scan(ctx: Context, uri: Uri, durationMs: Long, mode: String): List<Map<String, Any?>> {
        val mmr = MediaMetadataRetriever()
        val patches = ArrayList<Triple<Long, Double, Double>>()
        val fractions = ArrayList<Double>()
        try {
            mmr.setDataSource(ctx, uri)
            val step = max(STEP_MS, durationMs / MAX_FRAMES)
            var prev: IntArray? = null
            var t = 0L
            while (t <= durationMs) {
                val bmp = mmr.getScaledFrameAtTime(t * 1000, MediaMetadataRetriever.OPTION_CLOSEST, W, H)
                if (bmp == null) { fractions.add(0.0); t += step; continue }
                val luma = lumaOf(bmp)
                bmp.recycle()
                val p = prev
                if (p != null && p.size == luma.size) {
                    if (mode == "dots") patch(p, luma)?.let { patches.add(Triple(t, it[0], it[1])) }
                    var n = 0
                    for (i in p.indices) if (abs(p[i] - luma[i]) > DIFF) n++
                    fractions.add(n.toDouble() / p.size)
                } else fractions.add(0.0)
                prev = luma
                t += step
            }
        } catch (_: Exception) {
            // An unreadable file simply has no touches.
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
        if (mode == "dots") return chain(patches).map { it.toMap() }
        return changes(fractions).map { mapOf("tMs" to it, "x" to -1.0, "y" to -1.0, "durMs" to 0L, "dist" to 0.0) }
    }

    /**
     * Where each touch of [timesMs] happened, found from the picture: the screen reacts to a press at
     * once, in the spot that was pressed (a button lights up, a ripple spreads, "show taps" draws a
     * spot). A frame just before the touch is compared with the frames just after it, and the place is
     * the middle of the part that changed first. When the whole screen changes (a new page, a
     * scroll) or nothing does, the place stays unknown (-1) and only the moment is used.
     * Returns one map per time, in the same order, shaped like a scan result.
     */
    fun locate(ctx: Context, uri: Uri, timesMs: List<Long>): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(ctx, uri)
            for (t in timesMs) {
                val before = frameLuma(mmr, (t - 90).coerceAtLeast(0))
                val bw = lastW
                val bh = lastH
                var spot: DoubleArray? = null
                if (before != null) {
                    for (dt in LOCATE_OFFSETS) {
                        val after = frameLuma(mmr, t + dt) ?: continue
                        if (lastW == bw && lastH == bh) spot = reaction(before, after, bw, bh)
                        if (spot != null) break
                    }
                }
                out.add(mapOf("tMs" to t, "x" to (spot?.get(0) ?: -1.0), "y" to (spot?.get(1) ?: -1.0), "durMs" to 0L, "dist" to 0.0))
            }
        } catch (e: Exception) {
            android.util.Log.w("TouchScan", "locate failed", e)
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
        // A reader that failed early leaves the rest without a place.
        while (out.size < timesMs.size) {
            out.add(mapOf("tMs" to timesMs[out.size], "x" to -1.0, "y" to -1.0, "durMs" to 0L, "dist" to 0.0))
        }
        return out
    }

    // A press shows for a frame or two (a faint ripple on the key), about 250 ms after the touch on a phone
    // that records at 30 fps with encoder delay: look at every ~40 ms and take the first reaction.
    private val LOCATE_OFFSETS = LongArray(17) { 40L * (it + 1) }

    // The frame comes back with its own aspect ratio (not always exactly W x H): keep its real size.
    private var lastW = W
    private var lastH = H

    private fun frameLuma(mmr: MediaMetadataRetriever, ms: Long): IntArray? {
        val bmp = mmr.getScaledFrameAtTime(ms * 1000, MediaMetadataRetriever.OPTION_CLOSEST, W, H) ?: return null
        lastW = bmp.width
        lastH = bmp.height
        val l = lumaOf(bmp)
        bmp.recycle()
        return l
    }

    /**
     * The middle of the biggest changed area between two frames, as fractions, when that area is a
     * part of the screen (not a page change: more than [REACT_MAX] of it) and not just noise.
     */
    internal fun reaction(a: IntArray, b: IntArray, w: Int = W, h: Int = H): DoubleArray? {
        if (a.size != b.size || a.size != w * h) return null
        val changed = BooleanArray(a.size)
        var n = 0
        for (i in a.indices) if (abs(a[i] - b[i]) > REACT_DIFF) { changed[i] = true; n++ }
        val share = n.toDouble() / a.size
        if (n < REACT_MIN || share > REACT_MAX) return null
        // The biggest connected area wins; small flecks elsewhere (a clock, an animation) are ignored.
        val seen = BooleanArray(a.size)
        val stack = IntArray(a.size)
        var bestArea = 0
        var bx = 0.0
        var by = 0.0
        for (s in a.indices) {
            if (!changed[s] || seen[s]) continue
            var sp = 0
            stack[sp++] = s
            seen[s] = true
            var area = 0
            var sx = 0L
            var sy = 0L
            while (sp > 0) {
                val p = stack[--sp]
                val px = p % w
                val py = p / w
                area++
                sx += px; sy += py
                if (px > 0 && changed[p - 1] && !seen[p - 1]) { seen[p - 1] = true; stack[sp++] = p - 1 }
                if (px < w - 1 && changed[p + 1] && !seen[p + 1]) { seen[p + 1] = true; stack[sp++] = p + 1 }
                if (py > 0 && changed[p - w] && !seen[p - w]) { seen[p - w] = true; stack[sp++] = p - w }
                if (py < h - 1 && changed[p + w] && !seen[p + w]) { seen[p + w] = true; stack[sp++] = p + w }
            }
            if (area > bestArea) {
                bestArea = area
                bx = (sx.toDouble() / area + 0.5) / w
                by = (sy.toDouble() / area + 0.5) / h
            }
        }
        return if (bestArea >= REACT_MIN) doubleArrayOf(bx, by) else null
    }

    // Low on purpose: the ripple of a pressed key is faint. The biggest connected area wins, which is the key
    // (the digit that appears after it is small), and the first frame with a reaction decides.
    private const val REACT_DIFF = 4
    private const val REACT_MIN = 20
    private const val REACT_MAX = 0.35

    private fun lumaOf(b: Bitmap): IntArray {
        val w = b.width
        val h = b.height
        val px = IntArray(w * h)
        b.getPixels(px, 0, w, 0, 0, w, h)
        return IntArray(px.size) {
            val c = px[it]
            (((c shr 16) and 0xFF) * 299 + ((c shr 8) and 0xFF) * 587 + (c and 0xFF) * 114) / 1000
        }
    }
}
