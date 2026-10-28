package com.huluca.escreenrecorder.export

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteOrder

/** Decodes the first sound track of a file to 16-bit PCM (interleaved). Shared by the voice tools and speech to text. */
object AudioDecode {
    class Pcm(val rate: Int, val channels: Int, val data: ShortArray) {
        val frames get() = data.size / channels
    }

    /** Thrown when the file has no sound track. */
    class NoSound : Exception("no sound")

    /**
     * [open] points the extractor at the file (a path or a content URI); [maxMs] stops after that much
     * sound (0 = all of it).
     */
    fun decode(maxMs: Long = 0, open: (MediaExtractor) -> Unit): Pcm {
        val ex = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            open(ex)
            val track = (0 until ex.trackCount).firstOrNull {
                ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw NoSound()
            val format = ex.getTrackFormat(track)
            ex.selectTrack(track)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var buf = ShortArray(rate * channels * 5)
            var n = 0
            val limitUs = if (maxMs > 0) maxMs * 1000 else Long.MAX_VALUE
            val info = MediaCodec.BufferInfo()
            var eos = false
            var done = false
            while (!done) {
                // Feed every free input buffer, then take out everything that is ready; only wait
                // (briefly) when nothing moved. One frame per wait would take seconds.
                var fed = false
                while (!eos) {
                    val i = codec.dequeueInputBuffer(0)
                    if (i < 0) break
                    val ib = codec.getInputBuffer(i)!!
                    val size = ex.readSampleData(ib, 0)
                    if (size < 0 || ex.sampleTime > limitUs) {
                        codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        eos = true
                    } else {
                        codec.queueInputBuffer(i, 0, size, ex.sampleTime, 0)
                        ex.advance()
                    }
                    fed = true
                }
                var drained = false
                var o = codec.dequeueOutputBuffer(info, if (fed) 0 else 4_000)
                while (o != MediaCodec.INFO_TRY_AGAIN_LATER) {
                    drained = true
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val f = codec.outputFormat
                        rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    } else if (o >= 0) {
                        val ob = codec.getOutputBuffer(o)!!
                        ob.position(info.offset)
                        ob.limit(info.offset + info.size)
                        val sb = ob.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                        while (sb.hasRemaining()) {
                            if (n == buf.size) buf = buf.copyOf(buf.size * 2)
                            buf[n++] = sb.get()
                        }
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) { done = true; break }
                    }
                    o = codec.dequeueOutputBuffer(info, 0)
                }
                if (!fed && !drained && eos) Thread.sleep(1)
            }
            val frames = n / channels
            return Pcm(rate, channels, buf.copyOf(frames * channels))
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            codec?.release()
            ex.release()
        }
    }

    /** Mono 16 kHz (what speech recognisers want): channels averaged, rate reduced by averaging. */
    fun toMono16k(p: Pcm): ShortArray {
        val outRate = 16_000
        val ch = p.channels
        val frames = p.frames
        val outLen = (frames.toLong() * outRate / p.rate).toInt()
        val out = ShortArray(outLen)
        val step = p.rate.toDouble() / outRate
        for (i in 0 until outLen) {
            val a = (i * step).toInt()
            val b = minOf(frames, maxOf(a + 1, ((i + 1) * step).toInt()))
            var sum = 0L
            for (f in a until b) {
                var m = 0
                for (c in 0 until ch) m += p.data[f * ch + c]
                sum += m / ch
            }
            out[i] = (sum / (b - a)).toInt().toShort()
        }
        return out
    }
}
