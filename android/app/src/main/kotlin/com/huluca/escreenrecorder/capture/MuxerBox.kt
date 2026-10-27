package com.huluca.escreenrecorder.capture

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import java.nio.ByteBuffer

/**
 * Thread-safe MediaMuxer wrapper. The muxer can only start once every expected
 * track format is known; samples that arrive earlier are queued and flushed.
 */
class MuxerBox(path: String, private val needAudio: Boolean) {
    private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var videoTrack = -1
    private var audioTrack = -1
    private var started = false
    private var finished = false
    private val pending = ArrayList<Pending>()

    private class Pending(val video: Boolean, val data: ByteArray, val info: MediaCodec.BufferInfo)

    @Synchronized
    fun addVideo(format: MediaFormat) {
        videoTrack = muxer.addTrack(format)
        maybeStart()
    }

    @Synchronized
    fun addAudio(format: MediaFormat) {
        audioTrack = muxer.addTrack(format)
        maybeStart()
    }

    private fun maybeStart() {
        if (started || videoTrack < 0 || (needAudio && audioTrack < 0)) return
        muxer.start()
        started = true
        for (p in pending) writeNow(p.video, ByteBuffer.wrap(p.data), p.info)
        pending.clear()
    }

    @Synchronized
    fun write(video: Boolean, buf: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (finished) return
        if (!started) {
            buf.position(info.offset)
            buf.limit(info.offset + info.size)
            val copy = ByteArray(info.size)
            buf.get(copy)
            val i = MediaCodec.BufferInfo()
            i.set(0, info.size, info.presentationTimeUs, info.flags)
            pending.add(Pending(video, copy, i))
            return
        }
        writeNow(video, buf, info)
    }

    private fun writeNow(video: Boolean, buf: ByteBuffer, info: MediaCodec.BufferInfo) {
        val track = if (video) videoTrack else audioTrack
        if (track < 0) return
        buf.position(info.offset)
        buf.limit(info.offset + info.size)
        try {
            muxer.writeSampleData(track, buf, info)
        } catch (_: IllegalStateException) {
            // Muxer already stopped or a malformed sample; drop it rather than crash the recording.
        }
    }

    /** Returns true if the file holds a playable stream. */
    @Synchronized
    fun finish(): Boolean {
        if (finished) return false
        finished = true
        var ok = false
        try {
            if (started) {
                muxer.stop()
                ok = true
            }
        } catch (_: Exception) {
        }
        try {
            muxer.release()
        } catch (_: Exception) {
        }
        return ok
    }
}
