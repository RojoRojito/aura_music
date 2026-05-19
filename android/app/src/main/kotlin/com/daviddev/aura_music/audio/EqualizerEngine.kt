package com.daviddev.aura_music.audio

import android.content.Context
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log
import kotlin.math.ln

/**
 * EqualizerEngine — DSP engine with DynamicsProcessing as primary,
 * legacy AudioFX chain as fallback.
 *
 * Architecture (inspired by Flow Equalizer):
 * - Primary: DynamicsProcessing (API 28+) with Pre-EQ + Limiter in single pipeline
 * - Fallback: Equalizer + BassBoost + Virtualizer + LoudnessEnhancer (legacy chain)
 * - Bass: implemented as first band of DynamicsProcessing Pre-EQ
 * - Limiter: real DynamicsProcessing.Limiter (not no-op)
 * - Change detection: compares params before rebuild to avoid unnecessary recreation
 *
 * Thread safety: all public methods are synchronized.
 */
class EqualizerEngine(private val context: Context) {

    companion object {
        private const val TAG = "AURA_DSP_ENGINE"
        private const val PRIORITY = 1

        // Standard 12-band UI frequencies
        private val UI_FREQUENCIES = listOf(
            31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
        )

        // DynamicsProcessing supports up to 16 bands
        private const val MAX_DP_BANDS = 16

        // Limiter defaults
        private const val DEFAULT_LIMITER_THRESHOLD_DB = -3.0f
        private const val DEFAULT_LIMITER_RATIO = 20.0f  // ∞:1 for true limiting
        private const val DEFAULT_LIMITER_ATTACK_MS = 5.0f
        private const val DEFAULT_LIMITER_RELEASE_MS = 100.0f
        private const val DEFAULT_LIMITER_POST_GAIN_DB = 0.0f
    }

    // ─── DSP Components ────────────────────────────────────────

    private var dynamicsProcessing: DynamicsProcessing? = null
    private var dpConfig: DynamicsProcessing.Config? = null

    // Legacy fallback chain
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    // ─── State ─────────────────────────────────────────────────

    private var currentSessionId: Int = -1
    private var isInitialized: Boolean = false
    private var engineMode: String = "unavailable"  // "dynamics_processing", "legacy", "unavailable"
    private var nativeBandCount: Int = 0
    private var nativeBandFrequencies: List<Int> = emptyList()

    // ─── Configuration State (persisted for reapply + change detection) ──

    private var eqEnabled: Boolean = true
    private var bandGains: FloatArray = floatArrayOf()
    private var bassBoostStrength: Float = 0f
    private var bassFrequencyHz: Int = 80
    private var virtualizerStrength: Float = 0f
    private var loudnessGain: Float = 0f
    private var loudnessEnabled: Boolean = false

    // Limiter state
    private var limiterEnabled: Boolean = false
    private var limiterThreshold: Float = DEFAULT_LIMITER_THRESHOLD_DB
    private var limiterRatio: Float = DEFAULT_LIMITER_RATIO
    private var limiterAttack: Float = DEFAULT_LIMITER_ATTACK_MS
    private var limiterRelease: Float = DEFAULT_LIMITER_RELEASE_MS
    private var limiterPostGain: Float = DEFAULT_LIMITER_POST_GAIN_DB

    // ─── Change Detection (last applied values) ────────────────

    private var lastAppliedHash: Int = 0

    // ─── Getters ───────────────────────────────────────────────

    fun getEngineMode(): String = engineMode
    fun getNativeBandCount(): Int = nativeBandCount
    fun getNativeBandFrequencies(): List<Int> = nativeBandFrequencies

    // ─── Session Lifecycle ─────────────────────────────────────

