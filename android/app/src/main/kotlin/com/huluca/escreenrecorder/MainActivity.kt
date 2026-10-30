package com.huluca.escreenrecorder

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.Settings
import com.huluca.escreenrecorder.export.ExportJob
import com.huluca.escreenrecorder.export.IdleAnalyzer
import com.huluca.escreenrecorder.export.OverlayRenderers
import com.huluca.escreenrecorder.export.TouchScan
import com.huluca.escreenrecorder.marker.MarkerRenderer
import com.huluca.escreenrecorder.marker.MarkerSpec
import com.huluca.escreenrecorder.overlay.timecodeTypeface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingStart: MethodChannel.Result? = null
    private val io = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "escreenrecorder/recorder").setMethodCallHandler(::onCall)
        EventChannel(messenger, "escreenrecorder/recorder/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink) {
                RecorderBus.sink = { events.success(it) }
                events.success(RecorderBus.snapshot())
            }

            override fun onCancel(args: Any?) {
                RecorderBus.sink = null
            }
        })
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> { sendToService(RecorderService.ACTION_STOP); result.success(null) }
            "pause" -> { sendToService(RecorderService.ACTION_PAUSE); result.success(null) }
            "resume" -> { sendToService(RecorderService.ACTION_RESUME); result.success(null) }
            "snapshot" -> result.success(RecorderBus.snapshot())
            "canOverlay" -> result.success(Settings.canDrawOverlays(this))
            "scanTouches" -> async(result) {
                TouchScan.scan(
                    this, Uri.parse(call.argument<String>("uri")!!),
                    (call.argument<Number>("durationMs")!!).toLong(), call.argument<String>("mode") ?: "changes",
                )
            }
            // Where the user is in "show taps": developer options on, and the option itself on.
            "touchSetup" -> {
                val dev = Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
                val taps = Settings.System.getInt(contentResolver, "show_touches", 0) == 1
                result.success(mapOf("developer" to dev, "showTaps" to taps))
            }
            "openSystemSettings" -> {
                val action = when (call.argument<String>("page")) {
                    "about" -> Settings.ACTION_DEVICE_INFO_SETTINGS
                    "developer" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS
                    else -> Settings.ACTION_SETTINGS
                }
                try {
                    startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } catch (_: Exception) {
                    // Some makers hide the page: the main settings screen is the fallback.
                    try { startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) {}
                }
                result.success(null)
            }
            "requestOverlay" -> {
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "displayInfo" -> {
                // Full panel size: resources.displayMetrics excludes the navigation bar.
                val bounds = windowManager.maximumWindowMetrics.bounds
                result.success(
                    mapOf("width" to bounds.width(), "height" to bounds.height(), "dpi" to resources.displayMetrics.densityDpi),
                )
            }
            "freeSpace" -> result.success(
                try { StatFs(Environment.getExternalStorageDirectory().path).availableBytes } catch (_: Exception) { -1L },
            )
            "alignedSize" -> result.success(alignedSize(call))
            "renderMarker" -> async(result) { renderMarker(call) }
            "renderText" -> async(result) { renderText(call) }
            "renderCue" -> async(result) { renderCue(call) }
            "renderCover" -> async(result) { renderCover(call) }
            "renderShape" -> async(result) { renderShape(call) }
            "pickMedia" -> pickMedia(call, result)
            "pickVideoToEdit" -> pickVideoToEdit(result)
            "mediaInfo" -> async(result) { EditorMedia.info(this, call.argument<String>("path")!!) }
            "startVoice" -> {
                try {
                    voice = (voice ?: VoiceRecorder(this)).also { result.success(it.start()) }
                } catch (e: Exception) {
                    result.error("voice_error", e.message, null)
                }
            }
            "stopVoice" -> result.success(voice?.stop())
            "loudness" -> async(result) {
                EditorMedia.loudness(
                    this, call.argument<String>("uri")!!,
                    (call.argument<Number>("startMs")!!).toLong(), (call.argument<Number>("endMs")!!).toLong(),
                )
            }
            "processVoice" -> async(result) {
                val src = call.argument<String>("path")!!
                val fx = call.argument<String>("fx") ?: "none"
                val dn = call.argument<String>("denoise") ?: "off"
                val f = java.io.File(src)
                // One processed file per (voice, effect, noise level): asking again is instant.
                val key = "${f.name.hashCode().toUInt()}_${f.length()}_${f.lastModified()}_${fx}_$dn"
                val out = java.io.File(java.io.File(filesDir, "voice_fx"), "vfx_$key.m4a")
                if (!out.exists() || out.length() == 0L) {
                    val tmp = java.io.File(out.parentFile, "tmp_${System.nanoTime()}.m4a")
                    try {
                        out.parentFile?.mkdirs()
                        com.huluca.escreenrecorder.export.VoiceFx.process(src, tmp, fx, dn)
                        tmp.renameTo(out)
                    } finally {
                        if (tmp.exists()) tmp.delete()
                    }
                }
                out.absolutePath
            }
            "sttStart" -> {
                if (android.os.Build.VERSION.SDK_INT < 33) {
                    result.error("stt_unavailable", "needs Android 13", null)
                } else {
                    com.huluca.escreenrecorder.stt.SttJob.start(
                        this, call.argument<String>("uri")!!, call.argument<String>("lang") ?: "vi-VN",
                    )
                    result.success(null)
                }
            }
            "sttStatus" -> {
                if (android.os.Build.VERSION.SDK_INT < 33) {
                    result.success(mapOf("state" to "idle", "done" to 0, "total" to 0, "error" to "", "pieces" to emptyList<Any>()))
                } else {
                    result.success(com.huluca.escreenrecorder.stt.SttJob.status())
                }
            }
            "sttCancel" -> {
                if (android.os.Build.VERSION.SDK_INT >= 33) com.huluca.escreenrecorder.stt.SttJob.cancel()
                result.success(null)
            }
            "sttDownload" -> {
                if (android.os.Build.VERSION.SDK_INT >= 33) {
                    com.huluca.escreenrecorder.stt.SpeechToText(this).download(call.argument<String>("lang") ?: "vi-VN")
                }
                result.success(null)
            }
            "sttSupport" -> {
                val langs = call.argument<List<String>>("langs") ?: listOf("vi-VN", "en-US")
                if (android.os.Build.VERSION.SDK_INT < 33) {
                    result.success(mapOf("available" to false, "languages" to langs.associateWith { "unsupported" }))
                } else {
                    val stt = com.huluca.escreenrecorder.stt.SpeechToText(this)
                    val ok = stt.available()
                    stt.support(langs) { map -> result.success(mapOf("available" to ok, "languages" to map)) }
                }
            }
            "waveform" -> async(result) {
                EditorMedia.waveform(
                    this, call.argument<String>("uri")!!,
                    (call.argument<Number>("durationMs")!!).toLong(), (call.argument<Number>("bucketMs")!!).toLong(),
                )
            }
            "saveImage" -> async(result) {
                EditorMedia.saveImage(this, call.argument<ByteArray>("png")!!, call.argument<String>("prefix") ?: "ESR_frame")
            }
            "analyzeIdle" -> async(result) {
                IdleAnalyzer.analyze(
                    this, Uri.parse(call.argument<String>("uri")!!),
                    (call.argument<Number>("durationMs")!!).toLong(),
                )
            }
            "export" -> startExport(call, result)
            "cancelExport" -> {
                startService(Intent(this, ExportService::class.java).setAction(ExportService.ACTION_CANCEL))
                result.success(null)
            }
            "listMedia" -> async(result) { MediaRepo.list(this) }
            "thumbnail" -> async(result) {
                MediaRepo.thumbnail(this, Uri.parse(call.argument<String>("uri")!!), call.argument<Int>("w")!!, call.argument<Int>("h")!!)
            }
            "rename" -> async(result) {
                MediaRepo.rename(this, Uri.parse(call.argument<String>("uri")!!), call.argument<String>("name")!!)
            }
            "delete" -> async(result) { MediaRepo.delete(this, Uri.parse(call.argument<String>("uri")!!)) }
            "share" -> {
                MediaRepo.share(this, Uri.parse(call.argument<String>("uri")!!), getString(R.string.share_chooser))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun <T> async(result: MethodChannel.Result, block: () -> T) {
        io.execute {
            try {
                val v = block()
                main.post { result.success(v) }
            } catch (e: Exception) {
                main.post { result.error("native_error", e.message, null) }
            }
        }
    }

    /**
     * Renders one marker body (transparent PNG, sized to its bounds) for the editor and the
     * marker settings preview. Returns {png, half} where half is the bitmap half-size in px.
     */
    private fun renderMarker(call: MethodCall): Map<String, Any> {
        MarkerRenderer.typeface = timecodeTypeface()
        val spec = MarkerSpec.fromMap(call.argument<Map<String, Any?>>("spec")!!)
        val rendered = MarkerRenderer.renderBody(
            spec, call.argument<Int>("frameW")!!, call.argument<Int>("frameH")!!,
            phaseMs = (call.argument<Number>("phaseMs") ?: 0).toFloat(),
        )
        val out = java.io.ByteArrayOutputStream()
        rendered.bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
        rendered.bitmap.recycle()
        return mapOf("png" to out.toByteArray(), "half" to rendered.halfPx.toDouble())
    }

    private fun png(b: android.graphics.Bitmap): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        b.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    private fun renderText(call: MethodCall): Map<String, Any> {
        MarkerRenderer.typeface = timecodeTypeface()
        val m = call.argument<Map<String, Any?>>("clip")!!
        val clip = ExportJob.fromMap(mapOf(
            "sourceUri" to "", "frameW" to 1, "frameH" to 1, "outHeight" to 1, "bitrate" to 1,
            "texts" to listOf(m),
        )).texts.first()
        val r = OverlayRenderers.renderText(clip, call.argument<Int>("frameW")!!)
        val bytes = png(r.bitmap)
        r.bitmap.recycle()
        return mapOf("png" to bytes, "w" to r.wPx, "h" to r.hPx)
    }

    private fun renderCue(call: MethodCall): Map<String, Any> {
        MarkerRenderer.typeface = timecodeTypeface()
        val text = mutableMapOf<String, Any?>(
            "text" to "", "color" to -1, "sizeU" to 1.0, "x" to 0.5, "y" to 0.5, "startMs" to 0, "endMs" to 0,
            "cues" to listOf(call.argument<Map<String, Any?>>("cue")!!),
            "captionStyle" to call.argument<Map<String, Any?>>("style"),
        )
        val clip = ExportJob.parseText(text)
        val r = OverlayRenderers.renderCue(
            clip.cues!!.first(), clip.captionStyle, call.argument<Int>("frameW")!!,
            (call.argument<Number>("timeMs"))?.toLong(),
        )
        val bytes = png(r.bitmap)
        r.bitmap.recycle()
        return mapOf("png" to bytes, "w" to r.wPx, "h" to r.hPx)
    }

    private fun renderCover(call: MethodCall): Map<String, Any> {
        val m = call.argument<Map<String, Any?>>("clip")!!
        val clip = ExportJob.fromMap(mapOf(
            "sourceUri" to "", "frameW" to 1, "frameH" to 1, "outHeight" to 1, "bitrate" to 1,
            "covers" to listOf(m),
        )).covers.first()
        val r = OverlayRenderers.renderCover(clip, call.argument<Int>("frameW")!!, call.argument<Int>("frameH")!!)
        val bytes = png(r.bitmap)
        r.bitmap.recycle()
        return mapOf("png" to bytes, "w" to r.wPx, "h" to r.hPx)
    }

    private fun renderShape(call: MethodCall): Map<String, Any> {
        MarkerRenderer.typeface = timecodeTypeface()
        val clip = ExportJob.parseShape(call.argument<Map<String, Any?>>("clip")!!)
        val r = OverlayRenderers.renderShape(clip, call.argument<Int>("frameW")!!, call.argument<Int>("frameH")!!)
        val bytes = png(r.bitmap)
        r.bitmap.recycle()
        return mapOf("png" to bytes, "w" to r.wPx, "h" to r.hPx)
    }

    private var voice: VoiceRecorder? = null
    private var pendingPick: MethodChannel.Result? = null

    /** Opens the system picker for music, pictures or videos; the file is copied into the app. */
    private fun pickMedia(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPick != null) { result.success(null); return }
        val types = when (call.argument<String>("kind")) {
            "audio" -> arrayOf("audio/*")
            "image" -> arrayOf("image/*")
            "video" -> arrayOf("video/*")
            "file" -> arrayOf("*/*")
            else -> arrayOf("image/*", "video/*")
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (types.size == 1) types[0] else "*/*"
            if (types.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, types)
        }
        pendingPick = result
        startActivityForResult(intent, REQ_PICK)
    }

    private var pendingEditPick: MethodChannel.Result? = null

    /** Opens the system picker for ONE video and returns it where it is (no copy, no gallery scan). */
    private fun pickVideoToEdit(result: MethodChannel.Result) {
        if (pendingEditPick != null) { result.success(null); return }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
        }
        pendingEditPick = result
        startActivityForResult(intent, REQ_PICK_EDIT)
    }

    /** Hands the job to [ExportService], which keeps going when the app is left. */
    private fun startExport(call: MethodCall, result: MethodChannel.Result) {
        val job = try {
            ExportJob.fromMap(call.arguments as Map<*, *>)
        } catch (e: Exception) {
            result.error("bad_job", e.message, null); return
        }
        ExportService.pending = job
        try {
            startForegroundService(Intent(this, ExportService::class.java))
        } catch (e: Exception) {
            ExportService.pending = null
            result.error("export_service", e.message, null); return
        }
        result.success(null)
    }

    /** Snaps (w, h) to what the AVC encoder supports so the VirtualDisplay and encoder agree. */
    private fun alignedSize(call: MethodCall): Map<String, Int> {
        val w0 = call.argument<Int>("width")!!
        val h0 = call.argument<Int>("height")!!
        var w = w0 and 1.inv()
        var h = h0 and 1.inv()
        try {
            val codec = android.media.MediaCodec.createEncoderByType("video/avc")
            val caps = codec.codecInfo.getCapabilitiesForType("video/avc").videoCapabilities
            codec.release()
            // Shrink both sides by the same factor so the aspect ratio never changes. Some encoders
            // only list landscape limits, so a portrait size counts as supported when its
            // transpose is.
            var k = 1.0
            var tries = 0
            while (tries++ < 40) {
                w = (w0 * k).toInt() / caps.widthAlignment * caps.widthAlignment
                h = (h0 * k).toInt() / caps.heightAlignment * caps.heightAlignment
                if (w > 0 && h > 0 && (caps.isSizeSupported(w, h) || caps.isSizeSupported(h, w))) break
                k *= 0.95
            }
        } catch (_: Exception) {
        }
        return mapOf("width" to w, "height" to h)
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (RecorderBus.phase != RecorderBus.IDLE) { result.success(false); return }
        val cfg = try {
            RecConfig.fromMap(call.arguments as Map<*, *>)
        } catch (e: Exception) {
            result.error("bad_config", e.message, null); return
        }
        RecorderBus.pendingConfig = cfg
        pendingStart = result
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = if (Build.VERSION.SDK_INT >= 34) {
            mpm.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else {
            mpm.createScreenCaptureIntent()
        }
        startActivityForResult(intent, REQ_PROJECTION)
    }

    private fun sendToService(action: String) {
        startService(Intent(this, RecorderService::class.java).setAction(action))
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_EDIT) {
            val r = pendingEditPick
            pendingEditPick = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { r?.success(null); return }
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {}
            io.execute {
                try {
                    val info = EditorMedia.describeVideo(this, uri)
                    main.post { r?.success(info) }
                } catch (e: Exception) {
                    main.post { r?.error("pick_failed", e.message, null) }
                }
            }
            return
        }
        if (requestCode == REQ_PICK) {
            val r = pendingPick
            pendingPick = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { r?.success(null); return }
            io.execute {
                try {
                    val info = EditorMedia.importPicked(this, uri)
                    main.post { r?.success(info) }
                } catch (e: Exception) {
                    main.post { r?.error("pick_failed", e.message, null) }
                }
            }
            return
        }
        if (requestCode != REQ_PROJECTION) return
        val r = pendingStart
        pendingStart = null
        if (resultCode == RESULT_OK && data != null) {
            val i = Intent(this, RecorderService::class.java)
                .setAction(RecorderService.ACTION_START)
                .putExtra(RecorderService.EXTRA_CODE, resultCode)
                .putExtra(RecorderService.EXTRA_DATA, data)
            startForegroundService(i)
            r?.success(true)
            // Get out of the way so the user can open the app they want to record.
            main.postDelayed({ moveTaskToBack(true) }, 250)
        } else {
            RecorderBus.pendingConfig = null
            r?.success(false)
        }
    }

    companion object {
        const val REQ_PROJECTION = 4242
        const val REQ_PICK = 4243
        const val REQ_PICK_EDIT = 4244
    }
}
