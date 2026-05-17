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
    private val TAG = "AURA_EQ"
    private val PRIORITY = 1

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId: Int = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "configureFlutterEngine called")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSession" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        Log.i(TAG, ">> initSession: sessionId=$sessionId (current=$currentSessionId)")
                        if (sessionId == 0) {
                            Log.w(TAG, "initSession: sessionId=0, skipping (invalid)")
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        initEffects(sessionId)
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        Log.i(TAG, ">> setEnabled: $enabled (eq=${equalizer != null}, bb=${bassBoost != null}, virt=${virtualizer != null})")
                        try {
                            equalizer?.let {
                                it.enabled = enabled
                                Log.d(TAG, "  Equalizer.enabled = ${it.enabled}")
                            } ?: Log.w(TAG, "  Equalizer is null, skipping")
                            bassBoost?.let {
                                it.enabled = enabled
                                Log.d(TAG, "  BassBoost.enabled = ${it.enabled}")
                            } ?: Log.w(TAG, "  BassBoost is null, skipping")
                            virtualizer?.let {
                                it.enabled = enabled
                                Log.d(TAG, "  Virtualizer.enabled = ${it.enabled}")
                            } ?: Log.w(TAG, "  Virtualizer is null, skipping")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setEnabled ERROR", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setBandGain" -> {
                        val bandIndex = call.argument<Int>("bandIndex") ?: 0
                        val gainDb = call.argument<Double>("gainDb") ?: 0.0
                        try {
                            equalizer?.let {
                                val levelMb = (gainDb * 100).toInt().toShort()
                                it.setBandLevel(bandIndex.toShort(), levelMb)
                                Log.d(TAG, ">> setBandGain: band=$bandIndex, gainDb=$gainDb, levelMb=$levelMb")
                            } ?: Log.w(TAG, ">> setBandGain: Equalizer is null, skipping")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setBandGain ERROR: band=$bandIndex, gainDb=$gainDb", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setBassBoost" -> {
                        val gainDb = call.argument<Double>("gainDb") ?: 0.0
                        try {
                            bassBoost?.let {
                                if (it.strengthSupported) {
                                    val strength = ((gainDb / 15.0) * 1000).toInt().coerceIn(0, 1000)
                                    it.setStrength(strength.toShort())
                                    Log.d(TAG, ">> setBassBoost: gainDb=$gainDb, strength=$strength")
                                } else {
                                    Log.w(TAG, ">> setBassBoost: strengthSupported=false, skipping")
                                }
                            } ?: Log.w(TAG, ">> setBassBoost: BassBoost is null, skipping")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setBassBoost ERROR: gainDb=$gainDb", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setVirtualizer" -> {
                        val strength = call.argument<Double>("strength") ?: 0.0
                        try {
                            virtualizer?.let {
                                if (it.strengthSupported) {
                                    val strengthInt = (strength * 1000).toInt().coerceIn(0, 1000)
                                    it.setStrength(strengthInt.toShort())
                                    Log.d(TAG, ">> setVirtualizer: strength=$strength, int=$strengthInt")
                                } else {
                                    Log.w(TAG, ">> setVirtualizer: strengthSupported=false, skipping")
                                }
                            } ?: Log.w(TAG, ">> setVirtualizer: Virtualizer is null, skipping")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setVirtualizer ERROR: strength=$strength", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    else -> {
                        Log.w(TAG, "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
    }

    private fun initEffects(sessionId: Int) {
        Log.i(TAG, "initEffects: sessionId=$sessionId (previous=$currentSessionId)")

        // Release previous instances
        releaseEffects()

        try {
            equalizer = Equalizer(PRIORITY, sessionId).apply {
                enabled = true
            }
            Log.i(TAG, "  Equalizer created: bands=${equalizer!!.numberOfBands}, enabled=${equalizer!!.enabled}, range=${equalizer!!.bandLevelRange[0]}..${equalizer!!.bandLevelRange[1]}")
        } catch (e: Exception) {
            Log.e(TAG, "  Equalizer FAILED for sessionId=$sessionId", e)
            equalizer = null
        }

        try {
            bassBoost = BassBoost(PRIORITY, sessionId).apply {
                enabled = true
            }
            Log.i(TAG, "  BassBoost created: strengthSupported=${bassBoost!!.strengthSupported}, enabled=${bassBoost!!.enabled}")
        } catch (e: Exception) {
            Log.w(TAG, "  BassBoost not supported for sessionId=$sessionId: ${e.message}")
            bassBoost = null
        }

        try {
            virtualizer = Virtualizer(PRIORITY, sessionId).apply {
                enabled = true
            }
            Log.i(TAG, "  Virtualizer created: strengthSupported=${virtualizer!!.strengthSupported}, enabled=${virtualizer!!.enabled}")
        } catch (e: Exception) {
            Log.w(TAG, "  Virtualizer not supported for sessionId=$sessionId: ${e.message}")
            virtualizer = null
        }

        currentSessionId = sessionId
        Log.i(TAG, "initEffects complete: eq=${equalizer != null}, bb=${bassBoost != null}, virt=${virtualizer != null}")
    }

    private fun releaseEffects() {
        try {
            equalizer?.let {
                Log.d(TAG, "Releasing Equalizer (session=$currentSessionId)")
                it.release()
            }
            bassBoost?.let {
                Log.d(TAG, "Releasing BassBoost (session=$currentSessionId)")
                it.release()
            }
            virtualizer?.let {
                Log.d(TAG, "Releasing Virtualizer (session=$currentSessionId)")
                it.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing effects", e)
        }
        equalizer = null
        bassBoost = null
        virtualizer = null
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy: releasing effects (session=$currentSessionId)")
        releaseEffects()
        currentSessionId = -1
        super.onDestroy()
    }
}
