package com.daviddev.aura_music.audio

import android.content.Context
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.LoudnessEnhancer
import android.util.Log

class EqualizerEngine(private val context: Context) {

    companion object {
        private const val TAG = "AURA_DSP_ENGINE"
        private const val PRIORITY = 1
    }

    // DSP components
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    // State
    private var currentSessionId: Int = -1
    private var isInitialized: Boolean = false
    private var engineMode: String = "unavailable"
    private var nativeBandCount: Int = 0
    private var nativeBandFrequencies: List<Int> = emptyList()

    // Configuration state
    private var eqEnabled: Boolean = true
    private var bandGains: FloatArray = floatArrayOf()
    private var bassBoostStrength: Float = 0f
    private var bassFrequencyHz: Int = 80
    private var virtualizerStrength: Float = 0f
    private var loudnessGain: Float = 0f
    private var loudnessEnabled: Boolean = false

    // Getters
    fun getEngineMode(): String = engineMode
    fun getNativeBandCount(): Int = nativeBandCount
    fun getNativeBandFrequencies(): List<Int> = nativeBandFrequencies

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

        val ok = tryInitLegacyChain(sessionId)
        if (ok) {
            engineMode = "legacy"
            Log.i(TAG, "initSession: using legacy chain")
        } else {
            engineMode = "unavailable"
            Log.e(TAG, "initSession: NO DSP engine available")
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

    @Synchronized
    fun setBandGain(bandIndex: Int, gainDb: Double) {
        if (!isReady()) return

        val clampedGain = gainDb.toFloat().coerceIn(-12f, 12f)
        if (bandIndex < bandGains.size) {
            bandGains[bandIndex] = clampedGain
        }

        applyBandGainLegacy(bandIndex, clampedGain)
    }

    @Synchronized
    fun setAllBandGains(gains: List<Double>) {
        if (!isReady()) return

        bandGains = FloatArray(gains.size) { i ->
            gains[i].toFloat().coerceIn(-12f, 12f)
        }

        applyAllBandsLegacy()
    }

    @Synchronized
    fun setBassBoost(gainDb: Double) {
        bassBoostStrength = gainDb.toFloat().coerceIn(0f, 15f)

        bassBoost?.let { bb ->
            if (bb.strengthSupported) {
                val s = ((bassBoostStrength / 15f) * 1000).toInt().coerceIn(0, 1000)
                bb.setStrength(s.toShort())
            }
        }
    }

    @Synchronized
    fun setBassFrequency(hz: Int) {
        bassFrequencyHz = hz.coerceIn(30, 120)
        Log.d(TAG, "setBassFrequency: $bassFrequencyHz Hz (stored, legacy no-op)")
    }

    @Synchronized
    fun setVirtualizer(strength: Double) {
        virtualizerStrength = strength.toFloat().coerceIn(0f, 1f)

        virtualizer?.let { v ->
            if (v.strengthSupported) {
                val s = (virtualizerStrength * 1000).toInt().coerceIn(0, 1000)
                v.setStrength(s.toShort())
            }
        }
    }

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

    @Synchronized
    fun setLimiterEnabled(enabled: Boolean) {
        Log.d(TAG, "setLimiterEnabled: no-op (legacy mode)")
    }

    @Synchronized
    fun setLimiterParams(
        threshold: Double,
        ratio: Double,
        attack: Double,
        release: Double,
        postGain: Double
    ) {
        Log.d(TAG, "setLimiterParams: no-op (legacy mode)")
    }

    @Synchronized
    fun setEnabled(enabled: Boolean) {
        eqEnabled = enabled
        equalizer?.let { eq -> try { eq.enabled = enabled } catch (e: Exception) {} }
        bassBoost?.let { bb -> try { bb.enabled = enabled } catch (e: Exception) {} }
        virtualizer?.let { v -> try { v.enabled = enabled } catch (e: Exception) {} }
    }

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

    private fun reapplyConfiguration() {
        Log.d(TAG, "reapplyConfiguration: reapplying stored DSP state")
        setEnabled(eqEnabled)
        setAllBandGains(bandGains.map { it.toDouble() })
        setBassBoost(bassBoostStrength.toDouble())
        setVirtualizer(virtualizerStrength.toDouble())
        setLoudness(loudnessGain.toDouble())
        setLoudnessEnabled(loudnessEnabled)
    }

    private fun releaseAllEffects() {
        Log.d(TAG, "releaseAllEffects")
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
