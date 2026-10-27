package com.huluca.escreenrecorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.StatFs
import com.huluca.escreenrecorder.capture.RecordingSession
import com.huluca.escreenrecorder.marker.MarkerLayer
import com.huluca.escreenrecorder.marker.MarkerRenderer
import com.huluca.escreenrecorder.overlay.ControlBar
import com.huluca.escreenrecorder.marker.MarkerSpec
import com.huluca.escreenrecorder.overlay.CountdownOverlay
import com.huluca.escreenrecorder.overlay.Haptics
import com.huluca.escreenrecorder.overlay.HotCorner
import com.huluca.escreenrecorder.overlay.MarkDot
import com.huluca.escreenrecorder.overlay.ShakeDetector
import com.huluca.escreenrecorder.overlay.formatClock
import com.huluca.escreenrecorder.overlay.timecodeTypeface
import java.io.File

/** Foreground service that owns the MediaProjection and the active [RecordingSession]. */
class RecorderService : Service(), ControlBar.Listener {
    private val main = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var session: RecordingSession? = null
    private var bar: ControlBar? = null
    private var layer: MarkerLayer? = null
    private var dot: MarkDot? = null
    private var corner: HotCorner? = null
    private var shake: ShakeDetector? = null
    private var countdown: CountdownOverlay? = null
    private var config: RecConfig? = null
    private var pausedByPicker = false
    /** Clean mode: markers placed during the recording, saved next to the video for the editor. */
    private val marks = ArrayList<Map<String, Any?>>()
    private var tempFile: File? = null
    private var startedAtMs = 0L
    private var pausedAtMs = 0L
    private var pausedTotalMs = 0L
    private var paused = false
    private var ticking = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart(intent)
            ACTION_PAUSE -> onPause()
            ACTION_RESUME -> onResume()
            ACTION_STOP -> onStop()
            ACTION_MARK -> arm()
        }
        return START_NOT_STICKY
    }

    private fun handleStart(intent: Intent) {
        val config = RecorderBus.pendingConfig
        if (config == null || session != null || RecorderBus.phase != RecorderBus.IDLE) {
            stopSelf(); return
        }
        goForeground(config, getString(R.string.notif_title_countdown), 0)
        val code = intent.getIntExtra(EXTRA_CODE, 0)
        @Suppress("DEPRECATION")
        val data = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        else intent.getParcelableExtra(EXTRA_DATA)
        if (data == null) { fail("no_consent", "Missing projection consent"); return }
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        projection = mpm.getMediaProjection(code, data)
        if (projection == null) { fail("no_projection", "MediaProjection unavailable"); return }

        cleanTempFiles()
        RecorderBus.changePhase(if (config.countdownSec > 0) RecorderBus.COUNTDOWN else RecorderBus.RECORDING)
        if (config.countdownSec > 0) {
            countdown = CountdownOverlay(this).also { c -> c.run(config.countdownSec) { beginRecording(config) } }
        } else {
            beginRecording(config)
        }
    }

    private fun beginRecording(config: RecConfig) {
        val proj = projection ?: return
        countdown = null
        val dir = File(cacheDir, "rec").also { it.mkdirs() }
        val file = File(dir, "rec_${System.currentTimeMillis()}.mp4")
        tempFile = file
        try {
            val s = RecordingSession(proj, config, file) { reason -> main.post { onFatal(reason) } }
            s.start()
            session = s
        } catch (e: Exception) {
            fail("start_failed", e.javaClass.simpleName + ": " + e.message); return
        }
        startedAtMs = System.currentTimeMillis()
        pausedTotalMs = 0
        paused = false
        this.config = config
        marks.clear()
        pausedByPicker = false
        if (config.floatingBar) {
            if (config.clean) startClean(config) else startDot(config)
        }
        RecorderBus.changePhase(RecorderBus.RECORDING)
        ticking = true
        main.post(tick)
    }

    /** Dot mode: a small corner dot; a tap starts point mode with the tool chosen beforehand. */
    private fun startDot(config: RecConfig) {
        // Layer first so the dot and the pill (added later) stay above it and keep receiving touches.
        val l = MarkerLayer(this, config, object : MarkerLayer.Listener {
            override fun onAnnotateChanged(on: Boolean) { dot?.active = on }
            override fun onCountChanged(count: Int) {}
            override fun onToolChanged() {
                layer?.let { dot?.tool = it.tool; dot?.tint = it.color }
                bar?.refreshTool()
            }
        })
        l.show()
        layer = l
        dot = MarkDot(this, config.markCorner, object : MarkDot.Listener {
            override fun onDotTap() {
                val lay = layer ?: return
                if (bar?.pickerOpen == true || paused) return
                lay.setAnnotating(!lay.annotating)
            }

            override fun onDotLongPress() {
                layer?.setAnnotating(false)
                bar?.let { if (!it.isShown) { it.show(); it.update(elapsedMs(), paused) } }
            }
        }).also { it.tool = l.tool; it.tint = l.color; it.show() }
        bar = ControlBar(this, this, l)
    }

    /**
     * Clean mode: nothing is drawn. An invisible corner (or a shake, or the notification action)
     * arms the layer; the next touch is recorded as a marker with its video time and the editor
     * draws it afterwards.
     */
    private fun startClean(config: RecConfig) {
        corner = HotCorner(this, config.markCorner) { arm() }.also { it.show() } // below the layer
        val l = MarkerLayer(
            this, config,
            object : MarkerLayer.Listener {
                override fun onAnnotateChanged(on: Boolean) {}
                override fun onCountChanged(count: Int) {}
            },
            drawLive = false,
            clock = { elapsedMs() },
            onPlaced = { spec, tMs -> addMark(spec, tMs) },
        )
        l.show()
        layer = l
        if (config.armShake) shake = ShakeDetector(this) { arm() }.also { it.start() }
        updateNotification(0)
    }

    private fun arm() {
        val lay = layer ?: return
        if (paused || config?.clean != true || lay.annotating) return
        Haptics.tick(this, 25)
        lay.arm(ARM_TIMEOUT_MS)
    }

    private fun addMark(spec: MarkerSpec, tMs: Long) {
        Haptics.tick(this, 40)
        marks.add(mapOf("tMs" to tMs, "holdMs" to (config?.markerHoldMs ?: 2500L), "spec" to spec.toMap()))
    }

    private val tick = object : Runnable {
        override fun run() {
            if (!ticking) return
            val elapsed = elapsedMs()
            RecorderBus.elapsedMs = elapsed
            bar?.update(elapsed, paused)
            updateNotification(elapsed)
            RecorderBus.emit(RecorderBus.snapshot())
            if (freeBytes() < LOW_STORAGE_BYTES) {
                RecorderBus.error("low_storage", "Storage almost full, recording stopped")
                onStop()
                return
            }
            main.postDelayed(this, 1000)
        }
    }

    private fun elapsedMs(): Long {
        val now = if (paused) pausedAtMs else System.currentTimeMillis()
        return (now - startedAtMs - pausedTotalMs).coerceAtLeast(0)
    }

    override fun onPause() {
        val s = session ?: return
        if (paused) return
        s.pause()
        paused = true
        pausedAtMs = System.currentTimeMillis()
        RecorderBus.changePhase(RecorderBus.PAUSED)
        bar?.update(elapsedMs(), true)
        updateNotification(elapsedMs())
    }

    override fun onResume() {
        val s = session ?: return
        if (!paused) return
        s.resume()
        pausedTotalMs += System.currentTimeMillis() - pausedAtMs
        paused = false
        RecorderBus.changePhase(RecorderBus.RECORDING)
        bar?.update(elapsedMs(), false)
        updateNotification(elapsedMs())
    }

    override fun onPickerChanged(open: Boolean) {
        if (open) {
            layer?.setAnnotating(false)
            // The tray must never end up in the video: pause while it is open.
            if (!paused) { pausedByPicker = true; onPause() }
        } else if (pausedByPicker) {
            pausedByPicker = false
            onResume()
        }
    }

    override fun onBarDismissed() {
        bar?.setPicker(false)
        bar?.hide()
    }

    override fun onStop() {
        val s = session
        if (s == null) { // cancelled while counting down, or nothing running
            finishAndClose(); return
        }
        ticking = false
        hideOverlays()
        RecorderBus.changePhase(RecorderBus.SAVING)
        session = null
        val cfg = config
        val savedMarks = ArrayList(marks)
        Thread({
            val ok = try { s.stop() } catch (_: Exception) { false }
            val file = tempFile
            val durationMs = s.durationUs / 1000
            var saved: Map<String, Any?>? = null
            var errorCode: String? = null
            if (ok && file != null && file.length() > 0) {
                saved = MediaRepo.save(this, file, durationMs)
                if (saved == null) errorCode = "save_failed"
                else if (cfg != null) saved = saved + mapOf("width" to cfg.width, "height" to cfg.height, "marks" to savedMarks)
            } else {
                errorCode = "empty_recording"
            }
            file?.delete()
            main.post {
                // Go idle first, then announce the result: a new recording started right after
                // the notice must not be refused as "busy".
                finishAndClose()
                if (saved != null) RecorderBus.emit(saved)
                if (errorCode != null) RecorderBus.error(errorCode, "")
            }
        }, "esr-finish").start()
    }

    private fun onFatal(reason: String) {
        RecorderBus.error("capture_failed", reason)
        // The system ended the capture (or an encoder died); keep whatever was recorded.
        onStop()
    }

    private fun fail(code: String, message: String) {
        RecorderBus.error(code, message)
        finishAndClose()
    }

    private fun hideOverlays() {
        shake?.stop(); shake = null
        bar?.hide(); bar = null
        dot?.hide(); dot = null
        layer?.hide(); layer = null
        corner?.hide(); corner = null
    }

    private fun finishAndClose() {
        ticking = false
        hideOverlays()
        countdown?.cancel(); countdown = null
        try { projection?.stop() } catch (_: Exception) {}
        projection = null
        session = null
        RecorderBus.elapsedMs = 0
        RecorderBus.pendingConfig = null
        config = null
        RecorderBus.changePhase(RecorderBus.IDLE)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ---- notification ---------------------------------------------------------------------

    private fun goForeground(config: RecConfig, title: String, elapsed: Long) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, getString(R.string.channel_recording), NotificationManager.IMPORTANCE_LOW),
        )
        var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
        if (config.wantsAudio && Build.VERSION.SDK_INT >= 30) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        startForeground(NOTIF_ID, buildNotification(title, elapsed), type)
    }

    private fun updateNotification(elapsed: Long) {
        val title = getString(if (paused) R.string.notif_title_paused else R.string.notif_title_recording)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIF_ID, buildNotification(title, elapsed))
    }

    private fun buildNotification(title: String, elapsed: Long): Notification {
        fun action(act: String, label: Int, req: Int): Notification.Action {
            val pi = PendingIntent.getService(
                this, req, Intent(this, RecorderService::class.java).setAction(act),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            return Notification.Action.Builder(null, getString(label), pi).build()
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_rec)
            .setContentTitle(title)
            .setContentText(formatClock(elapsed))
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setColor(0xFFFF5A52.toInt())
        if (session != null) {
            b.addAction(if (paused) action(ACTION_RESUME, R.string.notif_action_resume, 1) else action(ACTION_PAUSE, R.string.notif_action_pause, 2))
        }
        if (session != null && config?.clean == true && config?.floatingBar == true && !paused) {
            b.addAction(action(ACTION_MARK, R.string.notif_action_mark, 4))
        }
        b.addAction(action(ACTION_STOP, R.string.notif_action_stop, 3))
        return b.build()
    }

    private fun freeBytes(): Long = try {
        StatFs(Environment.getExternalStorageDirectory().path).availableBytes
    } catch (_: Exception) {
        Long.MAX_VALUE
    }

    private fun cleanTempFiles() {
        File(cacheDir, "rec").listFiles()?.forEach {
            if (System.currentTimeMillis() - it.lastModified() > 3600_000) it.delete()
        }
    }

    override fun onCreate() {
        super.onCreate()
        MarkerRenderer.typeface = timecodeTypeface()
    }

    override fun onDestroy() {
        ticking = false
        hideOverlays()
        countdown?.cancel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "esr.start"
        const val ACTION_PAUSE = "esr.pause"
        const val ACTION_RESUME = "esr.resume"
        const val ACTION_STOP = "esr.stop"
        const val ACTION_MARK = "esr.mark"
        private const val ARM_TIMEOUT_MS = 8000L
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        private const val CHANNEL = "esr_recording"
        private const val NOTIF_ID = 4201
        private const val LOW_STORAGE_BYTES = 60L * 1024 * 1024
    }
}