    @Synchronized
    fun initSession(sessionId: Int) {
        Log.i(TAG, "initSession: sessionId=$sessionId (previous=$currentSessionId)")

        if (sessionId <= 0) {
            Log.w(TAG, "initSession: invalid sessionId=$sessionId, ignoring")
            return
        }

        if (sessionId != currentSessionId) {
            releaseAllEffects()
            currentSessionId = sessionId
        }

        val dpOk = tryInitDynamicsProcessing(sessionId)
        if (dpOk) {
            engineMode = "dynamics_processing"
            Log.i(TAG, "initSession: using DynamicsProcessing")
        } else {
            val legacyOk = tryInitLegacyChain(sessionId)
            if (legacyOk) {
                engineMode = "legacy"
                Log.i(TAG, "initSession: using legacy chain")
            } else {
                engineMode = "unavailable"
                Log.e(TAG, "initSession: NO DSP engine available")
            }
        }

        isInitialized = true
        lastAppliedHash = 0  // force reapply on first init
        reapplyConfiguration()
        Log.i(TAG, "initSession complete: mode=$engineMode")
    }

    @Synchronized
    fun release() {
        Log.i(TAG, "release: releasing all DSP resources")
        releaseAllEffects()
        currentSessionId = -1
        isInitialized = false
        engineMode = "unavailable"
        nativeBandCount = 0
        nativeBandFrequencies = emptyList()
        lastAppliedHash = 0
    }

    fun getSessionId(): Int = currentSessionId
    fun isReady(): Boolean = isInitialized && engineMode != "unavailable"

    // ─── EQ Band Control ───────────────────────────────────────

    @Synchronized
    fun setBandGain(bandIndex: Int, gainDb: Double) {
        if (!isReady()) return

        val clampedGain = gainDb.toFloat().coerceIn(-12f, 12f)
        if (bandIndex < bandGains.size) {
            bandGains[bandIndex] = clampedGain
        }

        applyConfigurationIfChanged()
    }

    @Synchronized
    fun setAllBandGains(gains: List<Double>) {
        if (!isReady()) return

        bandGains = FloatArray(gains.size) { i ->
            gains[i].toFloat().coerceIn(-12f, 12f)
        }

        applyConfigurationIfChanged()
    }

    // ─── Bass Control ──────────────────────────────────────────

    @Synchronized
    fun setBassBoost(gainDb: Double) {
        bassBoostStrength = gainDb.toFloat().coerceIn(0f, 15f)
        applyConfigurationIfChanged()
    }

    @Synchronized
    fun setBassFrequency(hz: Int) {
        bassFrequencyHz = hz.coerceIn(30, 120)
        applyConfigurationIfChanged()
    }

    // ─── Virtualizer ───────────────────────────────────────────

    @Synchronized
    fun setVirtualizer(strength: Double) {
        virtualizerStrength = strength.toFloat().coerceIn(0f, 1f)

        if (engineMode == "legacy") {
            virtualizer?.let { v ->
                try {
                    if (v.strengthSupported) {
                        val s = (virtualizerStrength * 1000).toInt().coerceIn(0, 1000)
                        v.setStrength(s.toShort())
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "setVirtualizer ERROR", e)
                }
            }
        }
        // In DP mode, virtualizer is not available (DynamicsProcessing doesn't support it)
    }

    // ─── Loudness ──────────────────────────────────────────────

    @Synchronized
    fun setLoudness(gainDb: Double) {
        loudnessGain = gainDb.toFloat().coerceIn(0f, 10f)

        if (engineMode == "legacy") {
            loudnessEnhancer?.let { le ->
                try {
                    le.setTargetGain((loudnessGain * 100).toInt())
                } catch (e: Exception) {
                    Log.e(TAG, "setLoudness ERROR", e)
                }
            }
        }
    }

    @Synchronized
    fun setLoudnessEnabled(enabled: Boolean) {
        loudnessEnabled = enabled
        if (engineMode == "legacy") {
            loudnessEnhancer?.let { le ->
                try {
                    le.enabled = enabled
                } catch (e: Exception) {
                    Log.e(TAG, "setLoudnessEnabled ERROR", e)
                }
            }
        }
    }

    // ─── Limiter (DynamicsProcessing) ─────────────────────────

    @Synchronized
    fun setLimiterEnabled(enabled: Boolean) {
        limiterEnabled = enabled
        applyConfigurationIfChanged()
    }

    @Synchronized
    fun setLimiterParams(
        threshold: Double,
        ratio: Double,
        attack: Double,
        release: Double,
        postGain: Double
    ) {
        limiterThreshold = threshold.toFloat().coerceIn(-12f, 0f)
        limiterRatio = ratio.toFloat().coerceIn(1f, 20f)
        limiterAttack = attack.toFloat().coerceIn(1f, 200f)
        limiterRelease = release.toFloat().coerceIn(1f, 200f)
        limiterPostGain = postGain.toFloat().coerceIn(0f, 6f)
        applyConfigurationIfChanged()
    }

