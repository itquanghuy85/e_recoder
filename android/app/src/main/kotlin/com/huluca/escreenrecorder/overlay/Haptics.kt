package com.huluca.escreenrecorder.overlay

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlin.math.sqrt

/** A short buzz: the only feedback in clean mode, where nothing may be drawn on screen. */
object Haptics {
    fun tick(ctx: Context, ms: Long = 30) {
        try {
            val v = if (Build.VERSION.SDK_INT >= 31) {
                (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (_: Exception) {}
    }
}

/** Two hard jolts within a second count as a shake. */
class ShakeDetector(private val ctx: Context, private val onShake: () -> Unit) : SensorEventListener {
    private val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var lastJolt = 0L
    private var lastFire = 0L
    private var joltCount = 0

    fun start() {
        val s = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        sm.registerListener(this, s, SensorManager.SENSOR_DELAY_GAME)
    }

    fun stop() = sm.unregisterListener(this)

    override fun onSensorChanged(e: SensorEvent) {
        val g = sqrt(e.values[0] * e.values[0] + e.values[1] * e.values[1] + e.values[2] * e.values[2]) / SensorManager.GRAVITY_EARTH
        if (g < JOLT_G) return
        val now = System.currentTimeMillis()
        if (now - lastJolt < 120) return
        joltCount = if (now - lastJolt < 900) joltCount + 1 else 1
        lastJolt = now
        if (joltCount >= 2 && now - lastFire > 2000) {
            joltCount = 0
            lastFire = now
            onShake()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private companion object { const val JOLT_G = 2.6f }
}
