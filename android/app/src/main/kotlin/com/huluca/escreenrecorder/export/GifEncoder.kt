package com.huluca.escreenrecorder.export

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import kotlin.math.max
import kotlin.math.min

/** GIF89a writer: global palette, LZW, looping. Only what the exporter needs. */
class GifWriter(private val out: OutputStream, private val width: Int, private val height: Int, palette: IntArray) {
    private val pal = IntArray(256) { palette.getOrElse(it) { 0 } }

    init {
        out.write("GIF89a".toByteArray())
        writeShort(width); writeShort(height)
        out.write(0xF7) // global colour table, 8 bits per colour, 256 entries
        out.write(0); out.write(0)
        for (c in pal) { out.write((c shr 16) and 0xFF); out.write((c shr 8) and 0xFF); out.write(c and 0xFF) }
        // Netscape 2.0 loop forever
        out.write(byteArrayOf(0x21, 0xFF.toByte(), 0x0B))
        out.write("NETSCAPE2.0".toByteArray())
        out.write(byteArrayOf(0x03, 0x01, 0x00, 0x00, 0x00))
    }

    private fun writeShort(v: Int) { out.write(v and 0xFF); out.write((v shr 8) and 0xFF) }

    /** [indices] holds one palette index per pixel, row by row. [delayCs] is in 1/100 s. */
    fun addFrame(indices: ByteArray, delayCs: Int) {
        out.write(byteArrayOf(0x21, 0xF9.toByte(), 0x04, 0x04)) // disposal: leave in place
        writeShort(delayCs); out.write(0); out.write(0)
        out.write(0x2C)
        writeShort(0); writeShort(0); writeShort(width); writeShort(height)
        out.write(0)
        lzw(indices)
    }

    fun finish() { out.write(0x3B); out.flush() }

    private fun lzw(data: ByteArray) {
        val minCode = 8
        out.write(minCode)
        val clear = 1 shl minCode
        val eoi = clear + 1
        var codeSize = minCode + 1
        var next = eoi + 1
        val dict = HashMap<Int, Int>(8192)
        val block = ByteArray(255)
        var blockLen = 0
        var bitBuf = 0
        var bitCnt = 0

        fun flushBlock() {
            if (blockLen > 0) { out.write(blockLen); out.write(block, 0, blockLen); blockLen = 0 }
        }
        fun emit(code: Int) {
            bitBuf = bitBuf or (code shl bitCnt)
            bitCnt += codeSize
            while (bitCnt >= 8) {
                block[blockLen++] = (bitBuf and 0xFF).toByte()
                bitBuf = bitBuf ushr 8
                bitCnt -= 8
                if (blockLen == 255) flushBlock()
            }
        }

        emit(clear)
        var prefix = data[0].toInt() and 0xFF
        for (i in 1 until data.size) {
            val c = data[i].toInt() and 0xFF
            val key = (prefix shl 8) or c
            val hit = dict[key]
            if (hit != null) {
                prefix = hit
            } else {
                emit(prefix)
                if (next < 4096) {
                    dict[key] = next++
                    if (next > (1 shl codeSize) && codeSize < 12) codeSize++
                } else {
                    emit(clear)
                    dict.clear()
                    next = eoi + 1
                    codeSize = minCode + 1
                }
                prefix = c
            }
        }
        emit(prefix)
        emit(eoi)
        if (bitCnt > 0) block[blockLen++] = (bitBuf and 0xFF).toByte()
        flushBlock()
        out.write(0)
    }
}

/** Median-cut quantiser over 5-bit-per-channel colours (plenty for screen recordings). */
class Palette(samples: List<IntArray>) {
    val colors = IntArray(256)
    private val lookup = IntArray(32768) { -1 }

