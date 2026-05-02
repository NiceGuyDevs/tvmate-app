import 'package:flutter/foundation.dart';

/// When opening fullscreen playback, we [LivePreviewChannel.dispose] the hero preview so only
/// one ExoPlayer runs at a time. This notifies [HeroLivePreview] to clear its texture state
/// immediately and to re-[bootstrap] after the fullscreen route pops.
class LiveHeroPreviewCoordinator {
  LiveHeroPreviewCoordinator._();

  static final ValueNotifier<int> releasedForFullscreen = ValueNotifier(0);
  static final ValueNotifier<int> fullscreenRoutePopped = ValueNotifier(0);

  static void markReleasedForFullscreen() {
    releasedForFullscreen.value++;
  }

  static void markFullscreenRoutePopped() {
    fullscreenRoutePopped.value++;
  }
}
