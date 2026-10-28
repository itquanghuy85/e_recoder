package com.huluca.escreenrecorder.export

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Pure signal processing for the voice tools (JVM unit tested). All buffers are mono floats in -1..1. */
object Dsp {
    private const val N = 1024
    private const val HOP = 256

    /** In-place radix-2 FFT of power-of-two size; [inverse] also divides by n. */
    fun fft(re: DoubleArray, im: DoubleArray, inverse: Boolean) {
        val n = re.size
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) {
                val tr = re[i]; re[i] = re[j]; re[j] = tr
                val ti = im[i]; im[i] = im[j]; im[j] = ti
            }
        }
        var len = 2
        while (len <= n) {
            val ang = 2 * PI / len * (if (inverse) 1 else -1)
            val wr = cos(ang)
            val wi = sin(ang)
            var i = 0
            while (i < n) {
                var cr = 1.0
                var ci = 0.0
                for (k in 0 until len / 2) {
                    val a = i + k
                    val b = a + len / 2
                    val tr = re[b] * cr - im[b] * ci
                    val ti = re[b] * ci + im[b] * cr
                    re[b] = re[a] - tr; im[b] = im[a] - ti
                    re[a] += tr; im[a] += ti
                    val ncr = cr * wr - ci * wi
                    ci = cr * wi + ci * wr
                    cr = ncr
                }
                i += len
            }
            len = len shl 1
        }
        if (inverse) for (i in 0 until n) { re[i] /= n; im[i] /= n }
    }

    /** How hard the noise reduction works: (subtraction factor, lowest gain kept). */
    fun denoiseParams(level: String): Pair<Float, Float>? = when (level) {
        "light" -> 1.0f to 0.25f
        "strong" -> 2.0f to 0.08f
        else -> null
    }

    /**
     * Spectral noise reduction. The noise spectrum is the average of the quietest 10 % of the frames
     * (a recording nearly always has pauses), subtracted from every frame with a smoothed gain so no
     * "musical noise" is left. Streams over the signal in three passes, so memory stays flat.
     */
    fun denoise(x: FloatArray, level: String): FloatArray {
        val (alpha, floor) = denoiseParams(level) ?: return x.copyOf()
        if (x.size < N * 2) return x.copyOf()
        val frames = (x.size - N + HOP - 1) / HOP + 1
        val len = (frames - 1) * HOP + N
        val win = FloatArray(N) { (0.5 - 0.5 * cos(2 * PI * it / N)).toFloat() }
        val src = x.copyOf(len)
        val re = DoubleArray(N)
        val im = DoubleArray(N)
        fun load(f: Int) {
            val o = f * HOP
            for (k in 0 until N) { re[k] = (src[o + k] * win[k]).toDouble(); im[k] = 0.0 }
        }
        // pass 1: frame energies
        val energy = DoubleArray(frames)
        for (f in 0 until frames) {
            var e = 0.0
            val o = f * HOP
            for (k in 0 until N) { val v = src[o + k] * win[k]; e += v * v }
            energy[f] = e
        }
        val sorted = energy.sortedArray()
        val take = max(4, frames / 10).coerceAtMost(frames)
        val thr = sorted[take - 1]
        // pass 2: noise profile from the quiet frames
        val bins = N / 2 + 1
        val noise = DoubleArray(bins)
        var count = 0
        for (f in 0 until frames) {
            if (energy[f] > thr) continue
            load(f)
            fft(re, im, false)
            for (b in 0 until bins) noise[b] += hypot(re[b], im[b])
            count++
        }
        for (b in 0 until bins) noise[b] /= max(1, count)
        // pass 3: gain, resynthesis with overlap-add
        val out = FloatArray(len)
        val norm = FloatArray(len)
        val prev = FloatArray(bins) { 1f }
        for (f in 0 until frames) {
            load(f)
            fft(re, im, false)
            for (b in 0 until bins) {
                val m = hypot(re[b], im[b])
                var g = max(floor.toDouble(), 1.0 - alpha * noise[b] / (m + 1e-9)).toFloat()
                g = 0.5f * prev[b] + 0.5f * g
                prev[b] = g
                re[b] *= g; im[b] *= g
                if (b in 1 until N / 2) { re[N - b] *= g; im[N - b] *= g }
            }
            fft(re, im, true)
            val o = f * HOP
            for (k in 0 until N) {
                out[o + k] += (re[k] * win[k]).toFloat()
                norm[o + k] += win[k] * win[k]
            }
        }
        return FloatArray(x.size) { out[it] / max(norm[it], 1e-3f) }
    }

    /** Ring modulation plus a short comb: the classic metallic "robot". */
    fun robot(x: FloatArray, rate: Int): FloatArray {
        val w = 2 * PI * 55.0 / rate
        val y = FloatArray(x.size) { (x[it] * (0.35 + 0.65 * sin(w * it))).toFloat() }
        val d = max(1, (rate * 0.007).toInt())
        for (i in d until y.size) y[i] += 0.35f * y[i - d]
        return y
    }

    /** One clear repeat after 280 ms that keeps feeding itself (decaying). */
    fun echo(x: FloatArray, rate: Int): FloatArray {
        val d = (rate * 0.28).toInt()
        val y = x.copyOf()
        for (i in d until y.size) y[i] += 0.42f * y[i - d]
        return y
    }

    /** Schroeder reverb: four combs in parallel, two all-passes in series, 35 % wet. */
    fun reverb(x: FloatArray, rate: Int): FloatArray {
        val delays = doubleArrayOf(0.0297, 0.0371, 0.0411, 0.0437)
        val gains = floatArrayOf(0.805f, 0.827f, 0.783f, 0.764f)
        val wet = FloatArray(x.size)
        for (c in delays.indices) {
            val d = max(1, (rate * delays[c]).toInt())
            val buf = FloatArray(x.size)
            for (i in x.indices) {
                val back = if (i >= d) buf[i - d] else 0f
                buf[i] = x[i] + gains[c] * back
                wet[i] += buf[i] * 0.25f
            }
        }
        var y = wet
        for ((delay, g) in listOf(0.005 to 0.7f, 0.0017 to 0.7f)) {
            val d = max(1, (rate * delay).toInt())
            val o = FloatArray(y.size)
            for (i in y.indices) {
                val xd = if (i >= d) y[i - d] else 0f
                val od = if (i >= d) o[i - d] else 0f
                o[i] = -g * y[i] + xd + g * od
            }
            y = o
        }
        return FloatArray(x.size) { 0.75f * x[it] + 0.35f * y[it] }
    }

    /** Scales everything down (never up) so the loudest sample is at most [ceiling]: no clipping, no distortion. */
    fun limit(channels: Array<FloatArray>, ceiling: Float = 0.97f) {
        var peak = 0f
        for (c in channels) for (v in c) peak = max(peak, abs(v))
        if (peak <= ceiling) return
        val k = ceiling / peak
        for (c in channels) for (i in c.indices) c[i] *= k
    }
}

