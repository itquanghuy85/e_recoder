package com.huluca.escreenrecorder.capture

import android.annotation.SuppressLint
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Surface
import com.huluca.escreenrecorder.RecConfig
import java.io.File

/**
 * One recording: VirtualDisplay -> H.264 surface encoder, plus optional AAC audio
 * (microphone and/or internal audio, mixed), muxed into a single MP4.
 *
 * Pause drops video until the next key frame and stops counting audio frames, so the
 * paused span is cut out of both tracks and they stay in sync.
 */
class RecordingSession(
    private val projection: MediaProjection,
    private val cfg: RecConfig,
    private val outFile: File,
    private val onFatal: (String) -> Unit,
) {
    private val nowUs get() = System.nanoTime() / 1000
    private val startUs = nowUs

    @Volatile private var paused = false
    @Volatile private var stopping = false
    @Volatile private var needKeyFrame = false
    private var pauseStartUs = 0L
    @Volatile private var pausedTotalUs = 0L
    @Volatile private var lastVideoPts = 0L
    @Volatile private var lastAudioPts = 0L

    private val audioEnabled = cfg.wantsAudio
    private lateinit var box: MuxerBox

    private lateinit var videoEnc: MediaCodec
    private var display: VirtualDisplay? = null
    private var inputSurface: Surface? = null
    private var videoThread: Thread? = null
    private var audioThread: Thread? = null

    private var sysRecord: AudioRecord? = null
    private var micRecord: AudioRecord? = null
    private var audioEnc: MediaCodec? = null

    val durationUs get() = maxOf(lastVideoPts, lastAudioPts)

    @SuppressLint("MissingPermission")
    fun start() {
        // Build audio sources first so we know whether the muxer needs an audio track.
        if (audioEnabled) setupAudio()
        val hasAudio = audioEnc != null
        box = MuxerBox(outFile.absolutePath, needAudio = hasAudio)

        setupVideo()
        videoThread = Thread({ drainVideo() }, "esr-video").also { it.start() }
        if (hasAudio) audioThread = Thread({ audioLoop() }, "esr-audio").also { it.start() }
    }

    private fun setupVideo() {
        val fmt = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, cfg.width, cfg.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, cfg.bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, cfg.fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // Static screens emit no frames; repeat so the tail of the clip is never empty.
            setLong("repeat-previous-frame-after", 500_000L)
        }
        videoEnc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoEnc.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = videoEnc.createInputSurface()
        videoEnc.start()

        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                if (!stopping) onFatal("projection_stopped")
            }
        }, Handler(Looper.getMainLooper()))
        display = projection.createVirtualDisplay(
            "esr", cfg.width, cfg.height, cfg.dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, inputSurface, null, null,
        )
    }

    private fun drainVideo() {
        val info = MediaCodec.BufferInfo()
        try {
            while (true) {
                val idx = videoEnc.dequeueOutputBuffer(info, 10_000)
                when {
                    idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> box.addVideo(videoEnc.outputFormat)
                    idx >= 0 -> {
                        val buf = videoEnc.getOutputBuffer(idx)
                        val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
                        if (buf != null && info.size > 0 && !isConfig && !paused) {
                            if (needKeyFrame && !isKey) {
                                // dropped: would reference frames cut out by the pause
                            } else {
                                needKeyFrame = false
                                var pts = info.presentationTimeUs - startUs - pausedTotalUs
                                if (pts <= lastVideoPts) pts = lastVideoPts + 1
                                if (pts < 0) pts = 0
                                info.presentationTimeUs = pts
                                lastVideoPts = pts
                                box.write(true, buf, info)
                            }
                        }
                        videoEnc.releaseOutputBuffer(idx, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    }
                    idx == MediaCodec.INFO_TRY_AGAIN_LATER -> if (stopping && videoDone) break
                }
            }
        } catch (e: Exception) {
            if (!stopping) onFatal("video_encoder:${e.javaClass.simpleName}")
        }
    }

    @Volatile private var videoDone = false

    // ---- audio ----------------------------------------------------------------------------

    private val sampleRate = 48_000
    private val chunkFrames = 1024

    @SuppressLint("MissingPermission")
    private fun setupAudio() {
        val stereo = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
            .build()
        val minStereo = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT)
        val minMono = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)

        if (cfg.system && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val pc = AudioPlaybackCaptureConfiguration.Builder(projection)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                    .build()
                val r = AudioRecord.Builder()
                    .setAudioFormat(stereo)
                    .setBufferSizeInBytes(maxOf(minStereo, chunkFrames * 4 * 4))
                    .setAudioPlaybackCaptureConfig(pc)
                    .build()
                if (r.state == AudioRecord.STATE_INITIALIZED) sysRecord = r else r.release()
            } catch (_: Exception) {
            }
        }
        if (cfg.mic) {
            try {
                val r = AudioRecord(
                    MediaRecorder.AudioSource.MIC, sampleRate,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(minMono, chunkFrames * 2 * 4),
                )
                if (r.state == AudioRecord.STATE_INITIALIZED) micRecord = r else r.release()
            } catch (_: Exception) {
            }
        }
        if (sysRecord == null && micRecord == null) return

        val af = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 2).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, chunkFrames * 4 * 2)
        }
        val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        enc.configure(af, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        enc.start()
        audioEnc = enc
    }

    private fun audioLoop() {
        val enc = audioEnc ?: return
        val info = MediaCodec.BufferInfo()
        val sys = sysRecord
        val mic = micRecord
        val sysBuf = ShortArray(chunkFrames * 2)
        val micBuf = ShortArray(chunkFrames)
        val mixed = ShortArray(chunkFrames * 2)
        var framesWritten = 0L
        var offsetUs = -1L
        try {
            sys?.startRecording()
            mic?.startRecording()
            offsetUs = nowUs - startUs
            var eosQueued = false
            while (true) {
                val gotSys = sys?.let { readFully(it, sysBuf, sysBuf.size) } ?: false
                val gotMic = mic?.let { readFully(it, micBuf, micBuf.size) } ?: false
                if (!stopping && !paused && (gotSys || gotMic)) {
                    for (i in 0 until chunkFrames) {
                        val m = if (gotMic) micBuf[i].toInt() else 0
                        val l = (if (gotSys) sysBuf[2 * i].toInt() else 0) + m
                        val r = (if (gotSys) sysBuf[2 * i + 1].toInt() else 0) + m
                        mixed[2 * i] = l.coerceIn(-32768, 32767).toShort()
                        mixed[2 * i + 1] = r.coerceIn(-32768, 32767).toShort()
                    }
                    val pts = offsetUs + framesWritten * 1_000_000L / sampleRate
                    queueAudio(enc, mixed, pts, 0)
                    framesWritten += chunkFrames
                    lastAudioPts = pts
                }
                drainAudio(enc, info)
                if (stopping && !eosQueued) {
                    queueAudio(enc, null, offsetUs + framesWritten * 1_000_000L / sampleRate, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    eosQueued = true
                }
                if (eosQueued && drainAudio(enc, info)) break
            }
        } catch (e: Exception) {
            if (!stopping) onFatal("audio:${e.javaClass.simpleName}")
        } finally {
            try { sys?.stop() } catch (_: Exception) {}
            try { mic?.stop() } catch (_: Exception) {}
            sys?.release()
            mic?.release()
        }
    }

    /** Blocks until [count] samples were read (or the recorder fails). */
    private fun readFully(rec: AudioRecord, buf: ShortArray, count: Int): Boolean {
        var read = 0
        while (read < count) {
            val n = rec.read(buf, read, count - read)
            if (n <= 0) return false
            read += n
        }
        return true
    }

    private fun queueAudio(enc: MediaCodec, pcm: ShortArray?, ptsUs: Long, flags: Int) {
        var spins = 0
        while (spins++ < 50) {
            val idx = enc.dequeueInputBuffer(10_000)
            if (idx >= 0) {
                val ib = enc.getInputBuffer(idx)!!
                ib.clear()
                var size = 0
                if (pcm != null) {
                    ib.asShortBuffer().put(pcm)
                    size = pcm.size * 2
                }
                enc.queueInputBuffer(idx, 0, size, ptsUs, flags)
                return
            }
            drainAudio(enc, MediaCodec.BufferInfo())
        }
    }

    /** Returns true once the end-of-stream buffer was drained. */
    private fun drainAudio(enc: MediaCodec, info: MediaCodec.BufferInfo): Boolean {
        while (true) {
            val idx = enc.dequeueOutputBuffer(info, 0)
            when {
                idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> box.addAudio(enc.outputFormat)
                idx >= 0 -> {
                    val buf = enc.getOutputBuffer(idx)
                    if (buf != null && info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                        box.write(false, buf, info)
                    }
                    enc.releaseOutputBuffer(idx, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return true
                }
                else -> return false
            }
        }
    }

    // ---- controls -------------------------------------------------------------------------

    fun pause() {
        if (paused) return
        pauseStartUs = nowUs
        paused = true
    }

    fun resume() {
        if (!paused) return
        pausedTotalUs += nowUs - pauseStartUs
        needKeyFrame = true
        try {
            videoEnc.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) })
        } catch (_: Exception) {
        }
        paused = false
    }

    /** Finalises the file. Returns true if it contains a playable stream. */
    fun stop(): Boolean {
        if (paused) resume()
        stopping = true
        try { display?.release() } catch (_: Exception) {}
        try { videoEnc.signalEndOfInputStream() } catch (_: Exception) {}
        videoDone = true
        videoThread?.join(4000)
        audioThread?.join(4000)
        try { videoEnc.stop() } catch (_: Exception) {}
        videoEnc.release()
        inputSurface?.release()
        try { audioEnc?.stop() } catch (_: Exception) {}
        audioEnc?.release()
        return box.finish()
    }
}
