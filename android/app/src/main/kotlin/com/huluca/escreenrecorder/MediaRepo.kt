package com.huluca.escreenrecorder

import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Everything that touches MediaStore: saving, listing, renaming, deleting, thumbnails, sharing. */
object MediaRepo {
    const val FOLDER = "Movies/E Screen Recorder"
    private val collection: Uri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

    /** Recording profile fps: anything 45 and over is the "smooth" 60 fps mode, 0 means unknown. */
    fun normalizeFps(v: Double): Int = when {
        v <= 0.5 -> 0
        v >= 45.0 -> 60
        else -> 30
    }

    fun newDisplayName(prefix: String = "ESR", ext: String = "mp4"): String =
        prefix + "_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + "." + ext

    /** Copies [file] into the public Movies folder and returns a result map for Flutter. */
    fun save(ctx: Context, file: File, durationMs: Long, prefix: String = "ESR"): Map<String, Any?>? {
        val name = newDisplayName(prefix)
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, FOLDER)
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val resolver = ctx.contentResolver
        val uri = resolver.insert(collection, values) ?: return null
        try {
            resolver.openOutputStream(uri)!!.use { out -> file.inputStream().use { it.copyTo(out) } }
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            return null
        }
        // Publishing is a second step: if it silently fails the row stays pending and every query
        // (including our own library) hides the video even though the bytes are there. Keep the file
        // in that case and tell Flutter it is not indexed yet, instead of deleting a good recording.
        val published = try {
            resolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null) > 0
        } catch (_: Exception) {
            false
        }
        val indexed = published && isIndexed(ctx, uri)
        return mapOf(
            "type" to "saved",
            "uri" to uri.toString(),
            "name" to name,
            "durationMs" to durationMs,
            "size" to file.length(),
            "indexed" to indexed,
        )
    }

    /** Whether MediaStore will hand this row to a normal query (published, with bytes). */
    private fun isIndexed(ctx: Context, uri: Uri): Boolean = try {
        ctx.contentResolver.query(
            uri,
            arrayOf(MediaStore.Video.Media.IS_PENDING, MediaStore.Video.Media.SIZE),
            null, null, null,
        )?.use { c -> c.moveToFirst() && c.getInt(0) == 0 && c.getLong(1) > 0 } ?: false
    } catch (_: Exception) {
        false
    }

    /** Saves a GIF into Pictures/E Screen Recorder (it is not a video, so the library does not list it). */
    fun saveGif(ctx: Context, file: File, durationMs: Long, prefix: String): Map<String, Any?>? {
        val name = newDisplayName(prefix, "gif")
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/gif")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/E Screen Recorder")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = ctx.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values) ?: return null
        try {
            resolver.openOutputStream(uri)!!.use { out -> file.inputStream().use { it.copyTo(out) } }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            return null
        }
        return mapOf("type" to "saved", "uri" to uri.toString(), "name" to name, "durationMs" to durationMs, "size" to file.length(), "mime" to "image/gif")
    }

    /** Columns every MediaStore has; [FPS_COLUMN] is added only where the phone knows it. */
    private val BASE_COLUMNS = arrayOf(
        MediaStore.Video.Media._ID, MediaStore.Video.Media.DISPLAY_NAME, MediaStore.Video.Media.DURATION,
        MediaStore.Video.Media.SIZE, MediaStore.Video.Media.WIDTH, MediaStore.Video.Media.HEIGHT,
        MediaStore.Video.Media.DATE_ADDED,
    )

    /**
     * Not a public MediaStore column: Samsung has it, AOSP / ColorOS (Android 13 at least) reject the
     * whole query with "Invalid column frame_rate". Asking for it unconditionally left the library
     * empty and the result screen never opened after a recording on those phones.
     */
    private const val FPS_COLUMN = "frame_rate"

    /** Null until the first query tells whether this phone's MediaStore has [FPS_COLUMN]. */
    @Volatile private var fpsColumnKnown: Boolean? = null

    fun list(ctx: Context): List<Map<String, Any?>> {
        if (fpsColumnKnown != false) {
            try {
                return list(ctx, withFps = true).also { fpsColumnKnown = true }
            } catch (e: IllegalArgumentException) {
                if (fpsColumnKnown == true) throw e
                fpsColumnKnown = false
                DiagLog.log("lib", "no $FPS_COLUMN column: ${e.message}")
            }
        }
        return list(ctx, withFps = false)
    }

    private fun list(ctx: Context, withFps: Boolean): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val proj = if (withFps) BASE_COLUMNS + FPS_COLUMN else BASE_COLUMNS
        ctx.contentResolver.query(
            collection, proj,
            "${MediaStore.Video.Media.RELATIVE_PATH} LIKE ? AND ${MediaStore.Video.Media.IS_PENDING} = 0",
            arrayOf("$FOLDER%"),
            "${MediaStore.Video.Media.DATE_ADDED} DESC",
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                out.add(
                    mapOf(
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "name" to c.getString(1),
                        "durationMs" to c.getLong(2),
                        "size" to c.getLong(3),
                        "width" to c.getInt(4),
                        "height" to c.getInt(5),
                        "dateAdded" to c.getLong(6),
                        // 0 = unknown (no column on this phone): the editor then sizes the export for 30 fps.
                        "fps" to if (withFps) normalizeFps(c.getDouble(7)) else 0,
                    ),
                )
            }
        }
        return out
    }

    fun thumbnail(ctx: Context, uri: Uri, w: Int, h: Int): ByteArray? = try {
        val bmp = ctx.contentResolver.loadThumbnail(uri, Size(w, h), null)
        ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.JPEG, 82, it) }.toByteArray()
    } catch (_: Exception) {
        // Fallback for files MediaStore has not indexed a thumbnail for yet.
        try {
            val r = MediaMetadataRetriever()
            r.setDataSource(ctx, uri)
            val frame = r.getFrameAtTime(0)
            r.release()
            frame?.let { f -> ByteArrayOutputStream().also { f.compress(Bitmap.CompressFormat.JPEG, 80, it) }.toByteArray() }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * One frame of a video at [atMs], scaled to fit [w] x [h] (JPEG), for small previews such as the
     * transition picker. Null when the frame cannot be read.
     */
    fun frameAt(ctx: Context, uri: Uri, atMs: Long, w: Int, h: Int): ByteArray? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(ctx, uri)
            val us = atMs.coerceAtLeast(0) * 1000
            val f = r.getScaledFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST, w, h)
                ?: r.getScaledFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, w, h)
            f?.let { b -> ByteArrayOutputStream().also { b.compress(Bitmap.CompressFormat.JPEG, 80, it) }.toByteArray() }
        } catch (_: Exception) {
            null
        } finally {
            r.release()
        }
    }

    /** Returns "ok", "needs_permission" or "error". */
    fun rename(ctx: Context, uri: Uri, newName: String): String = try {
        val name = if (newName.endsWith(".mp4", true)) newName else "$newName.mp4"
        val n = ctx.contentResolver.update(
            uri, ContentValues().apply { put(MediaStore.Video.Media.DISPLAY_NAME, name) }, null, null,
        )
        if (n > 0) "ok" else "error"
    } catch (_: RecoverableSecurityException) {
        "needs_permission"
    } catch (_: Exception) {
        "error"
    }

    fun delete(ctx: Context, uri: Uri): String = try {
        if (ctx.contentResolver.delete(uri, null, null) > 0) "ok" else "error"
    } catch (_: RecoverableSecurityException) {
        "needs_permission"
    } catch (_: Exception) {
        "error"
    }

    fun share(ctx: Context, uri: Uri, chooserTitle: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = ctx.contentResolver.getType(uri) ?: "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        ctx.startActivity(Intent.createChooser(send, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
