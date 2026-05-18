package com.daviddev.aura_music.audio

import kotlin.math.log
import kotlin.math.pow

/**
 * EqualizerConfigMapper — Converts Flutter/UI values into DSP configuration.
 *
 * Responsibilities:
 * - Map 12-band UI equalizer values to native device bands
 * - Interpolate gain values using logarithmic frequency scaling
 * - Convert preset names into band gain curves
 * - Handle frequency band mapping between UI and native layers
 * - Validate and clamp DSP parameter ranges
 *
 * Why logarithmic interpolation?
 * Audio frequencies are perceived logarithmically by humans.
 * A linear interpolation between 100Hz and 1000Hz would not match
 * how we hear the difference between those frequencies.
 * Log interpolation ensures smooth, natural-sounding EQ curves.
 *
 * Thread safety:
 * - This class is stateless and thread-safe
 * - All methods are pure functions (no side effects)
 */
object EqualizerConfigMapper {

    // ─── UI Band Constants ────────────────────────────────────

    /** Standard 12-band UI frequencies used by Flutter frontend */
    val uiFrequencies: List<Int> = listOf(
        31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
    )

    const val UI_BAND_COUNT = 12
    const val MIN_GAIN_DB = -12.0
    const val MAX_GAIN_DB = 12.0
    const val MIN_BASS_DB = 0.0
    const val MAX_BASS_DB = 15.0
    const val MIN_LOUDNESS_DB = 0.0
    const val MAX_LOUDNESS_DB = 10.0

    // ─── Preset Curves ────────────────────────────────────────

    /**
     * Preset EQ curves as frequency-to-gain maps.
     * Keys are frequencies in Hz, values are gain in dB.
     */
    val presetCurves: Map<String, Map<Int, Double>> = mapOf(
        "Plano" to mapOf(
            31 to 0.0, 62 to 0.0, 125 to 0.0, 250 to 0.0, 500 to 0.0,
            1000 to 0.0, 2000 to 0.0, 4000 to 0.0, 8000 to 0.0, 16000 to 0.0
        ),
        "Rock" to mapOf(
            31 to 4.0, 62 to 3.0, 125 to 2.0, 250 to 0.0, 500 to -1.0,
            1000 to -1.0, 2000 to 0.0, 4000 to 2.0, 8000 to 3.0, 16000 to 3.0
        ),
        "Pop" to mapOf(
            31 to -1.0, 62 to 0.0, 125 to 1.0, 250 to 2.0, 500 to 2.0,
            1000 to 0.0, 2000 to -1.0, 4000 to -1.0, 8000 to 0.0, 16000 to 0.0
        ),
        "Jazz" to mapOf(
            31 to 2.0, 62 to 1.0, 125 to 0.0, 250 to 1.0, 500 to 2.0,
            1000 to 3.0, 2000 to 3.0, 4000 to 2.0, 8000 to 1.0, 16000 to 1.0
        ),
        "Clasica" to mapOf(
            31 to 3.0, 62 to 2.0, 125 to 2.0, 250 to 1.0, 500 to 0.0,
            1000 to 0.0, 2000 to 0.0, 4000 to 0.0, 8000 to 2.0, 16000 to 3.0
        ),
        "Hip-Hop" to mapOf(
            31 to 5.0, 62 to 4.0, 125 to 2.0, 250 to 1.0, 500 to -1.0,
            1000 to -1.0, 2000 to 0.0, 4000 to 0.0, 8000 to 1.0, 16000 to 1.0
        ),
        "Electronica" to mapOf(
            31 to 4.0, 62 to 3.0, 125 to 2.0, 250 to 0.0, 500 to -1.0,
            1000 to -1.0, 2000 to 1.0, 4000 to 2.0, 8000 to 2.0, 16000 to 2.0
        ),
        "Latino" to mapOf(
            31 to 3.0, 62 to 2.0, 125 to 0.0, 250 to -1.0, 500 to -1.0,
            1000 to 0.0, 2000 to 1.0, 4000 to 2.0, 8000 to 3.0, 16000 to 2.0
        )
    )

    // ─── Band Selection Maps ──────────────────────────────────

    /**
     * Maps visual band count to indices in the 12-band UI array.
     * Used to determine which UI bands to display for 5/7/10 band modes.
     */
    val bandSelections: Map<Int, List<Int>> = mapOf(
        5 to listOf(0, 2, 5, 8, 11),
        7 to listOf(0, 2, 4, 6, 8, 10, 11),
        10 to listOf(0, 1, 2, 4, 5, 6, 7, 9, 10, 11)
    )

