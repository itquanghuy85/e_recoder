package com.huluca.escreenrecorder

import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File
import kotlin.math.log10
import kotlin.math.sqrt

/** Files the editor brings in (music, pictures, small videos, voice-overs) and a few probes on them. */
object EditorMedia {
    private fun dir(ctx: Context) = File(ctx.filesDir, "editor_media").also { it.mkdirs() }

    private fun displayName(ctx: Context, uri: Uri): String {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) return c.getString(0) ?: "media"
        }
        return uri.lastPathSegment ?: "media"
    }

    /**
     * Copies a picked document into the app's own storage (the picked uri may stop working later) and says
     * what it is: {path, name, kind, durationMs, width, height}.
     */
    fun importPicked(ctx: Context, uri: Uri): Map<String, Any?> {
        val name = displayName(ctx, uri)
        val ext = name.substringAfterLast('.', "").take(5).ifEmpty { "bin" }
        val out = File(dir(ctx), "m_${System.currentTimeMillis()}.$ext")
        ctx.contentResolver.openInputStream(uri)!!.use { i -> out.outputStream().use { o -> i.copyTo(o) } }
        return info(ctx, out.absolutePath) + mapOf("path" to out.absolutePath, "name" to name)
    }

    /**
     * A picked video where it lives: {uri, name, size, durationMs, width, height}. The size is the size the
     * picture is SHOWN at (a phone video stored landscape with a 90/270 turn flag is portrait here).
     */
    fun describeVideo(ctx: Context, uri: Uri): Map<String, Any?> {
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(ctx, uri)
            if (mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) != "yes") {
                throw IllegalArgumentException("not a video")
            }
            val dur = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            var w = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var h = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rot = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rot == 90 || rot == 270) { val t = w; w = h; h = t }
            var size = 0L
            ctx.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) size = c.getLong(0)
            }
            return mapOf(
                "uri" to uri.toString(), "name" to displayName(ctx, uri), "size" to size,
                "durationMs" to dur, "width" to w, "height" to h,
            )
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
    }

    /** Displayed (rotation-corrected) size of a local video, null when it cannot be read. */
    fun displaySize(path: String): Pair<Int, Int>? {
        val m = info(ctx = null, path = path)
        val w = (m["width"] as? Int) ?: 0
        val h = (m["height"] as? Int) ?: 0
        return if (w > 0 && h > 0) Pair(w, h) else null
    }

    /** {kind: audio|video|image, durationMs, width, height} for a local file. */
    fun info(ctx: Context?, path: String): Map<String, Any?> {
        val mime = android.webkit.MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(path.substringAfterLast('.', "").lowercase()) ?: ""
        val mmr = MediaMetadataRetriever()
        return try {
            mmr.setDataSource(path)
            val hasVideo = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"
            val dur = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            var w = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var h = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            // The size the picture is SHOWN at: a phone video stored landscape with a 90/270 flag is portrait.
            val rot = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rot == 90 || rot == 270) { val t = w; w = h; h = t }
            val kind = when {
                hasVideo -> "video"
                mime.startsWith("image") -> "image"
                else -> "audio"
            }
            mapOf("kind" to kind, "durationMs" to dur, "width" to w, "height" to h)
        } catch (_: Exception) {
            // Not a media file for the retriever: a picture.
            val o = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
            android.graphics.BitmapFactory.decodeFile(path, o)
            if (o.outWidth > 0) mapOf("kind" to "image", "durationMs" to 0L, "width" to o.outWidth, "height" to o.outHeight)
            else mapOf("kind" to "audio", "durationMs" to 0L, "width" to 0, "height" to 0)
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
    }

    /** Saves PNG bytes into Pictures/E Screen Recorder. */
    fun saveImage(ctx: Context, png: ByteArray, prefix: String): Map<String, Any?>? {
        val name = MediaRepo.newDisplayName(prefix, "png")
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/E Screen Recorder")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = ctx.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values) ?: return null
        try {
            resolver.openOutputStream(uri)!!.use { it.write(png) }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            return null
        }
        return mapOf("type" to "saved", "uri" to uri.toString(), "name" to name, "size" to png.size.toLong(), "mime" to "image/png")
    }

    /**
     * Peak level (0..1) of every [bucketMs] slice of a video's sound, for drawing a waveform; null
     * when there is no sound. Decodes at most the first 15 minutes.
     */
    fun waveform(ctx: Context, uri: String, durationMs: Long, bucketMs: Long): List<Double>? {
        val n = ((durationMs + bucketMs - 1) / bucketMs).toInt().coerceIn(1, 20000)
        val peaks = DoubleArray(n)
        val ex = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            ex.setDataSource(ctx, Uri.parse(uri), null)
            val track = (0 until ex.trackCount).firstOrNull {
                ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null
            val format = ex.getTrackFormat(track)
            ex.selectTrack(track)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()
            val info = MediaCodec.BufferInfo()
            val limitUs = minOf(durationMs, 15 * 60_000L) * 1000
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var eos = false
            var outDone = false
            while (!outDone) {
                if (!eos) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val buf = codec.getInputBuffer(i)!!
                        val size = ex.readSampleData(buf, 0)
                        if (size < 0 || ex.sampleTime > limitUs) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            eos = true
                        } else {
                            codec.queueInputBuffer(i, 0, size, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = codec.outputFormat
                    rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                } else if (o >= 0) {
                    val out = codec.getOutputBuffer(o)!!
                    out.position(info.offset)
                    out.limit(info.offset + info.size)
                    val s = out.asShortBuffer()
                    var frame = 0L
                    val perFrameUs = 1_000_000.0 / rate
                    while (s.remaining() >= channels) {
                        var peak = 0
                        for (c in 0 until channels) peak = maxOf(peak, kotlin.math.abs(s.get().toInt()))
                        val tMs = ((info.presentationTimeUs + frame * perFrameUs) / 1000).toLong()
                        val b = (tMs / bucketMs).toInt()
                        if (b in 0 until n) peaks[b] = maxOf(peaks[b], peak / 32768.0)
                        frame++
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outDone = true
                }
            }
            return if (peaks.all { it <= 1e-6 }) null else peaks.toList()
        } catch (_: Exception) {
            return null
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            codec?.release()
            ex.release()
        }
    }

    /**
     * RMS loudness (dBFS) of [startMs, endMs] of a video's sound, or null when it has none.
     * Reads at most 30 seconds. Used to even out the volume of segments.
     */
    fun loudness(ctx: Context, uri: String, startMs: Long, endMs: Long): Double? {
        val ex = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            ex.setDataSource(ctx, Uri.parse(uri), null)
            val track = (0 until ex.trackCount).firstOrNull {
                ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null
            val format = ex.getTrackFormat(track)
            ex.selectTrack(track)
            ex.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()
            val info = MediaCodec.BufferInfo()
            val limitUs = minOf(endMs, startMs + 30_000) * 1000
            var sumSq = 0.0
            var count = 0L
            var eos = false
            var outDone = false
            while (!outDone) {
                if (!eos) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val buf = codec.getInputBuffer(i)!!
                        val n = ex.readSampleData(buf, 0)
                        if (n < 0 || ex.sampleTime > limitUs) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            eos = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                if (o >= 0) {
                    val out = codec.getOutputBuffer(o)!!
                    out.position(info.offset)
                    out.limit(info.offset + info.size)
                    val s = out.asShortBuffer()
                    while (s.hasRemaining()) {
                        val v = s.get() / 32768.0
                        sumSq += v * v
                        count++
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outDone = true
                }
            }
            if (count == 0L) return null
            val rms = sqrt(sumSq / count)
            return if (rms <= 1e-9) null else 20 * log10(rms)
        } catch (_: Exception) {
            return null
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            codec?.release()
            ex.release()
        }
    }
}

/** Records a voice-over to an m4a file while the editor plays the video. */
class VoiceRecorder(private val ctx: Context) {
    private var rec: MediaRecorder? = null
    private var file: File? = null
    private var startedAt = 0L

    fun start(): String {
        stop()
        val f = File(File(ctx.filesDir, "editor_media").also { it.mkdirs() }, "voice_${System.currentTimeMillis()}.m4a")
        val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(ctx) else @Suppress("DEPRECATION") MediaRecorder()
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioSamplingRate(44100)
        r.setAudioEncodingBitRate(128_000)
        r.setOutputFile(f.absolutePath)
        r.prepare()
        r.start()
        rec = r
        file = f
        startedAt = System.currentTimeMillis()
        return f.absolutePath
    }

    /** Stops and returns {path, durationMs}, or null when nothing was recording. */
    fun stop(): Map<String, Any?>? {
        val r = rec ?: return null
        rec = null
        val f = file
        val ms = System.currentTimeMillis() - startedAt
        try { r.stop() } catch (_: Exception) { f?.delete(); return null } finally { r.release() }
        return if (f != null && f.length() > 0) mapOf("path" to f.absolutePath, "durationMs" to ms) else null
    }
}