    // ─── Master Enable ─────────────────────────────────────────

    @Synchronized
    fun setEnabled(enabled: Boolean) {
        eqEnabled = enabled

        when (engineMode) {
            "dynamics_processing" -> {
                dynamicsProcessing?.let { dp ->
                    try {
                        dp.enabled = enabled
                    } catch (e: Exception) {
                        Log.e(TAG, "setEnabled DP ERROR", e)
                    }
                }
            }
            "legacy" -> {
                equalizer?.let { eq -> try { eq.enabled = enabled } catch (e: Exception) {} }
                bassBoost?.let { bb -> try { bb.enabled = enabled } catch (e: Exception) {} }
                virtualizer?.let { v -> try { v.enabled = enabled } catch (e: Exception) {} }
            }
        }
    }

    // ─── DynamicsProcessing Initialization ─────────────────────

    private fun tryInitDynamicsProcessing(sessionId: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            Log.i(TAG, "DynamicsProcessing: API < 28, skipping")
            return false
        }

        return try {
            // Determine number of EQ bands: use native device bands if available, else 12
            val numBands = getAvailableBandCount(sessionId).coerceAtMost(MAX_DP_BANDS)
            nativeBandCount = numBands

            // Build initial config with current state
            buildAndApplyDynamicsProcessing(sessionId, numBands)

            // Extract frequencies from the DP config for Flutter
            val freqs = mutableListOf<Int>()
            dpConfig?.let { config ->
                val eq = config.preEq
                if (eq != null && eq.isEnabled) {
                    for (i in 0 until numBands) {
                        val band = eq.getBand(i)
                        freqs.add((band.frequency * 1000).toInt())
                    }
                }
            }
            if (freqs.isEmpty()) {
                // Fallback frequencies if we couldn't extract from DP
                for (i in 0 until numBands) {
                    freqs.add(UI_FREQUENCIES.getOrElse(i) { 1000 * (i + 1) })
                }
            }
            nativeBandFrequencies = freqs

            Log.i(TAG, "DynamicsProcessing OK: bands=$numBands")
            true
        } catch (e: Exception) {
            Log.e(TAG, "DynamicsProcessing FAILED", e)
            dynamicsProcessing = null
            dpConfig = null
            false
        }
    }

    /**
     * Build and apply DynamicsProcessing with current configuration state.
     * This is the core DSP pipeline builder.
     */
    private fun buildAndApplyDynamicsProcessing(sessionId: Int, numBands: Int) {
        // Release existing DP if any
        dynamicsProcessing?.release()
        dynamicsProcessing = null

        // Calculate gain stage compensation
        val maxBoost = bandGains.maxOrNull() ?: 0f
        val postGain = if (maxBoost > 0f) -maxBoost * 0.5f else 0f

        // Build config
        val builder = DynamicsProcessing.Config.Builder(
            2,  // stereo
            numBands  // max band count
        )

        // ── Pre-EQ ──
        builder.setPreEqEnabled(eqEnabled)
            .setPreEqBandCount(numBands)

        for (i in 0 until numBands) {
            val uiGain = mapUiGainToBand(i, numBands)
            val frequencyHz = mapFrequencyToBand(i, numBands)

            builder.setPreEqBand(i)
                .setEnabled(eqEnabled)
                .setFrequency(frequencyHz / 1000f)  // DP uses kHz
                .setGain(uiGain)
                .setBandwidth(1.0f)  // 1 octave bandwidth per band
        }

        // ── Bass boost as first EQ band (Flow pattern) ──
        if (bassBoostStrength > 0f && numBands > 0) {
            builder.setPreEqBand(0)
                .setEnabled(eqEnabled)
                .setFrequency(bassFrequencyHz / 1000f)
                .setGain(bassBoostStrength)
                .setBandwidth(1.5f)  // wider bandwidth for bass
        }

        // ── Limiter ──
        builder.setLimiterEnabled(limiterEnabled && eqEnabled)
        if (limiterEnabled && eqEnabled) {
            builder.setLimiterBandCount(1)
                .setLimiter(0)
                .setEnabled(true)
                .setThreshold(limiterThreshold)
                .setRatio(limiterRatio)
                .setAttack(limiterAttack)
                .setRelease(limiterRelease)
                .setPostGain(limiterPostGain + postGain)
        }

        // ── Compressor: disabled (we only need EQ + Limiter) ──
        builder.setCompressorEnabled(false)

        val config = builder.build()
        dpConfig = config

        // Create and enable DynamicsProcessing
        val dp = DynamicsProcessing(sessionId, config)
        dp.enabled = eqEnabled
        dynamicsProcessing = dp

        Log.d(TAG, "DynamicsProcessing built: bands=$numBands, limiter=$limiterEnabled, bass=${bassBoostStrength}dB")
    }

    // ─── Legacy Chain Initialization ───────────────────────────

    private fun tryInitLegacyChain(sessionId: Int): Boolean {
        var anyOk = false

        try {
            equalizer = Equalizer(PRIORITY, sessionId).apply { enabled = eqEnabled }
            val numBands = equalizer!!.numberOfBands.toInt()
            bandGains = FloatArray(numBands) { 0f }

            val freqs = mutableListOf<Int>()
            for (i in 0 until numBands) {
                freqs.add(equalizer!!.getCenterFreq(i.toShort()) / 1000)
            }
            nativeBandCount = numBands
            nativeBandFrequencies = freqs

            anyOk = true
            Log.i(TAG, "Legacy Equalizer OK: bands=$numBands")
        } catch (e: Exception) {
            Log.e(TAG, "Legacy Equalizer FAILED", e)
            equalizer = null
        }

        try {
            bassBoost = BassBoost(PRIORITY, sessionId).apply { enabled = eqEnabled }
            Log.i(TAG, "Legacy BassBoost OK")
        } catch (e: Exception) {
            Log.w(TAG, "Legacy BassBoost not available", e)
            bassBoost = null
        }

        try {
            virtualizer = Virtualizer(PRIORITY, sessionId).apply { enabled = eqEnabled }
            Log.i(TAG, "Legacy Virtualizer OK")
        } catch (e: Exception) {
            Log.w(TAG, "Legacy Virtualizer not available", e)
            virtualizer = null
        }

        try {
            loudnessEnhancer = LoudnessEnhancer(sessionId).apply {
                enabled = loudnessEnabled
                setTargetGain((loudnessGain * 100).toInt())
            }
            Log.i(TAG, "Legacy LoudnessEnhancer OK")
        } catch (e: Exception) {
            Log.w(TAG, "Legacy LoudnessEnhancer not available", e)
            loudnessEnhancer = null
        }

        return anyOk
    }

    // ─── Change Detection & Reapply ────────────────────────────

    /**
     * Compute a hash of current configuration to detect changes.
     * Avoids unnecessary DSP rebuilds (Flow pattern).
     */
    private fun computeConfigHash(): Int {
        var result = eqEnabled.hashCode()
        result = 31 * result + bandGains.contentHashCode()
        result = 31 * result + bassBoostStrength.hashCode()
        result = 31 * result + bassFrequencyHz
        result = 31 * result + limiterEnabled.hashCode()
        result = 31 * result + limiterThreshold.hashCode()
        result = 31 * result + limiterRatio.hashCode()
        result = 31 * result + limiterAttack.hashCode()
        result = 31 * result + limiterRelease.hashCode()
        result = 31 * result + limiterPostGain.hashCode()
        return result
    }

    private fun applyConfigurationIfChanged() {
        val newHash = computeConfigHash()
        if (newHash == lastAppliedHash) {
            Log.d(TAG, "applyConfigurationIfChanged: no changes detected, skipping")
            return
        }

        lastAppliedHash = newHash
        reapplyConfiguration()
    }

    private fun reapplyConfiguration() {
        Log.d(TAG, "reapplyConfiguration: reapplying stored DSP state, mode=$engineMode")

        when (engineMode) {
            "dynamics_processing" -> {
                // Rebuild the entire DP pipeline with current params
                if (currentSessionId > 0) {
                    try {
                        buildAndApplyDynamicsProcessing(currentSessionId, nativeBandCount)
                    } catch (e: Exception) {
                        Log.e(TAG, "reapplyConfiguration DP ERROR", e)
                    }
                }
            }
            "legacy" -> {
                setEnabled(eqEnabled)
                applyAllBandsLegacy()
                applyBassBoostLegacy()
                setVirtualizer(virtualizerStrength.toDouble())
                setLoudness(loudnessGain.toDouble())
                setLoudnessEnabled(loudnessEnabled)
            }
        }
    }

    // ─── Legacy Apply Helpers ──────────────────────────────────

    private fun applyBandGainLegacy(bandIndex: Int, gainDb: Float) {
        equalizer?.let { eq ->
            try {
                val numBands = eq.numberOfBands.toInt()
                if (bandIndex in 0 until numBands) {
                    val levelMb = (gainDb * 100).toInt().toShort()
                    eq.setBandLevel(bandIndex.toShort(), levelMb)
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBandGainLegacy ERROR", e)
            }
        }
    }

    private fun applyAllBandsLegacy() {
        equalizer?.let { eq ->
            try {
                val numBands = minOf(bandGains.size, eq.numberOfBands.toInt())
                for (i in 0 until numBands) {
                    val levelMb = (bandGains[i] * 100).toInt().toShort()
                    eq.setBandLevel(i.toShort(), levelMb)
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyAllBandsLegacy ERROR", e)
            }
        }
    }

    private fun applyBassBoostLegacy() {
        bassBoost?.let { bb ->
            try {
                if (bb.strengthSupported) {
                    val s = ((bassBoostStrength / 15f) * 1000).toInt().coerceIn(0, 1000)
                    bb.setStrength(s.toShort())
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBassBoostLegacy ERROR", e)
            }
        }
    }

    // ─── Frequency & Gain Mapping ──────────────────────────────

    /**
     * Get the number of bands available on this device.
     * Tries to query the native Equalizer for accurate count.
     */
    private fun getAvailableBandCount(sessionId: Int): Int {
        return try {
            val tempEq = Equalizer(PRIORITY, sessionId)
            val count = tempEq.numberOfBands.toInt().coerceAtMost(MAX_DP_BANDS)
            tempEq.release()
            if (count >= 3) count else 5
        } catch (e: Exception) {
            5  // safe default
        }
    }

    /**
     * Map a native band index to a UI gain value using logarithmic interpolation.
     */
    private fun mapUiGainToBand(nativeIndex: Int, nativeCount: Int): Float {
        if (bandGains.isEmpty() || nativeCount == 0) return 0f

        val nativeFreq = mapFrequencyToBand(nativeIndex, nativeCount)
        return EqualizerConfigMapper.interpolateGain(
            nativeFreq.toDouble(),
            UI_FREQUENCIES,
            bandGains.map { it.toDouble() }
        ).toFloat()
    }

    /**
     * Map a native band index to a center frequency in Hz.
     * Uses logarithmic spacing across the audible range.
     */
    private fun mapFrequencyToBand(index: Int, totalBands: Int): Int {
        if (totalBands <= 1) return 1000

        val minFreq = 31.0  // Hz
        val maxFreq = 20000.0  // Hz

        val logMin = ln(minFreq)
        val logMax = ln(maxFreq)
        val t = if (totalBands > 1) index.toDouble() / (totalBands - 1) else 0.5

        return kotlin.math.exp(logMin + t * (logMax - logMin)).toInt()
    }

    // ─── Resource Cleanup ──────────────────────────────────────

    private fun releaseAllEffects() {
        Log.d(TAG, "releaseAllEffects")

        try { dynamicsProcessing?.release() } catch (e: Exception) {}
        dynamicsProcessing = null
        dpConfig = null

        try { equalizer?.release() } catch (e: Exception) {}
        equalizer = null
        try { bassBoost?.release() } catch (e: Exception) {}
        bassBoost = null
        try { virtualizer?.release() } catch (e: Exception) {}
        virtualizer = null
        try { loudnessEnhancer?.release() } catch (e: Exception) {}
        loudnessEnhancer = null
    }
}
