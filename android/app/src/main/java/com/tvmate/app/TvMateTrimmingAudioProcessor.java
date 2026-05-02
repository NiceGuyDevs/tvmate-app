/*
 * Copyright (C) 2017 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * (Vendored from androidx.media3.exoplayer.audio.TrimmingAudioProcessor)
 */
package com.tvmate.app;

import static java.lang.Math.min;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.audio.BaseAudioProcessor;
import androidx.media3.common.util.Util;
import java.nio.ByteBuffer;

/**
 * Trims PCM samples from the start/end of the stream (negative audio delay ms = trim start).
 */
public final class TvMateTrimmingAudioProcessor extends BaseAudioProcessor {

  private static final @C.PcmEncoding int OUTPUT_ENCODING = C.ENCODING_PCM_16BIT;

  private int trimStartFrames;
  private int trimEndFrames;
  private boolean reconfigurationPending;

  private int pendingTrimStartBytes;
  private byte[] endBuffer;
  private int endBufferSize;
  private long trimmedFrameCount;

  public TvMateTrimmingAudioProcessor() {
    endBuffer = Util.EMPTY_BYTE_ARRAY;
  }

  public void setTrimFrameCount(int trimStartFrames, int trimEndFrames) {
    this.trimStartFrames = trimStartFrames;
    this.trimEndFrames = trimEndFrames;
  }

  public void resetTrimmedFrameCount() {
    trimmedFrameCount = 0;
  }

  public long getTrimmedFrameCount() {
    return trimmedFrameCount;
  }

  @Override
  public long getDurationAfterProcessorApplied(long durationUs) {
    return durationUs
        - Util.sampleCountToDurationUs(
            trimEndFrames + trimStartFrames, inputAudioFormat.sampleRate);
  }

  @Override
  public AudioProcessor.AudioFormat onConfigure(AudioProcessor.AudioFormat inputAudioFormat)
      throws AudioProcessor.UnhandledAudioFormatException {
    if (inputAudioFormat.encoding != OUTPUT_ENCODING) {
      throw new AudioProcessor.UnhandledAudioFormatException(inputAudioFormat);
    }
    reconfigurationPending = true;
    return trimStartFrames != 0 || trimEndFrames != 0
        ? inputAudioFormat
        : AudioProcessor.AudioFormat.NOT_SET;
  }

  @Override
  public void queueInput(ByteBuffer inputBuffer) {
    int position = inputBuffer.position();
    int limit = inputBuffer.limit();
    int remaining = limit - position;

    if (remaining == 0) {
      return;
    }

    int trimBytes = min(remaining, pendingTrimStartBytes);
    trimmedFrameCount += trimBytes / inputAudioFormat.bytesPerFrame;
    pendingTrimStartBytes -= trimBytes;
    inputBuffer.position(position + trimBytes);
    if (pendingTrimStartBytes > 0) {
      return;
    }
    remaining -= trimBytes;

    int remainingBytesToOutput = endBufferSize + remaining - endBuffer.length;
    ByteBuffer buffer = replaceOutputBuffer(remainingBytesToOutput);

    int endBufferBytesToOutput = Util.constrainValue(remainingBytesToOutput, 0, endBufferSize);
    buffer.put(endBuffer, 0, endBufferBytesToOutput);
    remainingBytesToOutput -= endBufferBytesToOutput;

    int inputBufferBytesToOutput = Util.constrainValue(remainingBytesToOutput, 0, remaining);
    inputBuffer.limit(inputBuffer.position() + inputBufferBytesToOutput);
    buffer.put(inputBuffer);
    inputBuffer.limit(limit);
    remaining -= inputBufferBytesToOutput;

    endBufferSize -= endBufferBytesToOutput;
    System.arraycopy(endBuffer, endBufferBytesToOutput, endBuffer, 0, endBufferSize);
    inputBuffer.get(endBuffer, endBufferSize, remaining);
    endBufferSize += remaining;

    buffer.flip();
  }

  @Override
  public ByteBuffer getOutput() {
    if (super.isEnded() && endBufferSize > 0) {
      replaceOutputBuffer(endBufferSize).put(endBuffer, 0, endBufferSize).flip();
      endBufferSize = 0;
    }
    return super.getOutput();
  }

  @Override
  public boolean isEnded() {
    return super.isEnded() && endBufferSize == 0;
  }

  @Override
  protected void onQueueEndOfStream() {
    if (reconfigurationPending) {
      if (endBufferSize > 0) {
        trimmedFrameCount += endBufferSize / inputAudioFormat.bytesPerFrame;
      }
      endBufferSize = 0;
    }
  }

  @Override
  protected void onFlush() {
    if (reconfigurationPending) {
      reconfigurationPending = false;
      endBuffer = new byte[trimEndFrames * inputAudioFormat.bytesPerFrame];
      pendingTrimStartBytes = trimStartFrames * inputAudioFormat.bytesPerFrame;
    }
    endBufferSize = 0;
  }

  @Override
  protected void onReset() {
    endBuffer = Util.EMPTY_BYTE_ARRAY;
  }
}
