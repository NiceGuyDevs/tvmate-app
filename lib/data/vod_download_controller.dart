import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_nav.dart';
import '../l10n/app_localizations.dart';
import '../player/vod_download_helpers.dart';
import 'vod_offline_library.dart';

/// Phases shown on the global download strip (Windows / Android VOD).
enum VodDownloadPhase {
  idle,
  downloading,
  /// Copying temp file into the user Downloads folder (no native dialog — avoids Windows freeze).
  copying,
}

/// App-wide VOD download: progress, cancel, persists across routes.
///
/// **Windows:** completed files go to the user **Downloads** folder (no Save As dialog).
/// **Android:** completed files go to app-private **offline VOD** storage and are listed
/// under Account → Offline downloads.
final class VodDownloadController extends ChangeNotifier {
  VodDownloadController._();
  static final VodDownloadController instance = VodDownloadController._();

  VodDownloadPhase _phase = VodDownloadPhase.idle;
  String _title = '';
  int _receivedBytes = 0;
  int? _totalBytes;
  bool _cancelRequested = false;
  HttpClient? _activeClient;

  VodDownloadPhase get phase => _phase;
  String get title => _title;
  int get receivedBytes => _receivedBytes;
  int? get totalBytes => _totalBytes;

  bool get isActive => _phase != VodDownloadPhase.idle;

  /// Strip: show **Cancel** only while bytes are still streaming.
  bool get canCancelDownload => _phase == VodDownloadPhase.downloading;

  /// Null when total unknown or zero — UI uses indeterminate bar.
  double? get progressFraction {
    final t = _totalBytes;
    if (t == null || t <= 0) return null;
    return (_receivedBytes / t).clamp(0.0, 1.0);
  }

