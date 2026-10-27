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
            resolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            return null
        }
        return mapOf(
            "type" to "saved",
            "uri" to uri.toString(),
            "name" to name,
            "durationMs" to durationMs,
            "size" to file.length(),
        )
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

    fun list(ctx: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val proj = arrayOf(
            MediaStore.Video.Media._ID, MediaStore.Video.Media.DISPLAY_NAME, MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE, MediaStore.Video.Media.WIDTH, MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.DATE_ADDED,
        )
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
