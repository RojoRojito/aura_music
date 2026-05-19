package com.daviddev.aura_music.audio

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * NativeEqualizerChannel — Isolated MethodChannel handler for Flutter ↔ Native communication.
 *
 * Responsibilities:
 * - Receive commands from Flutter via MethodChannel
 * - Forward commands to EqualizerEngine and EffectsController
 * - Persist DSP state to DspPrefs on every change
 * - Store pending config in AudioSessionManager for session recovery
 * - Return results/errors to Flutter
 * - NO DSP logic — pure delegation layer
 *
 * MethodChannel: "com.daviddev.aura/equalizer"
 */
class NativeEqualizerChannel(
    private val context: Context,
    private val engine: EqualizerEngine,
    private val sessionManager: AudioSessionManager,
    private val effectsController: EffectsController
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AURA_NATIVE_CH"
        const val CHANNEL_NAME = "com.daviddev.aura/equalizer"
    }

    private val dspPrefs = DspPrefs(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initSession" -> handleInitSession(call, result)
                "setEnabled" -> handleSetEnabled(call, result)
                "getBandCount" -> handleGetBandCount(result)
                "getBandFrequencies" -> handleGetBandFrequencies(result)
                "setBandGain" -> handleSetBandGain(call, result)
                "setAllBandGains" -> handleSetAllBandGains(call, result)
                "setBassBoost" -> handleSetBassBoost(call, result)
                "setVirtualizer" -> handleSetVirtualizer(call, result)
                "setLoudness" -> handleSetLoudness(call, result)
                "setLoudnessEnabled" -> handleSetLoudnessEnabled(call, result)
                "setLimiterEnabled" -> handleSetLimiterEnabled(call, result)
                "setLimiter" -> handleSetLimiter(call, result)
                "setBassFrequency" -> handleSetBassFrequency(call, result)
                "getEngineMode" -> handleGetEngineMode(result)
                "reinitializeSession" -> handleReinitializeSession(result)
                "saveDspState" -> handleSaveDspState(result)
                "loadDspState" -> handleLoadDspState(result)
                "setRestoreAfterBoot" -> handleSetRestoreAfterBoot(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "onMethodCall ERROR: method=${call.method}", e)
            result.error("DSP_ERROR", e.message, null)
        }
    }

    private fun handleInitSession(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<Int>("sessionId") ?: 0
        Log.i(TAG, ">> initSession: sessionId=$sessionId")

        if (sessionId == 0) {
            Log.w(TAG, "initSession: sessionId=0, ignoring")
            result.success(null)
            return
        }

        val success = sessionManager.onNewSessionId(sessionId)
        result.success(mapOf("success" to success))
    }

    private fun handleSetEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.i(TAG, ">> setEnabled: $enabled")
        effectsController.setEqEnabled(enabled)
        dspPrefs.setEqEnabled(enabled)
        dspPrefs.setRestoreAfterBoot(enabled)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleGetBandCount(result: MethodChannel.Result) {
        val count = engine.getNativeBandCount()
        Log.d(TAG, ">> getBandCount: $count")
        result.success(count)
    }

    private fun handleGetBandFrequencies(result: MethodChannel.Result) {
        val freqs = engine.getNativeBandFrequencies()
        Log.d(TAG, ">> getBandFrequencies: $freqs")
        result.success(freqs)
    }

    private fun handleSetBandGain(call: MethodCall, result: MethodChannel.Result) {
        val bandIndex = call.argument<Int>("bandIndex") ?: 0
        val gainDb = call.argument<Double>("gainDb") ?: 0.0
        Log.d(TAG, ">> setBandGain: band=$bandIndex, gain=$gainDb dB")
        engine.setBandGain(bandIndex, gainDb)
        // Persist individual band change
        val currentGains = dspPrefs.getBandGains().toMutableList()
        while (currentGains.size <= bandIndex) {
            currentGains.add(0.0)
        }
        currentGains[bandIndex] = gainDb
        dspPrefs.setBandGains(currentGains)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetAllBandGains(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val gains = call.argument<List<Double>>("gains") ?: emptyList()
        Log.d(TAG, ">> setAllBandGains: ${gains.size} bands")
        engine.setAllBandGains(gains)
        dspPrefs.setBandGains(gains)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetBassBoost(call: MethodCall, result: MethodChannel.Result) {
        val gainDb = call.argument<Double>("gainDb") ?: 0.0
        Log.d(TAG, ">> setBassBoost: gain=$gainDb dB")
        engine.setBassBoost(gainDb)
        dspPrefs.setBassBoost(gainDb)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetVirtualizer(call: MethodCall, result: MethodChannel.Result) {
        val strength = call.argument<Double>("strength") ?: 0.0
        Log.d(TAG, ">> setVirtualizer: strength=$strength")
        engine.setVirtualizer(strength)
        dspPrefs.setVirtualizer(strength)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetLoudness(call: MethodCall, result: MethodChannel.Result) {
        val gainDb = call.argument<Double>("gainDb") ?: 0.0
        Log.d(TAG, ">> setLoudness: gain=$gainDb dB")
        engine.setLoudness(gainDb)
        dspPrefs.setLoudness(gainDb)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetLoudnessEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.d(TAG, ">> setLoudnessEnabled: $enabled")
        engine.setLoudnessEnabled(enabled)
        dspPrefs.setLoudnessEnabled(enabled)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetLimiterEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.d(TAG, ">> setLimiterEnabled: $enabled")
        engine.setLimiterEnabled(enabled)
        dspPrefs.setLimiterEnabled(enabled)
        updatePendingConfig()
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
        dspPrefs.setLimiterThreshold(threshold)
        dspPrefs.setLimiterRatio(ratio)
        dspPrefs.setLimiterAttack(attack)
        dspPrefs.setLimiterRelease(release)
        dspPrefs.setLimiterPostGain(postGain)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleSetBassFrequency(call: MethodCall, result: MethodChannel.Result) {
        val hz = call.argument<Int>("hz") ?: 80
        Log.d(TAG, ">> setBassFrequency: $hz Hz")
        engine.setBassFrequency(hz)
        dspPrefs.setBassFrequency(hz)
        updatePendingConfig()
        result.success(null)
    }

    private fun handleGetEngineMode(result: MethodChannel.Result) {
        val mode = engine.getEngineMode()
        Log.d(TAG, ">> getEngineMode: $mode")
        result.success(mode)
    }

    private fun handleReinitializeSession(result: MethodChannel.Result) {
        Log.i(TAG, ">> reinitializeSession")
        sessionManager.reinitializeCurrentSession()
        result.success(null)
    }

    // ─── DSP State Persistence ─────────────────────────────────

    private fun handleSaveDspState(result: MethodChannel.Result) {
        Log.i(TAG, ">> saveDspState")
        val config = DspPrefs.DspConfig(
            eqEnabled = effectsController.isEqEnabled(),
            bandGains = dspPrefs.getBandGains(),
            bassBoost = dspPrefs.getBassBoost(),
            bassFrequencyHz = dspPrefs.getBassFrequency(),
            virtualizer = dspPrefs.getVirtualizer(),
            loudness = dspPrefs.getLoudness(),
            loudnessEnabled = dspPrefs.isLoudnessEnabled(),
            limiterEnabled = dspPrefs.isLimiterEnabled(),
            limiterThreshold = dspPrefs.getLimiterThreshold(),
            limiterRatio = dspPrefs.getLimiterRatio(),
            limiterAttack = dspPrefs.getLimiterAttack(),
            limiterRelease = dspPrefs.getLimiterRelease(),
            limiterPostGain = dspPrefs.getLimiterPostGain(),
            presetName = dspPrefs.getPresetName()
        )
        dspPrefs.saveConfig(config)
        result.success(null)
    }

    private fun handleLoadDspState(result: MethodChannel.Result) {
        Log.i(TAG, ">> loadDspState")
        val config = dspPrefs.loadConfig()
        val stateMap = mapOf(
            "eqEnabled" to config.eqEnabled,
            "bandGains" to config.bandGains,
            "bassBoost" to config.bassBoost,
            "bassFrequencyHz" to config.bassFrequencyHz,
            "virtualizer" to config.virtualizer,
            "loudness" to config.loudness,
            "loudnessEnabled" to config.loudnessEnabled,
            "limiterEnabled" to config.limiterEnabled,
            "limiterThreshold" to config.limiterThreshold,
            "limiterRatio" to config.limiterRatio,
            "limiterAttack" to config.limiterAttack,
            "limiterRelease" to config.limiterRelease,
            "limiterPostGain" to config.limiterPostGain,
            "presetName" to config.presetName
        )
        result.success(stateMap)
    }

    private fun handleSetRestoreAfterBoot(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        Log.d(TAG, ">> setRestoreAfterBoot: $enabled")
        dspPrefs.setRestoreAfterBoot(enabled)
        result.success(null)
    }

    /**
     * Update the pending configuration in AudioSessionManager.
     * Called after every DSP state change so config survives session transitions.
     */
    private fun updatePendingConfig() {
        val config = AudioSessionManager.PendingConfig(
            enabled = effectsController.isEqEnabled(),
            bandGains = dspPrefs.getBandGains(),
            bassBoost = dspPrefs.getBassBoost(),
            bassFrequencyHz = dspPrefs.getBassFrequency(),
            virtualizer = dspPrefs.getVirtualizer(),
            loudness = dspPrefs.getLoudness(),
            loudnessEnabled = dspPrefs.isLoudnessEnabled(),
            limiterEnabled = dspPrefs.isLimiterEnabled(),
            limiterThreshold = dspPrefs.getLimiterThreshold(),
            limiterRatio = dspPrefs.getLimiterRatio(),
            limiterAttack = dspPrefs.getLimiterAttack(),
            limiterRelease = dspPrefs.getLimiterRelease(),
            limiterPostGain = dspPrefs.getLimiterPostGain()
        )
        sessionManager.storePendingConfig(config)
    }
}