    // ─── Mapping Functions ────────────────────────────────────

    /**
     * Map 12 UI band gains to native device band gains using logarithmic interpolation.
     *
     * @param uiGains List of 12 gain values from the UI (-12 to +12 dB)
     * @param nativeFrequencies Native device band center frequencies in Hz
     * @return List of gain values mapped to native bands
     */
    fun mapToNativeBands(
        uiGains: List<Double>,
        nativeFrequencies: List<Int>
    ): List<Double> {
        if (nativeFrequencies.isEmpty()) return emptyList()

        return nativeFrequencies.map { nativeFreq ->
            interpolateGain(nativeFreq.toDouble(), uiFrequencies, uiGains)
        }
    }

    /**
     * Interpolate a gain value at a target frequency.
     * Uses logarithmic interpolation for natural-sounding EQ curves.
     *
     * @param targetFreq The frequency to interpolate at (in Hz)
     * @param freqs Reference frequencies (in Hz)
     * @param gains Gain values at the reference frequencies (in dB)
     * @return Interpolated gain at targetFreq
     */
    fun interpolateGain(
        targetFreq: Double,
        freqs: List<Int>,
        gains: List<Double>
    ): Double {
        if (freqs.isEmpty() || gains.isEmpty()) return 0.0
        if (freqs.size != gains.size) return 0.0

        // Clamp to edges if outside range
        if (targetFreq <= freqs.first()) return gains.first()
        if (targetFreq >= freqs.last()) return gains.last()

        // Find the bracketing frequencies and interpolate logarithmically
        for (i in 0 until freqs.size - 1) {
            if (freqs[i] <= targetFreq && freqs[i + 1] >= targetFreq) {
                val logTarget = log(targetFreq)
                val logLow = log(freqs[i].toDouble())
                val logHigh = log(freqs[i + 1].toDouble())

                // Avoid division by zero (shouldn't happen with valid data)
                val denominator = logHigh - logLow
                if (denominator == 0.0) return gains[i]

                val t = (logTarget - logLow) / denominator
                return gains[i] + t * (gains[i + 1] - gains[i])
            }
        }

        return 0.0
    }

    /**
     * Convert a preset name into a 12-band gain list.
     *
     * @param presetName Name of the preset (e.g., "Rock", "Pop")
     * @return List of 12 gain values, or null if preset not found
     */
    fun presetToBands(presetName: String): List<Double>? {
        val curve = presetCurves[presetName] ?: return null

        val sortedFreqs = curve.keys.toList().sorted()
        val sortedGains = sortedFreqs.map { curve[it]!! }

        return uiFrequencies.map { freq ->
            interpolateGain(freq.toDouble(), sortedFreqs, sortedGains)
        }
    }

    /**
     * Clamp a gain value to the valid EQ range.
     */
    fun clampGain(gainDb: Double): Double = gainDb.coerceIn(MIN_GAIN_DB, MAX_GAIN_DB)

    /**
     * Clamp bass boost to valid range.
     */
    fun clampBassBoost(gainDb: Double): Double = gainDb.coerceIn(MIN_BASS_DB, MAX_BASS_DB)

    /**
     * Clamp loudness to valid range.
     */
    fun clampLoudness(gainDb: Double): Double = gainDb.coerceIn(MIN_LOUDNESS_DB, MAX_LOUDNESS_DB)

    /**
     * Convert bass boost dB to Android BassBoost strength (0-1000).
     */
    fun bassBoostToStrength(gainDb: Double): Int {
        return ((gainDb / MAX_BASS_DB) * 1000).toInt().coerceIn(0, 1000)
    }

    /**
     * Convert virtualizer 0-1 float to Android Virtualizer strength (0-1000).
     */
    fun virtualizerToStrength(strength: Double): Int {
        return (strength * 1000).toInt().coerceIn(0, 1000)
    }

    /**
     * Convert dB to Android millibels (used by Equalizer.setBandLevel).
     */
    fun dbToMillibels(db: Double): Short {
        return (db * 100).toInt().toShort()
    }

    /**
     * Get the visual band indices for a given visual band count.
     */
    fun getVisualBandIndices(visualBandCount: Int): List<Int> {
        return bandSelections[visualBandCount] ?: bandSelections[5]!!
    }
}
