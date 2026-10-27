package com.huluca.escreenrecorder.export

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.net.Uri
import java.io.File

/** PNG files for freeze frames and blank (black) gaps; the exporter turns them into image clips. */
object StillFrames {
    /** The exact frame of [uri] at [atMs], scaled to [w] x [h]. */
    fun frame(ctx: Context, uri: String, atMs: Long, w: Int, h: Int, dir: File): File {
        dir.mkdirs()
        val out = File(dir, "still_${uri.hashCode()}_${atMs}_${w}x$h.png")
        if (out.exists() && out.length() > 0) return out
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(ctx, Uri.parse(uri))
            val src = mmr.getFrameAtTime(atMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                ?: mmr.getFrameAtTime(atMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: throw IllegalStateException("no frame at $atMs")
            val bmp = if (src.width == w && src.height == h) src else Bitmap.createScaledBitmap(src, w, h, true)
            out.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            if (bmp !== src) src.recycle()
            bmp.recycle()
        } finally {
            try { mmr.release() } catch (_: Exception) {}
        }
        return out
    }

    fun black(w: Int, h: Int, dir: File): File {
        dir.mkdirs()
        val out = File(dir, "black_${w}x$h.png")
        if (out.exists() && out.length() > 0) return out
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.BLACK)
        out.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bmp.recycle()
        return out
    }
}
