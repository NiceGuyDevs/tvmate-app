/// Prepared for future audio / subtitle UI; populated from native ExoPlayer when ready.
class PlayerMediaTrack {
  const PlayerMediaTrack({
    required this.id,
    this.label,
    this.language,
  });

  final String id;
  final String? label;
  final String? language;
}

class TracksSnapshot {
  const TracksSnapshot({
    required this.audioTracks,
    required this.subtitleTracks,
    this.videoHeights = const [],
  });

  final List<PlayerMediaTrack> audioTracks;
  final List<PlayerMediaTrack> subtitleTracks;

  /// Distinct video track heights from the manifest (descending), when known.
  final List<int> videoHeights;

  static const TracksSnapshot empty = TracksSnapshot(
    audioTracks: [],
    subtitleTracks: [],
    videoHeights: [],
  );

  factory TracksSnapshot.fromPayload(dynamic raw) {
    final m = Map<Object?, Object?>.from(raw as Map);
    List<PlayerMediaTrack> parseList(Object? key) {
      final list = m[key];
      if (list is! List) return [];
      return list.map((e) {
        final tm = Map<Object?, Object?>.from(e as Map);
        return PlayerMediaTrack(
          id: tm['id'] as String? ?? '',
          label: tm['label'] as String?,
          language: tm['language'] as String?,
        );
      }).where((t) => t.id.isNotEmpty).toList();
    }

    List<int> parseHeights() {
      final list = m['videoHeights'];
      if (list is! List) return const [];
      final out = <int>[];
      for (final e in list) {
        if (e is int) {
          if (e > 0) out.add(e);
        } else if (e is double) {
          final v = e.toInt();
          if (v > 0) out.add(v);
        }
      }
      return out;
    }

    return TracksSnapshot(
      audioTracks: parseList('audioTracks'),
      subtitleTracks: parseList('subtitleTracks'),
      videoHeights: parseHeights(),
    );
  }
}
