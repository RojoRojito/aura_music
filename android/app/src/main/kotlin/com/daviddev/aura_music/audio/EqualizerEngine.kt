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
 * IMPORTANT: DynamicsProcessing cannot be reconfigured after creation.
 * Any parameter change requires release + recreate with new Config.
 */
class EqualizerEngine(private val context: Context) {

    companion object {
        private const val TAG = "AURA_DSP_ENGINE"
        private const val PRIORITY = 1
        private const val MAX_DP_BANDS = 16
        private const val DEFAULT_LIMITER_THRESHOLD_DB = -3.0f
        private const val DEFAULT_LIMITER_RATIO = 20.0f
        private const val DEFAULT_LIMITER_ATTACK_MS = 5.0f
        private const val DEFAULT_LIMITER_RELEASE_MS = 100.0f
        private const val DEFAULT_LIMITER_POST_GAIN_DB = 0.0f
    }

    // ─── DSP Components ────────────────────────────────────────

    private var dynamicsProcessing: DynamicsProcessing? = null
    private var dpNumBands: Int = 0
    private var dpSessionId: Int = -1

    // Legacy fallback chain
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    // ─── State ─────────────────────────────────────────────────

    private var currentSessionId: Int = -1
    private var isInitialized: Boolean = false
    private var engineMode: String = "unavailable"
    private var nativeBandCount: Int = 0
    private var nativeBandFrequencies: List<Int> = emptyList()

