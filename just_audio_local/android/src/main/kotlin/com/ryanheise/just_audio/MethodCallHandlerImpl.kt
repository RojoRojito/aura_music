package com.ryanheise.just_audio

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.android.exoplayer2.DefaultRenderersFactory
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.audio.AudioProcessor
import com.google.android.exoplayer2.audio.DefaultAudioSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MethodCallHandlerImpl(
    private val context: Context,
    private val player: ExoPlayer
) : MethodCallHandler {

    companion object {
        var externalAudioProcessor: AudioProcessor? = null
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "play" -> {
                player.play()
                result.success(null)
            }
            "pause" -> {
                player.pause()
                result.success(null)
            }
            "stop" -> {
                player.stop()
                result.success(null)
            }
            "seek" -> {
                val position = call.argument<Double>("position")?.toLong() ?: 0L
                player.seekTo(position)
                result.success(null)
            }
            "setUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    // In a real implementation, this would set the audio source
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL is null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        executor.shutdown()
    }
}