package app.triage.mobile

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.content.IntentFilter
import android.os.BatteryManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.KeyEvent
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt
import kotlin.math.sqrt

class NativeActionBridge(
    private val context: Context,
    binaryMessenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, SensorEventListener {

    private companion object {
        const val CONTACT_PICKER_REQUEST = 9402
    }

    private val methodChannel = MethodChannel(binaryMessenger, "triage.native_actions")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var pendingContactPickerResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setVolume" -> handleSetVolume(call, result)
            "getVolume" -> handleGetVolume(result)
            "setBrightness" -> handleSetBrightness(call, result)
            "getBrightness" -> handleGetBrightness(result)
            "openWriteSettings" -> handleOpenWriteSettings(result)
            "setDoNotDisturb" -> handleSetDoNotDisturb(call, result)
            "getDoNotDisturb" -> handleGetDoNotDisturb(result)
            "openNotificationPolicySettings" -> handleOpenNotificationPolicySettings(result)
            "setTimer" -> handleSetTimer(call, result)
            "setAlarm" -> handleSetAlarm(call, result)
            "openApp" -> handleOpenApp(call, result)
            "mediaControl" -> handleMediaControl(call, result)
            "canScheduleExactAlarms" -> handleCanScheduleExactAlarms(result)
            "openExactAlarmSettings" -> handleOpenExactAlarmSettings(result)
            "scheduleExactAlarm" -> handleScheduleExactAlarm(call, result)
            "cancelExactAlarm" -> handleCancelExactAlarm(call, result)
            "checkCapabilities" -> handleCheckCapabilities(result)
            "getPendingAlarmTrigger" -> handleGetPendingAlarmTrigger(result)
            "startShakeDetection" -> handleStartShakeDetection(result)
            "stopShakeDetection" -> handleStopShakeDetection(result)
            "setBackgroundShakeEnabled" -> handleSetBackgroundShakeEnabled(call, result)
            "getPendingBackgroundShake" -> handleGetPendingBackgroundShake(result)
            "triggerHapticFeedback" -> handleTriggerHapticFeedback(call, result)
            "searchContacts" -> handleSearchContacts(call, result)
            "pickContact" -> handlePickContact(result)
            "openTriggerAccessibilitySettings" -> {
                context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }
            "dialContact" -> handleDialContact(call, result)
            "composeSms" -> handleComposeSms(call, result)
            "composeWhatsApp" -> handleComposeWhatsApp(call, result)
            "openNavigation" -> handleOpenNavigation(call, result)
            "getInstalledApps" -> handleGetInstalledApps(result)
            else -> result.notImplemented()
        }
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        val rawPercent = call.argument<Any>("percent")
        val showUi = call.argument<Boolean>("showUi") ?: true

        val percent: Double? = when (rawPercent) {
            is Number -> rawPercent.toDouble()
            is String -> rawPercent.toDoubleOrNull()
            else -> null
        }

        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val minVol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
                } else {
                    0
                }
                val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val previousPercent = if (maxVol > minVol) {
                    ((currentVol - minVol).toDouble() / (maxVol - minVol) * 100.0).roundToInt()
                } else {
                    0
                }

                if (percent == null || percent.isNaN() || percent.isInfinite() || percent < 0.0 || percent > 100.0) {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "error",
                            "action" to "set_volume",
                            "previousValue" to previousPercent,
                            "targetValue" to null,
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "INVALID_VOLUME_ARGUMENT",
                            "errorMessage" to "Volume level must be a numeric value between 0 and 100."
                        )
                    )
                    return@post
                }

                val targetIndex = Math.round((percent / 100.0) * (maxVol - minVol) + minVol).toInt().coerceIn(minVol, maxVol)
                val flags = if (showUi) AudioManager.FLAG_SHOW_UI else 0

                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetIndex, flags)

                val newVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val actualNewPercent = if (maxVol > minVol) {
                    ((newVol - minVol).toDouble() / (maxVol - minVol) * 100.0).roundToInt()
                } else {
                    0
                }
                val latencyMs = SystemClock.elapsedRealtime() - startTime

                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "set_volume",
                        "previousValue" to previousPercent,
                        "targetValue" to actualNewPercent,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "set_volume",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "VOLUME_SET_FAILED",
                        "errorMessage" to (e.message ?: "Failed to set system volume")
                    )
                )
            }
        }
    }

    private fun handleGetVolume(result: MethodChannel.Result) {
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val minVol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    audioManager.getStreamMinVolume(AudioManager.STREAM_MUSIC)
                } else {
                    0
                }
                val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val currentPercent = if (maxVol > minVol) {
                    ((currentVol - minVol).toDouble() / (maxVol - minVol) * 100.0).roundToInt()
                } else {
                    0
                }
                val latencyMs = SystemClock.elapsedRealtime() - startTime

                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "get_volume",
                        "previousValue" to currentPercent,
                        "targetValue" to currentPercent,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "get_volume",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "VOLUME_GET_FAILED",
                        "errorMessage" to (e.message ?: "Failed to read system volume")
                    )
                )
            }
        }
    }

    private fun handleSetBrightness(call: MethodCall, result: MethodChannel.Result) {
        val rawPercent = call.argument<Any>("percent")
        val percent: Double? = when (rawPercent) {
            is Number -> rawPercent.toDouble()
            is String -> rawPercent.toDoubleOrNull()
            else -> null
        }

        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                if (!Settings.System.canWrite(context)) {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "permission_required",
                            "action" to "set_brightness",
                            "previousValue" to null,
                            "targetValue" to null,
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "PERMISSION_DENIED",
                            "errorMessage" to "WRITE_SETTINGS permission required to modify screen brightness."
                        )
                    )
                    return@post
                }

                val currentInt = Settings.System.getInt(
                    context.contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    128
                )
                val currentPercent = (currentInt / 255.0 * 100.0).roundToInt()

                if (percent == null || percent.isNaN() || percent.isInfinite() || percent < 0.0 || percent > 100.0) {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "error",
                            "action" to "set_brightness",
                            "previousValue" to currentPercent,
                            "targetValue" to null,
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "INVALID_BRIGHTNESS_ARGUMENT",
                            "errorMessage" to "Brightness level must be a numeric value between 0 and 100."
                        )
                    )
                    return@post
                }

                val targetInt = (percent / 100.0 * 255.0).roundToInt().coerceIn(0, 255)
                Settings.System.putInt(
                    context.contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    targetInt
                )

                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "set_brightness",
                        "previousValue" to currentPercent,
                        "targetValue" to percent.roundToInt(),
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "set_brightness",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "BRIGHTNESS_SET_FAILED",
                        "errorMessage" to (e.message ?: "Failed to set screen brightness.")
                    )
                )
            }
        }
    }

    private fun handleGetBrightness(result: MethodChannel.Result) {
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val currentInt = Settings.System.getInt(
                    context.contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    128
                )
                val currentPercent = (currentInt / 255.0 * 100.0).roundToInt()
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "get_brightness",
                        "previousValue" to currentPercent,
                        "targetValue" to currentPercent,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "get_brightness",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "BRIGHTNESS_GET_FAILED",
                        "errorMessage" to (e.message ?: "Failed to get screen brightness.")
                    )
                )
            }
        }
    }

    private fun handleOpenWriteSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                data = Uri.parse("package:" + context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(mapOf("status" to "handed_off", "action" to "open_write_settings"))
        } catch (e: Exception) {
            result.success(mapOf("status" to "error", "errorMessage" to (e.message ?: "Failed to open settings")))
        }
    }

    private fun handleSetDoNotDisturb(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "permission_required",
                            "action" to "set_dnd",
                            "previousValue" to null,
                            "targetValue" to enabled,
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "PERMISSION_DENIED",
                            "errorMessage" to "Notification Policy access (DND permission) required."
                        )
                    )
                    return@post
                }

                val currentFilter = notificationManager.currentInterruptionFilter
                val currentEnabled = (currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL)

                val targetFilter = if (enabled) {
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                } else {
                    NotificationManager.INTERRUPTION_FILTER_ALL
                }
                notificationManager.setInterruptionFilter(targetFilter)

                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "set_dnd",
                        "previousValue" to currentEnabled,
                        "targetValue" to enabled,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "set_dnd",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "DND_SET_FAILED",
                        "errorMessage" to (e.message ?: "Failed to set Do Not Disturb filter.")
                    )
                )
            }
        }
    }

    private fun handleGetDoNotDisturb(result: MethodChannel.Result) {
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val hasPermission = notificationManager.isNotificationPolicyAccessGranted
                val currentFilter = if (hasPermission) notificationManager.currentInterruptionFilter else NotificationManager.INTERRUPTION_FILTER_ALL
                val isDnd = (currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL)
                val latencyMs = SystemClock.elapsedRealtime() - startTime

                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "get_dnd",
                        "previousValue" to isDnd,
                        "targetValue" to isDnd,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null,
                        "extra" to mapOf("permissionGranted" to hasPermission)
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "get_dnd",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "DND_GET_FAILED",
                        "errorMessage" to (e.message ?: "Failed to get Do Not Disturb state.")
                    )
                )
            }
        }
    }

    private fun handleOpenNotificationPolicySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(mapOf("status" to "handed_off", "action" to "open_notification_policy_settings"))
        } catch (e: Exception) {
            result.success(mapOf("status" to "error", "errorMessage" to (e.message ?: "Failed to open settings")))
        }
    }

    private fun handleSetTimer(call: MethodCall, result: MethodChannel.Result) {
        val seconds = call.argument<Int>("seconds") ?: 60
        val message = call.argument<String>("message")
        val skipUi = call.argument<Boolean>("skipUi") ?: true

        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                    putExtra(AlarmClock.EXTRA_LENGTH, seconds)
                    if (!message.isNullOrEmpty()) {
                        putExtra(AlarmClock.EXTRA_MESSAGE, message)
                    }
                    putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)

                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "handed_off",
                        "action" to "set_timer",
                        "previousValue" to null,
                        "targetValue" to seconds,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null,
                        "extra" to mapOf("message" to message, "seconds" to seconds)
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "set_timer",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "TIMER_FAILED",
                        "errorMessage" to (e.message ?: "Failed to hand off timer to Clock app.")
                    )
                )
            }
        }
    }

    private fun handleSetAlarm(call: MethodCall, result: MethodChannel.Result) {
        val hour = call.argument<Int>("hour") ?: 8
        val minutes = call.argument<Int>("minutes") ?: 0
        val message = call.argument<String>("message")
        val skipUi = call.argument<Boolean>("skipUi") ?: true

        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                    putExtra(AlarmClock.EXTRA_HOUR, hour)
                    putExtra(AlarmClock.EXTRA_MINUTES, minutes)
                    if (!message.isNullOrEmpty()) {
                        putExtra(AlarmClock.EXTRA_MESSAGE, message)
                    }
                    putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)

                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "handed_off",
                        "action" to "set_alarm",
                        "previousValue" to null,
                        "targetValue" to String.format("%02d:%02d", hour, minutes),
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null,
                        "extra" to mapOf("hour" to hour, "minutes" to minutes)
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "set_alarm",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "ALARM_FAILED",
                        "errorMessage" to (e.message ?: "Failed to hand off alarm to Clock app.")
                    )
                )
            }
        }
    }

    private fun handleOpenApp(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("app")?.trim() ?: ""
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val packageManager = context.packageManager
                val normalizedTarget = target.lowercase()
                if (normalizedTarget == "torch_on" || normalizedTarget == "torch_off") {
                    val cameras = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                    val cameraId = cameras.cameraIdList.firstOrNull { id ->
                        cameras.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                    } ?: throw IllegalStateException("This device has no flashlight.")
                    cameras.setTorchMode(cameraId, normalizedTarget == "torch_on")
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(mapOf(
                        "status" to "success", "action" to "open_app", "previousValue" to null,
                        "targetValue" to normalizedTarget, "executionLatencyMs" to latencyMs,
                    ))
                    return@post
                }
                if (normalizedTarget == "battery_status") {
                    val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                    val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                    val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(mapOf(
                        "status" to "success", "action" to "open_app", "previousValue" to null,
                        "targetValue" to normalizedTarget, "executionLatencyMs" to latencyMs,
                        "extra" to mapOf("level" to if (level >= 0 && scale > 0) level * 100 / scale else -1, "charging" to charging),
                    ))
                    return@post
                }
                val packageCandidates = when (normalizedTarget) {
                    "whatsapp" -> listOf("com.whatsapp", "com.whatsapp.w4b")
                    "whatsapp business", "business whatsapp" -> listOf("com.whatsapp.w4b", "com.whatsapp")
                    "youtube" -> listOf("com.google.android.youtube")
                    "maps", "google maps" -> listOf("com.google.android.apps.maps")
                    "settings" -> listOf("com.android.settings")
                    "chrome" -> listOf("com.android.chrome")
                    "spotify" -> listOf("com.spotify.music")
                    "keep", "google keep", "notes" -> listOf("com.google.android.keep")
                    "gmail" -> listOf("com.google.android.gm")
                    else -> if (target.contains(".")) listOf(target) else emptyList()
                }

                var launchIntent: Intent? = null
                var resolvedPackage: String? = null
                if (normalizedTarget == "camera") {
                    launchIntent = Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                } else {
                    if (normalizedTarget == "wifi") {
                        launchIntent = Intent(Settings.ACTION_WIFI_SETTINGS)
                    } else if (normalizedTarget == "bluetooth") {
                        launchIntent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                    }
                    for (pkg in packageCandidates) {
                        if (launchIntent != null) break
                        launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            resolvedPackage = pkg
                            break
                        }
                    }
                    launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                if (launchIntent != null && launchIntent.resolveActivity(packageManager) != null) {
                    context.startActivity(launchIntent)
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "success",
                            "action" to "open_app",
                            "previousValue" to null,
                            "targetValue" to (resolvedPackage ?: target),
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to null,
                            "errorMessage" to null
                        )
                    )
                } else {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "action" to "open_app",
                            "previousValue" to null,
                            "targetValue" to target,
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "APP_NOT_FOUND",
                            "errorMessage" to "Application \"$target\" is not installed on this device."
                        )
                    )
                }
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "open_app",
                        "previousValue" to null,
                        "targetValue" to target,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "OPEN_APP_FAILED",
                        "errorMessage" to (e.message ?: "Failed to launch application.")
                    )
                )
            }
        }
    }

    private fun handlePickContact(result: MethodChannel.Result) {
        val activity = context as? Activity
        if (activity == null || pendingContactPickerResult != null) {
            result.success(mapOf("status" to "unavailable"))
            return
        }
        pendingContactPickerResult = result
        try {
            val intent = Intent(
                Intent.ACTION_PICK,
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            )
            activity.startActivityForResult(intent, CONTACT_PICKER_REQUEST)
        } catch (_: ActivityNotFoundException) {
            pendingContactPickerResult = null
            result.success(mapOf("status" to "unavailable"))
        } catch (error: Exception) {
            pendingContactPickerResult = null
            result.success(mapOf("status" to "unavailable", "error" to error.message.orEmpty()))
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != CONTACT_PICKER_REQUEST) return
        val callback = pendingContactPickerResult ?: return
        pendingContactPickerResult = null
        if (resultCode != Activity.RESULT_OK) {
            callback.success(mapOf("status" to "cancelled"))
            return
        }
        val uri = data?.data
        if (uri == null) {
            callback.success(mapOf("status" to "unavailable"))
            return
        }
        try {
            context.contentResolver.query(
                uri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val name = cursor.getString(0)?.trim().orEmpty()
                    val rawPhone = cursor.getString(1).orEmpty()
                    val phone = buildString {
                        rawPhone.forEach { char ->
                            if (char.isDigit() || (char == '+' && isEmpty())) append(char)
                        }
                    }
                    if (name.isNotEmpty() && phone.isNotEmpty()) {
                        callback.success(mapOf("status" to "selected", "name" to name, "phone" to phone))
                        return
                    }
                }
            }
            callback.success(mapOf("status" to "unavailable"))
        } catch (error: Exception) {
            callback.success(mapOf("status" to "unavailable", "error" to error.message.orEmpty()))
        }
    }

    private fun handleSearchContacts(call: MethodCall, result: MethodChannel.Result) {
        val query = call.argument<String>("query")?.trim() ?: ""
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "permission_required",
                        "action" to "search_contacts",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "PERMISSION_DENIED",
                        "errorMessage" to "READ_CONTACTS permission is required to search contacts.",
                        "contacts" to emptyList<Map<String, String>>()
                    )
                )
                return@post
            }

            try {
                val contactsList = mutableListOf<Map<String, String>>()
                val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                val projection = arrayOf(
                      ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                      ContactsContract.CommonDataKinds.Phone.IS_SUPER_PRIMARY,
                      ContactsContract.CommonDataKinds.Phone.IS_PRIMARY
                )

                var selection: String? = null
                var selectionArgs: Array<String>? = null
                if (query.isNotEmpty()) {
                    selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
                    selectionArgs = arrayOf("%$query%")
                }

                val cursor = context.contentResolver.query(
                    uri,
                    projection,
                    selection,
                    selectionArgs,
                    "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
                )

                  cursor?.use {
                      val idIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
                      val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                      val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                      val superPrimaryIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.IS_SUPER_PRIMARY)
                      val primaryIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.IS_PRIMARY)
                      val bestByContact = linkedMapOf<String, Pair<Int, Map<String, String>>>()

                      while (it.moveToNext()) {
                          val contactId = if (idIdx >= 0) it.getString(idIdx) ?: "" else ""
                          val name = if (nameIdx >= 0) it.getString(nameIdx)?.trim() ?: "" else ""
                          val num = if (numIdx >= 0) it.getString(numIdx) ?: "" else ""
                          val cleanNum = num.replace("[^0-9+]".toRegex(), "")
                          if (contactId.isEmpty() || name.isEmpty() || cleanNum.isEmpty()) continue
                          val priority = (if (superPrimaryIdx >= 0 && it.getInt(superPrimaryIdx) == 1) 2 else 0) +
                              (if (primaryIdx >= 0 && it.getInt(primaryIdx) == 1) 1 else 0)
                          val current = bestByContact[contactId]
                          if (current == null || priority > current.first) {
                              bestByContact[contactId] = priority to mapOf("name" to name, "phone" to cleanNum)
                          }
                      }
                      contactsList.addAll(bestByContact.values.map { it.second })
                  }

                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "success",
                        "action" to "search_contacts",
                        "executionLatencyMs" to latencyMs,
                        "contacts" to contactsList
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "search_contacts",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "CONTACTS_QUERY_FAILED",
                        "errorMessage" to (e.message ?: "Failed to read contacts"),
                        "contacts" to emptyList<Map<String, String>>()
                    )
                )
            }
        }
    }

    private fun handleDialContact(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>("phoneNumber")?.trim() ?: ""
        val contactName = call.argument<String>("name")?.trim() ?: phoneNumber
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            if (phoneNumber.isEmpty()) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "dial_contact",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "INVALID_PHONE_NUMBER",
                        "errorMessage" to "Phone number is empty."
                    )
                )
                return@post
            }

            try {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (dialIntent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(dialIntent)
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "handed_off",
                            "action" to "dial_contact",
                            "previousValue" to null,
                            "targetValue" to contactName,
                            "executionLatencyMs" to latencyMs,
                            "extra" to mapOf("phoneNumber" to phoneNumber, "name" to contactName)
                        )
                    )
                } else {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "action" to "dial_contact",
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "NO_DIALER_APP",
                            "errorMessage" to "No phone dialer application found."
                        )
                    )
                }
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "dial_contact",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "DIAL_FAILED",
                        "errorMessage" to (e.message ?: "Failed to launch phone dialer")
                    )
                )
            }
        }
    }

    private fun handleComposeSms(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>("phoneNumber")?.trim() ?: ""
        val message = call.argument<String>("message")?.trim() ?: ""
        val contactName = call.argument<String>("name")?.trim() ?: phoneNumber
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val smsIntent = Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse(if (phoneNumber.isNotEmpty()) "smsto:$phoneNumber" else "smsto:")
                    if (message.isNotEmpty()) {
                        putExtra("sms_body", message)
                        putExtra(Intent.EXTRA_TEXT, message)
                    }
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (smsIntent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(smsIntent)
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "handed_off",
                            "action" to "compose_sms",
                            "previousValue" to null,
                            "targetValue" to contactName,
                            "executionLatencyMs" to latencyMs,
                            "extra" to mapOf("phoneNumber" to phoneNumber, "messageLength" to message.length)
                        )
                    )
                } else {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "action" to "compose_sms",
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "NO_SMS_APP",
                            "errorMessage" to "No SMS messaging application found."
                        )
                    )
                }
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "compose_sms",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "SMS_FAILED",
                        "errorMessage" to (e.message ?: "Failed to open SMS composer")
                    )
                )
            }
        }
    }

    private fun handleComposeWhatsApp(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>("phoneNumber")?.trim()?.replace("[^0-9]".toRegex(), "") ?: ""
        val message = call.argument<String>("message")?.trim() ?: ""
        val contactName = call.argument<String>("name")?.trim() ?: phoneNumber
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                // Verify WhatsApp or WhatsApp Business is installed
                val pm = context.packageManager
                val packages = listOf("com.whatsapp", "com.whatsapp.w4b")
                var installedTargetPkg: String? = null
                for (pkg in packages) {
                    try {
                        pm.getPackageInfo(pkg, 0)
                        installedTargetPkg = pkg
                        break
                    } catch (_: PackageManager.NameNotFoundException) {}
                }

                if (installedTargetPkg == null) {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "action" to "compose_whatsapp",
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "WHATSAPP_NOT_INSTALLED",
                            "errorMessage" to "WhatsApp is not installed on this device."
                        )
                    )
                    return@post
                }

                // wa.me format: https://wa.me/<number>?text=<encoded_text>
                val encodedText = Uri.encode(message)
                val uriString = if (phoneNumber.isNotEmpty()) {
                    "https://wa.me/$phoneNumber?text=$encodedText"
                } else {
                    "https://wa.me/?text=$encodedText"
                }

                val waIntent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString)).apply {
                    setPackage(installedTargetPkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                context.startActivity(waIntent)
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "handed_off",
                        "action" to "compose_whatsapp",
                        "previousValue" to null,
                        "targetValue" to contactName,
                        "executionLatencyMs" to latencyMs,
                        "extra" to mapOf("targetPackage" to installedTargetPkg, "messageLength" to message.length)
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "compose_whatsapp",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "WHATSAPP_FAILED",
                        "errorMessage" to (e.message ?: "Failed to open WhatsApp composer")
                    )
                )
            }
        }
    }

    private fun handleOpenNavigation(call: MethodCall, result: MethodChannel.Result) {
        val destination = call.argument<String>("destination")?.trim() ?: ""
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            if (destination.isEmpty()) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "open_navigation",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "EMPTY_DESTINATION",
                        "errorMessage" to "Destination cannot be empty."
                    )
                )
                return@post
            }

            try {
                val encodedDest = Uri.encode(destination)
                val navUri = Uri.parse("google.navigation:q=$encodedDest")
                var navIntent = Intent(Intent.ACTION_VIEW, navUri).apply {
                    setPackage("com.google.android.apps.maps")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                if (navIntent.resolveActivity(context.packageManager) == null) {
                    navIntent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=$encodedDest")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                }

                if (navIntent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(navIntent)
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "handed_off",
                            "action" to "open_navigation",
                            "previousValue" to null,
                            "targetValue" to destination,
                            "executionLatencyMs" to latencyMs
                        )
                    )
                } else {
                    val latencyMs = SystemClock.elapsedRealtime() - startTime
                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "action" to "open_navigation",
                            "executionLatencyMs" to latencyMs,
                            "errorCode" to "NO_MAPS_APP",
                            "errorMessage" to "No navigation or maps application found."
                        )
                    )
                }
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "open_navigation",
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "NAVIGATION_FAILED",
                        "errorMessage" to (e.message ?: "Failed to launch navigation")
                    )
                )
            }
        }
    }

    private fun handleGetInstalledApps(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                val pm = context.packageManager
                val intent = Intent(Intent.ACTION_MAIN, null).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                }
                val resolveInfos = pm.queryIntentActivities(intent, 0)
                val appsList = mutableListOf<Map<String, String>>()

                for (info in resolveInfos) {
                    val pkg = info.activityInfo.packageName
                    val label = info.loadLabel(pm).toString()
                    if (pkg.isNotEmpty() && label.isNotEmpty()) {
                        appsList.add(mapOf("packageName" to pkg, "label" to label))
                    }
                }

                appsList.sortBy { it["label"]?.lowercase() ?: "" }
                result.success(appsList)
            } catch (e: Exception) {
                result.error("APPS_QUERY_FAILED", e.message, null)
            }
        }
    }

    private fun handleMediaControl(call: MethodCall, result: MethodChannel.Result) {
        val command = call.argument<String>("command") ?: "play_pause"
        mainHandler.post {
            val startTime = SystemClock.elapsedRealtime()
            try {
                val keyCode = when (command.lowercase()) {
                    "next", "skip" -> KeyEvent.KEYCODE_MEDIA_NEXT
                    "previous", "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                    "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                    "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                    else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                }

                val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, keyCode)
                val eventUp = KeyEvent(KeyEvent.ACTION_UP, keyCode)
                audioManager.dispatchMediaKeyEvent(eventDown)
                audioManager.dispatchMediaKeyEvent(eventUp)

                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "handed_off",
                        "action" to "media_control",
                        "previousValue" to null,
                        "targetValue" to command,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to null,
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                val latencyMs = SystemClock.elapsedRealtime() - startTime
                result.success(
                    mapOf(
                        "status" to "error",
                        "action" to "media_control",
                        "previousValue" to null,
                        "targetValue" to null,
                        "executionLatencyMs" to latencyMs,
                        "errorCode" to "MEDIA_CONTROL_FAILED",
                        "errorMessage" to (e.message ?: "Failed to dispatch media key event.")
                    )
                )
            }
        }
    }

    private fun handleCanScheduleExactAlarms(result: MethodChannel.Result) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canSchedule = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
        result.success(canSchedule)
    }

    private fun handleOpenExactAlarmSettings(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:${context.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                }
                result.success(mapOf("status" to "success", "action" to "open_exact_alarm_settings"))
            } catch (e: Exception) {
                result.success(mapOf("status" to "error", "errorMessage" to e.message))
            }
        }
    }

    private fun handleScheduleExactAlarm(call: MethodCall, result: MethodChannel.Result) {
        val occurrenceId = call.argument<String>("occurrenceId") ?: ""
        val epochMs = (call.argument<Number>("epochMs"))?.toLong() ?: 0L
        val name = call.argument<String>("name") ?: "Routine"

        if (occurrenceId.isEmpty() || epochMs <= 0) {
            result.success(
                mapOf(
                    "status" to "error",
                    "action" to "schedule_exact_alarm",
                    "errorCode" to "INVALID_ARGUMENTS",
                    "errorMessage" to "Valid occurrenceId and future epochMs required"
                )
            )
            return
        }

        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "triage.routine.ALARM_TRIGGER"
                putExtra("occurrenceId", occurrenceId)
                putExtra("name", name)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(context, occurrenceId.hashCode(), intent, flags)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, epochMs, pendingIntent)
            }

            result.success(
                mapOf(
                    "status" to "success",
                    "action" to "schedule_exact_alarm",
                    "targetValue" to epochMs,
                    "executionLatencyMs" to 5
                )
            )
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "status" to "error",
                    "action" to "schedule_exact_alarm",
                    "errorCode" to "ALARM_SCHEDULE_FAILED",
                    "errorMessage" to (e.message ?: "Failed to schedule exact alarm")
                )
            )
        }
    }

    private fun handleCancelExactAlarm(call: MethodCall, result: MethodChannel.Result) {
        val occurrenceId = call.argument<String>("occurrenceId") ?: ""
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "triage.routine.ALARM_TRIGGER"
                putExtra("occurrenceId", occurrenceId)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            val pendingIntent = PendingIntent.getActivity(context, occurrenceId.hashCode(), intent, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
            result.success(mapOf("status" to "success", "action" to "cancel_exact_alarm"))
        } catch (e: Exception) {
            result.success(mapOf("status" to "error", "errorMessage" to e.message))
        }
    }

    private fun handleCheckCapabilities(result: MethodChannel.Result) {
        mainHandler.post {
            val canWriteSettings = Settings.System.canWrite(context)
            val isDndAccessGranted = notificationManager.isNotificationPolicyAccessGranted
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                alarmManager.canScheduleExactAlarms()
            } else {
                true
            }
            result.success(
                mapOf(
                    "canWriteSettings" to canWriteSettings,
                    "isNotificationPolicyAccessGranted" to isDndAccessGranted,
                    "canScheduleExactAlarms" to canScheduleExact
                )
            )
        }
    }

    private var pendingAlarmTrigger: Map<String, String>? = null

    private fun handleGetPendingAlarmTrigger(result: MethodChannel.Result) {
        val pending = pendingAlarmTrigger
        pendingAlarmTrigger = null
        result.success(pending)
    }

    // --- Shake Detection & Haptic Feedback ---
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var isShakeDetectionActive = false
    private var lastShakeTimestamp: Long = 0L
    private var pendingBackgroundShake = false
    private val SHAKE_THRESHOLD = 14.5f // m/s^2 above gravity
    private val SHAKE_COOLDOWN_MS = 1200L

    private fun handleStartShakeDetection(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (sensorManager == null) {
                    sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                    accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                }
                if (accelerometer != null && !isShakeDetectionActive) {
                    sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
                    isShakeDetectionActive = true
                }
                result.success(mapOf("status" to "success", "active" to isShakeDetectionActive))
            } catch (e: Exception) {
                result.success(mapOf("status" to "error", "errorMessage" to e.message))
            }
        }
    }

    private fun handleStopShakeDetection(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (isShakeDetectionActive) {
                    sensorManager?.unregisterListener(this)
                    isShakeDetectionActive = false
                }
                result.success(mapOf("status" to "success", "active" to false))
            } catch (e: Exception) {
                result.success(mapOf("status" to "error", "errorMessage" to e.message))
            }
        }
    }

    private fun handleSetBackgroundShakeEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        try {
            context.getSharedPreferences("triage_settings", Context.MODE_PRIVATE)
                .edit().putBoolean("background_shake_enabled", enabled).apply()
            val intent = Intent(context, BackgroundShakeService::class.java).apply {
                action = if (enabled) BackgroundShakeService.ACTION_START
                else BackgroundShakeService.ACTION_STOP
            }
            if (enabled) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
                else context.startService(intent)
            } else {
                context.startService(intent)
            }
            result.success(true)
        } catch (error: Exception) {
            context.getSharedPreferences("triage_settings", Context.MODE_PRIVATE)
                .edit().putBoolean("background_shake_enabled", false).apply()
            result.success(false)
        }
    }

    fun handleBackgroundShakeIntent(intent: Intent?) {
        if (intent?.action != BackgroundShakeService.ACTION_OPEN_ASSIST_FROM_SHAKE) return
        pendingBackgroundShake = true
        mainHandler.post {
            methodChannel.invokeMethod("onBackgroundShakeLaunch", null)
        }
    }

    private fun handleGetPendingBackgroundShake(result: MethodChannel.Result) {
        val pending = pendingBackgroundShake
        pendingBackgroundShake = false
        result.success(pending)
    }

    private fun handleTriggerHapticFeedback(call: MethodCall, result: MethodChannel.Result) {
        val type = call.argument<String>("type") ?: "medium"
        performHaptic(type)
        result.success(true)
    }

    fun performHaptic(type: String = "medium") {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                val vibrator = vibratorManager?.defaultVibrator
                when (type) {
                    "heavy" -> vibrator?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK))
                    "double" -> vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 40, 80, 50), -1))
                    else -> vibrator?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK))
                }
            } else {
                @Suppress("DEPRECATION")
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val effect = if (type == "heavy") VibrationEffect.DEFAULT_AMPLITUDE else 120
                    vibrator?.vibrate(VibrationEffect.createOneShot(50, effect))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(50)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        val gX = x / SensorManager.GRAVITY_EARTH
        val gY = y / SensorManager.GRAVITY_EARTH
        val gZ = z / SensorManager.GRAVITY_EARTH
        val gForce = sqrt((gX * gX + gY * gY + gZ * gZ).toDouble()).toFloat()

        if (gForce > 2.2f) { // ~2.2G peak force
            val now = SystemClock.elapsedRealtime()
            if (now - lastShakeTimestamp > SHAKE_COOLDOWN_MS) {
                if (!AssistantTriggerGate.consume(now)) return
                lastShakeTimestamp = now
                performHaptic("heavy")
                mainHandler.post {
                    methodChannel.invokeMethod("onDeviceShaken", mapOf("gForce" to gForce, "timestamp" to now))
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun onPause() {
        if (isShakeDetectionActive) {
            sensorManager?.unregisterListener(this)
        }
    }

    fun onResume() {
        if (isShakeDetectionActive && accelerometer != null) {
            sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
        }
    }

    fun onDestroy() {
        if (sensorManager != null) {
            sensorManager?.unregisterListener(this)
            sensorManager = null
        }
    }

    fun handleAlarmIntent(intent: Intent?) {
        if (intent?.action == "triage.routine.ALARM_TRIGGER") {
            val occurrenceId = intent.getStringExtra("occurrenceId") ?: ""
            val name = intent.getStringExtra("name") ?: ""
            if (occurrenceId.isNotEmpty()) {
                val payload = mapOf(
                    "occurrenceId" to occurrenceId,
                    "name" to name
                )
                pendingAlarmTrigger = payload
                mainHandler.post {
                    methodChannel.invokeMethod("onAlarmTriggered", payload)
                }
            }
        }
    }
}