    init {
        val hist = IntArray(32768)
        for (px in samples) for (p in px) hist[key(p)]++
        class Box(val keys: IntArray) {
            var lo = IntArray(3); var hi = IntArray(3)
            init {
                lo = intArrayOf(31, 31, 31); hi = intArrayOf(0, 0, 0)
                for (k in keys) {
                    val c = intArrayOf((k shr 10) and 31, (k shr 5) and 31, k and 31)
                    for (a in 0..2) { lo[a] = min(lo[a], c[a]); hi[a] = max(hi[a], c[a]) }
                }
            }
            fun range(a: Int) = hi[a] - lo[a]
            fun weight() = keys.sumOf { hist[it].toLong() }
        }
        val used = (0 until 32768).filter { hist[it] > 0 }.toIntArray()
        val boxes = ArrayList<Box>()
        boxes.add(Box(if (used.isEmpty()) intArrayOf(0) else used))
        while (boxes.size < 256) {
            val b = boxes.filter { it.keys.size > 1 }.maxByOrNull { max(it.range(0), max(it.range(1), it.range(2))) * 1.0 * it.weight().coerceAtLeast(1) } ?: break
            val axis = (0..2).maxByOrNull { b.range(it) }!!
            val shift = when (axis) { 0 -> 10; 1 -> 5; else -> 0 }
            val sorted = b.keys.sortedBy { (it shr shift) and 31 }
            val half = b.weight() / 2
            var acc = 0L
            var cut = 1
            for ((i, k) in sorted.withIndex()) { acc += hist[k]; if (acc >= half) { cut = (i + 1).coerceIn(1, sorted.size - 1); break } }
            boxes.remove(b)
            boxes.add(Box(sorted.subList(0, cut).toIntArray()))
            boxes.add(Box(sorted.subList(cut, sorted.size).toIntArray()))
        }
        boxes.forEachIndexed { i, b ->
            var r = 0L; var g = 0L; var bl = 0L; var n = 0L
            for (k in b.keys) {
                val w = hist[k].toLong().coerceAtLeast(1)
                r += ((k shr 10) and 31) * w; g += ((k shr 5) and 31) * w; bl += (k and 31) * w; n += w
            }
            val rr = (r / n * 255 / 31).toInt(); val gg = (g / n * 255 / 31).toInt(); val bb = (bl / n * 255 / 31).toInt()
            colors[i] = (rr shl 16) or (gg shl 8) or bb
        }
    }

    private fun key(p: Int) = (((p shr 19) and 31) shl 10) or (((p shr 11) and 31) shl 5) or ((p shr 3) and 31)

    /** Nearest palette index for ARGB pixel [p] (cached per 15-bit colour). */
    fun index(p: Int): Int {
        val k = key(p)
        var i = lookup[k]
        if (i >= 0) return i
        val r = (p shr 16) and 0xFF; val g = (p shr 8) and 0xFF; val b = p and 0xFF
        var best = 0; var bd = Int.MAX_VALUE
        for (j in 0 until 256) {
            val c = colors[j]
            val dr = r - ((c shr 16) and 0xFF); val dg = g - ((c shr 8) and 0xFF); val db = b - (c and 0xFF)
            val d = dr * dr * 3 + dg * dg * 4 + db * db * 2
            if (d < bd) { bd = d; best = j }
        }
        lookup[k] = best
        return best
    }
}

object GifEncoder {
    /**
     * Turns [mp4] into a GIF of at most [maxFrames] frames, [width] px wide. [progress] gets 0..1.
     * Frame rate is lowered automatically for long clips so the file stays small.
     */
    fun encode(mp4: File, out: File, width: Int, fps: Int, maxFrames: Int, progress: (Float) -> Unit, cancelled: () -> Boolean) {
        val r = MediaMetadataRetriever()
        r.setDataSource(mp4.absolutePath)
        try {
            val durationUs = (r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L) * 1000
            val srcW = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
            val srcH = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            val dispW = if (rot == 90 || rot == 270) srcH else srcW
            val dispH = if (rot == 90 || rot == 270) srcW else srcH
            val w = min(width, dispW).let { it - it % 2 }
            val h = (w.toLong() * dispH / dispW).toInt().let { it - it % 2 }
            val effFps = min(fps.toDouble(), maxFrames * 1_000_000.0 / max(durationUs, 1L)).coerceAtLeast(2.0)
            val stepUs = (1_000_000 / effFps).toLong()
            val times = generateSequence(0L) { it + stepUs }.takeWhile { it < durationUs }.toList().ifEmpty { listOf(0L) }

            fun frame(t: Long): IntArray {
                val bmp: Bitmap = r.getScaledFrameAtTime(t, MediaMetadataRetriever.OPTION_CLOSEST, w, h) ?: Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val s = if (bmp.width != w || bmp.height != h) Bitmap.createScaledBitmap(bmp, w, h, true) else bmp
                val pixels = IntArray(w * h)
                s.getPixels(pixels, 0, w, 0, 0, w, h)
                if (s !== bmp) s.recycle()
                bmp.recycle()
                return pixels
            }

            // Pass 1: palette from a spread of frames. Pass 2: encode every frame.
            val sampleIdx = (0 until min(times.size, 10)).map { it * times.size / min(times.size, 10) }
            val palette = Palette(sampleIdx.map { frame(times[it]) })
            FileOutputStream(out).buffered(1 shl 16).use { os ->
                val gif = GifWriter(os, w, h, palette.colors)
                val delay = max(2, (100.0 / effFps).toInt())
                val idx = ByteArray(w * h)
                for ((n, t) in times.withIndex()) {
                    if (cancelled()) return
                    val px = frame(t)
                    for (i in px.indices) idx[i] = palette.index(px[i]).toByte()
                    gif.addFrame(idx, delay)
                    progress((n + 1f) / times.size)
                }
                gif.finish()
            }
        } finally {
            r.release()
        }
    }
}
