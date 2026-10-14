package app.triage.mobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class OfflineVoiceBridge(
    private val context: Context,
    binaryMessenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val methodChannel = MethodChannel(binaryMessenger, "triage.offline_voice")
    private val eventChannel = EventChannel(binaryMessenger, "triage.offline_voice_events")

    private val mainHandler = Handler(Looper.getMainLooper())

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var speechStartTime: Long = 0L
    private var speechEndTime: Long = 0L
    private var activeSpeechResultCallback: MethodChannel.Result? = null
    private var currentSpeechSessionId: Long = 0L

    private var tts: TextToSpeech? = null
    private var isTtsInitialized = false
    private var selectedOfflineVoice: Voice? = null
    private var activeTtsResultCallback: MethodChannel.Result? = null
    private var ttsSpeakStartTime: Long = 0L
    private var ttsStartLatencyMs: Long = 0L
    private var currentUtteranceId: String? = null
    private var currentTtsSessionId: Long = 0L

    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        ensureTts()
    }

    private fun ensureTts(onReady: (() -> Unit)? = null) {
        if (tts != null && isTtsInitialized) {
            if (selectedOfflineVoice == null) {
                configureOfflineVoice()
            }
            onReady?.invoke()
            return
        }

        initializeTts(onReady)
    }

    private fun initializeTts(onReady: (() -> Unit)? = null) {
        tts?.stop()
        tts?.shutdown()
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isTtsInitialized = true
                configureOfflineVoice()
                onReady?.invoke()
            } else {
                isTtsInitialized = false
                selectedOfflineVoice = null
            }
        }

        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                if (utteranceId == null || utteranceId != currentUtteranceId) return
                val now = SystemClock.elapsedRealtime()
                ttsStartLatencyMs = now - ttsSpeakStartTime
                mainHandler.post {
                    if (utteranceId != currentUtteranceId) return@post
                    eventSink?.success(
                        mapOf(
                            "event" to "tts_start",
                            "startLatencyMs" to ttsStartLatencyMs
                        )
                    )
                }
            }

            override fun onDone(utteranceId: String?) {
                if (utteranceId == null || utteranceId != currentUtteranceId) return
                val now = SystemClock.elapsedRealtime()
                val totalLatency = now - ttsSpeakStartTime
                mainHandler.post {
                    if (utteranceId != currentUtteranceId) return@post
                    currentUtteranceId = null
                    activeTtsResultCallback?.let { callback ->
                        callback.success(
                            mapOf(
                                "status" to "success",
                                "ttsLatencyMs" to totalLatency,
                                "startLatencyMs" to ttsStartLatencyMs,
                                "voice" to (selectedOfflineVoice?.name ?: "default")
                            )
                        )
                        activeTtsResultCallback = null
                    }
                    eventSink?.success(
                        mapOf(
                            "event" to "tts_done",
                            "ttsLatencyMs" to totalLatency,
                            "startLatencyMs" to ttsStartLatencyMs
                        )
                    )
                }
            }

            override fun onStop(utteranceId: String?, interrupted: Boolean) {
                if (utteranceId == null || utteranceId != currentUtteranceId) return
                mainHandler.post {
                    if (utteranceId != currentUtteranceId) return@post
                    currentUtteranceId = null
                    activeTtsResultCallback?.let { callback ->
                        callback.success(
                            mapOf(
                                "status" to "error",
                                "code" to "TTS_INTERRUPTED",
                                "message" to "Speech playback was stopped or interrupted (interrupted: $interrupted)"
                            )
                        )
                        activeTtsResultCallback = null
                    }
                    eventSink?.success(
                        mapOf(
                            "event" to "tts_stopped",
                            "interrupted" to interrupted
                        )
                    )
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                if (utteranceId == null || utteranceId != currentUtteranceId) return
                mainHandler.post {
                    if (utteranceId != currentUtteranceId) return@post
                    currentUtteranceId = null
                    activeTtsResultCallback?.let { callback ->
                        callback.success(
                            mapOf(
                                "status" to "error",
                                "code" to "TTS_SYNTHESIS_FAILED",
                                "message" to "Offline speech synthesis failed"
                            )
                        )
                        activeTtsResultCallback = null
                    }
                    eventSink?.success(
                        mapOf(
                            "event" to "tts_error",
                            "code" to "TTS_SYNTHESIS_FAILED"
                        )
                    )
                }
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                if (utteranceId == null || utteranceId != currentUtteranceId) return
                mainHandler.post {
                    if (utteranceId != currentUtteranceId) return@post
                    currentUtteranceId = null
                    activeTtsResultCallback?.let { callback ->
                        callback.success(
                            mapOf(
                                "status" to "error",
                                "code" to "TTS_ERROR_$errorCode",
                                "message" to "Offline speech synthesis failed with code $errorCode"
                            )
                        )
                        activeTtsResultCallback = null
                    }
                    eventSink?.success(
                        mapOf(
                            "event" to "tts_error",
                            "code" to "TTS_ERROR_$errorCode"
                        )
                    )
                }
            }
        })
    }

    private fun configureOfflineVoice() {
        val currentTts = tts ?: return
        try {
            val voices = currentTts.voices
            if (!voices.isNullOrEmpty()) {
                val defaultLocale = Locale.getDefault()
                val matchingVoice = voices.firstOrNull { voice ->
                    !voice.isNetworkConnectionRequired &&
                        voice.locale.language == defaultLocale.language
                } ?: voices.firstOrNull { voice ->
                    !voice.isNetworkConnectionRequired &&
                        voice.locale.language == Locale.ENGLISH.language
                } ?: voices.firstOrNull { voice ->
                    !voice.isNetworkConnectionRequired
                }

                if (matchingVoice != null) {
                    val setResult = currentTts.setVoice(matchingVoice)
                    if (setResult == TextToSpeech.SUCCESS) {
                        selectedOfflineVoice = matchingVoice
                    } else {
                        selectedOfflineVoice = null
                    }
                } else {
                    val cur = currentTts.voice
                    if (cur != null && !cur.isNetworkConnectionRequired) {
                        selectedOfflineVoice = cur
                    } else {
                        selectedOfflineVoice = null
                    }
                }
            } else {
                val cur = currentTts.voice
                if (cur != null && !cur.isNetworkConnectionRequired) {
                    selectedOfflineVoice = cur
                } else {
                    selectedOfflineVoice = null
                }
            }
        } catch (_: Exception) {
            selectedOfflineVoice = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkCapabilities" -> handleCheckCapabilities(result)
            "startListening" -> handleStartListening(call, result)
            "stopListening" -> handleStopListening(result)
            "cancelListening" -> handleCancelListening(result)
            "speakOffline" -> handleSpeakOffline(call, result)
            "openVoiceInputSettings" -> handleOpenVoiceInputSettings(result)
            "openTtsSettings" -> handleOpenTtsSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun handleCheckCapabilities(result: MethodChannel.Result) {
        if (tts == null || !isTtsInitialized) {
            ensureTts()
        } else if (selectedOfflineVoice == null) {
            configureOfflineVoice()
        }

        val onDeviceSttAvailable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } else {
            false
        }

        val micGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        val offlineVoice = selectedOfflineVoice
        val offlineTtsAvailable = isTtsInitialized && offlineVoice != null && !offlineVoice.isNetworkConnectionRequired

        result.success(
            mapOf(
                "onDeviceRecognitionAvailable" to onDeviceSttAvailable,
                "offlineTtsAvailable" to offlineTtsAvailable,
                "selectedVoiceName" to (offlineVoice?.name ?: "none"),
                "selectedLocale" to (offlineVoice?.locale?.toLanguageTag() ?: Locale.getDefault().toLanguageTag()),
                "micPermissionGranted" to micGranted,
                "apiLevel" to Build.VERSION.SDK_INT
            )
        )
    }

    private fun handleStartListening(call: MethodCall, result: MethodChannel.Result) {
        val micGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!micGranted) {
            result.success(
                mapOf(
                    "status" to "permission_required",
                    "code" to "MIC_PERMISSION_DENIED",
                    "message" to "Microphone permission is required for speech recognition."
                )
            )
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                result.success(
                    mapOf(
                        "status" to "unsupported",
                        "code" to "ON_DEVICE_RECOGNITION_UNAVAILABLE",
                        "message" to "On-device speech recognition is not available on this device."
                    )
                )
                return
            }
        }

        // Concurrency fix: invalidate old session and supersede prior callback
        currentSpeechSessionId++
        val sessionId = currentSpeechSessionId

        if (isListening || activeSpeechResultCallback != null) {
            val supersededCb = activeSpeechResultCallback
            activeSpeechResultCallback = null
            isListening = false
            try {
                speechRecognizer?.cancel()
                speechRecognizer?.destroy()
            } catch (_: Exception) {}
            speechRecognizer = null

            supersededCb?.let { cb ->
                mainHandler.post {
                    cb.success(
                        mapOf(
                            "status" to "error",
                            "code" to "RECOGNITION_SUPERSEDED",
                            "message" to "Speech recognition was superseded by a new request."
                        )
                    )
                }
            }
        }

        activeSpeechResultCallback = result
        isListening = true
        speechStartTime = 0L
        speechEndTime = 0L

        mainHandler.post {
            // Guard in case another request arrived while posting
            if (sessionId != currentSpeechSessionId) return@post

            try {
                val recognizer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }
                speechRecognizer = recognizer

                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        if (sessionId != currentSpeechSessionId) return
                        eventSink?.success(mapOf("event" to "ready_for_speech"))
                    }

                    override fun onBeginningOfSpeech() {
                        if (sessionId != currentSpeechSessionId) return
                        speechStartTime = SystemClock.elapsedRealtime()
                        eventSink?.success(mapOf("event" to "beginning_of_speech"))
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        if (sessionId != currentSpeechSessionId) return
                        eventSink?.success(
                            mapOf(
                                "event" to "rms_changed",
                                "rms" to rmsdB
                            )
                        )
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        if (sessionId != currentSpeechSessionId) return
                        speechEndTime = SystemClock.elapsedRealtime()
                        eventSink?.success(mapOf("event" to "end_of_speech"))
                    }

                    override fun onError(error: Int) {
                        if (sessionId != currentSpeechSessionId) return
                        isListening = false
                        val errorCode = mapErrorCode(error)
                        val status = if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                            "permission_required"
                        } else {
                            "error"
                        }

                        val payload = mapOf(
                            "status" to status,
                            "code" to errorCode,
                            "message" to "Recognition failed with error code $error ($errorCode)"
                        )

                        activeSpeechResultCallback?.let { callback ->
                            callback.success(payload)
                            activeSpeechResultCallback = null
                        }
                        eventSink?.success(mapOf("event" to "speech_error", "payload" to payload))
                        destroyRecognizerInternal()
                    }

                    override fun onResults(results: Bundle?) {
                        if (sessionId != currentSpeechSessionId) return
                        isListening = false
                        val emitTime = SystemClock.elapsedRealtime()
                        val sttLatency = if (speechEndTime > 0L) {
                            emitTime - speechEndTime
                        } else if (speechStartTime > 0L) {
                            emitTime - speechStartTime
                        } else {
                            0L
                        }

                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val payload = mapOf(
                                "status" to "success",
                                "transcript" to matches[0],
                                "alternatives" to matches,
                                "sttLatencyMs" to sttLatency
                            )
                            activeSpeechResultCallback?.let { callback ->
                                callback.success(payload)
                                activeSpeechResultCallback = null
                            }
                            eventSink?.success(mapOf("event" to "speech_result", "payload" to payload))
                        } else {
                            val payload = mapOf(
                                "status" to "error",
                                "code" to "NO_SPEECH_RECOGNIZED",
                                "message" to "No speech detected in audio stream."
                            )
                            activeSpeechResultCallback?.let { callback ->
                                callback.success(payload)
                                activeSpeechResultCallback = null
                            }
                        }
                        destroyRecognizerInternal()
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        if (sessionId != currentSpeechSessionId) return
                        val partials = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!partials.isNullOrEmpty()) {
                            eventSink?.success(
                                mapOf(
                                    "event" to "partial_result",
                                    "text" to partials[0]
                                )
                            )
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                }

                recognizer.startListening(intent)
            } catch (e: Exception) {
                if (sessionId != currentSpeechSessionId) return@post
                isListening = false
                val payload = mapOf(
                    "status" to "error",
                    "code" to "RECOGNITION_INIT_FAILED",
                    "message" to (e.message ?: "Failed to start on-device speech recognizer")
                )
                activeSpeechResultCallback?.let { callback ->
                    callback.success(payload)
                    activeSpeechResultCallback = null
                }
                destroyRecognizerInternal()
            }
        }
    }

    private fun handleStopListening(result: MethodChannel.Result) {
        if (!isListening) {
            result.success(true)
            return
        }
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    private fun handleCancelListening(result: MethodChannel.Result) {
        cancelRecognitionInternal()
        result.success(true)
    }

    private fun handleSpeakOffline(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
        if (text.isNullOrBlank()) {
            result.success(
                mapOf(
                    "status" to "error",
                    "code" to "EMPTY_TEXT",
                    "message" to "Spoken text cannot be empty"
                )
            )
            return
        }

        val currentTts = tts
        if (!isTtsInitialized || currentTts == null) {
            result.success(
                mapOf(
                    "status" to "error",
                    "code" to "TTS_NOT_INITIALIZED",
                    "message" to "TextToSpeech engine is not initialized"
                )
            )
            return
        }

        val verifiedOfflineVoice = selectedOfflineVoice
        if (verifiedOfflineVoice == null || verifiedOfflineVoice.isNetworkConnectionRequired) {
            result.success(
                mapOf(
                    "status" to "error",
                    "code" to "NO_OFFLINE_TTS_VOICE",
                    "message" to "No verified offline TTS voice is available. Open TTS settings to install offline voice data."
                )
            )
            return
        }

        // Concurrency fix: supersede prior TTS callback and invalidate older utterance
        if (activeTtsResultCallback != null) {
            val supersededTts = activeTtsResultCallback
            activeTtsResultCallback = null
            supersededTts?.let { cb ->
                mainHandler.post {
                    cb.success(
                        mapOf(
                            "status" to "error",
                            "code" to "TTS_SUPERSEDED",
                            "message" to "TTS was superseded by a newer utterance request."
                        )
                    )
                }
            }
        }

        currentTtsSessionId++
        val utteranceId = "triage_tts_${currentTtsSessionId}_${SystemClock.elapsedRealtime()}"
        currentUtteranceId = utteranceId

        activeTtsResultCallback = result
        ttsSpeakStartTime = SystemClock.elapsedRealtime()
        ttsStartLatencyMs = 0L

        mainHandler.post {
            if (utteranceId != currentUtteranceId) return@post
            try {
                val speakStatus = currentTts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                if (speakStatus != TextToSpeech.SUCCESS) {
                    if (utteranceId != currentUtteranceId) return@post
                    currentUtteranceId = null
                    activeTtsResultCallback?.let { callback ->
                        callback.success(
                            mapOf(
                                "status" to "error",
                                "code" to "TTS_SPEAK_FAILED",
                                "message" to "TextToSpeech.speak failed with status code $speakStatus"
                            )
                        )
                        activeTtsResultCallback = null
                    }
                    eventSink?.success(
                        mapOf(
                            "event" to "tts_error",
                            "code" to "TTS_SPEAK_FAILED"
                        )
                    )
                }
            } catch (e: Exception) {
                if (utteranceId != currentUtteranceId) return@post
                currentUtteranceId = null
                activeTtsResultCallback?.let { callback ->
                    callback.success(
                        mapOf(
                            "status" to "error",
                            "code" to "TTS_INVOCATION_FAILED",
                            "message" to (e.message ?: "Failed to invoke TTS speak")
                        )
                    )
                    activeTtsResultCallback = null
                }
                eventSink?.success(
                    mapOf(
                        "event" to "tts_error",
                        "code" to "TTS_INVOCATION_FAILED"
                    )
                )
            }
        }
    }

    private fun handleOpenVoiceInputSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            try {
                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallback)
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    private fun handleOpenTtsSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent("com.android.settings.TTS_SETTINGS").apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            try {
                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallback)
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    private fun cancelRecognitionInternal(
        errorCode: String = "RECOGNITION_CANCELLED",
        message: String = "Speech recognition was cancelled"
    ) {
        currentSpeechSessionId++
        isListening = false
        val pendingCallback = activeSpeechResultCallback
        activeSpeechResultCallback = null
        mainHandler.post {
            try {
                speechRecognizer?.cancel()
            } catch (_: Exception) {}
            destroyRecognizerInternal()
            pendingCallback?.let { callback ->
                callback.success(
                    mapOf(
                        "status" to "error",
                        "code" to errorCode,
                        "message" to message
                    )
                )
            }
        }
    }

    private fun cancelTtsInternal(
        errorCode: String = "TTS_CANCELLED",
        message: String = "TTS playback was cancelled"
    ) {
        currentUtteranceId = null
        currentTtsSessionId++
        val pendingTts = activeTtsResultCallback
        activeTtsResultCallback = null
        mainHandler.post {
            try {
                tts?.stop()
            } catch (_: Exception) {}
            pendingTts?.let { callback ->
                callback.success(
                    mapOf(
                        "status" to "error",
                        "code" to errorCode,
                        "message" to message
                    )
                )
            }
        }
    }

    private fun destroyRecognizerInternal() {
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
    }

    private fun mapErrorCode(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "ERROR_AUDIO"
        SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
        SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
        SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
        SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "ERROR_LANGUAGE_NOT_SUPPORTED"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "ERROR_LANGUAGE_UNAVAILABLE"
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "ERROR_SERVER_DISCONNECTED"
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "ERROR_TOO_MANY_REQUESTS"
        SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> "ERROR_CANNOT_CHECK_SUPPORT"
        else -> "ERROR_UNKNOWN_$error"
    }

    fun onPause() {
        if (isListening) {
            cancelRecognitionInternal("RECOGNITION_PAUSED", "Recognition stopped because Activity paused")
        }
        cancelTtsInternal("TTS_PAUSED", "TTS playback stopped because Activity paused")
    }

    fun onStop() {
        if (isListening) {
            cancelRecognitionInternal("RECOGNITION_STOPPED", "Recognition stopped because Activity stopped")
        }
        cancelTtsInternal("TTS_STOPPED", "TTS playback stopped because Activity stopped")
    }

    fun onDestroy() {
        cancelRecognitionInternal("RECOGNITION_DESTROYED", "Activity destroyed")
        cancelTtsInternal("TTS_DESTROYED", "Activity destroyed")
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {}
        tts = null
        isTtsInitialized = false
        selectedOfflineVoice = null
    }
}