    // ─── Configuration State ───────────────────────────────────

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
            Log.i(TAG, "Session changed: $currentSessionId → $sessionId, releasing old")
            releaseAllEffects()
            currentSessionId = sessionId
        }

        val dpOk = tryInitDynamicsProcessing(sessionId)
        if (dpOk) {
            engineMode = "dynamics_processing"
            Log.i(TAG, "initSession: using DynamicsProcessing")
        } else {
            val legacyOk = tryInitLegacyChain(sessionId)
            engineMode = if (legacyOk) "legacy" else "unavailable"
            if (!legacyOk) Log.e(TAG, "initSession: NO DSP engine available")
        }

        isInitialized = true
        applyAllToEngine()
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
    }

    fun getSessionId(): Int = currentSessionId
    fun isReady(): Boolean = isInitialized && engineMode != "unavailable"

    // ─── EQ Band Control ───────────────────────────────────────

    @Synchronized
    fun setBandGain(bandIndex: Int, gainDb: Double) {
        if (!isReady()) return

        val clampedGain = gainDb.toFloat().coerceIn(-12f, 12f)
        if (bandIndex >= bandGains.size) {
            val newGains = FloatArray(bandIndex + 1)
            bandGains.copyInto(newGains)
            bandGains = newGains
        }
        bandGains[bandIndex] = clampedGain
        applyAllToEngine()
    }

    @Synchronized
    fun setAllBandGains(gains: List<Double>) {
        if (!isReady()) return

        bandGains = FloatArray(gains.size) { i ->
            gains[i].toFloat().coerceIn(-12f, 12f)
        }
        applyAllToEngine()
    }

    // ─── Bass Control ──────────────────────────────────────────

    @Synchronized
    fun setBassBoost(gainDb: Double) {
        bassBoostStrength = gainDb.toFloat().coerceIn(0f, 15f)
        applyAllToEngine()
    }

    @Synchronized
    fun setBassFrequency(hz: Int) {
        bassFrequencyHz = hz.coerceIn(30, 120)
        applyAllToEngine()
    }

    // ─── Virtualizer ───────────────────────────────────────────

    @Synchronized
    fun setVirtualizer(strength: Double) {
        virtualizerStrength = strength.toFloat().coerceIn(0f, 1f)
        applyAllToEngine()
    }

    // ─── Loudness ──────────────────────────────────────────────

    @Synchronized
    fun setLoudness(gainDb: Double) {
        loudnessGain = gainDb.toFloat().coerceIn(0f, 10f)
        applyAllToEngine()
    }

    @Synchronized
    fun setLoudnessEnabled(enabled: Boolean) {
        loudnessEnabled = enabled
        applyAllToEngine()
    }

    // ─── Limiter ───────────────────────────────────────────────

    @Synchronized
    fun setLimiterEnabled(enabled: Boolean) {
        limiterEnabled = enabled
        applyAllToEngine()
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
        applyAllToEngine()
    }

    // ─── Master Enable ─────────────────────────────────────────

    @Synchronized
    fun setEnabled(enabled: Boolean) {
        eqEnabled = enabled
        if (engineMode == "dynamics_processing") {
            dynamicsProcessing?.let { dp ->
                try {
                    dp.enabled = enabled
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

    private fun tryInitDynamicsProcessing(sessionId: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            Log.i(TAG, "DynamicsProcessing not available (API < 28)")
            return false
        }

        return try {
            val numBands = determineDPBandCount(sessionId)
            dpNumBands = numBands
            dpSessionId = sessionId

            val cutoffFreqs = computeCutoffFrequencies(numBands)
            nativeBandFrequencies = cutoffFreqs
            nativeBandCount = numBands

            val config = buildDPConfig(numBands, cutoffFreqs)
            dynamicsProcessing = DynamicsProcessing(PRIORITY, sessionId, config)
            dynamicsProcessing?.enabled = eqEnabled

            Log.i(TAG, "DynamicsProcessing initialized: bands=$numBands")
            true
        } catch (e: Exception) {
            Log.e(TAG, "DynamicsProcessing init failed", e)
            dynamicsProcessing = null
            false
        }
    }

    private fun determineDPBandCount(sessionId: Int): Int {
        var nativeBands = 0
        try {
            val probeEq = Equalizer(PRIORITY, sessionId)
            nativeBands = probeEq.numberOfBands.toInt()
            probeEq.release()
        } catch (e: Exception) {
            Log.d(TAG, "Could not probe native EQ bands: ${e.message}")
        }
        return maxOf(nativeBands, 12).coerceAtMost(MAX_DP_BANDS)
    }

    private fun computeCutoffFrequencies(numBands: Int): List<Int> {
        if (numBands <= 1) return listOf(1000)

        val minFreq = 20.0
        val maxFreq = 20000.0
        val logMin = log10(minFreq)
        val logMax = log10(maxFreq)
        val step = (logMax - logMin) / numBands

        return List(numBands) { i ->
            val logFreq = logMin + step * (i + 1)
            10.0.pow(logFreq).toInt().coerceIn(20, 20000)
        }
    }

    private fun buildDPConfig(numBands: Int, cutoffFreqs: List<Int>): DynamicsProcessing.Config {
        val eqBands = List(numBands) { i ->
            val gain = if (i < bandGains.size) bandGains[i] else 0f
            val effectiveGain = if (i == 0) {
                (gain + bassBoostStrength).coerceIn(-12f, 12f)
            } else {
                gain
            }
            val freq = if (i == 0) bassFrequencyHz.toFloat() else cutoffFreqs[i].toFloat()
            DynamicsProcessing.EqBand(true, freq, effectiveGain)
        }

        val eq = DynamicsProcessing.Eq(true, eqEnabled, numBands)
        eqBands.forEachIndexed { index, band -> eq.setBand(index, band) }

        val builder = DynamicsProcessing.Config.Builder(
            0, // variant (0 = default)
            2, // stereo
            true, numBands,  // preEq
            false, 0,         // mbc
            false, 0,         // postEq
            limiterEnabled    // limiter
        )
        builder.setPreEqAllChannelsTo(eq)
        if (limiterEnabled) {
            val limiter = DynamicsProcessing.Limiter(
                true, true, 2,
                limiterThreshold,
                limiterRatio,
                limiterAttack,
                limiterRelease,
                limiterPostGain
            )
            builder.setLimiterAllChannelsTo(limiter)
        }

        return builder.build()
    }

    /**
     * Rebuild the entire DynamicsProcessing pipeline with current params.
     * DP cannot be reconfigured in-place — must release and recreate.
     */
    private fun rebuildDP() {
        val sessionId = dpSessionId
        if (sessionId <= 0) return

        try {
            dynamicsProcessing?.release()
        } catch (e: Exception) {
            Log.e(TAG, "rebuildDP: release old DP failed", e)
        }

        try {
            val numBands = dpNumBands
            val cutoffFreqs = computeCutoffFrequencies(numBands)
            nativeBandFrequencies = cutoffFreqs
            nativeBandCount = numBands

            val config = buildDPConfig(numBands, cutoffFreqs)
            dynamicsProcessing = DynamicsProcessing(PRIORITY, sessionId, config)
            dynamicsProcessing?.enabled = eqEnabled
            Log.d(TAG, "rebuildDP: OK, bands=$numBands")
        } catch (e: Exception) {
            Log.e(TAG, "rebuildDP: failed", e)
            dynamicsProcessing = null
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

    private fun applyBandGainLegacy(bandIndex: Int, gainDb: Float) {
        equalizer?.let { eq ->
            try {
                val numBands = eq.numberOfBands.toInt()
                if (bandIndex >= 0 && bandIndex < numBands) {
                    val levelMb = (gainDb * 100).toInt().toShort()
                    eq.setBandLevel(bandIndex.toShort(), levelMb)
                } else Unit
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

    // ─── Apply All ─────────────────────────────────────────────

    /**
     * Apply all current configuration to the active engine.
     * In DP mode: rebuild entire pipeline (DP cannot be modified in-place).
     * In legacy mode: apply each effect individually.
     */
    private fun applyAllToEngine() {
        if (!isReady()) return

        if (engineMode == "dynamics_processing") {
            rebuildDP()
        } else {
            applyAllBandsLegacy()
            bassBoost?.let { bb ->
                try {
                    if (bb.strengthSupported) {
                        val strength = ((bassBoostStrength / 15f) * 1000).toInt().coerceIn(0, 1000)
                        bb.setStrength(strength.toShort())
                    } else Unit
                } catch (e: Exception) {
                    Log.e(TAG, "setBassBoost legacy ERROR", e)
                }
            }
            virtualizer?.let { v ->
                try {
                    if (v.strengthSupported) {
                        val s = (virtualizerStrength * 1000).toInt().coerceIn(0, 1000)
                        v.setStrength(s.toShort())
                    } else Unit
                } catch (e: Exception) {
                    Log.e(TAG, "setVirtualizer legacy ERROR", e)
                }
            }
            loudnessEnhancer?.let { le ->
                try {
                    le.enabled = loudnessEnabled
                    if (loudnessEnabled) {
                        le.setTargetGain((loudnessGain * 100).toInt())
                    } else Unit
                } catch (e: Exception) {
                    Log.e(TAG, "setLoudness legacy ERROR", e)
                }
            }
        }
    }

    // ─── Cleanup ───────────────────────────────────────────────

    private fun releaseAllEffects() {
        Log.d(TAG, "releaseAllEffects")
        try { dynamicsProcessing?.release() } catch (e: Exception) {
            Log.e(TAG, "release DP ERROR", e)
        }
        dynamicsProcessing = null
        dpSessionId = -1
        dpNumBands = 0

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
