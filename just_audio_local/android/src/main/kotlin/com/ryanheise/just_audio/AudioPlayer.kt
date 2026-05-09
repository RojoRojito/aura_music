package com.ryanheise.just_audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.exoplayer2.DefaultRenderersFactory
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.audio.AudioProcessor
import com.google.android.exoplayer2.audio.DefaultAudioSink
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AudioPlayerFactory(private val context: Context) {
    fun create(messenger: BinaryMessenger): AudioPlayer {
        return AudioPlayer(context, messenger)
    }
}

class AudioPlayer(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        var externalAudioProcessor: AudioProcessor? = null
    }

    private var player: ExoPlayer? = null
    private var methodChannel: MethodChannel? = null

    init {
        val renderersFactory = object : DefaultRenderersFactory(context) {
            override fun buildAudioSink(
                context: Context,
                audioAttributes: android.media.AudioAttributes,
                enableFloatOutput: Boolean
            ): DefaultAudioSink {
                val processors = listOfNotNull(externalAudioProcessor)
                return DefaultAudioSink.Builder(context)
                    .setAudioProcessors(processors.toTypedArray())
                    .build()
            }
        }

        player = ExoPlayer.Builder(context)
            .setRenderersFactory(renderersFactory)
            .build()

        methodChannel = MethodChannel(messenger, "com.ryanheise.just_audio")
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                player?.play()
                result.success(null)
            }
            "pause" -> {
                player?.pause()
                result.success(null)
            }
            "stop" -> {
                player?.stop()
                result.success(null)
            }
            "seek" -> {
                val position = call.argument<Double>("position")?.toLong() ?: 0L
                player?.seekTo(position)
                result.success(null)
            }
            "setUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL is null", null)
                }
            }
            "setVolume" -> {
                val volume = call.argument<Double>("volume") ?: 1.0
                player?.volume = volume.toFloat()
                result.success(null)
            }
            "setSpeed" -> {
                val speed = call.argument<Double>("speed") ?: 1.0
                player?.setPlaybackSpeed(speed.toFloat())
                result.success(null)
            }
            "setLoopMode" -> {
                val loopMode = call.argument<Int>("loopMode") ?: 0
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        player?.release()
        player = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}