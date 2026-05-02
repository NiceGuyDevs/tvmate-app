/// Latest Live TV category + focused channel, updated from [LiveTvScreen].
/// Read when the app goes to background to persist session restore.
class LiveTvSessionSnapshot {
  LiveTvSessionSnapshot._();

  static String? categoryId;
  static String? channelId;

  static void update({required String categoryId, required String channelId}) {
    LiveTvSessionSnapshot.categoryId = categoryId;
    LiveTvSessionSnapshot.channelId = channelId;
  }

  static void clear() {
    categoryId = null;
    channelId = null;
  }
}
