import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import '../data/vod_download_controller.dart';

export 'vod_download_helpers.dart';

/// Enqueues a VOD download (Windows: user Downloads; Android: app offline folder).
void startVodDownload({
  required String streamUrl,
  required String title,
  String? posterUrl,
}) {
  if (kIsWeb || (!Platform.isWindows && !Platform.isAndroid)) return;
  VodDownloadController.instance.start(
    streamUrl: streamUrl,
    displayTitle: title,
    posterUrl: posterUrl,
  );
}

/// @nodoc — use [startVodDownload].
void startWindowsVodDownload({
  required String streamUrl,
  required String title,
}) {
  startVodDownload(streamUrl: streamUrl, title: title);
}
