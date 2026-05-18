package com.daviddev.aura_music.audio

import android.content.Context
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

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
 * - State flows are used for reactive state observation from Flutter
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

    // Engine mode: "dynamics_processing" | "legacy" | "unavailable"
    private val _engineMode = MutableStateFlow<String>("unavailable")
    val engineMode: StateFlow<String> = _engineMode.asStateFlow()

    // Native band count (from active EQ)
    private val _nativeBandCount = MutableStateFlow(0)
    val nativeBandCount: StateFlow<Int> = _nativeBandCount.asStateFlow()

    // Native band frequencies in Hz
    private val _nativeBandFrequencies = MutableStateFlow<List<Int>>(emptyList())
    val nativeBandFrequencies: StateFlow<List<Int>> = _nativeBandFrequencies.asStateFlow()

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

    // ─── Public API ───────────────────────────────────────────

    /**
     * Initialize the DSP engine with an audio session ID.
     * This is the main entry point called when a new audio session is available.
     *
     * Automatically selects DynamicsProcessing (primary) or legacy fallback.
     * Rebuilds the entire DSP chain if the session changes.
     */
    @Synchronized
    fun initSession(sessionId: Int) {
        Log.i(TAG, "initSession: sessionId=$sessionId (previous=$currentSessionId)")

        if (sessionId <= 0) {
            Log.w(TAG, "initSession: invalid sessionId=$sessionId, ignoring")
            return
        }

        // If session changed, release old chain
        if (sessionId != currentSessionId) {
            releaseAllEffects()
            currentSessionId = sessionId
        }

        // Try primary engine first
        val primaryOk = tryInitDynamicsProcessing(sessionId)

        if (primaryOk) {
            _engineMode.value = "dynamics_processing"
            Log.i(TAG, "initSession: using DynamicsProcessing (primary)")
        } else {
            // Fallback to legacy chain
            val fallbackOk = tryInitLegacyChain(sessionId)
            if (fallbackOk) {
                _engineMode.value = "legacy"
                Log.i(TAG, "initSession: using legacy fallback chain")
            } else {
                _engineMode.value = "unavailable"
                Log.e(TAG, "initSession: NO DSP engine available")
            }
        }

        isInitialized = true

        // Reapply stored configuration
        reapplyConfiguration()

        Log.i(TAG, "initSession complete: mode=${_engineMode.value}")
    }

    /**
     * Release all DSP resources. Called on session close or engine destruction.
     */
    @Synchronized
    fun release() {
        Log.i(TAG, "release: releasing all DSP resources")
        releaseAllEffects()
        currentSessionId = -1
        isInitialized = false
        _engineMode.value = "unavailable"
        _nativeBandCount.value = 0
        _nativeBandFrequencies.value = emptyList()
    }

    /**
     * Get the active audio session ID.
     */
    @Synchronized
    fun getSessionId(): Int = currentSessionId

    /**
     * Check if the engine is ready to process audio.
     */
    fun isReady(): Boolean = isInitialized && _engineMode.value != "unavailable"

    // ─── EQ Band Operations ───────────────────────────────────

    /**
     * Set gain for a specific EQ band (in dB).
     * Works with both DynamicsProcessing and legacy Equalizer.
     */
    @Synchronized
    fun setBandGain(bandIndex: Int, gainDb: Double) {
        if (!isReady()) {
            Log.w(TAG, "setBandGain: engine not ready")
            return
        }

        val clampedGain = gainDb.toFloat().coerceIn(-12f, 12f)

        // Update stored state
        if (bandIndex < bandGains.size) {
            bandGains[bandIndex] = clampedGain
        }

        when (_engineMode.value) {
            "dynamics_processing" -> applyBandGainDynamicsProcessing(bandIndex, clampedGain)
            "legacy" -> applyBandGainLegacy(bandIndex, clampedGain)
        }
    }

    /**
     * Set all EQ band gains at once.
     */
    @Synchronized
    fun setAllBandGains(gains: List<Double>) {
        if (!isReady()) return

        bandGains = FloatArray(gains.size) { i ->
            gains[i].toFloat().coerceIn(-12f, 12f)
        }

        when (_engineMode.value) {
            "dynamics_processing" -> applyAllBandsDynamicsProcessing()
            "legacy" -> applyAllBandsLegacy()
        }
    }

    // ─── Bass Boost ───────────────────────────────────────────

    @Synchronized
    fun setBassBoost(gainDb: Double) {
        bassBoostStrength = gainDb.toFloat().coerceIn(0f, 15f)

        when (_engineMode.value) {
            "dynamics_processing" -> applyBassBoostDynamicsProcessing()
            "legacy" -> {
                bassBoost?.let { bb ->
                    if (bb.strengthSupported) {
                        val strength = ((bassBoostStrength / 15f) * 600).toInt().coerceIn(0, 600)
                        bb.strength = strength.toShort()
                    }
                }
            }
        }
    }

    // ─── Virtualizer ──────────────────────────────────────────

    @Synchronized
    fun setVirtualizer(strength: Double) {
        virtualizerStrength = strength.toFloat().coerceIn(0f, 1f)

        when (_engineMode.value) {
            "dynamics_processing" -> applyVirtualizerDynamicsProcessing()
            "legacy" -> {
                virtualizer?.let { v ->
                    if (v.strengthSupported) {
                        val s = (virtualizerStrength * 500).toInt().coerceIn(0, 500)
                        v.strength = s.toShort()
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
                Log.d(TAG, "setLoudness: ${loudnessGain}dB → targetGainMb=${(loudnessGain * 100).toInt()}")
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

    // ─── Limiter (DynamicsProcessing) ─────────────────────────

    @Synchronized
    fun setLimiterEnabled(enabled: Boolean) {
        limiterEnabled = enabled

        if (_engineMode.value == "dynamics_processing") {
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

        if (_engineMode.value == "dynamics_processing") {
            applyLimiterDynamicsProcessing()
        }
    }

    // ─── Master Enable ────────────────────────────────────────

    @Synchronized
    fun setEnabled(enabled: Boolean) {
        eqEnabled = enabled

        dynamicsProcessing?.let { dp ->
            try { dp.enabled = enabled } catch (_: Exception) {}
        }
        equalizer?.let { eq ->
            try { eq.enabled = enabled } catch (_: Exception) {}
        }
        bassBoost?.let { bb ->
            try { bb.enabled = enabled } catch (_: Exception) {}
        }
        virtualizer?.let { v ->
            try { v.enabled = enabled } catch (_: Exception) {}
        }
        // Loudness enhancer has its own enabled state
    }

    // ─── Internal: DynamicsProcessing Initialization ──────────

    /**
     * Try to initialize DynamicsProcessing as the primary DSP engine.
     * DynamicsProcessing provides:
     * - Full parametric EQ via DynamicsProcessing.EqBand
     * - Built-in limiter via DynamicsProcessing.Limiter
     * - Compressor stages (optional)
     *
     * Returns true if initialization succeeded.
     */
    private fun tryInitDynamicsProcessing(sessionId: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            Log.i(TAG, "DynamicsProcessing: API < 28, skipping")
            return false
        }

        return try {
            // DynamicsProcessing doesn't take sessionId in constructor —
            // it attaches to the audio session via AudioEffect's internal mechanism
            // when used with just_audio's audio session.
            // We create it with 2 channels (stereo) as default.
            val dp = DynamicsProcessing(2) // 2 channels = stereo

            // Configure EQ bands — we'll set these properly when config is applied
            val numBands = dp.channelCount
            Log.i(TAG, "DynamicsProcessing: channels=${dp.channelCount}")

            // Set up default EQ bands (will be reconfigured when config arrives)
            setupDefaultEqBands(dp)

            // Set up default limiter (disabled initially)
            setupDefaultLimiter(dp)

            dp.enabled = eqEnabled
            dynamicsProcessing = dp

            // Extract band info for Flutter UI
            extractDynamicsProcessingBandInfo(dp)

            Log.i(TAG, "DynamicsProcessing initialized OK")
            true
        } catch (e: Exception) {
            Log.e(TAG, "DynamicsProcessing init FAILED", e)
            dynamicsProcessing = null
            false
        }
    }

    /**
     * Set up default EQ bands on DynamicsProcessing.
     * Creates a standard set of frequency bands covering the audible spectrum.
     */
    private fun setupDefaultEqBands(dp: DynamicsProcessing) {
        // Standard 5-band EQ as baseline (will be reconfigured)
        val frequencies = floatArrayOf(60f, 230f, 910f, 3600f, 14000f)
        val numBands = frequencies.size

        // Initialize band gains array
        bandGains = FloatArray(numBands) { 0f }

        for (ch in 0 until dp.channelCount) {
            for (i in frequencies.indices) {
                val eqBand = DynamicsProcessing.EqBand(
                    true,    // enabled
                    true,    // active
                    frequencies[i], // center frequency in Hz
                    1.0f,    // Q factor (bandwidth)
                    0.0f,    // gain in dB (flat)
                    0.0f     // phase (not used)
                )
                dp.setEqBand(ch, i, eqBand)
            }
        }
    }

    /**
     * Set up default limiter on DynamicsProcessing.
     * Limiter prevents clipping when EQ boosts cause signal overflow.
     */
    private fun setupDefaultLimiter(dp: DynamicsProcessing) {
        val defaultLimiter = DynamicsProcessing.Limiter(
            true,            // enabled
            true,            // limiter mode (not compressor)
            1,               // link group (all channels linked)
            limiterAttack,   // attack time in ms
            limiterRelease,  // release time in ms
            limiterRatio,    // ratio (∞:1 for limiter)
            limiterThreshold,// threshold in dB
            limiterPostGain  // post-gain in dB
        )
        dp.setLimiterAllChannelsTo(defaultLimiter)
        dp.enabled = limiterEnabled
    }

    /**
     * Extract band count and frequencies from DynamicsProcessing for Flutter UI.
     */
    private fun extractDynamicsProcessingBandInfo(dp: DynamicsProcessing) {
        // DynamicsProcessing uses the same band configuration across all channels
        // We read from channel 0
        val channel = 0
        val bandCount = dp.getEqBandCount(channel)

        _nativeBandCount.value = bandCount

        val freqs = mutableListOf<Int>()
        for (i in 0 until bandCount) {
            val band = dp.getEqBand(channel, i)
            freqs.add(band.frequency.toInt())
        }
        _nativeBandFrequencies.value = freqs

        Log.i(TAG, "DP band info: count=$bandCount, freqs=$freqs")
    }

    // ─── Internal: Legacy Chain Initialization ────────────────

    /**
     * Try to initialize the legacy audio effects chain.
     * Fallback path for devices that don't support DynamicsProcessing.
     */
    private fun tryInitLegacyChain(sessionId: Int): Boolean {
        var anyOk = false

        try {
            equalizer = Equalizer(PRIORITY, sessionId).apply { enabled = eqEnabled }
            val numBands = equalizer!!.numberOfBands.toInt()

            // Initialize band gains array to match native bands
            bandGains = FloatArray(numBands) { 0f }

            // Extract native band frequencies
            val freqs = mutableListOf<Int>()
            for (i in 0 until numBands) {
                freqs.add(equalizer!!.getCenterFreq(i.toShort()) / 1000) // mHz → Hz
            }
            _nativeBandCount.value = numBands
            _nativeBandFrequencies.value = freqs

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
                val channel = 0
                if (bandIndex < dp.getEqBandCount(channel)) {
                    val band = dp.getEqBand(channel, bandIndex)
                    band.gain = gainDb
                    dp.setEqBand(channel, bandIndex, band)
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBandGainDynamicsProcessing ERROR", e)
            }
        }
    }

    private fun applyAllBandsDynamicsProcessing() {
        dynamicsProcessing?.let { dp ->
            try {
                val channel = 0
                val bandCount = minOf(bandGains.size, dp.getEqBandCount(channel))
                for (i in 0 until bandCount) {
                    val band = dp.getEqBand(channel, i)
                    band.gain = bandGains[i]
                    dp.setEqBand(channel, i, band)
                }
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
                    // Convert dB to millibels (Android Equalizer uses mB)
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

    private fun applyBassBoostDynamicsProcessing() {
        // In DynamicsProcessing mode, bass boost is applied as an EQ band boost
        // on the lowest frequency band
        dynamicsProcessing?.let { dp ->
            try {
                val channel = 0
                if (dp.getEqBandCount(channel) > 0 && bassBoostStrength > 0) {
                    val band = dp.getEqBand(channel, 0)
                    band.gain = bassBoostStrength.coerceIn(0f, 12f)
                    dp.setEqBand(channel, 0, band)
                }
            } catch (e: Exception) {
                Log.e(TAG, "applyBassBoostDynamicsProcessing ERROR", e)
            }
        }
    }

    private fun applyVirtualizerDynamicsProcessing() {
        // Virtualizer is not available in DynamicsProcessing mode
        // This is a known limitation — virtualizer is a separate Android effect
        Log.d(TAG, "applyVirtualizerDynamicsProcessing: virtualizer not available in DP mode")
    }

    private fun applyLimiterDynamicsProcessing() {
        dynamicsProcessing?.let { dp ->
            try {
                val limiter = DynamicsProcessing.Limiter(
                    true,
                    true,
                    1,
                    limiterAttack,
                    limiterRelease,
                    limiterRatio,
                    limiterThreshold,
                    limiterPostGain
                )
                dp.setLimiterAllChannelsTo(limiter)
                dp.enabled = limiterEnabled
                Log.d(TAG, "applyLimiterDynamicsProcessing: threshold=$limiterThreshold, ratio=$limiterRatio")
            } catch (e: Exception) {
                Log.e(TAG, "applyLimiterDynamicsProcessing ERROR", e)
            }
        }
    }

    // ─── Internal: Configuration Reapplication ────────────────

    /**
     * Reapply all stored configuration to the newly created DSP chain.
     * Called after session change or engine recreation.
     */
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
            limiterThreshold.toDouble(),
            limiterRatio.toDouble(),
            limiterAttack.toDouble(),
            limiterRelease.toDouble(),
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
