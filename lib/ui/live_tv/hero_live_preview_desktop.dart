import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

/// Separate media_kit player for Live TV hero preview on Windows/macOS (fullscreen
/// uses another [PlayerService] instance).
final class HeroLivePreviewDesktopController {
  HeroLivePreviewDesktopController() {
    _player = mk.Player();
    _videoController = mkv.VideoController(_player);
  }

  late final mk.Player _player;
  late final mkv.VideoController _videoController;

  mkv.VideoController get videoController => _videoController;

  var _disposed = false;

  Future<void> load(String url) async {
    if (_disposed) return;
    final u = url.trim();
    if (u.isEmpty) return;
    await _player.open(mk.Media(u));
  }

  Future<void> play() async {
    if (_disposed) return;
    await _player.play();
  }

  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
  }

  Future<void> setUserMuted(bool muted) async {
    if (_disposed) return;
    await _player.setVolume(muted ? 0.0 : 100.0);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _player.dispose();
  }
}
