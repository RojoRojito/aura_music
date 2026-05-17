package com.daviddev.aura_music

import android.media.audiofx.BassBoost
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import android.os.Build
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
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var dynamicsProcessing: DynamicsProcessing? = null
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
                    "getBandCount" -> {
                        result.success(equalizer?.numberOfBands?.toInt() ?: 5)
                    }
                    "getBandFrequencies" -> {
                        equalizer?.let {
                            val freqs = mutableListOf<Int>()
                            for (i in 0 until it.numberOfBands) {
                                freqs.add(it.getCenterFreq(i.toShort()) / 1000) // milliHz to Hz
                            }
                            result.success(freqs)
                        } ?: result.success(listOf(60, 230, 910, 3600, 14000))
                    }
                    "setBandGain" -> {
                        val bandIndex = call.argument<Int>("bandIndex") ?: 0
                        val gainDb = call.argument<Double>("gainDb") ?: 0.0
                        try {
                            equalizer?.let {
                                val numBands = it.numberOfBands.toInt()
                                if (bandIndex < 0 || bandIndex >= numBands) {
                                    result.success(null)
                                    return@setMethodCallHandler
                                }
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
                                    val strength = ((gainDb / 15.0) * 600).toInt().coerceIn(0, 600)
                                    Log.i(TAG, "setBassBoost: gainDb=$gainDb → strength=$strength")
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
                                    val s = (strength * 500).toInt().coerceIn(0, 500)
                                    Log.i(TAG, "setVirtualizer: input=$strength → strength=$s")
                                    it.setStrength(s.toShort())
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setVirtualizer ERROR", e)
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setLoudness" -> {
                        val gainDb = call.argument<Double>("gainDb") ?: 0.0
                        try {
                            loudnessEnhancer?.let {
                                val targetGainMb = (gainDb * 100).toInt()
                                it.setTargetGain(targetGainMb)
                                Log.i(TAG, "setLoudness: gainDb=$gainDb → targetGainMb=$targetGainMb")
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setLoudness ERROR", e)
                            result.error("FX_ERROR", e.message, null)
                        }
                    }
                    "setLoudnessEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            loudnessEnhancer?.enabled = enabled
                            Log.i(TAG, "setLoudnessEnabled: $enabled")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setLoudnessEnabled ERROR", e)
                            result.error("FX_ERROR", e.message, null)
                        }
                    }
                    "setLimiterEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                dynamicsProcessing?.enabled = enabled
                                Log.i(TAG, "setLimiterEnabled: $enabled")
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setLimiterEnabled ERROR", e)
                            result.error("FX_ERROR", e.message, null)
                        }
                    }
                    "setLimiter" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                val threshold = call.argument<Double>("threshold") ?: -3.0
                                val ratio = call.argument<Double>("ratio") ?: 4.0
                                val attack = call.argument<Double>("attack") ?: 10.0
                                val release = call.argument<Double>("release") ?: 100.0
                                val postGain = call.argument<Double>("postGain") ?: 0.0

                                dynamicsProcessing?.let { dp ->
                                    val limiter = DynamicsProcessing.Limiter(
                                        true,   // enabled
                                        1,      // linkGroup
                                        attack.toFloat(),
                                        release.toFloat(),
                                        ratio.toFloat(),
                                        threshold.toFloat(),
                                        postGain.toFloat()
                                    )
                                    dp.setLimiterAllChannelsTo(limiter)
                                    Log.i(TAG, "setLimiter: threshold=$threshold, ratio=$ratio, attack=$attack, release=$release, postGain=$postGain")
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "setLimiter ERROR", e)
                            result.error("FX_ERROR", e.message, null)
                        }
                    }
                    "setBassFrequency" -> {
                        // Handled in Dart side — no-op here
                        result.success(null)
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

        try {
            loudnessEnhancer = LoudnessEnhancer(sessionId).apply { enabled = false }
            Log.i(TAG, "  LoudnessEnhancer OK")
        } catch (e: Exception) {
            Log.w(TAG, "  LoudnessEnhancer not supported: ${e.message}")
            loudnessEnhancer = null
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                dynamicsProcessing = DynamicsProcessing.Builder()
                    .setPreEqInUse(false)
                    .setMbcInUse(false)
                    .setPostEqInUse(false)
                    .setLimiterInUse(true)
                    .build()
                dynamicsProcessing!!.enabled = false

                // Set default limiter params
                val defaultLimiter = DynamicsProcessing.Limiter(
                    true, 1,
                    10.0f,   // attack ms
                    100.0f,  // release ms
                    4.0f,    // ratio
                    -3.0f,   // threshold dB
                    0.0f     // postGain dB
                )
                dynamicsProcessing!!.setLimiterAllChannelsTo(defaultLimiter)
                Log.i(TAG, "  DynamicsProcessing (Limiter) OK")
            } catch (e: Exception) {
                Log.w(TAG, "  DynamicsProcessing not supported: ${e.message}")
                dynamicsProcessing = null
            }
        } else {
            Log.i(TAG, "  DynamicsProcessing skipped: API < 28")
            dynamicsProcessing = null
        }

        currentSessionId = sessionId
        Log.i(TAG, "initEffects complete: eq=${equalizer != null}, bb=${bassBoost != null}, virt=${virtualizer != null}, loudness=${loudnessEnhancer != null}, dp=${dynamicsProcessing != null}")
    }

    private fun releaseEffects() {
        try { equalizer?.release() } catch (_: Exception) {}
        try { bassBoost?.release() } catch (_: Exception) {}
        try { virtualizer?.release() } catch (_: Exception) {}
        try { loudnessEnhancer?.release() } catch (_: Exception) {}
        try { dynamicsProcessing?.release() } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
        loudnessEnhancer = null
        dynamicsProcessing = null
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        releaseEffects()
        super.onDestroy()
    }
}
