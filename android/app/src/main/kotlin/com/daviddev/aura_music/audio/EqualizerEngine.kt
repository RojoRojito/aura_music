package com.daviddev.aura_music.audio

import android.content.Context
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log

/**
 * EqualizerEngine — Core DSP engine for AURA Music.
 *
 * Ownership model:
 * - PRIMARY: DynamicsProcessing (API 28+) for full EQ band processing + limiter
 * - FALLBACK: Equalizer + BassBoost + LoudnessEnhancer (legacy path)
 *
 * Lifecycle:
 * - Created once, survives activity recreation
 * - Reconnects when AudioSessionManager signals session changes
 * - Releases all effects safely on destroy or session invalidation
 *
 * Thread safety:
 * - All public methods are synchronized on the engine lock
 */
class EqualizerEngine(private val context: Context) {

    companion object {
        private const val TAG = "AURA_DSP_ENGINE"
        private const val PRIORITY = 1
    }

    // ─── DSP Components ───────────────────────────────────────

    // Primary DSP chain (DynamicsProcessing)
    private var dynamicsProcessing: DynamicsProcessing? = null

    // Fallback DSP chain (legacy effects)
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    // ─── State ────────────────────────────────────────────────

    private var currentSessionId: Int = -1
    private var isInitialized: Boolean = false
    private var engineMode: String = "unavailable" // "dynamics_processing" | "legacy" | "unavailable"
    private var nativeBandCount: Int = 0
    private var nativeBandFrequencies: List<Int> = emptyList()

    // ─── Configuration State ──────────────────────────────────

    private var eqEnabled: Boolean = true
    private var bandGains: FloatArray = floatArrayOf()
    private var bassBoostStrength: Float = 0f
    private var virtualizerStrength: Float = 0f
    private var loudnessGain: Float = 0f
    private var loudnessEnabled: Boolean = false

    // Limiter state
    private var limiterEnabled: Boolean = false
    private var limiterThreshold: Float = -3.0f
    private var limiterRatio: Float = 4.0f
    private var limiterAttack: Float = 10.0f
    private var limiterRelease: Float = 100.0f
    private var limiterPostGain: Float = 0.0f

    // ─── Getters ──────────────────────────────────────────────

    fun getEngineMode(): String = engineMode
    fun getNativeBandCount(): Int = nativeBandCount
    fun getNativeBandFrequencies(): List<Int> = nativeBandFrequencies

    // ─── Public API ───────────────────────────────────────────

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

        val primaryOk = tryInitDynamicsProcessing(sessionId)

        if (primaryOk) {
            engineMode = "dynamics_processing"
            Log.i(TAG, "initSession: using DynamicsProcessing (primary)")
        } else {
            val fallbackOk = tryInitLegacyChain(sessionId)
            if (fallbackOk) {
                engineMode = "legacy"
                Log.i(TAG, "initSession: using legacy fallback chain")
            } else {
                engineMode = "unavailable"
                Log.e(TAG, "initSession: NO DSP engine available")
            }
        }

