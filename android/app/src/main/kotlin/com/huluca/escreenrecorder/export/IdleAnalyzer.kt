package com.huluca.escreenrecorder.export

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import kotlin.math.abs

/**
 * Finds stretches where the screen does not change (loading, waiting, talking over a still page),
 * so the editor can play them faster. Frames are sampled small and compared by luma, which is
 * cheap and ignores the tiny differences of video compression noise.
 */
object IdleAnalyzer {
    private const val MIN_GAP_MS = 800L
    private const val W = 48
    private const val H = 84
    private const val MEAN_DIFF = 1.6
    private const val CHANGED_PIXEL = 28
    private const val CHANGED_FRACTION = 0.004
    private const val MIN_IDLE_MS = 1800L
    private const val BEFORE_CHANGE_MS = 250L

    /**
     * Key-frame times in ms, at least [MIN_GAP_MS] apart. Decoding only key frames keeps the scan fast
     * (about a frame per second) and every sample is a genuinely different picture.
     */
    private fun keyFrameTimes(ctx: Context, uri: Uri): List<Long> {
        val ex = MediaExtractor()
        val out = ArrayList<Long>()
        try {
            ex.setDataSource(ctx, uri, null)
            val track = (0 until ex.trackCount).firstOrNull {
                ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
            } ?: return out
            ex.selectTrack(track)
            var last = -MIN_GAP_MS
            while (true) {
                if (ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
                    val t = ex.sampleTime / 1000
                    if (t - last >= MIN_GAP_MS) { out.add(t); last = t }
                }
                if (!ex.advance()) break
            }
        } catch (_: Exception) {
        } finally {
            try { ex.release() } catch (_: Exception) {}
        }
        return out
    }

    /** Returns [start, end] pairs in source milliseconds. */
    fun analyze(ctx: Context, uri: Uri, durationMs: Long): List<List<Long>> {
        val times = keyFrameTimes(ctx, uri)
        val mmr = MediaMetadataRetriever()
        val out = ArrayList<List<Long>>()
        try {
            mmr.setDataSource(ctx, uri)
            var prev: IntArray? = null
            var runStart = -1L
            var lastStill = 0L
            var prevT = 0L
            // Some encoders (Samsung) emit a key frame only when the picture changes, so the key frame that ends a
            // still stretch already shows the change. A long gap gets one exact sample just before its end.
            val samples = ArrayList<Pair<Long, Boolean>>()
            for ((i, t) in times.withIndex()) {
                if (i > 0 && t - times[i - 1] > MIN_IDLE_MS) samples.add(Pair(t - BEFORE_CHANGE_MS, true))
                samples.add(Pair(t, false))
            }
            for ((t, exact) in samples) {
                if (t > durationMs) break
                val option = if (exact) MediaMetadataRetriever.OPTION_CLOSEST else MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                val bmp = mmr.getScaledFrameAtTime(t * 1000, option, W, H) ?: continue
                val luma = lumaOf(bmp)
                bmp.recycle()
                val p = prev
                if (p != null) {
                    if (isStill(p, luma)) {
                        if (runStart < 0) runStart = prevT
                        lastStill = t
                    } else {
                        if (runStart >= 0 && lastStill - runStart >= MIN_IDLE_MS) out.add(listOf(runStart, lastStill))
                        runStart = -1
                    }
                }
                prev = luma
                prevT = t
            }
            if (runStart >= 0 && lastStill - runStart >= MIN_IDLE_MS) out.add(listOf(runStart, lastStill))
        } catch (_: Exception) {
            // An unreadable file simply has no idle stretches.
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
        return out
    }

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

    internal fun isStill(a: IntArray, b: IntArray): Boolean {
        if (a.size != b.size) return false
        var sum = 0L
        var changed = 0
        for (i in a.indices) {
            val d = abs(a[i] - b[i])
            sum += d
            if (d > CHANGED_PIXEL) changed++
        }
        return sum.toDouble() / a.size < MEAN_DIFF && changed.toDouble() / a.size < CHANGED_FRACTION
    }
}
