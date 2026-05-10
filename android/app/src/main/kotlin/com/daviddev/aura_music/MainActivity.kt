package com.daviddev.aura_music

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCallHandler

class MainActivity: FlutterActivity(), MethodCallHandler {
    private val TAG = "AuraEQ"
    private val channelName = "com.daviddev.aura/equalizer"
    private lateinit var equalizerEngine: EqualizerEngine
    private lateinit var methodChannel: MethodChannel
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId = -1
    private var isEnabled = true
    private var currentBassBoostGain = 0f
    private var currentVirtualizerStrength = 0f
    private val currentBandGains = FloatArray(12) { 0f }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d(TAG, "configureFlutterEngine: initializing DSP engine")
        
        equalizerEngine = EqualizerEngine()
        
        Log.d(TAG, "DSP engine ready")
        
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel.setMethodCallHandler(this)
        Log.d(TAG, "MethodChannel registered: $channelName")
        
        android.os.Handler(android.os.Looper.getMainLooper())
            .postDelayed({
                if (currentSessionId == -1) {
                    Log.w(TAG, "No session ID received from Dart after 3s, trying session 0")
                    initAudioEffects(0)
                }
            }, 3000)
    }

    private fun initAudioEffects(sessionId: Int) {
        if (sessionId == currentSessionId) {
            Log.d(TAG, "Session ID unchanged ($sessionId), skipping re-init")
            return
        }
        currentSessionId = sessionId
        Log.d(TAG, "initAudioEffects($sessionId)")
        
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        
        equalizer = Equalizer(0, sessionId).apply { enabled = isEnabled }
        bassBoost = BassBoost(0, sessionId).apply { enabled = isEnabled }
        virtualizer = Virtualizer(0, sessionId).apply { enabled = isEnabled }
        
        Log.d(TAG, "Equalizer created: numBands=${equalizer?.numberOfBands}")
        Log.d(TAG, "Equalizer enabled=${equalizer?.enabled}")
        Log.d(TAG, "BassBoost enabled=${bassBoost?.enabled}")
        Log.d(TAG, "Virtualizer enabled=${virtualizer?.enabled}")
        val range = equalizer?.bandLevelRange
        Log.d(TAG, "Band level range: ${range?.get(0)} to ${range?.get(1)} millibels")
        
        for (i in 0 until 12) {
            applyBandGain(i, currentBandGains[i])
        }
        applyBassBoost(currentBassBoostGain)
        applyVirtualizer(currentVirtualizerStrength)
        
        Log.d(TAG, "Effects initialized for session $sessionId")
    }

    private fun applyBandGain(bandIndex: Int, gainDb: Float) {
        currentBandGains[bandIndex] = gainDb
        equalizer?.let { eq ->
            try {
                val numBands = eq.numberOfBands.toInt()
                val bandRange = eq.bandLevelRange
                val minLevel = bandRange[0].toFloat()
                val maxLevel = bandRange[1].toFloat()
                val millibels = ((gainDb / 12f) * (maxLevel - minLevel) / 2f).toInt().toShort()
                val deviceBands = numBands
                val deviceBand = (bandIndex * deviceBands / 12).coerceIn(0, deviceBands - 1)
                eq.setBandLevel(deviceBand.toShort(), millibels)
                Log.d(TAG, "applyBandGain: band=$deviceBand level=$millibels millibels (de ${gainDb}dB)")
            } catch (e: Exception) {
                Log.e(TAG, "setBandLevel error: $e")
            }
        }
    }

    private fun applyBassBoost(gainDb: Float) {
        currentBassBoostGain = gainDb
        bassBoost?.let { bb ->
            try {
                val strength = ((gainDb / 15f) * 1000f).toInt().coerceIn(0, 1000).toShort()
                bb.setStrength(strength)
            } catch (e: Exception) {
                Log.e(TAG, "BassBoost error: $e")
            }
        }
    }

    private fun applyVirtualizer(strength: Float) {
        currentVirtualizerStrength = strength
        virtualizer?.let { virt ->
            try {
                val s = (strength * 1000f).toInt().coerceIn(0, 1000).toShort()
                virt.setStrength(s)
            } catch (e: Exception) {
                Log.e(TAG, "Virtualizer error: $e")
            }
        }
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method} args=${call.arguments}")
        when (call.method) {
            "initSession" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                initAudioEffects(sessionId)
                result.success(null)
            }
            "setBandGain" -> {
                val bandIndex = call.argument<Int>("bandIndex") ?: 0
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                applyBandGain(bandIndex, gainDb.toFloat())
                equalizerEngine.setBandGain(bandIndex, gainDb.toFloat())
                Log.d(TAG, "setBandGain[$bandIndex] = $gainDb dB")
                result.success(null)
            }
            "setBassBoost" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                applyBassBoost(gainDb.toFloat())
                equalizerEngine.setBassBoost(gainDb.toFloat())
                Log.d(TAG, "setBassBoost = $gainDb dB")
                result.success(null)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Double>("strength") ?: 0.0
                applyVirtualizer(strength.toFloat())
                equalizerEngine.setVirtualizerStrength(strength.toFloat())
                Log.d(TAG, "setVirtualizer = $strength")
                result.success(null)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                isEnabled = enabled
                equalizer?.enabled = enabled
                bassBoost?.enabled = enabled
                virtualizer?.enabled = enabled
                equalizerEngine.setEnabled(enabled)
                Log.d(TAG, "setEnabled = $enabled")
                result.success(null)
            }
            "reset" -> {
                currentBandGains.fill(0f)
                currentBassBoostGain = 0f
                currentVirtualizerStrength = 0f
                equalizer?.let { eq ->
                    for (i in 0 until eq.numberOfBands) {
                        try { eq.setBandLevel(i.toShort(), 0) } catch (e: Exception) { }
                    }
                }
                bassBoost?.setStrength(0)
                virtualizer?.setStrength(0)
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

    override fun onDestroy() {
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        super.onDestroy()
    }
}