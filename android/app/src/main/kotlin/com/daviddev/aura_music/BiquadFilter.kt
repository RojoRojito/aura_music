package com.daviddev.aura_music

import kotlin.math.*

class BiquadFilter {
    enum class FilterType {
        PEAK, LOW_SHELF, HIGH_SHELF, NOTCH
    }

    private var b0 = 0.0
    private var b1 = 0.0
    private var b2 = 0.0
    private var a1 = 0.0
    private var a2 = 0.0

    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    fun process(sample: Float): Float {
        val x = sample.toDouble()
        val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        
        return y.toFloat()
    }

    fun reset() {
        x1 = 0.0; x2 = 0.0; y1 = 0.0; y2 = 0.0
    }

    fun updateCoefficients(type: FilterType, frequency: Double, gainDb: Double, q: Double, sampleRate: Double) {
        val omega = 2.0 * PI * frequency / sampleRate
        val sinW0 = sin(omega)
        val cosW0 = cos(omega)
        val alpha = sinW0 / (2.0 * q)
        val A = 10.0.pow(gainDb / 40.0)

        var b0_raw = 0.0
        var b1_raw = 0.0
        var b2_raw = 0.0
        var a0 = 0.0
        var a1_raw = 0.0
        var a2_raw = 0.0

        when (type) {
            FilterType.PEAK -> {
                b0_raw = 1.0 + alpha * A
                b1_raw = -2.0 * cosW0
                b2_raw = 1.0 - alpha * A
                a0 = 1.0 + alpha / A
                a1_raw = -2.0 * cosW0
                a2_raw = 1.0 - alpha / A
            }
            FilterType.LOW_SHELF -> {
                val alphaS = sinW0 / 2.0 * sqrt(2.0) * A
                b0_raw = A * ((A + 1.0) - (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alphaS)
                b1_raw = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosW0)
                b2_raw = A * ((A + 1.0) + (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alphaS)
                a0 = (A + 1.0) + (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alphaS
                a1_raw = -2.0 * ((A - 1.0) + (A + 1.0) * cosW0)
                a2_raw = (A + 1.0) + (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alphaS
            }
            FilterType.HIGH_SHELF -> {
                val alphaS = sinW0 / 2.0 * sqrt(2.0) * A
                b0_raw = A * ((A + 1.0) + (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alphaS)
                b1_raw = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW0)
                b2_raw = A * ((A + 1.0) - (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alphaS)
                a0 = (A + 1.0) - (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alphaS
                a1_raw = 2.0 * ((A - 1.0) - (A + 1.0) * cosW0)
                a2_raw = (A + 1.0) - (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alphaS
            }
            FilterType.NOTCH -> {
                b0_raw = 1.0
                b1_raw = -2.0 * cosW0
                b2_raw = 1.0
                a0 = 1.0 + alpha
                a1_raw = -2.0 * cosW0
                a2_raw = 1.0 - alpha
            }
        }

        b0 = b0_raw / a0
        b1 = b1_raw / a0
        b2 = b2_raw / a0
        a1 = a1_raw / a0
        a2 = a2_raw / a0
    }
}
