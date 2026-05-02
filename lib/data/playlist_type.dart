enum PlaylistType {
  xtream,
  m3u,
}

extension PlaylistTypeCodec on PlaylistType {
  String get storageValue => name;

  static PlaylistType fromStorage(String? raw) {
    switch (raw) {
      case 'm3u':
        return PlaylistType.m3u;
      case 'xtream':
      default:
        return PlaylistType.xtream;
    }
  }
}
