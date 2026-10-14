package app.triage.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import kotlin.math.sqrt

/** User-enabled, visible background shake listener. It never opens Triage from the lock screen. */
class BackgroundShakeService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var listening = false
    private var lastShakeAt = 0L

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            getSharedPreferences("triage_settings", Context.MODE_PRIVATE)
                .edit().putBoolean("background_shake_enabled", false).apply()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        promoteToForeground()
        when (intent?.action) {
            ACTION_PAUSE -> unregisterSensor()
            ACTION_RESUME -> if (!isTriageActivityForeground()) registerSensor()
                else unregisterSensor()
            else -> if (!isTriageActivityForeground()) registerSensor()
                else unregisterSensor()
        }
        return START_STICKY
    }

    private fun promoteToForeground() {
        val notification = buildServiceNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                SERVICE_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(SERVICE_NOTIFICATION_ID, notification)
        }
    }

    private fun isTriageActivityForeground(): Boolean =
        getSharedPreferences("triage_settings", Context.MODE_PRIVATE)
            .getBoolean("activity_foreground", false)

    private fun registerSensor() {
        if (listening) return
        val sensor = accelerometer ?: return
        listening = sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    private fun unregisterSensor() {
        if (!listening) return
        sensorManager.unregisterListener(this)
        listening = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_ACCELEROMETER) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!power.isInteractive || keyguard.isKeyguardLocked) return

        val values = event.values
        val gx = values[0] / SensorManager.GRAVITY_EARTH
        val gy = values[1] / SensorManager.GRAVITY_EARTH
        val gz = values[2] / SensorManager.GRAVITY_EARTH
        val force = sqrt((gx * gx + gy * gy + gz * gz).toDouble()).toFloat()
        val now = SystemClock.elapsedRealtime()
        if (force < SHAKE_THRESHOLD_G || now - lastShakeAt < SHAKE_COOLDOWN_MS) return
        if (!AssistantTriggerGate.consume(now)) return

        lastShakeAt = now
        TriageAppHaptics.tap(this)
        openAssistantOrNotify()
    }

    private fun openAssistantOrNotify() {
        val launch = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_ASSIST_FROM_SHAKE
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        // Android may block background activity launches. The notification is the supported
        // user-mediated fallback and remains useful when a launcher or OEM permits the attempt.
        if (Settings.canDrawOverlays(this)) {
            try {
                startActivity(launch)
                Handler(Looper.getMainLooper()).postDelayed({
                    if (isTriageActivityForeground()) {
                        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                            .cancel(EVENT_NOTIFICATION_ID)
                    } else {
                        showAssistantNotification(launch)
                    }
                }, 1500)
                return
            } catch (_: Exception) {
                // Keep the tap-to-open path when the OS declines the launch.
            }
        }

        showAssistantNotification(launch)
    }

    private fun showAssistantNotification(launch: Intent) {

        val tapToOpen = PendingIntent.getActivity(
            this,
            EVENT_NOTIFICATION_ID,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(this, EVENT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Triage is ready")
            .setContentText("Tap to open the voice assistant")
            .setCategory(Notification.CATEGORY_REMINDER)
            .setContentIntent(tapToOpen)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(EVENT_NOTIFICATION_ID, notification)
    }

    private fun buildServiceNotification(): Notification {
        return Notification.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Triage shake access is on")
            .setContentText("Hold Volume Up and shake while unlocked")
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Background shake access",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Shows when Triage is listening for a background shake gesture." },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                EVENT_CHANNEL_ID,
                "Shake to open assistant",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Tap to open Triage after a background shake." },
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onDestroy() {
        unregisterSensor()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_START = "app.triage.mobile.START_SHAKE_SERVICE"
        const val ACTION_OPEN_ASSIST_FROM_SHAKE = "app.triage.mobile.OPEN_ASSIST_FROM_SHAKE"
        const val ACTION_PAUSE = "app.triage.mobile.PAUSE_SHAKE_SENSOR"
        const val ACTION_RESUME = "app.triage.mobile.RESUME_SHAKE_SENSOR"
        const val ACTION_STOP = "app.triage.mobile.STOP_SHAKE_SERVICE"
        const val SERVICE_NOTIFICATION_ID = 7401
        private const val EVENT_NOTIFICATION_ID = 7402
        private const val SERVICE_CHANNEL_ID = "triage_background_shake"
        private const val EVENT_CHANNEL_ID = "triage_shake_open"
        private const val SHAKE_THRESHOLD_G = 2.2f
        private const val SHAKE_COOLDOWN_MS = 3000L
    }
}

private object TriageAppHaptics {
    fun tap(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(android.os.VibrationEffect.createOneShot(40, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(40)
            }
        } catch (_: Exception) {
            // Haptics are optional; shake handling must keep working without them.
        }
    }
}