  /// Starts a download in the background. Ignored if one is already running.
  ///
  /// [posterUrl] is stored for the Android offline library (optional).
  void start({
    required String streamUrl,
    required String displayTitle,
    String? posterUrl,
  }) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isAndroid)) {
      return;
    }
    if (_phase != VodDownloadPhase.idle) {
      _snackAlreadyRunning();
      return;
    }
    unawaited(_run(streamUrl, displayTitle, posterUrl: posterUrl));
  }

  void cancel() {
    if (_phase != VodDownloadPhase.downloading) return;
    _cancelRequested = true;
    _activeClient?.close(force: true);
  }

  void _snackAlreadyRunning() {
    final ctx = AppNav.rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);
    AppNav.rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(l10n.playerVodDownloadAlreadyInProgress)),
    );
  }

  void _resetIdle() {
    _phase = VodDownloadPhase.idle;
    _title = '';
    _receivedBytes = 0;
    _totalBytes = null;
    _cancelRequested = false;
    _activeClient = null;
    notifyListeners();
  }

  Future<Directory> _destinationDirectory() async {
    if (Platform.isAndroid) {
      return VodOfflineLibrary.instance.rootDirectory();
    }
    final d = await getDownloadsDirectory();
    if (d != null && await d.exists()) {
      return d;
    }
    final user = Platform.environment['USERPROFILE'];
    if (user != null && user.isNotEmpty) {
      final fallback = Directory(p.join(user, 'Downloads'));
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      return fallback;
    }
    throw StateError('Downloads folder not available');
  }

  Future<String> _uniquePathIn(Directory dir, String fileName) async {
    var path = p.join(dir.path, fileName);
    if (!await File(path).exists()) {
      return path;
    }
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    for (var i = 1; i < 10000; i++) {
      path = p.join(dir.path, '${base}_$i$ext');
      if (!await File(path).exists()) {
        return path;
      }
    }
    return p.join(
      dir.path,
      '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
  }

  Future<void> _run(
    String streamUrl,
    String displayTitle, {
    String? posterUrl,
  }) async {
    _title = displayTitle;
    _phase = VodDownloadPhase.downloading;
    _receivedBytes = 0;
    _totalBytes = null;
    _cancelRequested = false;
    notifyListeners();

    final uri = Uri.parse(streamUrl);
    HttpClient? client;
    File? outFile;

    try {
      client = HttpClient();
      _activeClient = client;
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
      final response = await request.close();
      final code = response.statusCode;
      if (code != HttpStatus.ok && code != HttpStatus.partialContent) {
        throw HttpException('HTTP $code', uri: uri);
      }

      final cl = response.contentLength;
      _totalBytes = cl >= 0 ? cl : null;
      notifyListeners();

      final tempDir = await getTemporaryDirectory();
      final path = p.join(
        tempDir.path,
        'tvmate_vod_${DateTime.now().millisecondsSinceEpoch}.tmp',
      );
      outFile = File(path);

      final sink = outFile.openWrite();
      var lastNotifyMs = DateTime.now().millisecondsSinceEpoch;
      var bytesSinceNotify = 0;
      const minNotifyIntervalMs = 200;
      const minBytesBeforeNotify = 256 * 1024;

      try {
        await for (final chunk in response) {
          if (_cancelRequested) {
            break;
          }
          sink.add(chunk);
          _receivedBytes += chunk.length;
          bytesSinceNotify += chunk.length;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastNotifyMs >= minNotifyIntervalMs ||
              bytesSinceNotify >= minBytesBeforeNotify) {
            lastNotifyMs = now;
            bytesSinceNotify = 0;
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }

      notifyListeners();

      if (_cancelRequested) {
        try {
          await outFile.delete();
        } catch (_) {}
        _resetIdle();
        return;
      }

      final len = await outFile.length();
      if (len == 0) {
        try {
          await outFile.delete();
        } catch (_) {}
        throw const FormatException('empty');
      }
      final take = len < 16 ? len : 16;
      final head = await outFile.openRead(0, take).first;
      final probe = String.fromCharCodes(head).trimLeft();
      if (probe.startsWith('#EXTM3U')) {
        try {
          await outFile.delete();
        } catch (_) {}
        throw const VodHlsPlaylistException();
      }

      _phase = VodDownloadPhase.copying;
      notifyListeners();

      final navContext = AppNav.rootNavigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) {
        try {
          await outFile.delete();
        } catch (_) {}
        _resetIdle();
        return;
      }
      // ignore: use_build_context_synchronously
      final l10n = AppLocalizations.of(navContext);

      final destDir = await _destinationDirectory();
      final contentType = response.headers.value(HttpHeaders.contentTypeHeader);
      final suggested = vodDownloadSuggestedFileName(
        displayTitle,
        streamUrl,
        httpContentType: contentType,
      );
      final destPath = await _uniquePathIn(destDir, suggested);

      final file = outFile;
      await Future<void>.delayed(Duration.zero);

      await file.copy(destPath);
      await file.delete();
      outFile = null;

      if (Platform.isAndroid) {
        int sz;
        try {
          sz = await File(destPath).length();
        } catch (_) {
          sz = 0;
        }
        await VodOfflineLibrary.instance.addEntry(
          title: displayTitle,
          filePath: destPath,
          sizeBytes: sz,
          posterUrl: posterUrl,
        );
      }

      AppNav.rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            Platform.isAndroid
                ? l10n.playerVodDownloadSavedShort(displayTitle)
                : l10n.playerVodDownloadSaved(destPath),
          ),
        ),
      );
      _resetIdle();
    } on VodHlsPlaylistException {
      try {
        await outFile?.delete();
      } catch (_) {}
      _snackFromL10n((l) => l.playerVodDownloadPlaylistNotSupported);
      _resetIdle();
    } catch (e, _) {
      if (_cancelRequested) {
        try {
          await outFile?.delete();
        } catch (_) {}
        _resetIdle();
        return;
      }
      try {
        await outFile?.delete();
      } catch (_) {}
      _snackError(e);
      _resetIdle();
    } finally {
      client?.close(force: true);
      _activeClient = null;
    }
  }

  void _snackFromL10n(String Function(AppLocalizations l10n) message) {
    final ctx = AppNav.rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);
    AppNav.rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message(l10n))),
    );
  }

  void _snackError(Object e) {
    final ctx = AppNav.rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);
    final msg = e is FormatException && e.message == 'empty'
        ? l10n.playerVodDownloadFailed(l10n.playerVodDownloadErrorEmpty)
        : l10n.playerVodDownloadFailed(_formatError(e));
    AppNav.rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  static String _formatError(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }
}