/** What each voice effect does to the pitch (1 = unchanged). Mirror of VoiceFx in audio_track.dart. */
object VoiceFxMath {
    fun pitchOf(fx: String): Float = when (fx) {
        "deep" -> 0.78f
        "high" -> 1.25f
        "chipmunk" -> 1.6f
        else -> 1f
    }

    fun isKnown(fx: String) = fx in setOf("none", "deep", "high", "chipmunk", "robot", "echo", "reverb")
}

/** Decodes a voice file, applies noise reduction and an effect once, and writes an AAC (m4a) file. */
object VoiceFx {
    private const val MAX_MS = 10 * 60_000L

    private class Pcm(val rate: Int, val channels: Int, val data: ShortArray)

    @OptIn(UnstableApi::class)
    fun process(src: String, out: File, fx: String, denoise: String) {
        require(VoiceFxMath.isKnown(fx)) { "unknown effect $fx" }
        val pcm = decode(src)
        val ch = pcm.channels
        val frames = pcm.data.size / ch
        var chans = Array(ch) { c -> FloatArray(frames) { pcm.data[it * ch + c] / 32768f } }
        if (Dsp.denoiseParams(denoise) != null) chans = Array(ch) { Dsp.denoise(chans[it], denoise) }
        val pitch = VoiceFxMath.pitchOf(fx)
        if (pitch != 1f) {
            val shifted = pitchShift(interleave(chans), pcm.rate, ch, pitch, frames)
            chans = Array(ch) { c -> FloatArray(frames) { shifted[it * ch + c] / 32768f } }
        }
        chans = when (fx) {
            "robot" -> Array(ch) { Dsp.robot(chans[it], pcm.rate) }
            "echo" -> Array(ch) { Dsp.echo(chans[it], pcm.rate) }
            "reverb" -> Array(ch) { Dsp.reverb(chans[it], pcm.rate) }
            else -> chans
        }
        Dsp.limit(chans)
        encodeAac(out, pcm.rate, ch, interleave(chans))
    }

