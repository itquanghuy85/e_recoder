package com.huluca.escreenrecorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.media3.common.util.UnstableApi
import com.huluca.escreenrecorder.export.ExportJob
import com.huluca.escreenrecorder.export.Exporter
import com.huluca.escreenrecorder.marker.MarkerRenderer
import com.huluca.escreenrecorder.overlay.timecodeTypeface

/**
 * Runs an export as a foreground service, so it goes on when the app is left or the screen turns off.
 * Progress is a notification (with Cancel); the editor, if it is open, still gets the same events through
 * [RecorderBus]. The job is handed over in memory ([pending]): it holds file paths and numbers only.
 */
@UnstableApi
class ExportService : Service() {
    private var exporter: Exporter? = null
    private var lastNotifyAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                exporter?.cancel()
                exporter = null
                pending = null
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> start()
        }
        return START_NOT_STICKY
    }

    private fun start() {
        val job = pending
        pending = null
        if (job == null) { stopSelf(); return }
        ensureChannel()
        goForeground(buildProgress(0f))
        MarkerRenderer.typeface = timecodeTypeface()
        exporter?.cancel()
        val ex = Exporter(this)
        exporter = ex
        ex.start(job, object : Exporter.Callback {
            override fun onProgress(fraction: Float) {
                RecorderBus.emit(mapOf("type" to "exportProgress", "value" to fraction.toDouble()))
                val now = System.currentTimeMillis()
                if (now - lastNotifyAt > 700) {
                    lastNotifyAt = now
                    notify(buildProgress(fraction))
                }
            }

            override fun onDone(result: Map<String, Any?>) {
                RecorderBus.emit(result + ("type" to "exportDone"))
                finish(buildResult(R.string.export_notif_done))
            }

            override fun onError(code: String, message: String) {
                RecorderBus.emit(mapOf("type" to "exportError", "code" to code, "message" to message))
                finish(buildResult(R.string.export_notif_failed))
            }
        })
    }

    /** Ends the foreground state but leaves a normal notification behind that says how it went. */
    private fun finish(done: Notification) {
        exporter = null
        stopForeground(STOP_FOREGROUND_DETACH)
        notify(done)
        stopSelf()
    }

    private fun ensureChannel() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, getString(R.string.channel_export), NotificationManager.IMPORTANCE_LOW),
        )
    }

    private fun goForeground(n: Notification) {
        // The type must be one the manifest declares; media processing exists from Android 15.
        val type = if (Build.VERSION.SDK_INT >= 35) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
        else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        startForeground(NOTIF_ID, n, type)
    }

    private fun notify(n: Notification) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIF_ID, n)
    }

    private fun openApp() = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun buildProgress(fraction: Float): Notification {
        val cancel = PendingIntent.getService(
            this, 1, Intent(this, ExportService::class.java).setAction(ACTION_CANCEL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val pct = (fraction * 100).toInt().coerceIn(0, 100)
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_rec)
            .setContentTitle(getString(R.string.export_notif_title))
            .setContentText("$pct%")
            .setProgress(100, pct, fraction <= 0f)
            .setContentIntent(openApp())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, getString(R.string.export_notif_cancel), cancel).build())
            .build()
    }

    private fun buildResult(text: Int): Notification =
        Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_rec)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(text))
            .setContentIntent(openApp())
            .setAutoCancel(true)
            .build()

    override fun onDestroy() {
        exporter?.cancel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_CANCEL = "esr.export.cancel"
        const val CHANNEL = "esr_export"
        const val NOTIF_ID = 4202

        /** The job waiting for the service to start (one at a time). */
        @Volatile var pending: ExportJob? = null
    }
}
