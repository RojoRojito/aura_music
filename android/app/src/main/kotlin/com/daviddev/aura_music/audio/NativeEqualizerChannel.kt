package com.daviddev.aura_music.audio

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * NativeEqualizerChannel — Isolated MethodChannel handler for Flutter ↔ Native communication.
 *
 * Responsibilities:
 * - Receive commands from Flutter via MethodChannel
 * - Forward commands to EqualizerEngine and EffectsController
 * - Return results/errors to Flutter
 * - NO DSP logic — pure delegation layer
 *
 * This class replaces the old pattern where MainActivity.kt handled
 * all DSP logic directly. Now MainActivity only registers this channel.
 *
 * MethodChannel: "com.daviddev.aura/equalizer"
 *
 * Supported methods:
 * - initSession({sessionId: Int})
 * - setEnabled({enabled: Boolean})
 * - getBandCount() → Int
 * - getBandFrequencies() → List<Int>
 * - setBandGain({bandIndex: Int, gainDb: Double})
 * - setBassBoost({gainDb: Double})
 * - setVirtualizer({strength: Double})
 * - setLoudness({gainDb: Double})
 * - setLoudnessEnabled({enabled: Boolean})
 * - setLimiterEnabled({enabled: Boolean})
 * - setLimiter({threshold, ratio, attack, release, postGain: Double})
 * - setBassFrequency({hz: Int}) — handled in Dart, no-op here
 * - getEngineMode() → String
 * - reinitializeSession()
 */
class NativeEqualizerChannel(
    private val engine: EqualizerEngine,
    private val sessionManager: AudioSessionManager,
    private val effectsController: EffectsController
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AURA_NATIVE_CH"
        const val CHANNEL_NAME = "com.daviddev.aura/equalizer"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initSession" -> handleInitSession(call, result)
                "setEnabled" -> handleSetEnabled(call, result)
                "getBandCount" -> handleGetBandCount(result)
                "getBandFrequencies" -> handleGetBandFrequencies(result)
                "setBandGain" -> handleSetBandGain(call, result)
                "setBassBoost" -> handleSetBassBoost(call, result)
                "setVirtualizer" -> handleSetVirtualizer(call, result)
                "setLoudness" -> handleSetLoudness(call, result)
                "setLoudnessEnabled" -> handleSetLoudnessEnabled(call, result)
                "setLimiterEnabled" -> handleSetLimiterEnabled(call, result)
                "setLimiter" -> handleSetLimiter(call, result)
                "setBassFrequency" -> handleSetBassFrequency(call, result)
                "getEngineMode" -> handleGetEngineMode(result)
                "reinitializeSession" -> handleReinitializeSession(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "onMethodCall ERROR: method=${call.method}", e)
            result.error("DSP_ERROR", e.message, null)
        }
    }

    // ─── Method Handlers ──────────────────────────────────────

    private fun handleInitSession(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<Int>("sessionId") ?: 0
        Log.i(TAG, ">> initSession: sessionId=$sessionId")

        if (sessionId == 0) {
            Log.w(TAG, "initSession: sessionId=0, ignoring")
            result.success(null)
            return
        }

        val accepted = sessionManager.onNewSessionId(sessionId)
        Log.i(TAG, "initSession: accepted=$accepted")
        result.success(null)
    }

    private fun handleSetEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.i(TAG, ">> setEnabled: $enabled")
        effectsController.setEqEnabled(enabled)
        result.success(null)
    }

    private fun handleGetBandCount(result: MethodChannel.Result) {
        val count = engine.nativeBandCount.value
        Log.d(TAG, ">> getBandCount: $count")
        result.success(count)
    }

    private fun handleGetBandFrequencies(result: MethodChannel.Result) {
        val freqs = engine.nativeBandFrequencies.value
        Log.d(TAG, ">> getBandFrequencies: $freqs")
        result.success(freqs)
    }

    private fun handleSetBandGain(call: MethodCall, result: MethodChannel.Result) {
        val bandIndex = call.argument<Int>("bandIndex") ?: 0
        val gainDb = call.argument<Double>("gainDb") ?: 0.0
        Log.d(TAG, ">> setBandGain: band=$bandIndex, gain=$gainDb dB")

        engine.setBandGain(bandIndex, gainDb)
        result.success(null)
    }

    private fun handleSetBassBoost(call: MethodCall, result: MethodChannel.Result) {
        val gainDb = call.argument<Double>("gainDb") ?: 0.0
        Log.d(TAG, ">> setBassBoost: gain=$gainDb dB")

        engine.setBassBoost(gainDb)
        result.success(null)
    }

    private fun handleSetVirtualizer(call: MethodCall, result: MethodChannel.Result) {
        val strength = call.argument<Double>("strength") ?: 0.0
        Log.d(TAG, ">> setVirtualizer: strength=$strength")

        engine.setVirtualizer(strength)
        result.success(null)
    }

    private fun handleSetLoudness(call: MethodCall, result: MethodChannel.Result) {
        val gainDb = call.argument<Double>("gainDb") ?: 0.0
        Log.d(TAG, ">> setLoudness: gain=$gainDb dB")

        engine.setLoudness(gainDb)
        result.success(null)
    }

    private fun handleSetLoudnessEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.d(TAG, ">> setLoudnessEnabled: $enabled")

        engine.setLoudnessEnabled(enabled)
        result.success(null)
    }

    private fun handleSetLimiterEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.d(TAG, ">> setLimiterEnabled: $enabled")

        engine.setLimiterEnabled(enabled)
        result.success(null)
    }

    private fun handleSetLimiter(call: MethodCall, result: MethodChannel.Result) {
        val threshold = call.argument<Double>("threshold") ?: -3.0
        val ratio = call.argument<Double>("ratio") ?: 4.0
        val attack = call.argument<Double>("attack") ?: 10.0
        val release = call.argument<Double>("release") ?: 100.0
        val postGain = call.argument<Double>("postGain") ?: 0.0

        Log.d(TAG, ">> setLimiter: threshold=$threshold, ratio=$ratio, attack=$attack, release=$release, postGain=$postGain")

        engine.setLimiterParams(threshold, ratio, attack, release, postGain)
        result.success(null)
    }

    private fun handleSetBassFrequency(call: MethodCall, result: MethodChannel.Result) {
        // Handled entirely in Dart — no native action needed
        Log.d(TAG, ">> setBassFrequency: handled in Dart")
        result.success(null)
    }

    private fun handleGetEngineMode(result: MethodChannel.Result) {
        val mode = engine.engineMode.value
        Log.d(TAG, ">> getEngineMode: $mode")
        result.success(mode)
    }

    private fun handleReinitializeSession(result: MethodChannel.Result) {
        Log.i(TAG, ">> reinitializeSession")
        sessionManager.reinitializeCurrentSession()
        result.success(null)
    }
}
