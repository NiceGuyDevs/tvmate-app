class PlayerNativeEvent {
  const PlayerNativeEvent({
    required this.type,
    this.playbackState,
    this.isPlaying,
    this.positionMs,
    this.bufferedMs,
    this.durationMs,
    this.attempt,
    this.maxAttempts,
    this.message,
    this.videoWidth,
    this.videoHeight,
    this.bitrate,
    this.cueLines,
  });

  final String type;
  final String? playbackState;
  final bool? isPlaying;
  final int? positionMs;
  final int? bufferedMs;
  final int? durationMs;
  final int? attempt;
  final int? maxAttempts;
  final String? message;

  /// Decoded video size from the selected track (-1 when unknown).
  final int? videoWidth;
  final int? videoHeight;

  /// Bits per second from format when available (-1 when unknown).
  final int? bitrate;

  /// Active subtitle line(s) from ExoPlayer [TextOutput] (`type == "cues"`).
  final List<String>? cueLines;

  factory PlayerNativeEvent.fromPayload(dynamic raw) {
    final m = Map<Object?, Object?>.from(raw as Map);
    int? intVal(Map<Object?, Object?> map, Object? k) {
      final v = map[k];
      if (v is int) return v;
      if (v is double) return v.toInt();
      return null;
    }

    List<String>? parseCueLines(dynamic list) {
      if (list is! List) return null;
      final out = <String>[];
      for (final item in list) {
        final s = item.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
      return out;
    }

    return PlayerNativeEvent(
      type: m['type'] as String? ?? 'unknown',
      playbackState: m['playbackState'] as String?,
      isPlaying: m['isPlaying'] as bool?,
      positionMs: intVal(m, 'positionMs'),
      bufferedMs: intVal(m, 'bufferedMs'),
      durationMs: intVal(m, 'durationMs'),
      attempt: intVal(m, 'attempt'),
      maxAttempts: intVal(m, 'maxAttempts'),
      message: m['message'] as String?,
      videoWidth: intVal(m, 'videoWidth'),
      videoHeight: intVal(m, 'videoHeight'),
      bitrate: intVal(m, 'bitrate'),
      cueLines: parseCueLines(m['lines']),
    );
  }

  bool get isBuffering => playbackState == 'buffering';
}
