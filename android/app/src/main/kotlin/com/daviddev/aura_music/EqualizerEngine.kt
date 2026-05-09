package com.daviddev.aura_music

import kotlin.math.*

class EqualizerEngine {
    private val frequencies = doubleArrayOf(
        31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 
        2000.0, 4000.0, 8000.0, 12000.0, 16000.0, 20000.0
    )
    
    private val bandFilters = Array(12) { BiquadFilter() }
    private val bassFilter = BiquadFilter()
    
    private var virtualizerStrength = 0f
    private var enabled = true
    private var sampleRate = 44100
    private var haasBufferL = FloatArray(0)
    private var haasBufferR = FloatArray(0)
    private var haasPosL = 0
    private var haasPosR = 0
    
    private val currentGains = FloatArray(12) { 0f }
    private var currentBassGain = 0f

    fun setSampleRate(rate: Int) {
        this.sampleRate = rate
        val delaySamples = (rate * 0.02).toInt()
        haasBufferL = FloatArray(delaySamples)
        haasBufferR = FloatArray(delaySamples)
        haasPosL = 0
        haasPosR = 0
        
        for (i in 0 until 12) {
            updateBand(i, currentGains[i])
        }
        setBassBoost(currentBassGain)
    }

    fun setBandGain(index: Int, gainDb: Float) {
        if (index !in 0..11) return
        currentGains[index] = gainDb.coerceIn(-12f, 12f)
        updateBand(index, currentGains[index])
    }

    private fun updateBand(index: Int, gain: Float) {
        bandFilters[index].updateCoefficients(
            BiquadFilter.FilterType.PEAK,
            frequencies[index],
            gain.toDouble(),
            1.41,
            sampleRate.toDouble()
        )
    }

    fun setBassBoost(gainDb: Float) {
        currentBassGain = gainDb.coerceIn(0f, 15f)
        bassFilter.updateCoefficients(
            BiquadFilter.FilterType.LOW_SHELF,
            80.0,
            currentBassGain.toDouble(),
            0.707,
            sampleRate.toDouble()
        )
    }

    fun setVirtualizerStrength(strength: Float) {
        this.virtualizerStrength = strength.coerceIn(0f, 1f)
    }

    fun setEnabled(value: Boolean) {
        this.enabled = value
    }

    fun isEnabled(): Boolean = enabled

    fun reset() {
        bandFilters.forEach { it.reset() }
        bassFilter.reset()
        haasBufferL.fill(0f)
        haasBufferR.fill(0f)
        haasPosL = 0
        haasPosR = 0
    }

    fun processAudio(buffer: ShortArray, channelCount: Int) {
        if (!enabled) return

        for (i in 0 until buffer.size) {
            var sample = buffer[i].toFloat() / 32768f
            
            for (filter in bandFilters) {
                sample = filter.process(sample)
            }
            
            sample = bassFilter.process(sample)
            sample = sample.coerceIn(-1f, 1f)
            
            buffer[i] = (sample * 32768f).toInt().toShort()
        }
        
        if (channelCount == 2 && virtualizerStrength > 0f) {
            applyHaasEffect(buffer)
        }
    }

    private fun applyHaasEffect(buffer: ShortArray) {
        val bufSize = haasBufferL.size
        if (bufSize == 0) return
        val str = virtualizerStrength
        
        for (i in 0 until buffer.size step 2) {
            val left  = buffer[i].toFloat()  / 32768f
            val right = buffer[i+1].toFloat() / 32768f
            
            val delayedL = haasBufferL[haasPosL]
            val delayedR = haasBufferR[haasPosR]
            
            haasBufferL[haasPosL] = left
            haasBufferR[haasPosR] = right
            
            haasPosL = (haasPosL + 1) % bufSize
            haasPosR = (haasPosR + 1) % bufSize
            
            val outLeft  = (left  + delayedR * str).coerceIn(-1f, 1f)
            val outRight = (right + delayedL * str).coerceIn(-1f, 1f)
            
            buffer[i]   = (outLeft  * 32768f).toInt().toShort()
            buffer[i+1] = (outRight * 32768f).toInt().toShort()
        }
    }
}