        isInitialized = true
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
    }

    fun getSessionId(): Int = currentSessionId
    fun isReady(): Boolean = isInitialized && engineMode != "unavailable"

    // ─── EQ Band Operations ───────────────────────────────────

    @Synchronized
    fun setBandGain(bandIndex: Int, gainDb: Double) {
        if (!isReady()) return

        val clampedGain = gainDb.toFloat().coerceIn(-12f, 12f)
        if (bandIndex < bandGains.size) {
            bandGains[bandIndex] = clampedGain
        }

        when (engineMode) {
            "dynamics_processing" -> applyBandGainDynamicsProcessing(bandIndex, clampedGain)
            "legacy" -> applyBandGainLegacy(bandIndex, clampedGain)
        }
    }

    @Synchronized
    fun setAllBandGains(gains: List<Double>) {
        if (!isReady()) return

        bandGains = FloatArray(gains.size) { i ->
            gains[i].toFloat().coerceIn(-12f, 12f)
        }

        when (engineMode) {
            "dynamics_processing" -> applyAllBandsDynamicsProcessing()
            "legacy" -> applyAllBandsLegacy()
        }
    }

    // ─── Bass Boost ───────────────────────────────────────────

    @Synchronized
    fun setBassBoost(gainDb: Double) {
        bassBoostStrength = gainDb.toFloat().coerceIn(0f, 15f)

        when (engineMode) {
            "dynamics_processing" -> applyBassBoostDynamicsProcessing()
            "legacy" -> {
                bassBoost?.let { bb ->
                    if (bb.strengthSupported) {
                        val s = ((bassBoostStrength / 15f) * 1000).toInt().coerceIn(0, 1000)
                        bb.setStrength(s.toShort())
                    }
                }
            }
        }
    }

    // ─── Virtualizer ──────────────────────────────────────────

    @Synchronized
    fun setVirtualizer(strength: Double) {
        virtualizerStrength = strength.toFloat().coerceIn(0f, 1f)

        when (engineMode) {
            "dynamics_processing" -> applyVirtualizerDynamicsProcessing()
            "legacy" -> {
                virtualizer?.let { v ->
                    if (v.strengthSupported) {
                        val s = (virtualizerStrength * 1000).toInt().coerceIn(0, 1000)
                        v.setStrength(s.toShort())
                    }
                }
            }
        }
    }

    // ─── Loudness Enhancer ────────────────────────────────────

    @Synchronized
    fun setLoudness(gainDb: Double) {
        loudnessGain = gainDb.toFloat().coerceIn(0f, 10f)

        loudnessEnhancer?.let { le ->
            try {
                le.setTargetGain((loudnessGain * 100).toInt())
                Log.d(TAG, "setLoudness: ${loudnessGain}dB")
            } catch (e: Exception) {
                Log.e(TAG, "setLoudness ERROR", e)
            }
        }
    }

    @Synchronized
    fun setLoudnessEnabled(enabled: Boolean) {
        loudnessEnabled = enabled
        loudnessEnhancer?.let { le ->
            try {
                le.enabled = enabled
                Log.d(TAG, "setLoudnessEnabled: $enabled")
            } catch (e: Exception) {
                Log.e(TAG, "setLoudnessEnabled ERROR", e)
            }
        }
    }

    // ─── Limiter ──────────────────────────────────────────────

    @Synchronized
    fun setLimiterEnabled(enabled: Boolean) {
        limiterEnabled = enabled

        if (engineMode == "dynamics_processing") {
            dynamicsProcessing?.let { dp ->
                try {
                    dp.enabled = enabled
                    Log.d(TAG, "setLimiterEnabled: $enabled")
                } catch (e: Exception) {
                    Log.e(TAG, "setLimiterEnabled ERROR", e)
                }
            }
        }
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

        if (engineMode == "dynamics_processing") {
            applyLimiterDynamicsProcessing()
        }
    }

    // ─── Master Enable ────────────────────────────────────────

    @Synchronized
    fun setEnabled(enabled: Boolean) {
        eqEnabled = enabled

        dynamicsProcessing?.let { dp -> try { dp.enabled = enabled } catch (_: Exception) {} }
        equalizer?.let { eq -> try { eq.enabled = enabled } catch (_: Exception) {} }
        bassBoost?.let { bb -> try { bb.enabled = enabled } catch (_: Exception) {} }
        virtualizer?.let { v -> try { v.enabled = enabled } catch (_: Exception) {} }
    }

    // ─── Internal: DynamicsProcessing ─────────────────────────

    private fun tryInitDynamicsProcessing(sessionId: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            Log.i(TAG, "DynamicsProcessing: API < 28, skipping")
            return false
        }

        return try {
            val dp = DynamicsProcessing(2) // stereo

            setupDefaultEqBands(dp)
            setupDefaultLimiter(dp)

            dp.enabled = eqEnabled
            dynamicsProcessing = dp

            extractDynamicsProcessingBandInfo(dp)

            Log.i(TAG, "DynamicsProcessing initialized OK")
            true
        } catch (e: Exception) {
            Log.e(TAG, "DynamicsProcessing init FAILED", e)
            dynamicsProcessing = null
            false
        }
    }

    private fun setupDefaultEqBands(dp: DynamicsProcessing) {
        val frequencies = floatArrayOf(60f, 230f, 910f, 3600f, 14000f)

        bandGains = FloatArray(frequencies.size) { 0f }

        val stage = dp.getPreEqStage()
        for (i in frequencies.indices) {
            stage.setBand(i, DynamicsProcessing.EqBand(true, frequencies[i], 0.0f))
        }
        dp.setPreEqStageTo(stage)
    }

    private fun setupDefaultLimiter(dp: DynamicsProcessing) {
        val defaultLimiter = DynamicsProcessing.Limiter(
            true, true, 1,
            limiterAttack, limiterRelease, limiterRatio,
            limiterThreshold, limiterPostGain
        )
        dp.setLimiterAllChannelsTo(defaultLimiter)
        dp.enabled = limiterEnabled
    }

    private fun extractDynamicsProcessingBandInfo(dp: DynamicsProcessing) {
        val stage = dp.getPreEqStage()
        val bandCount = stage.getBandCount()

        nativeBandCount = bandCount

        val freqs = mutableListOf<Int>()
        for (i in 0 until bandCount) {
            val band = stage.getBand(i)
            freqs.add(band.cutoffFrequency.toInt())
        }
        nativeBandFrequencies = freqs

        Log.i(TAG, "DP band info: count=$bandCount, freqs=$freqs")
    }

    // ─── Internal: Legacy Chain ───────────────────────────────

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

    // ─── Internal: Apply Operations ───────────────────────────

    private fun applyBandGainDynamicsProcessing(bandIndex: Int, gainDb: Float) {
        dynamicsProcessing?.let { dp ->
            try {
                val stage = dp.getPreEqStage()
                if (bandIndex < stage.getBandCount()) {
                    val band = stage.getBand(bandIndex)
                    band.gainDb = gainDb
                    stage.setBand(bandIndex, band)
                    dp.setPreEqStageTo(stage)
                } else {
                    Unit
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBandGainDynamicsProcessing ERROR", e)
            }
        }
    }

    private fun applyAllBandsDynamicsProcessing() {
        dynamicsProcessing?.let { dp ->
            try {
                val stage = dp.getPreEqStage()
                val bandCount = minOf(bandGains.size, stage.getBandCount())
                for (i in 0 until bandCount) {
                    val band = stage.getBand(i)
                    band.gainDb = bandGains[i]
                    stage.setBand(i, band)
                }
                dp.setPreEqStageTo(stage)
            } catch (e: Exception) {
                Log.e(TAG, "applyAllBandsDynamicsProcessing ERROR", e)
            }
        }
    }

    private fun applyBandGainLegacy(bandIndex: Int, gainDb: Float) {
        equalizer?.let { eq ->
            try {
                val numBands = eq.numberOfBands.toInt()
                if (bandIndex in 0 until numBands) {
                    val levelMb = (gainDb * 100).toInt().toShort()
                    eq.setBandLevel(bandIndex.toShort(), levelMb)
                } else {
                    Unit
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

    private fun applyBassBoostDynamicsProcessing() {
        dynamicsProcessing?.let { dp ->
            try {
                val stage = dp.getPreEqStage()
                if (stage.getBandCount() > 0 && bassBoostStrength > 0) {
                    val band = stage.getBand(0)
                    band.gainDb = bassBoostStrength.coerceIn(0f, 12f)
                    stage.setBand(0, band)
                    dp.setPreEqStageTo(stage)
                } else {
                    Unit
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBassBoostDynamicsProcessing ERROR", e)
            }
        }
    }

    private fun applyVirtualizerDynamicsProcessing() {
        Log.d(TAG, "applyVirtualizerDynamicsProcessing: not available in DP mode")
    }

    private fun applyLimiterDynamicsProcessing() {
        dynamicsProcessing?.let { dp ->
            try {
                val limiter = DynamicsProcessing.Limiter(
                    true, true, 1,
                    limiterAttack, limiterRelease, limiterRatio,
                    limiterThreshold, limiterPostGain
                )
                dp.setLimiterAllChannelsTo(limiter)
                dp.enabled = limiterEnabled
                Log.d(TAG, "applyLimiterDynamicsProcessing OK")
            } catch (e: Exception) {
                Log.e(TAG, "applyLimiterDynamicsProcessing ERROR", e)
            }
        }
    }

    // ─── Internal: Configuration Reapplication ────────────────

    private fun reapplyConfiguration() {
        Log.d(TAG, "reapplyConfiguration: reapplying stored DSP state")

        setEnabled(eqEnabled)
        setAllBandGains(bandGains.map { it.toDouble() })
        setBassBoost(bassBoostStrength.toDouble())
        setVirtualizer(virtualizerStrength.toDouble())
        setLoudness(loudnessGain.toDouble())
        setLoudnessEnabled(loudnessEnabled)
        setLimiterEnabled(limiterEnabled)
        setLimiterParams(
            limiterThreshold.toDouble(), limiterRatio.toDouble(),
            limiterAttack.toDouble(), limiterRelease.toDouble(),
            limiterPostGain.toDouble()
        )
    }

    // ─── Internal: Resource Cleanup ───────────────────────────

    private fun releaseAllEffects() {
        Log.d(TAG, "releaseAllEffects")

        try { dynamicsProcessing?.release() } catch (_: Exception) {}
        dynamicsProcessing = null

        try { equalizer?.release() } catch (_: Exception) {}
        equalizer = null

        try { bassBoost?.release() } catch (_: Exception) {}
        bassBoost = null

        try { virtualizer?.release() } catch (_: Exception) {}
        virtualizer = null

        try { loudnessEnhancer?.release() } catch (_: Exception) {}
        loudnessEnhancer = null
    }
}
