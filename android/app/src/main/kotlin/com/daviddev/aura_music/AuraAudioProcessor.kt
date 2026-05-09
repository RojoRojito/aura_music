package com.daviddev.aura_music

import java.nio.ByteBuffer
import java.nio.ByteOrder
import com.google.android.exoplayer2.audio.AudioProcessor
import com.google.android.exoplayer2.audio.AudioFormat

class AuraAudioProcessor(private val equalizerEngine: EqualizerEngine) : AudioProcessor {
    private var currentFormat: AudioFormat = AudioProcessor.EMPTY_AUDIO_FORMAT
    private var outputBuffer: ByteBuffer = ByteBuffer.allocateDirect(0).order(ByteOrder.nativeOrder())
    private var inputEnded = false

    override fun configure(inputFormat: AudioFormat): Boolean {
        if (inputFormat != currentFormat) {
            currentFormat = inputFormat
            equalizerEngine.setSampleRate(inputFormat.sampleRate)
            return true
        }
        return false
    }

    override fun isActive(): Boolean = true

    override fun queueInput(inputBuffer: ByteBuffer) {
        if (!inputBuffer.hasRemaining()) return
        val remaining = inputBuffer.remaining()
        
        if (outputBuffer.capacity() < remaining) {
            outputBuffer = ByteBuffer.allocateDirect(remaining * 2)
                .order(ByteOrder.nativeOrder())
        }
        outputBuffer.clear()
        
        val inputCopy = inputBuffer.slice().order(ByteOrder.nativeOrder())
        val shorts = ShortArray(remaining / 2)
        inputCopy.asShortBuffer().get(shorts)
        inputBuffer.position(inputBuffer.limit())
        
        equalizerEngine.processAudio(shorts, currentFormat.channelCount)
        
        outputBuffer.asShortBuffer().put(shorts)
        outputBuffer.limit(remaining)
        outputBuffer.position(0)
    }

    override fun getOutput(): ByteBuffer {
        val buffer = outputBuffer.flip() as ByteBuffer
        return buffer
    }

    override fun queueEndOfStream() {
        inputEnded = true
    }

    override fun isEnded(): Boolean {
        return inputEnded && !outputBuffer.hasRemaining()
    }

    override fun flush() {
        outputBuffer.clear()
        inputEnded = false
        equalizerEngine.reset()
    }

    override fun reset() {
        flush()
    }
}
