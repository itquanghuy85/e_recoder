package com.huluca.escreenrecorder.export

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri

/**
 * Small grey pictures (brightness only) of every frame in a time window, decoded in ONE forward
 * pass. Asking MediaMetadataRetriever for frames one by one decodes again from the previous key frame
 * for each of them: finding the places of 4 touches took 90 s on a 54 s recording. Here the window
 * around a touch costs one seek and ~100 frames of hardware decoding.
 *
 * The brightness comes straight from the decoder's Y plane (video range 16..235 stretched to 0..255,
 * close to what [TouchScan] computes from a bitmap), box-averaged down to fit [boxW] x [boxH] with the
 * video's own aspect ratio, as the retriever's scaled frames are.
 */
class LumaDecoder(
    ctx: Context,
    uri: Uri,
    private val boxW: Int = TouchScan.W,
    private val boxH: Int = TouchScan.H,
) : AutoCloseable {
    class Frame(val ms: Long, val luma: IntArray, val w: Int, val h: Int)

    private val ex = MediaExtractor()
    private val codec: MediaCodec
    private val track: Int
    private val format: MediaFormat

    init {
        ex.setDataSource(ctx, uri, null)
        track = (0 until ex.trackCount).firstOrNull {
            ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
        } ?: throw IllegalStateException("no video track")
        ex.selectTrack(track)
        format = ex.getTrackFormat(track)
        codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        try {
            codec.configure(format, null, null, 0)
            codec.start()
        } catch (e: Exception) {
            codec.release()
            ex.release()
            throw e
        }
    }

    /**
     * Every frame shown between [fromMs] and [toMs] (both included), oldest first. Starts from the key
     * frame before [fromMs]; frames before [fromMs] are decoded but not kept.
     */
    fun window(fromMs: Long, toMs: Long): List<Frame> {
        val out = ArrayList<Frame>()
        codec.flush()
        ex.seekTo(fromMs.coerceAtLeast(0) * 1000, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var idle = 0
        while (true) {
            if (!inputDone) {
                val i = codec.dequeueInputBuffer(5_000)
                if (i >= 0) {
                    val buf = codec.getInputBuffer(i)!!
                    val n = ex.readSampleData(buf, 0)
                    if (n < 0 || ex.sampleTime > toMs * 1000 + 200_000) {
                        codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                        ex.advance()
                    }
                }
            }
            val o = codec.dequeueOutputBuffer(info, 10_000)
            if (o >= 0) {
                idle = 0
                val ms = info.presentationTimeUs / 1000
                val eos = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                if (info.size > 0 && ms >= fromMs - 40 && ms <= toMs) {
                    codec.getOutputImage(o)?.use { img -> out.add(lumaOf(img, ms)) }
                }
                codec.releaseOutputBuffer(o, false)
                if (eos || ms > toMs) break
            } else if (o == MediaCodec.INFO_TRY_AGAIN_LATER) {
                // A decoder that stops answering must not hold the caller for ever.
                if (++idle > 300) break
            }
        }
        return out
    }

    private fun lumaOf(img: android.media.Image, ms: Long): Frame {
        val plane = img.planes[0]
        val buf = plane.buffer
        val row = plane.rowStride
        val pix = plane.pixelStride
        val vw = img.cropRect.width()
        val vh = img.cropRect.height()
        val ox = img.cropRect.left
        val oy = img.cropRect.top
        val k = minOf(boxW.toDouble() / vw, boxH.toDouble() / vh)
        val w = (vw * k).toInt().coerceIn(1, boxW)
        val h = (vh * k).toInt().coerceIn(1, boxH)
        val out = IntArray(w * h)
        for (y in 0 until h) {
            val sy0 = oy + y * vh / h
            val sy1 = maxOf(sy0 + 1, oy + (y + 1) * vh / h)
            for (x in 0 until w) {
                val sx0 = ox + x * vw / w
                val sx1 = maxOf(sx0 + 1, ox + (x + 1) * vw / w)
                // A sparse 4x4 sample of the cell is plenty for "did this part change".
                var sum = 0
                var n = 0
                val stepY = maxOf(1, (sy1 - sy0) / 4)
                val stepX = maxOf(1, (sx1 - sx0) / 4)
                var yy = sy0
                while (yy < sy1) {
                    var xx = sx0
                    while (xx < sx1) {
                        sum += buf.get(yy * row + xx * pix).toInt() and 0xFF
                        n++
                        xx += stepX
                    }
                    yy += stepY
                }
                val yv = if (n == 0) 16 else sum / n
                out[y * w + x] = ((yv - 16) * 255 / 219).coerceIn(0, 255)
            }
        }
        return Frame(ms, out, w, h)
    }

    override fun close() {
        try { codec.stop() } catch (_: Exception) {}
        try { codec.release() } catch (_: Exception) {}
        try { ex.release() } catch (_: Exception) {}
    }
}
