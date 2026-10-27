package com.huluca.escreenrecorder.export

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

/**
 * A copy of part of a video at a fixed frame rate and a limited size where EVERY frame is a key frame.
 *
 * A screen recording often has a key frame only when the picture changes, so reading its frames one at a
 * time (reversing, sampling for picture-in-picture) would decode seconds of video per frame. In this copy
 * each frame is a cheap single-frame decode. Must be started on the main thread; callbacks run there.
 */
@UnstableApi
class IntraCopy(private val ctx: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var transformer: Transformer? = null
    @Volatile private var polling = false
    @Volatile var cancelled = false
        private set

    fun cancel() {
        cancelled = true
        polling = false
        transformer?.cancel()
    }

    /** Output size and frame count that [make] will produce for a source of [srcW] x [srcH]. */
    fun make(
        sourceUri: String,
        startMs: Long,
        endMs: Long,
        srcW: Int,
        srcH: Int,
        maxShortSide: Int,
        fps: Int,
        out: File,
        progress: (Float) -> Unit,
        done: (error: String?) -> Unit,
    ) {
        val short = minOf(srcW, srcH)
        val scale = if (short > maxShortSide) maxShortSide.toFloat() / short else 1f
        val w = even((srcW * scale).toInt())
        val h = even((srcH * scale).toInt())
        out.delete()
        val clip = MediaItem.ClippingConfiguration.Builder().setStartPositionMs(startMs).setEndPositionMs(endMs).build()
        val item = EditedMediaItem.Builder(
            MediaItem.Builder().setUri(Uri.parse(sourceUri)).setClippingConfiguration(clip).build(),
        )
            .setRemoveAudio(true)
            .setEffects(
                Effects(
                    emptyList(),
                    listOf(
                        FrameDropEffect.createDefaultFrameDropEffect(fps.toFloat()),
                        Presentation.createForWidthAndHeight(w, h, Presentation.LAYOUT_SCALE_TO_FIT),
                    ),
                ),
            )
            .build()
        val settings = VideoEncoderSettings.Builder()
            .setBitrate((w.toLong() * h * fps * 0.35).toInt().coerceIn(2_000_000, 40_000_000))
            .setiFrameIntervalSeconds(0f)
            .build()
        val t = Transformer.Builder(ctx)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setEncoderFactory(DefaultEncoderFactory.Builder(ctx).setRequestedVideoEncoderSettings(settings).build())
            .setPortraitEncodingEnabled(true)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    polling = false
                    done(null)
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    polling = false
                    out.delete()
                    done(exportException.errorCodeName + ": " + exportException.message)
                }
            })
            .build()
        transformer = t
        cancelled = false
        try {
            t.start(Composition.Builder(EditedMediaItemSequence.Builder(item).build()).build(), out.absolutePath)
        } catch (e: Exception) {
            done(e.javaClass.simpleName + ": " + e.message)
            return
        }
        polling = true
        val holder = ProgressHolder()
        main.post(object : Runnable {
            override fun run() {
                if (!polling) return
                if (t.getProgress(holder) != Transformer.PROGRESS_STATE_NOT_STARTED) progress(holder.progress / 100f)
                main.postDelayed(this, 250)
            }
        })
    }

    private fun even(v: Int) = maxOf(2, v - v % 2)
}