    private fun interleave(chans: Array<FloatArray>): ShortArray {
        val ch = chans.size
        val n = chans[0].size
        return ShortArray(n * ch) { i ->
            val v = chans[i % ch][i / ch]
            (v * 32767f).toInt().coerceIn(-32768, 32767).toShort()
        }
    }

    @OptIn(UnstableApi::class)
    private fun pitchShift(data: ShortArray, rate: Int, channels: Int, pitch: Float, targetFrames: Int): ShortArray {
        val sonic = SonicAudioProcessor()
        sonic.setPitch(pitch)
        sonic.setSpeed(1f)
        sonic.configure(AudioProcessor.AudioFormat(rate, channels, C.ENCODING_PCM_16BIT))
        sonic.flush(AudioProcessor.StreamMetadata.DEFAULT)
        var out = ShortArray(data.size + channels * 8192)
        var n = 0
        fun drain() {
            while (true) {
                val o = sonic.output
                if (!o.hasRemaining()) break
                val sb = o.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                while (sb.hasRemaining()) {
                    if (n == out.size) out = out.copyOf(out.size * 2)
                    out[n++] = sb.get()
                }
                o.position(o.limit())
            }
        }
        val chunk = 4096 * channels
        var pos = 0
        while (pos < data.size) {
            val len = min(chunk, data.size - pos)
            val bb = ByteBuffer.allocateDirect(len * 2).order(ByteOrder.LITTLE_ENDIAN)
            bb.asShortBuffer().put(data, pos, len)
            bb.position(0); bb.limit(len * 2)
            sonic.queueInput(bb)
            drain()
            pos += len
        }
        sonic.queueEndOfStream()
        drain()
        sonic.reset()
        // the length stays what it was: a few samples more or less are trimmed or padded
        return out.copyOf(targetFrames * channels).also { r ->
            if (n < r.size) java.util.Arrays.fill(r, n, r.size, 0)
        }
    }

    private fun decode(path: String): Pcm {
        // One second more than allowed: a longer file is refused, never silently cut short.
        val d = AudioDecode.decode(MAX_MS + 1000) { it.setDataSource(path) }
        if (d.frames.toLong() * 1000 / d.rate > MAX_MS) throw IllegalStateException("too long")
        return Pcm(d.rate, d.channels, d.data)
    }

    private fun encodeAac(out: File, rate: Int, channels: Int, pcm: ShortArray) {
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, rate, channels).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, if (channels == 1) 96_000 else 160_000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 1 shl 16)
        }
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        out.parentFile?.mkdirs()
        val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            var track = -1
            val info = MediaCodec.BufferInfo()
            var pos = 0
            var inputDone = false
            var outputDone = false
            while (!outputDone) {
                var fed = false
                while (!inputDone) {
                    val i = codec.dequeueInputBuffer(0)
                    if (i < 0) break
                    val ib = codec.getInputBuffer(i)!!
                    ib.clear()
                    ib.order(ByteOrder.LITTLE_ENDIAN)
                    val len = min(ib.remaining() / 2, pcm.size - pos)
                    val ptsUs = pos / channels * 1_000_000L / rate
                    if (len <= 0) {
                        codec.queueInputBuffer(i, 0, 0, ptsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        ib.asShortBuffer().put(pcm, pos, len)
                        codec.queueInputBuffer(i, 0, len * 2, ptsUs, 0)
                        pos += len
                    }
                    fed = true
                }
                var o = codec.dequeueOutputBuffer(info, if (fed) 0 else 4_000)
                while (o != MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        started = true
                    } else if (o >= 0) {
                        val ob = codec.getOutputBuffer(o)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && started) {
                            ob.position(info.offset)
                            ob.limit(info.offset + info.size)
                            muxer.writeSampleData(track, ob, info)
                        }
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) { outputDone = true; break }
                    }
                    o = codec.dequeueOutputBuffer(info, 0)
                }
            }
        } finally {
            try { codec.stop() } catch (_: Exception) {}
            codec.release()
            try { if (started) muxer.stop() } catch (_: Exception) {}
            muxer.release()
        }
    }
}
