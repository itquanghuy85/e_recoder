package com.huluca.escreenrecorder.export

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Crop
import androidx.media3.effect.Presentation
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.effect.SpeedChangeEffect
import androidx.media3.effect.TextureOverlay
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
import com.google.common.collect.ImmutableList
import com.huluca.escreenrecorder.MediaRepo
import java.io.File

/**
 * Turns an [ExportJob] into a file: segments (cut/ordered, with speed), burned-in markers, text,
 * cover blocks and zoom, scaled to the requested height at the requested bitrate.
 * Must be started from the main thread (Transformer needs a Looper).
 */
@UnstableApi
class Exporter(private val ctx: Context) {
    interface Callback {
        fun onProgress(fraction: Float)
        fun onDone(result: Map<String, Any?>)
        fun onError(code: String, message: String)
    }

    companion object { const val MAX_GIF_FRAMES = 300 }

    private val main = Handler(Looper.getMainLooper())
    private var transformer: Transformer? = null
    private var polling = false
    @Volatile private var cancelled = false

    private var reverser: ReverseRenderer? = null
    private var pipPrep: PipFrames? = null
    private val pipFrames = HashMap<String, PipFrames.Result>()

    private fun pipKey(p: PipClip) = p.path + "|" + p.startOutMs

    /** A preparation step that takes a while (a reversed copy, the frames of a picture-in-picture video). */
    private class PrepStep(val weight: Float, val run: (progress: (Float) -> Unit, done: (String?) -> Unit) -> Unit)

    fun start(job: ExportJob, cb: Callback) {
        cancelled = false
        reversed.clear()
        pipFrames.clear()
        val steps = ArrayList<PrepStep>()
        val revDir = File(ctx.cacheDir, "export_rev").also { it.mkdirs() }
        job.segments.filter { it.reverse && !it.isStill }.distinctBy { reverseKey(job, it) }.forEachIndexed { i, seg ->
            steps.add(
                PrepStep(2f) { progress, done ->
                    val r = ReverseRenderer(ctx)
                    reverser = r
                    val file = File(revDir, "rev_${System.currentTimeMillis()}_$i.mp4")
                    r.render(
                        seg.uri ?: job.sourceUri, seg.startMs, seg.endMs, job.picture.srcW, job.picture.srcH, file,
                        progress = progress,
                        done = { err ->
                            if (err == null) reversed[reverseKey(job, seg)] = file
                            done(err?.let { "reverse: $it" })
                        },
                    )
                },
            )
        }
        job.pips.filter { it.isVideo && it.playMs > 0 }.forEachIndexed { i, pip ->
            steps.add(
                PrepStep(1f) { progress, done ->
                    val p = PipFrames(ctx)
                    pipPrep = p
                    p.prepare(pip, File(ctx.cacheDir, "export_pip/$i"), progress) { res, err ->
                        if (res != null) pipFrames[pipKey(pip)] = res
                        done(err?.let { "pip: $it" })
                    }
                },
            )
        }
        if (steps.isEmpty()) { run(job, cb, 0f); return }
        val share = 0.4f
        val total = steps.sumOf { it.weight.toDouble() }.toFloat()
        var finishedWeight = 0f
        var i = 0
        fun next() {
            if (cancelled) return
            if (i >= steps.size) { run(job, cb, share); return }
            val st = steps[i]
            val before = finishedWeight
            st.run({ p -> cb.onProgress(share * (before + st.weight * p) / total) }) { err ->
                if (!cancelled) {
                    if (err != null) {
                        cb.onError("prepare_failed", err)
                    } else {
                        finishedWeight += st.weight
                        i++
                        next()
                    }
                }
            }
        }
        next()
    }

