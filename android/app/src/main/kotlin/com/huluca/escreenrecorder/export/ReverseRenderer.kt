package com.huluca.escreenrecorder.export

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import androidx.media3.common.util.UnstableApi
import java.io.File

/**
 * Renders a clip played BACKWARDS into a temporary MP4 (video only).
 *
 * A screen recording often has a key frame only when the picture changes, so asking the retriever for
 * the frames of such a file one by one would decode seconds of video per frame. Two steps avoid that
 * without keeping frames in memory:
 *  1. Media3 re-encodes the clip at a fixed 24 fps and a limited size with EVERY frame a key frame;
 *  2. the frames of that file are read newest first (each is a cheap single-frame decode) and encoded
 *     again in that order.
 * Memory stays at one frame; the cost is time (about the length of the clip), so the editor limits
 * reversed clips to 30 seconds.
 */
@UnstableApi
class ReverseRenderer(private val ctx: Context) {
    companion object {
        const val FPS = 24
        /** Reverse copies are made at this short-side size at most: they are previews of motion, not detail. */
        const val MAX_SHORT_SIDE = 720
    }

    private val main = Handler(Looper.getMainLooper())
    private val intraCopy = IntraCopy(ctx)
    @Volatile private var cancelled = false

    fun cancel() {
        cancelled = true
        intraCopy.cancel()
    }

    /** Must be called on the main thread. [done] runs on the main thread. */
    fun render(
        sourceUri: String,
        startMs: Long,
        endMs: Long,
        frameW: Int,
        frameH: Int,
        out: File,
        progress: (Float) -> Unit,
        done: (error: String?) -> Unit,
    ) {
        cancelled = false
        val intra = File(out.parentFile, out.nameWithoutExtension + "_intra.mp4")
        intraCopy.make(
            sourceUri, startMs, endMs, frameW, frameH, MAX_SHORT_SIDE, FPS, intra,
            progress = { p -> progress(p * 0.5f) },
            done = { err ->
                if (err != null) {
                    done(err)
                } else {
                    Thread({
                        val e = try {
                            reverseFile(intra, out, endMs - startMs) { p -> main.post { progress(0.5f + p * 0.5f) } }
                            null
                        } catch (ex: Exception) {
                            ex.javaClass.simpleName + ": " + ex.message
                        } finally {
                            intra.delete()
                        }
                        main.post { done(if (cancelled) "cancelled" else e) }
                    }, "esr-reverse").start()
                }
            },
        )
    }

    private fun even(v: Int) = maxOf(2, v - v % 2)

    /** Step 2: read [intra] backwards and encode it. Runs on a worker thread. */
    private fun reverseFile(intra: File, out: File, lengthMs: Long, progress: (Float) -> Unit) {
        val mmr = MediaMetadataRetriever()
        mmr.setDataSource(intra.absolutePath)
        val durationMs = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: lengthMs
        val frames = maxOf(2, (minOf(durationMs, lengthMs + 200) * FPS / 1000).toInt())
        val first = mmr.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST) ?: throw IllegalStateException("empty clip")
        val w = even(first.width)
        val h = even(first.height)
        first.recycle()

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, (w.toLong() * h * FPS * 0.15).toInt().coerceIn(1_500_000, 20_000_000))
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        enc.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        enc.start()
        out.delete()
        val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var track = -1
        var muxing = false
        val info = MediaCodec.BufferInfo()

        fun drain(untilEos: Boolean) {
            while (true) {
                val idx = enc.dequeueOutputBuffer(info, if (untilEos) 10_000 else 0)
                when {
                    idx == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!untilEos) return
                    idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(enc.outputFormat)
                        muxer.start()
                        muxing = true
                    }
                    idx >= 0 -> {
                        val buf = enc.getOutputBuffer(idx)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && muxing) {
                            buf.position(info.offset)
                            buf.limit(info.offset + info.size)
                            muxer.writeSampleData(track, buf, info)
                        }
                        enc.releaseOutputBuffer(idx, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        try {
            var last: Bitmap? = null
            val px = IntArray(w * h)
            for (n in 0 until frames) {
                if (cancelled) break
                // Newest first: frame (frames-1-n) of the intra copy becomes frame n of the reversed clip.
                val srcIdx = frames - 1 - n
                val t = srcIdx * 1_000_000L / FPS
                val bmp = mmr.getFrameAtTime(t, MediaMetadataRetriever.OPTION_CLOSEST) ?: last ?: continue
                val scaled = if (bmp.width == w && bmp.height == h) bmp else Bitmap.createScaledBitmap(bmp, w, h, true)
                scaled.getPixels(px, 0, w, 0, 0, w, h)
                // wait for a free input buffer, draining output meanwhile
                var inIdx = enc.dequeueInputBuffer(10_000)
                while (inIdx < 0) {
                    drain(false)
                    inIdx = enc.dequeueInputBuffer(10_000)
                }
                val img = enc.getInputImage(inIdx)!!
                fillYuv(img, px, w, h)
                enc.queueInputBuffer(inIdx, 0, w * h * 3 / 2, n * 1_000_000L / FPS, 0)
                drain(false)
                if (scaled !== bmp) bmp.recycle()
                last?.let { if (it !== scaled) it.recycle() }
                last = scaled
                if (n % 8 == 0) progress(n.toFloat() / frames)
            }
            val eos = enc.dequeueInputBuffer(100_000)
            if (eos >= 0) enc.queueInputBuffer(eos, 0, 0, frames * 1_000_000L / FPS, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drain(true)
            last?.recycle()
        } finally {
            try { enc.stop() } catch (_: Exception) {}
            enc.release()
            try { if (muxing) muxer.stop() } catch (_: Exception) {}
            muxer.release()
            mmr.release()
        }
        if (cancelled) out.delete()
    }

    /** ARGB pixels -> the three planes of a flexible YUV 4:2:0 input image (BT.601, limited range). */
    private fun fillYuv(img: android.media.Image, px: IntArray, w: Int, h: Int) {
        val yP = img.planes[0]
        val uP = img.planes[1]
        val vP = img.planes[2]
        val yBuf = yP.buffer
        val uBuf = uP.buffer
        val vBuf = vP.buffer
        for (y in 0 until h) {
            val rowY = y * yP.rowStride
            val chroma = y % 2 == 0
            val rowC = (y / 2)
            for (x in 0 until w) {
                val c = px[y * w + x]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                val yy = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yBuf.put(rowY + x * yP.pixelStride, yy.coerceIn(16, 235).toByte())
                if (chroma && x % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    uBuf.put(rowC * uP.rowStride + (x / 2) * uP.pixelStride, u.coerceIn(16, 240).toByte())
                    vBuf.put(rowC * vP.rowStride + (x / 2) * vP.pixelStride, v.coerceIn(16, 240).toByte())
                }
            }
        }
    }
}
