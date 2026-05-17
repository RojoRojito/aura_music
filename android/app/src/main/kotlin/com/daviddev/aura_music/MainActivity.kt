package com.daviddev.aura_music

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.daviddev.aura/equalizer"
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSession" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        initEffects(sessionId)
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            equalizer?.enabled = enabled
                            bassBoost?.enabled = enabled
                            virtualizer?.enabled = enabled
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("EQ", "setEnabled error", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setBandGain" -> {
                        val bandIndex = call.argument<Int>("bandIndex") ?: 0
                        val gainDb = call.argument<Double>("gainDb") ?: 0.0
                        try {
                            equalizer?.let {
                                // Android Equalizer uses millibels (1 dB = 100 mB)
                                val levelMb = (gainDb * 100).toInt().toShort()
                                it.setBandLevel(bandIndex.toShort(), levelMb)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("EQ", "setBandGain error", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setBassBoost" -> {
                        val gainDb = call.argument<Double>("gainDb") ?: 0.0
                        try {
                            // Android BassBoost strength: 0-1000, maps from 0-15 dB
                            val strength = ((gainDb / 15.0) * 1000).toInt().coerceIn(0, 1000)
                            bassBoost?.setStrength(strength.toShort())
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("EQ", "setBassBoost error", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setVirtualizer" -> {
                        val strength = call.argument<Double>("strength") ?: 0.0
                        try {
                            // Android Virtualizer strength: 0-1000, maps from 0.0-1.0
                            val strengthInt = (strength * 1000).toInt().coerceIn(0, 1000)
                            virtualizer?.setStrength(strengthInt.toShort())
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("EQ", "setVirtualizer error", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initEffects(sessionId: Int) {
        try {
            // Release previous instances
            equalizer?.release()
            bassBoost?.release()
            virtualizer?.release()

            // Priority 0 = global session effects
            equalizer = Equalizer(0, sessionId)
            bassBoost = BassBoost(0, sessionId)
            virtualizer = Virtualizer(0, sessionId)

            Log.i("EQ", "Effects initialized for sessionId=$sessionId")
        } catch (e: Exception) {
            Log.e("EQ", "initEffects error for sessionId=$sessionId", e)
        }
    }

    override fun onDestroy() {
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        super.onDestroy()
    }
}
