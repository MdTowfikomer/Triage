package app.triage.mobile

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Plays Gemini Live's 24 kHz mono PCM in memory; no audio is written to disk. */
class LiveAudioBridge(messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private var track: AudioTrack? = null
    @Volatile private var playbackGeneration = 0

    init {
        MethodChannel(messenger, "triage.live_audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "playPcm" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) { result.error("invalid_audio", "PCM bytes required", null); return@setMethodCallHandler }
                    val generation = playbackGeneration
                    worker.execute {
                        if (generation != playbackGeneration) return@execute
                        try {
                            val player = track ?: createTrack().also { track = it; it.play() }
                            player.write(bytes, 0, bytes.size)
                        } catch (_: Exception) { stopPlayback() }
                    }
                    result.success(null)
                }
                "stop" -> {
                    playbackGeneration++
                    stopPlayback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createTrack(): AudioTrack {
        val buffer = AudioTrack.getMinBufferSize(24000, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
        return AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(24000).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(maxOf(buffer, 4800))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
    }

    private fun stopPlayback() {
        try { track?.pause(); track?.flush(); track?.release() } catch (_: Exception) { }
        track = null
    }
}
