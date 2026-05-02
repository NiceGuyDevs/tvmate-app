package com.tvmate.app

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import java.nio.ByteBuffer
import java.util.ArrayDeque
import kotlin.math.min

/**
 * Prepends silence to PCM (positive audio delay ms — audio late vs video).
 * Buffers decoder output while emitting silence in chunks (one output per [queueInput] max).
 */
class TvMateLeadingSilenceAudioProcessor : BaseAudioProcessor() {

    /** Positive delay in ms (audio late vs video). Not a Kotlin property — avoids JVM clash with [setDelayMs]. */
    @Volatile
    private var configuredDelayMs: Int = 0

    private var pendingSilenceBytes: Long = 0
    private val queuedChunks: ArrayDeque<ByteArray> = ArrayDeque()

    fun setDelayMs(ms: Int) {
        configuredDelayMs = ms.coerceIn(0, 10_000)
    }

    override fun onConfigure(
        inputAudioFormat: AudioProcessor.AudioFormat,
    ): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        if (configuredDelayMs <= 0) {
            pendingSilenceBytes = 0
            queuedChunks.clear()
            return AudioProcessor.AudioFormat.NOT_SET
        }
        val frames = inputAudioFormat.sampleRate.toLong() * configuredDelayMs / 1000L
        pendingSilenceBytes = frames * inputAudioFormat.bytesPerFrame
        queuedChunks.clear()
        return inputAudioFormat
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        if (!isActive) return
        val rem = inputBuffer.remaining()
        if (rem > 0) {
            val copy = ByteArray(rem)
            inputBuffer.get(copy)
            queuedChunks.addLast(copy)
        }
        emitOneOutput()
    }

    private fun emitOneOutput() {
        if (pendingSilenceBytes > 0) {
            val chunk = min(pendingSilenceBytes, 65536).toInt()
            val buf = replaceOutputBuffer(chunk)
            val zero = 0.toByte()
            for (i in 0 until chunk) {
                buf.put(zero)
            }
            buf.flip()
            pendingSilenceBytes -= chunk
            return
        }
        if (queuedChunks.isEmpty()) return
        val chunk = queuedChunks.removeFirst()
        val out = replaceOutputBuffer(chunk.size)
        out.put(chunk)
        out.flip()
    }

    override fun onQueueEndOfStream() {}

    override fun onFlush() {
        queuedChunks.clear()
        if (!isActive || inputAudioFormat == AudioProcessor.AudioFormat.NOT_SET) {
            pendingSilenceBytes = 0
            return
        }
        if (configuredDelayMs > 0) {
            val frames = inputAudioFormat.sampleRate.toLong() * configuredDelayMs / 1000L
            pendingSilenceBytes = frames * inputAudioFormat.bytesPerFrame
        } else {
            pendingSilenceBytes = 0
        }
    }

    override fun onReset() {
        queuedChunks.clear()
    }
}
