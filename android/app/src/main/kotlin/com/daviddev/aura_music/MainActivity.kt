package com.daviddev.aura_music

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCallHandler

class MainActivity: FlutterActivity(), MethodCallHandler {
    private val TAG = "AuraEQ"
    private val channelName = "com.daviddev.aura/equalizer"
    private lateinit var equalizerEngine: EqualizerEngine
    private lateinit var audioProcessor: AuraAudioProcessor
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d(TAG, "configureFlutterEngine: initializing DSP engine")
        
        equalizerEngine = EqualizerEngine()
        audioProcessor = AuraAudioProcessor(equalizerEngine)
        
        Log.d(TAG, "DSP engine ready. AudioProcessor hash: ${audioProcessor.hashCode()}")
        
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel.setMethodCallHandler(this)
        Log.d(TAG, "MethodChannel registered: $channelName")
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method} args=${call.arguments}")
        when (call.method) {
            "setBandGain" -> {
                val bandIndex = call.argument<Int>("bandIndex") ?: 0
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                equalizerEngine.setBandGain(bandIndex, gainDb.toFloat())
                Log.d(TAG, "setBandGain[$bandIndex] = $gainDb dB, isEnabled=${equalizerEngine.isEnabled()}")
                result.success(null)
            }
            "setBassBoost" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                equalizerEngine.setBassBoost(gainDb.toFloat())
                Log.d(TAG, "setBassBoost = $gainDb dB")
                result.success(null)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Double>("strength") ?: 0.0
                equalizerEngine.setVirtualizerStrength(strength.toFloat())
                Log.d(TAG, "setVirtualizer = $strength")
                result.success(null)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                equalizerEngine.setEnabled(enabled)
                Log.d(TAG, "setEnabled = $enabled")
                result.success(null)
            }
            "reset" -> {
                equalizerEngine.reset()
                Log.d(TAG, "reset")
                result.success(null)
            }
            "getState" -> {
                val state = mapOf(
                    "enabled" to equalizerEngine.isEnabled(),
                    "bandCount" to 12,
                    "bandFrequencies" to listOf(31,62,125,250,500,1000,2000,4000,8000,12000,16000,20000)
                )
                Log.d(TAG, "getState: $state")
                result.success(state)
            }
            else -> {
                Log.w(TAG, "notImplemented: ${call.method}")
                result.notImplemented()
            }
        }
    }
}