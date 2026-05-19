package com.daviddev.aura_music.audio

import android.content.Context
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log
import kotlin.math.log10
import kotlin.math.pow

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

        // Standard 12-band UI frequencies (Hz)
        private val UI_FREQUENCIES = listOf(
            31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
        )

        // DynamicsProcessing supports up to 16 bands
        private const val MAX_DP_BANDS = 16

        // Limiter defaults
        private const val DEFAULT_LIMITER_THRESHOLD_DB = -3.0f
        private const val DEFAULT_LIMITER_RATIO = 20.0f  // near ∞:1 for true limiting
        private const val DEFAULT_LIMITER_ATTACK_MS = 5.0f
        private const val DEFAULT_LIMITER_RELEASE_MS = 100.0f
        private const val DEFAULT_LIMITER_POST_GAIN_DB = 0.0f

        // Gain staging: auto-compensate when total EQ boost exceeds threshold
        private const val GAIN_STAGING_THRESHOLD_DB = 6.0f
    }

    // ─── DSP Components ────────────────────────────────────────

    private var dynamicsProcessing: DynamicsProcessing? = null
    private var dpConfig: DynamicsProcessing.Config? = null
    private var dpNumBands: Int = 0

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

        // Release previous session if different
        if (sessionId != currentSessionId) {
            Log.i(TAG, "Session changed: $currentSessionId → $sessionId, releasing old")
            releaseAllEffects()
            currentSessionId = sessionId
        }

        // Try DynamicsProcessing first (API 28+), then fall back to legacy
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
        reapplyConfiguration()
        Log.i(TAG, "initSession complete: mode=$engineMode, bands=$nativeBandCount")
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
        if (!isReady()) {
            Log.w(TAG, "setBandGain: engine not ready")
            return
        }

        val clampedGain = gainDb.toFloat().coerceIn(-12f, 12f)

        // Expand bandGains array if needed
        if (bandIndex >= bandGains.size) {
            val newGains = FloatArray(bandIndex + 1)
            bandGains.copyInto(newGains)
            bandGains = newGains
        }
        bandGains[bandIndex] = clampedGain

        applyBandGainDirect(bandIndex, clampedGain)
        invalidateHash() // force reapply on next session change
    }

    @Synchronized
    fun setAllBandGains(gains: List<Double>) {
        if (!isReady()) {
            Log.w(TAG, "setAllBandGains: engine not ready")
            return
        }

        bandGains = FloatArray(gains.size) { i ->
            gains[i].toFloat().coerceIn(-12f, 12f)
        }

        applyAllBandsDirect()
        invalidateHash()
    }

    // ─── Bass Control ──────────────────────────────────────────

    @Synchronized
    fun setBassBoost(gainDb: Double) {
        bassBoostStrength = gainDb.toFloat().coerceIn(0f, 15f)
        Log.d(TAG, "setBassBoost: ${bassBoostStrength}dB")

        if (engineMode == "dynamics_processing") {
            // In DP mode, bass is applied as the first EQ band
            applyBassAsFirstBand()
        } else {
            bassBoost?.let { bb ->
                try {
                    if (bb.strengthSupported) {
                        val strength = ((bassBoostStrength / 15f) * 1000).toInt().coerceIn(0, 1000)
                        bb.setStrength(strength.toShort())
                        Log.d(TAG, "setBassBoost: legacy strength=$strength")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "setBassBoost ERROR", e)
                }
            }
        }
        invalidateHash()
    }

    @Synchronized
    fun setBassFrequency(hz: Int) {
        bassFrequencyHz = hz.coerceIn(30, 120)
        Log.d(TAG, "setBassFrequency: $bassFrequencyHz Hz")

        if (engineMode == "dynamics_processing") {
            // In DP mode, bass frequency affects the first band's cutoff
            applyBassAsFirstBand()
        }
        // In legacy mode, this is stored but BassBoost doesn't support frequency control
        invalidateHash()
    }

    // ─── Virtualizer ───────────────────────────────────────────

    @Synchronized
    fun setVirtualizer(strength: Double) {
        virtualizerStrength = strength.toFloat().coerceIn(0f, 1f)
        Log.d(TAG, "setVirtualizer: strength=$virtualizerStrength")

        virtualizer?.let { v ->
            try {
                if (v.strengthSupported) {
                    val s = (virtualizerStrength * 1000).toInt().coerceIn(0, 1000)
                    v.setStrength(s.toShort())
                    Log.d(TAG, "setVirtualizer: legacy strength=$s")
                }
            } catch (e: Exception) {
                Log.e(TAG, "setVirtualizer ERROR", e)
            }
        }
        invalidateHash()
    }

    // ─── Loudness ──────────────────────────────────────────────

    @Synchronized
    fun setLoudness(gainDb: Double) {
        loudnessGain = gainDb.toFloat().coerceIn(0f, 10f)
        Log.d(TAG, "setLoudness: ${loudnessGain}dB")

        loudnessEnhancer?.let { le ->
            try {
                le.setTargetGain((loudnessGain * 100).toInt())
                Log.d(TAG, "setLoudness: applied ${loudnessGain}dB")
            } catch (e: Exception) {
                Log.e(TAG, "setLoudness ERROR", e)
            }
        }
        invalidateHash()
    }

    @Synchronized
    fun setLoudnessEnabled(enabled: Boolean) {
        loudnessEnabled = enabled
        Log.d(TAG, "setLoudnessEnabled: $enabled")

        loudnessEnhancer?.let { le ->
            try {
                le.enabled = enabled
                Log.d(TAG, "setLoudnessEnabled: applied")
            } catch (e: Exception) {
                Log.e(TAG, "setLoudnessEnabled ERROR", e)
            }
        }
        invalidateHash()
    }

    // ─── Limiter ───────────────────────────────────────────────

    @Synchronized
    fun setLimiterEnabled(enabled: Boolean) {
        limiterEnabled = enabled
        Log.d(TAG, "setLimiterEnabled: $enabled")

        if (engineMode == "dynamics_processing") {
            applyLimiterToDP()
        }
        invalidateHash()
    }

    @Synchronized
    fun setLimiterParams(
        threshold: Double,
        ratio: Double,
        attack: Double,
        release: Double,
        postGain: Double
    ) {
        limiterThreshold = threshold.toFloat()
        limiterRatio = ratio.toFloat()
        limiterAttack = attack.toFloat()
        limiterRelease = release.toFloat()
        limiterPostGain = postGain.toFloat()

        Log.d(TAG, "setLimiterParams: threshold=$limiterThreshold, ratio=$limiterRatio, " +
                "attack=$limiterAttack, release=$limiterRelease, postGain=$limiterPostGain")

        if (engineMode == "dynamics_processing") {
            applyLimiterToDP()
        }
        invalidateHash()
    }

    // ─── Master Enable ─────────────────────────────────────────

    @Synchronized
    fun setEnabled(enabled: Boolean) {
        eqEnabled = enabled
        Log.d(TAG, "setEnabled: $enabled")

        if (engineMode == "dynamics_processing") {
            dynamicsProcessing?.let { dp ->
                try {
                    dp.enabled = enabled
                    Log.d(TAG, "setEnabled: DP enabled=$enabled")
                } catch (e: Exception) {
                    Log.e(TAG, "setEnabled DP ERROR", e)
                }
            }
        } else {
            try { equalizer?.enabled = enabled } catch (_: Exception) {}
            try { bassBoost?.enabled = enabled } catch (_: Exception) {}
            try { virtualizer?.enabled = enabled } catch (_: Exception) {}
        }
    }

    // ─── DynamicsProcessing Implementation ─────────────────────

    /**
     * Initialize DynamicsProcessing engine (API 28+).
     * Uses Pre-EQ stage for our equalizer bands and Limiter for gain staging.
     * MBC and Post-EQ stages are disabled.
     */
    private fun tryInitDynamicsProcessing(sessionId: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            Log.i(TAG, "DynamicsProcessing not available (API < 28)")
            return false
        }

        return try {
            // Determine number of bands: use max of native EQ bands and UI bands (12)
            val numBands = determineDPBandCount(sessionId)
            dpNumBands = numBands

            // Compute cutoff frequencies for the bands
            val cutoffFreqs = computeCutoffFrequencies(numBands)
            nativeBandFrequencies = cutoffFreqs
            nativeBandCount = numBands

            // Build EQ bands with current gains
            val eqBands = List(numBands) { i ->
                val gain = if (i < bandGains.size) bandGains[i] else 0f
                DynamicsProcessing.EqBand(true, cutoffFreqs[i].toFloat(), gain)
            }

            // Create EQ stage
            val eq = DynamicsProcessing.Eq(true, eqEnabled, numBands)
            eqBands.forEachIndexed { index, band ->
                eq.setBand(index, band)
            }

            // Create limiter stage
            val limiter = createDPLimiter()

            // Build config: PreEQ enabled, MBC disabled, PostEQ disabled, Limiter enabled
            val builder = DynamicsProcessing.Config.Builder(
                DynamicsProcessing.Config.VARIANT_DEFAULT,
                2 /* channelCount (stereo) */,
                true /* preEqInUse */, numBands /* preEqBandCount */,
                false /* mbcInUse */, 0 /* mbcBandCount */,
                false /* postEqInUse */, 0 /* postEqBandCount */,
                limiterEnabled /* limiterInUse */
            )
            builder.setPreEqAllChannelsTo(eq)
            if (limiterEnabled) {
                builder.setLimiterAllChannelsTo(limiter)
            }

            val config = builder.build()
            dpConfig = config

            // Create the DynamicsProcessing instance
            dynamicsProcessing = DynamicsProcessing(PRIORITY, sessionId, config)
            dynamicsProcessing?.enabled = eqEnabled

            Log.i(TAG, "DynamicsProcessing initialized: bands=$numBands, freqs=$cutoffFreqs")
            true
        } catch (e: Exception) {
            Log.e(TAG, "DynamicsProcessing init failed", e)
            dynamicsProcessing = null
            dpConfig = null
            false
        }
    }

    /**
     * Determine the number of bands to use for DynamicsProcessing.
     * Tries to match the device's native equalizer band count, falling back to 12.
     */
    private fun determineDPBandCount(sessionId: Int): Int {
        // Try to probe the native equalizer band count
        var nativeBands = 0
        try {
            val probeEq = Equalizer(PRIORITY, sessionId)
            nativeBands = probeEq.numberOfBands.toInt()
            probeEq.release()
            Log.d(TAG, "Native EQ bands detected: $nativeBands")
        } catch (e: Exception) {
            Log.d(TAG, "Could not probe native EQ bands: ${e.message}")
        }

        // Use the larger of native bands or UI bands, capped at MAX_DP_BANDS
        return maxOf(nativeBands, UI_FREQUENCIES.size).coerceAtMost(MAX_DP_BANDS)
    }

    /**
     * Compute cutoff frequencies for N bands using logarithmic spacing
     * across the audible range (20Hz - 20kHz).
     */
    private fun computeCutoffFrequencies(numBands: Int): List<Int> {
        if (numBands <= 1) return listOf(1000)

        val minFreq = 20f
        val maxFreq = 20000f
        val logMin = log10(minFreq)
        val logMax = log10(maxFreq)
        val step = (logMax - logMin) / numBands

        return List(numBands) { i ->
            val logFreq = logMin + step * (i + 1)
            10.0.pow(logFreq).toInt().coerceIn(20, 20000)
        }
    }

    /**
     * Create a DynamicsProcessing.Limiter with current parameters.
     */
    private fun createDPLimiter(): DynamicsProcessing.Limiter {
        return DynamicsProcessing.Limiter(
            true /* enabled */,
            limiterThreshold,   // threshold dB
            limiterRatio,       // ratio
            limiterAttack,      // attack ms
            limiterRelease,     // release ms
            limiterPostGain     // post-gain dB
        )
    }

    /**
     * Apply the current limiter settings to the active DynamicsProcessing instance.
     */
    private fun applyLimiterToDP() {
        val dp = dynamicsProcessing
        val config = dpConfig
        if (dp == null || config == null) return

        try {
            if (limiterEnabled) {
                val limiter = createDPLimiter()
                // Update config's limiter for all channels
                // We need to rebuild the config since limiter params changed
                val numBands = dpNumBands
                val eqBands = List(numBands) { i ->
                    val gain = if (i < bandGains.size) bandGains[i] else 0f
                    DynamicsProcessing.EqBand(true, nativeBandFrequencies[i].toFloat(), gain)
                }
                val eq = DynamicsProcessing.Eq(true, eqEnabled, numBands)
                eqBands.forEachIndexed { index, band -> eq.setBand(index, band) }

                val builder = DynamicsProcessing.Config.Builder(
                    DynamicsProcessing.Config.VARIANT_DEFAULT,
                    2,
                    true, numBands,
                    false, 0,
                    false, 0,
                    true
                )
                builder.setPreEqAllChannelsTo(eq)
                builder.setLimiterAllChannelsTo(limiter)
                val newConfig = builder.build()
                dpConfig = newConfig
                dp.setConfig(newConfig)
                dp.enabled = eqEnabled
                Log.d(TAG, "applyLimiterToDP: applied with limiter enabled")
            } else {
                // Rebuild without limiter
                val numBands = dpNumBands
                val eqBands = List(numBands) { i ->
                    val gain = if (i < bandGains.size) bandGains[i] else 0f
                    DynamicsProcessing.EqBand(true, nativeBandFrequencies[i].toFloat(), gain)
                }
                val eq = DynamicsProcessing.Eq(true, eqEnabled, numBands)
                eqBands.forEachIndexed { index, band -> eq.setBand(index, band) }

                val builder = DynamicsProcessing.Config.Builder(
                    DynamicsProcessing.Config.VARIANT_DEFAULT,
                    2,
                    true, numBands,
                    false, 0,
                    false, 0,
                    false
                )
                builder.setPreEqAllChannelsTo(eq)
                val newConfig = builder.build()
                dpConfig = newConfig
                dp.setConfig(newConfig)
                dp.enabled = eqEnabled
                Log.d(TAG, "applyLimiterToDP: applied with limiter disabled")
            }
        } catch (e: Exception) {
            Log.e(TAG, "applyLimiterToDP ERROR", e)
        }
    }

    /**
     * Apply bass boost as the first EQ band in DynamicsProcessing.
     * This gives real low-frequency control instead of a generic BassBoost effect.
     */
    private fun applyBassAsFirstBand() {
        val dp = dynamicsProcessing
        if (dp == null || engineMode != "dynamics_processing") return

        try {
            val numBands = dpNumBands
            if (numBands == 0) return

            // Get current EQ state from DP
            val eq = dp.preEq
            if (eq == null) {
                Log.w(TAG, "applyBassAsFirstBand: preEq is null")
                return
            }

            // Modify the first band to include bass boost
            val firstBand = eq.getBand(0)
            if (firstBand != null) {
                // The first band's cutoff frequency is set to the bass frequency
                firstBand.cutoffFrequency = bassFrequencyHz.toFloat()
                // The gain includes both the stored band gain and bass boost
                val baseGain = if (bandGains.isNotEmpty()) bandGains[0] else 0f
                val totalGain = (baseGain + bassBoostStrength).coerceIn(-12f, 12f)
                firstBand.gain = totalGain
                eq.setBand(0, firstBand)
                dp.preEq = eq
                Log.d(TAG, "applyBassAsFirstBand: band0 freq=${bassFrequencyHz}Hz, gain=$totalGain dB")
            }
        } catch (e: Exception) {
            Log.e(TAG, "applyBassAsFirstBand ERROR", e)
        }
    }

    /**
     * Apply a single band gain directly to the active DSP engine.
     */
    private fun applyBandGainDirect(bandIndex: Int, gainDb: Float) {
        if (engineMode == "dynamics_processing") {
            val dp = dynamicsProcessing
            if (dp == null) return

            try {
                val eq = dp.preEq
                if (eq != null && bandIndex < eq.bandCount) {
                    val band = eq.getBand(bandIndex)
                    if (band != null) {
                        // For band 0, include bass boost in the gain
                        val effectiveGain = if (bandIndex == 0) {
                            (gainDb + bassBoostStrength).coerceIn(-12f, 12f)
                        } else {
                            gainDb
                        }
                        band.gain = effectiveGain
                        eq.setBand(bandIndex, band)
                        dp.preEq = eq
                        Log.d(TAG, "applyBandGainDirect: DP band=$bandIndex, gain=$effectiveGain dB")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBandGainDirect DP ERROR", e)
            }
        } else {
            applyBandGainLegacy(bandIndex, gainDb)
        }
    }

    /**
     * Apply all band gains directly to the active DSP engine.
     */
    private fun applyAllBandsDirect() {
        if (engineMode == "dynamics_processing") {
            applyAllBandsDP()
        } else {
            applyAllBandsLegacy()
        }
    }

    /**
     * Apply all band gains to DynamicsProcessing.
     */
    private fun applyAllBandsDP() {
        val dp = dynamicsProcessing
        if (dp == null) return

        try {
            val eq = dp.preEq
            if (eq == null) return

            val numBands = minOf(bandGains.size, eq.bandCount)
            for (i in 0 until numBands) {
                val band = eq.getBand(i)
                if (band != null) {
                    // For band 0, include bass boost
                    val effectiveGain = if (i == 0) {
                        (bandGains[i] + bassBoostStrength).coerceIn(-12f, 12f)
                    } else {
                        bandGains[i]
                    }
                    band.gain = effectiveGain
                    eq.setBand(i, band)
                }
            }
            dp.preEq = eq
            Log.d(TAG, "applyAllBandsDP: applied $numBands bands")
        } catch (e: Exception) {
            Log.e(TAG, "applyAllBandsDP ERROR", e)
        }
    }

    // ─── Legacy Fallback Implementation ────────────────────────

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
            Log.i(TAG, "Legacy Equalizer OK: bands=$numBands, freqs=$freqs")
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

    private fun applyBandGainLegacy(bandIndex: Int, gainDb: Float) {
        equalizer?.let { eq ->
            try {
                val numBands = eq.numberOfBands.toInt()
                if (bandIndex in 0 until numBands) {
                    val levelMb = (gainDb * 100).toInt().toShort()
                    eq.setBandLevel(bandIndex.toShort(), levelMb)
                    Log.d(TAG, "applyBandGainLegacy: band=$bandIndex, gain=$gainDb dB")
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
                Log.d(TAG, "applyAllBandsLegacy: applied $numBands bands")
            } catch (e: Exception) {
                Log.e(TAG, "applyAllBandsLegacy ERROR", e)
            }
        }
    }

    // ─── Reapply / Change Detection ────────────────────────────

    /**
     * Recompute the hash of current configuration.
     * Used for change detection to avoid unnecessary DSP rebuilds.
     */
    private fun computeConfigHash(): Int {
        var result = eqEnabled.hashCode()
        result = 31 * result + bandGains.contentHashCode()
        result = 31 * result + bassBoostStrength.hashCode()
        result = 31 * result + bassFrequencyHz
        result = 31 * result + virtualizerStrength.hashCode()
        result = 31 * result + loudnessGain.hashCode()
        result = 31 * result + loudnessEnabled.hashCode()
        result = 31 * result + limiterEnabled.hashCode()
        result = 31 * result + limiterThreshold.hashCode()
        result = 31 * result + limiterRatio.hashCode()
        result = 31 * result + limiterAttack.hashCode()
        result = 31 * result + limiterRelease.hashCode()
        result = 31 * result + limiterPostGain.hashCode()
        return result
    }

    private fun invalidateHash() {
        lastAppliedHash = 0
    }

    /**
     * Reapply all stored configuration to the current DSP engine.
     * Called after session init to restore settings.
     */
    private fun reapplyConfiguration() {
        Log.d(TAG, "reapplyConfiguration: reapplying stored DSP state")

        val newHash = computeConfigHash()
        if (newHash == lastAppliedHash && lastAppliedHash != 0) {
            Log.d(TAG, "reapplyConfiguration: no changes detected, skipping")
            return
        }

        setEnabled(eqEnabled)
        if (bandGains.isNotEmpty()) {
            if (engineMode == "dynamics_processing") {
                applyAllBandsDP()
            } else {
                applyAllBandsLegacy()
            }
        }
        setBassBoost(bassBoostStrength.toDouble())
        setVirtualizer(virtualizerStrength.toDouble())
        setLoudness(loudnessGain.toDouble())
        setLoudnessEnabled(loudnessEnabled)
        setLimiterEnabled(limiterEnabled)
        setLimiterParams(
            limiterThreshold.toDouble(),
            limiterRatio.toDouble(),
            limiterAttack.toDouble(),
            limiterRelease.toDouble(),
            limiterPostGain.toDouble()
        )

        lastAppliedHash = newHash
        Log.d(TAG, "reapplyConfiguration: applied, hash=$newHash")
    }

    // ─── Cleanup ───────────────────────────────────────────────

    private fun releaseAllEffects() {
        Log.d(TAG, "releaseAllEffects")
        try { dynamicsProcessing?.release() } catch (e: Exception) {
            Log.e(TAG, "release DP ERROR", e)
        }
        dynamicsProcessing = null
        dpConfig = null

        try { equalizer?.release() } catch (e: Exception) {
            Log.e(TAG, "release EQ ERROR", e)
        }
        equalizer = null
        try { bassBoost?.release() } catch (e: Exception) {
            Log.e(TAG, "release BB ERROR", e)
        }
        bassBoost = null
        try { virtualizer?.release() } catch (e: Exception) {
            Log.e(TAG, "release Virt ERROR", e)
        }
        virtualizer = null
        try { loudnessEnhancer?.release() } catch (e: Exception) {
            Log.e(TAG, "release Loud ERROR", e)
        }
        loudnessEnhancer = null
    }
}
