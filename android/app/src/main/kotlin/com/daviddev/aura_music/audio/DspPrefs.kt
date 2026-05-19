package com.daviddev.aura_music.audio

import android.content.Context
import android.content.SharedPreferences

/**
 * DspPrefs — SharedPreferences wrapper for DSP engine state persistence.
 *
 * Stores:
 * - EQ band gains (12 bands)
 * - Bass boost strength and frequency
 * - Virtualizer strength
 * - Loudness gain and enabled state
 * - Limiter params (threshold, ratio, attack, release, postGain) and enabled state
 * - Master EQ enabled state
 * - Current preset name
 * - Restore-after-boot flag
 *
 * Format:
 * - Band gains stored as comma-separated string: "0.0,2.5,-1.0,..."
 * - All other values stored as individual prefs
 *
 * Thread safety: SharedPreferences is thread-safe for reads/writes.
 */
class DspPrefs(context: Context) {

    companion object {
        private const val PREFS_NAME = "aura_dsp_state"

        // Keys
        private const val KEY_EQ_ENABLED = "eq_enabled"
        private const val KEY_BAND_GAINS = "band_gains"
        private const val KEY_BASS_BOOST = "bass_boost"
        private const val KEY_BASS_FREQUENCY = "bass_frequency"
        private const val KEY_VIRTUALIZER = "virtualizer"
        private const val KEY_LOUDNESS = "loudness"
        private const val KEY_LOUDNESS_ENABLED = "loudness_enabled"
        private const val KEY_LIMITER_ENABLED = "limiter_enabled"
        private const val KEY_LIMITER_THRESHOLD = "limiter_threshold"
        private const val KEY_LIMITER_RATIO = "limiter_ratio"
        private const val KEY_LIMITER_ATTACK = "limiter_attack"
        private const val KEY_LIMITER_RELEASE = "limiter_release"
        private const val KEY_LIMITER_POST_GAIN = "limiter_post_gain"
        private const val KEY_PRESET_NAME = "preset_name"
        private const val KEY_RESTORE_AFTER_BOOT = "restore_after_boot"

        private const val DEFAULT_BAND_GAINS = "0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0"
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // ─── EQ State ──────────────────────────────────────────────

    fun isEqEnabled(): Boolean = prefs.getBoolean(KEY_EQ_ENABLED, true)

    fun setEqEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_EQ_ENABLED, enabled).apply()
    }

    fun getBandGains(): List<Double> {
        val gainsStr = prefs.getString(KEY_BAND_GAINS, DEFAULT_BAND_GAINS) ?: DEFAULT_BAND_GAINS
        return try {
            gainsStr.split(",").map { it.toDouble() }
        } catch (e: NumberFormatException) {
            List(12) { 0.0 }
        }
    }

    fun setBandGains(gains: List<Double>) {
        val gainsStr = gains.joinToString(",")
        prefs.edit().putString(KEY_BAND_GAINS, gainsStr).apply()
    }

    fun getPresetName(): String? = prefs.getString(KEY_PRESET_NAME, null)

    fun setPresetName(name: String?) {
        prefs.edit().putString(KEY_PRESET_NAME, name).apply()
    }

    // ─── Bass State ────────────────────────────────────────────

    fun getBassBoost(): Double = prefs.getFloat(KEY_BASS_BOOST, 0f).toDouble()

    fun setBassBoost(gainDb: Double) {
        prefs.edit().putFloat(KEY_BASS_BOOST, gainDb.toFloat()).apply()
    }

    fun getBassFrequency(): Int = prefs.getInt(KEY_BASS_FREQUENCY, 80)

    fun setBassFrequency(hz: Int) {
        prefs.edit().putInt(KEY_BASS_FREQUENCY, hz).apply()
    }

    // ─── Virtualizer State ─────────────────────────────────────

    fun getVirtualizer(): Double = prefs.getFloat(KEY_VIRTUALIZER, 0f).toDouble()

    fun setVirtualizer(strength: Double) {
        prefs.edit().putFloat(KEY_VIRTUALIZER, strength.toFloat()).apply()
    }

    // ─── Loudness State ────────────────────────────────────────

    fun getLoudness(): Double = prefs.getFloat(KEY_LOUDNESS, 0f).toDouble()

    fun setLoudness(gainDb: Double) {
        prefs.edit().putFloat(KEY_LOUDNESS, gainDb.toFloat()).apply()
    }

    fun isLoudnessEnabled(): Boolean = prefs.getBoolean(KEY_LOUDNESS_ENABLED, false)

    fun setLoudnessEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_LOUDNESS_ENABLED, enabled).apply()
    }

    // ─── Limiter State ─────────────────────────────────────────

    fun isLimiterEnabled(): Boolean = prefs.getBoolean(KEY_LIMITER_ENABLED, false)

    fun setLimiterEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_LIMITER_ENABLED, enabled).apply()
    }

    fun getLimiterThreshold(): Double = prefs.getFloat(KEY_LIMITER_THRESHOLD, -3.0f).toDouble()

    fun setLimiterThreshold(db: Double) {
        prefs.edit().putFloat(KEY_LIMITER_THRESHOLD, db.toFloat()).apply()
    }

    fun getLimiterRatio(): Double = prefs.getFloat(KEY_LIMITER_RATIO, 20.0f).toDouble()

    fun setLimiterRatio(ratio: Double) {
        prefs.edit().putFloat(KEY_LIMITER_RATIO, ratio.toFloat()).apply()
    }

    fun getLimiterAttack(): Double = prefs.getFloat(KEY_LIMITER_ATTACK, 5.0f).toDouble()

    fun setLimiterAttack(ms: Double) {
        prefs.edit().putFloat(KEY_LIMITER_ATTACK, ms.toFloat()).apply()
    }

    fun getLimiterRelease(): Double = prefs.getFloat(KEY_LIMITER_RELEASE, 100.0f).toDouble()

    fun setLimiterRelease(ms: Double) {
        prefs.edit().putFloat(KEY_LIMITER_RELEASE, ms.toFloat()).apply()
    }

    fun getLimiterPostGain(): Double = prefs.getFloat(KEY_LIMITER_POST_GAIN, 0.0f).toDouble()

    fun setLimiterPostGain(db: Double) {
        prefs.edit().putFloat(KEY_LIMITER_POST_GAIN, db.toFloat()).apply()
    }

    // ─── Boot Restore ──────────────────────────────────────────

    fun isRestoreAfterBoot(): Boolean = prefs.getBoolean(KEY_RESTORE_AFTER_BOOT, false)

    fun setRestoreAfterBoot(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_RESTORE_AFTER_BOOT, enabled).apply()
    }

    // ─── Bulk Operations ───────────────────────────────────────

    /**
     * Save the entire DSP configuration at once.
     */
    fun saveConfig(config: DspConfig) {
        prefs.edit().apply {
            putBoolean(KEY_EQ_ENABLED, config.eqEnabled)
            putString(KEY_BAND_GAINS, config.bandGains.joinToString(","))
            putFloat(KEY_BASS_BOOST, config.bassBoost.toFloat())
            putInt(KEY_BASS_FREQUENCY, config.bassFrequencyHz)
            putFloat(KEY_VIRTUALIZER, config.virtualizer.toFloat())
            putFloat(KEY_LOUDNESS, config.loudness.toFloat())
            putBoolean(KEY_LOUDNESS_ENABLED, config.loudnessEnabled)
            putBoolean(KEY_LIMITER_ENABLED, config.limiterEnabled)
            putFloat(KEY_LIMITER_THRESHOLD, config.limiterThreshold.toFloat())
            putFloat(KEY_LIMITER_RATIO, config.limiterRatio.toFloat())
            putFloat(KEY_LIMITER_ATTACK, config.limiterAttack.toFloat())
            putFloat(KEY_LIMITER_RELEASE, config.limiterRelease.toFloat())
            putFloat(KEY_LIMITER_POST_GAIN, config.limiterPostGain.toFloat())
            putString(KEY_PRESET_NAME, config.presetName)
            apply()
        }
    }

    /**
     * Load the entire DSP configuration at once.
     */
    fun loadConfig(): DspConfig {
        val gainsStr = prefs.getString(KEY_BAND_GAINS, DEFAULT_BAND_GAINS) ?: DEFAULT_BAND_GAINS
        val bandGains = try {
            gainsStr.split(",").map { it.toDouble() }
        } catch (e: NumberFormatException) {
            List(12) { 0.0 }
        }

        return DspConfig(
            eqEnabled = prefs.getBoolean(KEY_EQ_ENABLED, true),
            bandGains = bandGains,
            bassBoost = prefs.getFloat(KEY_BASS_BOOST, 0f).toDouble(),
            bassFrequencyHz = prefs.getInt(KEY_BASS_FREQUENCY, 80),
            virtualizer = prefs.getFloat(KEY_VIRTUALIZER, 0f).toDouble(),
            loudness = prefs.getFloat(KEY_LOUDNESS, 0f).toDouble(),
            loudnessEnabled = prefs.getBoolean(KEY_LOUDNESS_ENABLED, false),
            limiterEnabled = prefs.getBoolean(KEY_LIMITER_ENABLED, false),
            limiterThreshold = prefs.getFloat(KEY_LIMITER_THRESHOLD, -3.0f).toDouble(),
            limiterRatio = prefs.getFloat(KEY_LIMITER_RATIO, 20.0f).toDouble(),
            limiterAttack = prefs.getFloat(KEY_LIMITER_ATTACK, 5.0f).toDouble(),
            limiterRelease = prefs.getFloat(KEY_LIMITER_RELEASE, 100.0f).toDouble(),
            limiterPostGain = prefs.getFloat(KEY_LIMITER_POST_GAIN, 0.0f).toDouble(),
            presetName = prefs.getString(KEY_PRESET_NAME, null)
        )
    }

    /**
     * Complete DSP configuration data class.
     */
    data class DspConfig(
        val eqEnabled: Boolean = true,
        val bandGains: List<Double> = List(12) { 0.0 },
        val bassBoost: Double = 0.0,
        val bassFrequencyHz: Int = 80,
        val virtualizer: Double = 0.0,
        val loudness: Double = 0.0,
        val loudnessEnabled: Boolean = false,
        val limiterEnabled: Boolean = false,
        val limiterThreshold: Double = -3.0,
        val limiterRatio: Double = 20.0,
        val limiterAttack: Double = 5.0,
        val limiterRelease: Double = 100.0,
        val limiterPostGain: Double = 0.0,
        val presetName: String? = null
    )
}
