import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted hero live-preview **audio** mute (video keeps playing). Default: sound on.
final LiveHeroPreviewAudioStore liveHeroPreviewAudioStore =
    LiveHeroPreviewAudioStore._();

class LiveHeroPreviewAudioStore extends ChangeNotifier {
  LiveHeroPreviewAudioStore._();

  static const _kMuted = 'tvmatepro_hero_preview_audio_muted_v1';

  bool _muted = false;
  bool _loaded = false;

  bool get muted => _muted;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_kMuted) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMuted(bool value) async {
    await ensureLoaded();
    if (_muted == value) return;
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMuted, value);
    notifyListeners();
  }

  Future<void> toggleMuted() => setMuted(!muted);
}
