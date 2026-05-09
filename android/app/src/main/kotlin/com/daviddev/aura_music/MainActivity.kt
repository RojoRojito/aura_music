package com.daviddev.aura_music

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCallHandler
import com.ryanheise.just_audio.AudioPlayer

class MainActivity: FlutterActivity(), MethodCallHandler {
    private val channelName = "com.daviddev.aura/equalizer"
    private lateinit var equalizerEngine: EqualizerEngine
    private lateinit var audioProcessor: AuraAudioProcessor
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        equalizerEngine = EqualizerEngine()
        audioProcessor = AuraAudioProcessor(equalizerEngine)

        AudioPlayer.externalAudioProcessor = audioProcessor

        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        when (call.method) {
            "setBandGain" -> {
                val bandIndex = call.argument<Int>("bandIndex") ?: 0
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                equalizerEngine.setBandGain(bandIndex, gainDb.toFloat())
                result.success(null)
            }
            "setBassBoost" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                equalizerEngine.setBassBoost(gainDb.toFloat())
                result.success(null)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Double>("strength") ?: 0.0
                equalizerEngine.setVirtualizerStrength(strength.toFloat())
                result.success(null)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                equalizerEngine.setEnabled(enabled)
                result.success(null)
            }
            "reset" -> {
                equalizerEngine.reset()
                result.success(null)
            }
            "getState" -> {
                result.success(mapOf(
                    "enabled" to equalizerEngine.isEnabled(),
                    "bandCount" to 12,
                    "bandFrequencies" to listOf(31,62,125,250,500,1000,2000,4000,8000,12000,16000,20000)
                ))
            }
            else -> result.notImplemented()
        }
    }
}