    private fun run(job: ExportJob, cb: Callback, base: Float) {
        val out = File(File(ctx.cacheDir, "export").also { it.mkdirs() }, "edit_${System.currentTimeMillis()}.mp4")
        val composition = try {
            buildComposition(job)
        } catch (e: Exception) {
            cb.onError("build_failed", e.javaClass.simpleName + ": " + e.message); return
        }
        val settings = VideoEncoderSettings.Builder().setBitrate(job.bitrate).build()
        val encoderFactory = DefaultEncoderFactory.Builder(ctx).setRequestedVideoEncoderSettings(settings).build()
        val t = Transformer.Builder(ctx)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            // Recordings are portrait: encode portrait frames instead of landscape + rotation flag.
            .setPortraitEncodingEnabled(true)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    polling = false
                    finish(job, out, cb)
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    polling = false
                    out.delete()
                    if (!cancelled) cb.onError("export_failed", exportException.errorCodeName + ": " + exportException.message)
                }
            })
            .build()
        transformer = t
        t.start(composition, out.absolutePath)
        polling = true
        val holder = ProgressHolder()
        main.post(object : Runnable {
            override fun run() {
                if (!polling) return
                val state = t.getProgress(holder)
                if (state != Transformer.PROGRESS_STATE_NOT_STARTED) {
                    // A GIF is two stages: the edited video (first half), then the GIF itself.
                    cb.onProgress(base + holder.progress / 100f * (1f - base) * (if (job.gif) 0.5f else 1f))
                }
                main.postDelayed(this, 200)
            }
        })
    }

    fun cancel() {
        cancelled = true
        polling = false
        transformer?.cancel()
        reverser?.cancel()
        pipPrep?.cancel()
    }

    private fun finish(job: ExportJob, mp4: File, cb: Callback) {
        Thread({
            try {
                val durationMs = job.segments.sumOf { it.outLenMs }
                val saved: Map<String, Any?>?
                if (job.gif) {
                    val gif = File(mp4.parentFile, mp4.nameWithoutExtension + ".gif")
                    GifEncoder.encode(
                        mp4, gif, job.gifWidth, job.gifFps, MAX_GIF_FRAMES,
                        progress = { p -> main.post { cb.onProgress(0.5f + p * 0.5f) } },
                        cancelled = { cancelled },
                    )
                    mp4.delete()
                    if (cancelled) { gif.delete(); return@Thread }
                    saved = MediaRepo.saveGif(ctx, gif, durationMs, job.namePrefix)
                    gif.delete()
                } else {
                    saved = MediaRepo.save(ctx, mp4, durationMs, job.namePrefix)
                    mp4.delete()
                }
                main.post {
                    if (saved != null) cb.onDone(saved) else cb.onError("save_failed", "Could not save export")
                }
            } catch (e: Exception) {
                main.post { cb.onError("save_failed", e.message ?: "") }
            }
        }, "esr-export-save").start()
    }
    /** Reversed copies made for this export, keyed by [reverseKey]. */
    private val reversed = HashMap<String, File>()

    private fun reverseKey(job: ExportJob, seg: SegmentSpec) = "${seg.uri ?: job.sourceUri}|${seg.startMs}|${seg.endMs}"

    private fun stillDir() = File(ctx.cacheDir, "export_stills")

    private fun buildComposition(job: ExportJob): Composition {
        require(job.segments.isNotEmpty()) { "no segments" }
        val items = ArrayList<EditedMediaItem>()
        var outCursor = 0L
        for (seg in job.segments) {
            items.addAll(itemsFor(job, seg, outCursor))
            outCursor += seg.outLenMs
        }
        val sequences = ArrayList<EditedMediaItemSequence>()
        // Stills, blanks and reversed clips have no sound: silence is generated for them so the audio track stays whole.
        // (Set on the sequence: the composition-level switch trips over image clips in this Media3 version.)
        sequences.add(EditedMediaItemSequence.Builder(items).experimentalSetForceAudioTrack(!job.gif).build())
        if (!job.gif) sequences.addAll(audioSequences(job))
        val builder = Composition.Builder(sequences)
        // A GIF is built from a small, silent render of the edit.
        val targetH = if (job.gif) (job.gifWidth.toLong() * job.outFrameH / job.outW).toInt().let { it - it % 2 } else job.outHeight
        if (targetH in 1 until job.outFrameH) {
            builder.setEffects(Effects(emptyList(), listOf(Presentation.createForHeight(targetH))))
        }
        return builder.build()
    }

    /** The clips one segment turns into: one piece (or one per ramp step), or a single still image. */
    private fun itemsFor(job: ExportJob, seg: SegmentSpec, segOutStart: Long): List<EditedMediaItem> {
        val outLen = seg.outLenMs
        if (seg.isStill) {
            val png = if (seg.blank) StillFrames.black(job.picture.srcW, job.picture.srcH, stillDir())
            else StillFrames.frame(ctx, seg.uri ?: job.sourceUri, seg.startMs, job.picture.srcW, job.picture.srcH, stillDir())
            val mediaItem = MediaItem.Builder().setUri(Uri.fromFile(png)).setImageDurationMs(seg.freezeMs).build()
            val clock = ItemClock(seg.startMs, 1, fixed = true)
            val video = pictureEffects(job, seg.startMs, seg.startMs + 1, clock)
            video.addAll(pipEffects(job, segOutStart, segOutStart + outLen))
            video.addAll(transitionEffects(job, seg, 0, outLen))
            return listOf(
                EditedMediaItem.Builder(mediaItem)
                    .setFrameRate(30)
                    .setEffects(Effects(emptyList(), video))
                    .build(),
            )
        }
        val parts = SegmentPlan.parts(seg)
        val reversedFile = if (seg.reverse) reversed[reverseKey(job, seg)] else null
        return parts.map { part ->
            val uri = if (reversedFile != null) Uri.fromFile(reversedFile) else Uri.parse(seg.uri ?: job.sourceUri)
            // Window of this piece on the file it is cut from: the reversed copy is indexed by play offset.
            val clipStart = if (seg.reverse) part.playStartMs else seg.startMs + part.playStartMs
            val clipEnd = if (seg.reverse) part.playEndMs else seg.startMs + part.playEndMs
            val clip = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(clipStart)
                .setEndPositionMs(maxOf(clipEnd, clipStart + 1))
                .build()
            val mediaItem = MediaItem.Builder().setUri(uri).setClippingConfiguration(clip).build()
            // Source window of this piece (for the overlays) and the direction time runs through it.
            val winStart = if (seg.reverse) seg.endMs - part.playEndMs else seg.startMs + part.playStartMs
            val winEnd = if (seg.reverse) seg.endMs - part.playStartMs else seg.startMs + part.playEndMs
            val clock = if (seg.reverse) ItemClock(seg.endMs - part.playStartMs, -1) else ItemClock(seg.startMs + part.playStartMs, 1)

            // Order matters: covers and markers belong to the picture, so they are composed first
            // and zoom WITH it (a marker stays on the button it points at); captions come after
            // the zoom so their size and place never change; speed comes next; transitions last so they
            // see output time.
            val video = pictureEffects(job, winStart, winEnd, clock)
            if (part.speed != 1f) video.add(SpeedChangeEffect(part.speed))
            video.addAll(pipEffects(job, segOutStart + part.outOffsetMs, segOutStart + part.outOffsetMs + part.outLenMs))
            video.addAll(transitionEffects(job, seg, part.outOffsetMs, outLen))

            val audio = ArrayList<AudioProcessor>()
            if (part.speed != 1f) audio.add(SonicAudioProcessor().apply { setSpeed(part.speed) })
            if (seg.volume != 1f || seg.fadeInMs > 0 || seg.fadeOutMs > 0) {
                audio.add(GainAudioProcessor(seg.volume, seg.fadeInMs, seg.fadeOutMs, outLen, part.outOffsetMs))
            }
            val noAudio = job.gif || seg.reverse || seg.volume <= 0f
            EditedMediaItem.Builder(mediaItem).setEffects(Effects(audio, video)).setRemoveAudio(noAudio).build()
        }
    }

    /**
     * The picture pipeline for the source window [winStart, winEnd], in this order (the preview does the same):
     * rotate, markers and covers, zoom, crop, fit the output shape, then images, shapes and text in the
     * OUTPUT frame.
     */
    private fun pictureEffects(job: ExportJob, winStart: Long, winEnd: Long, clock: ItemClock): ArrayList<Effect> {
        val video = ArrayList<Effect>()
        val pic = job.picture
        if (pic.rotation != 0) {
            // Media3 turns counter-clockwise; the editor's rotation is clockwise.
            video.add(ScaleAndRotateTransformation.Builder().setRotationDegrees(-pic.rotation.toFloat()).build())
        }
        // Blocks, blur, mosaic and spotlight act on the video itself, so they go under every overlay.
        for (c in job.covers) {
            if (c.endMs > winStart && c.startMs < winEnd) video.add(RegionEffect(c, clock))
        }
        val picture = pictureOverlays(job, winStart, winEnd, clock)
        if (picture.isNotEmpty()) video.add(OverlayEffect(ImmutableList.copyOf(picture)))
        val zooms = job.zooms.filter { it.endMs > winStart && it.startMs < winEnd }
        if (zooms.isNotEmpty()) video.add(ZoomTransformation(zooms, clock))
        if (pic.isCropped) {
            video.add(Crop(-1f + 2f * pic.cropL, -1f + 2f * pic.cropR, 1f - 2f * pic.cropB, 1f - 2f * pic.cropT))
        }
        if (pic.aspect > 0f) {
            video.add(
                Presentation.createForAspectRatio(
                    pic.aspect,
                    if (pic.fill) Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP else Presentation.LAYOUT_SCALE_TO_FIT,
                ),
            )
        }
        val captions = captionOverlays(job, winStart, winEnd, clock)
        if (captions.isNotEmpty()) video.add(OverlayEffect(ImmutableList.copyOf(captions)))
        return video
    }

    /** Colour look of the whole picture and the transitions around the cuts. */
    private fun transitionEffects(job: ExportJob, seg: SegmentSpec, offsetMs: Long, outLen: Long): List<Effect> {
        val tr = seg.transitions
        val has = (tr.inKind != null && tr.inHalfMs > 0) || (tr.outKind != null && tr.outHalfMs > 0)
        val list = ArrayList<Effect>()
        val base = job.picture.color
        if (has || base != null) {
            list.add(LookColor(if (has) tr else SegmentTransitions.NONE, ItemClock(0), outLen, offsetMs, base))
        }
        if (has) list.add(TransitionShift(tr, ItemClock(0), outLen, offsetMs))
        return list
    }

    private val imageCache = HashMap<String, OverlayRenderers.Rendered>()

    /** Images, shapes and text, all positioned in the OUTPUT frame (after crop and aspect). */
    private fun captionOverlays(job: ExportJob, winStart: Long, winEnd: Long, clock: ItemClock): List<TextureOverlay> {
        val list = ArrayList<TextureOverlay>()
        val fw = job.outW
        val fh = job.outFrameH
        for (im in job.images) {
            if (im.endMs <= winStart || im.startMs >= winEnd) continue
            val widthPx = (im.widthFrac * fw).toInt()
            val r = imageCache.getOrPut(im.path + "|" + widthPx) { OverlayRenderers.loadImage(im.path, widthPx) }
            list.add(MotionBitmapOverlay(r.bitmap, im.x, im.y, 1f, im.opacity, im.rotation, im.startMs, im.endMs, im.motion, clock))
        }
        for (sh in job.shapes) {
            if (sh.endMs <= winStart || sh.startMs >= winEnd) continue
            val r = OverlayRenderers.renderShape(sh, fw, fh)
            list.add(MotionBitmapOverlay(r.bitmap, sh.x, sh.y, 1f, sh.opacity, sh.rotation, sh.startMs, sh.endMs, sh.motion, clock))
        }
        for (t in job.texts) {
            if (t.endMs <= winStart || t.startMs >= winEnd) continue
            val r = OverlayRenderers.renderText(t, fw)
            list.add(MotionBitmapOverlay(r.bitmap, t.x, t.y, 1f, t.opacity, t.rotation, t.startMs, t.endMs, t.motion, clock))
        }
        return list
    }

    private fun pictureOverlays(job: ExportJob, winStart: Long, winEnd: Long, clock: ItemClock): List<TextureOverlay> {
        val list = ArrayList<TextureOverlay>()
        val fw = job.frameW
        val fh = job.frameH
        // Covers are a GL pass under the overlays (see pictureEffects), so the pointer stays visible on top.
        for (m in job.markers) {
            val end = m.cueStartMs + com.huluca.escreenrecorder.marker.MarkerAnim.CUE_MS + m.holdMs +
                com.huluca.escreenrecorder.marker.MarkerAnim.FADE_MS
            if (end <= winStart || m.cueStartMs >= winEnd) continue
            list.add(MarkerOverlay(m, fw, fh, clock))
        }
        return list
    }

    /** Picture-in-picture overlays that are on screen during the output window [winStartOut, winEndOut]. */
    private fun pipEffects(job: ExportJob, winStartOut: Long, winEndOut: Long): List<Effect> {
        if (job.pips.isEmpty()) return emptyList()
        val fw = job.outW
        val list = ArrayList<TextureOverlay>()
        for (pip in job.pips) {
            val end = pip.startOutMs + pip.playMs
            if (pip.playMs <= 0 || end <= winStartOut || pip.startOutMs >= winEndOut) continue
            val widthPx = maxOf(2, (pip.widthFrac * fw).toInt())
            if (pip.isVideo) {
                val res = pipFrames[pipKey(pip)] ?: continue
                val cache = FrameCache(res.dir, widthPx)
                list.add(
                    PipOverlay(
                        { cache.get(it) }, res.frames, PipFrames.FPS, pip.x, pip.y, pip.opacity,
                        pip.startOutMs, end, winStartOut, ItemClock(0),
                    ),
                )
            } else {
                val r = imageCache.getOrPut(pip.path + "|" + widthPx) { OverlayRenderers.loadImage(pip.path, widthPx) }
                list.add(
                    PipOverlay(
                        { r.bitmap }, 1, 1, pip.x, pip.y, pip.opacity, pip.startOutMs, end, winStartOut, ItemClock(0),
                    ),
                )
            }
        }
        return if (list.isEmpty()) emptyList() else listOf(OverlayEffect(ImmutableList.copyOf(list)))
    }

    /** One audio-only sequence per music / voice-over track: a gap up to its start, then its clip(s). */
    private fun audioSequences(job: ExportJob): List<EditedMediaItemSequence> {
        val voice = job.audioClips.filter { !it.music && it.playMs > 0 }.map { longArrayOf(it.startOutMs, it.startOutMs + it.playMs) }
        val result = ArrayList<EditedMediaItemSequence>()
        for (clip in job.audioClips) {
            if (clip.playMs <= 0) continue
            val b = EditedMediaItemSequence.Builder()
            if (clip.startOutMs > 0) b.addGap(clip.startOutMs * 1000)
            var produced = 0L
            var trim = clip.trimStartMs
            while (produced < clip.playMs) {
                val room = (if (clip.loop && clip.music) clip.fileMs else clip.fileMs) - trim
                val len = minOf(clip.playMs - produced, room)
                if (len <= 0) break
                val cut = MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(trim)
                    .setEndPositionMs(trim + len)
                    .build()
                val mi = MediaItem.Builder().setUri(Uri.fromFile(File(clip.path))).setClippingConfiguration(cut).build()
                val gain = GainAudioProcessor(
                    clip.volume, clip.fadeInMs, clip.fadeOutMs, clip.playMs, produced,
                    absStartMs = clip.startOutMs + produced,
                    duck = if (clip.music && clip.duck) voice else emptyList(),
                )
                b.addItem(
                    EditedMediaItem.Builder(mi)
                        .setRemoveVideo(true)
                        .setEffects(Effects(listOf<AudioProcessor>(gain), emptyList()))
                        .build(),
                )
                produced += len
                if (!(clip.loop && clip.music)) break
                trim = 0
            }
            result.add(b.build())
        }
        return result
    }
}
