package com.daviddev.aura_music

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.daviddev.aura/equalizer"
    private val TAG = "AURA_EQ"
    private val PRIORITY = 1

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId: Int = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "onCreate called — registering MethodChannel")

        val engine = flutterEngine
        if (engine == null) {
            Log.e(TAG, "flutterEngine is NULL in onCreate!")
            return
        }

        Log.i(TAG, "flutterEngine OK, registering channel=$CHANNEL")
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSession" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        Log.i(TAG, ">> initSession: sessionId=$sessionId")
                        if (sessionId == 0) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        initEffects(sessionId)
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        Log.i(TAG, ">> setEnabled: $enabled")
                        try {
                            equalizer?.enabled = enabled
                            bassBoost?.enabled = enabled
                            virtualizer?.enabled = enabled
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
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setBandGain ERROR", e)
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
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setBassBoost ERROR", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setVirtualizer" -> {
                        val strength = call.argument<Double>("strength") ?: 0.0
                        try {
                            virtualizer?.let {
                                if (it.strengthSupported) {
                                    val s = (strength * 1000).toInt().coerceIn(0, 1000)
                                    it.setStrength(s.toShort())
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setVirtualizer ERROR", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        Log.i(TAG, "MethodChannel registered OK")
    }

    private fun initEffects(sessionId: Int) {
        Log.i(TAG, "initEffects: sessionId=$sessionId (previous=$currentSessionId)")
        releaseEffects()

        try {
            equalizer = Equalizer(PRIORITY, sessionId).apply { enabled = true }
            Log.i(TAG, "  Equalizer OK: bands=${equalizer!!.numberOfBands}")
        } catch (e: Exception) {
            Log.e(TAG, "  Equalizer FAILED", e)
            equalizer = null
        }

        try {
            bassBoost = BassBoost(PRIORITY, sessionId).apply { enabled = true }
            Log.i(TAG, "  BassBoost OK: supported=${bassBoost!!.strengthSupported}")
        } catch (e: Exception) {
            Log.w(TAG, "  BassBoost not supported: ${e.message}")
            bassBoost = null
        }

        try {
            virtualizer = Virtualizer(PRIORITY, sessionId).apply { enabled = true }
            Log.i(TAG, "  Virtualizer OK: supported=${virtualizer!!.strengthSupported}")
        } catch (e: Exception) {
            Log.w(TAG, "  Virtualizer not supported: ${e.message}")
            virtualizer = null
        }

        currentSessionId = sessionId
        Log.i(TAG, "initEffects complete: eq=${equalizer != null}, bb=${bassBoost != null}, virt=${virtualizer != null}")
    }

    private fun releaseEffects() {
        try { equalizer?.release() } catch (_: Exception) {}
        try { bassBoost?.release() } catch (_: Exception) {}
        try { virtualizer?.release() } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        releaseEffects()
        super.onDestroy()
    }
}
