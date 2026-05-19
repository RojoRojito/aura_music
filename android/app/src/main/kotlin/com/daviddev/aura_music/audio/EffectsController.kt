package com.daviddev.aura_music.audio

import android.util.Log

/**
 * EffectsController — Manages enable/disable state of individual DSP modules.
 *
 * Responsibilities:
 * - Enable/disable individual effects (EQ, Bass, Loudness, Limiter, Virtualizer)
 * - Track the enabled state of each module independently
 * - Handle resource release safely when modules are disabled
 * - Provide a centralized control point for effect toggling
 *
 * Module states:
 * - EQ: Master equalizer toggle
 * - Bass: Bass boost module
 * - Loudness: Loudness enhancer
 * - Limiter: DynamicsProcessing limiter
 * - Virtualizer: 3D spatial audio effect
 *
 * Safety:
 * - All operations are synchronized
 * - Null-safe — handles cases where effects aren't available
 * - State is tracked independently from engine availability
 */
class EffectsController(private val engine: EqualizerEngine) {

    companion object {
        private const val TAG = "AURA_FX_CTRL"
    }

    // Module enabled states
    private var eqEnabled: Boolean = true
    private var bassEnabled: Boolean = false
    private var loudnessEnabled: Boolean = false
    private var limiterEnabled: Boolean = false
    private var virtualizerEnabled: Boolean = false

    // ─── Master EQ Toggle ─────────────────────────────────────

    fun setEqEnabled(enabled: Boolean) {
        Log.d(TAG, "setEqEnabled: $enabled")
        eqEnabled = enabled
        engine.setEnabled(enabled)
    }

    fun isEqEnabled(): Boolean = eqEnabled

    // ─── Bass Boost ───────────────────────────────────────────

    fun setBassEnabled(enabled: Boolean) {
        Log.d(TAG, "setBassEnabled: $enabled")
        bassEnabled = enabled
        if (!enabled) {
            engine.setBassBoost(0.0)
        }
    }

    fun isBassEnabled(): Boolean = bassEnabled

    fun setBassFrequency(hz: Int) {
        Log.d(TAG, "setBassFrequency: $hz Hz")
        engine.setBassFrequency(hz)
    }

    // ─── Loudness Enhancer ────────────────────────────────────

    fun setLoudnessEnabled(enabled: Boolean) {
        Log.d(TAG, "setLoudnessEnabled: $enabled")
        loudnessEnabled = enabled
        engine.setLoudnessEnabled(enabled)
    }

    fun isLoudnessEnabled(): Boolean = loudnessEnabled

    // ─── Limiter ──────────────────────────────────────────────

    fun setLimiterEnabled(enabled: Boolean) {
        Log.d(TAG, "setLimiterEnabled: $enabled")
        limiterEnabled = enabled
        engine.setLimiterEnabled(enabled)
    }

    fun isLimiterEnabled(): Boolean = limiterEnabled

    // ─── Virtualizer ──────────────────────────────────────────

    fun setVirtualizerEnabled(enabled: Boolean) {
        Log.d(TAG, "setVirtualizerEnabled: $enabled")
        virtualizerEnabled = enabled
        if (!enabled) {
            engine.setVirtualizer(0.0)
        }
    }

    fun isVirtualizerEnabled(): Boolean = virtualizerEnabled

    // ─── Bulk Operations ──────────────────────────────────────

    /**
     * Disable all effects at once.
     * Preserves individual enabled states for later restoration.
     */
    fun disableAll() {
        Log.d(TAG, "disableAll: disabling all effects")
        engine.setEnabled(false)
    }

    /**
     * Enable all effects that have been configured.
     */
    fun enableAll() {
        Log.d(TAG, "enableAll: enabling all effects")
        engine.setEnabled(true)
    }

    /**
     * Reset all module states to defaults.
     */
    fun resetAll() {
        Log.d(TAG, "resetAll: resetting all module states")
        eqEnabled = true
        bassEnabled = false
        loudnessEnabled = false
        limiterEnabled = false
        virtualizerEnabled = false

        engine.setEnabled(true)
        engine.setBassBoost(0.0)
        engine.setBassFrequency(80)
        engine.setLoudnessEnabled(false)
        engine.setLimiterEnabled(false)
        engine.setVirtualizer(0.0)
    }
}
