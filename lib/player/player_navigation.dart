import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../account/access_gate.dart';
import '../account/paywall_screen.dart';
import '../data/live_hero_preview_audio_store.dart';
import '../data/live_hero_preview_coordinator.dart';
import '../data/lightning_switch_store.dart';
import '../data/performance_tier_store.dart';
import '../ui/live_tv/live_preview_channel.dart';
import 'live_lineup_item.dart';
import 'playback_resume_store.dart';
import 'player_browse_restore.dart';
import 'player_screen.dart';
import 'windows/windows_vod_player_screen.dart';

/// Pushes fullscreen player and restores the previous focus node when popped.
///
/// When [onPlayerClosed] is set, it receives [PlayerBrowseRestore] from the
/// route (e.g. last live channel after in-player UP/DOWN); default focus
/// restoration is skipped so the caller can refocus by id.
Future<void> openTvMatePlayer(
  BuildContext context, {
  required String title,
  required String streamUrl,
  required bool isLive,
  /// VOD: synopsis / episode text for the Up info banner.
  String? contentDescription,
  List<LiveLineupItem>? liveLineup,
  int initialLiveIndex = 0,
  String? resumeContentId,
  bool startFromBeginning = false,
  String? browseRestoreMovieId,
  String? browseRestoreSeriesId,
  String? liveChannelId,
  String? liveEpgXmltvId,
  /// Live: current browse category / favorite pill id (for parental lock-from-player).
  String? liveViewCategoryId,
  /// VOD: OpenSubtitles search query (title / episode); optional — falls back to [title] and stream name.
  String? subtitleSearchQuery,
  /// VOD: poster/backdrop URL for offline download metadata (Android).
  String? vodPosterUrl,
  void Function(PlayerBrowseRestore? result)? onPlayerClosed,

  /// When true, skip refocusing the widget that had focus before the player
  /// (e.g. Live TV / My Space restore focus by channel id instead).
  bool suppressPreviousFocusRestore = false,
}) async {
  if (startFromBeginning && resumeContentId != null) {
    await PlaybackResumeStore.clear(resumeContentId);
  }
  if (!context.mounted) return;

  // Freemium browse mode: if subscription/trial is expired the inline shell
  // paywall may have been dismissed so the user could browse. Re-prompt as a
  // dismissable full-screen route on every playback attempt instead of
  // launching the player.
  // If the cached access state is missing or stale (e.g. the user just signed
  // out and we still hold a NO_TOKEN result, or we hit a transient network
  // error), force a fresh check before deciding so the gate can't be skipped
  // due to stale state.
  var gate = accessGate.lastResult;
  const stale = {'NO_TOKEN', 'NETWORK_ERROR'};
  if (gate == null || (!gate.allowed && stale.contains(gate.reason))) {
    await accessGate.check();
    if (!context.mounted) return;
    gate = accessGate.lastResult;
  }
  if (gate != null && gate.needsSubscription) {
    await PaywallScreen.show(context);
    return;
  }

  final navigator = Navigator.of(context);
  final previousFocus = FocusManager.instance.primaryFocus;
  // Optimized, or Full with Lightning off: dispose hero (same as Optimized).
  // Full + Lightning on: pause hero for faster resume when leapfrog pool is active.
  final strictSinglePlayer = performanceTierStore.isOptimizedEffective ||
      !lightningSwitchStore.enabled;
  if (LivePreviewChannel.supported) {
    try {
      if (strictSinglePlayer) {
        await LivePreviewChannel.dispose();
        LiveHeroPreviewCoordinator.markReleasedForFullscreen();
      } else {
        await LivePreviewChannel.pauseForFullscreen();
      }
    } catch (_) {}
  } else if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    // Hero uses a separate media_kit instance; release before fullscreen (matches strict path).
    LiveHeroPreviewCoordinator.markReleasedForFullscreen();
  }
  final restore = await navigator.push<PlayerBrowseRestore?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) {
        // Windows desktop VOD: dedicated entry (same [PlayerScreen] implementation for parity).
        if (!isLive &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows) {
          return WindowsVodPlayerScreen(
            title: title,
            streamUrl: streamUrl,
            contentDescription: contentDescription,
            liveLineup: liveLineup,
            initialLiveIndex: initialLiveIndex,
            resumeContentId: resumeContentId,
            browseMovieId: browseRestoreMovieId,
            browseSeriesId: browseRestoreSeriesId,
            liveChannelId: liveChannelId,
            liveEpgXmltvId: liveEpgXmltvId,
            liveViewCategoryId: liveViewCategoryId,
            subtitleSearchQuery: subtitleSearchQuery,
            vodPosterUrl: vodPosterUrl,
          );
        }
        return PlayerScreen(
          title: title,
          streamUrl: streamUrl,
          isLive: isLive,
          contentDescription: contentDescription,
          liveLineup: liveLineup,
          initialLiveIndex: initialLiveIndex,
          resumeContentId: resumeContentId,
          browseMovieId: browseRestoreMovieId,
          browseSeriesId: browseRestoreSeriesId,
          liveChannelId: liveChannelId,
          liveEpgXmltvId: liveEpgXmltvId,
          liveViewCategoryId: liveViewCategoryId,
          subtitleSearchQuery: subtitleSearchQuery,
          vodPosterUrl: vodPosterUrl,
        );
      },
    ),
  );

  void schedulePreviousFocusRestore() {
    if (suppressPreviousFocusRestore) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final n = previousFocus;
      if (n == null) return;
      final ctx = n.context;
      if (ctx == null || !ctx.mounted) return;
      try {
        if (n.canRequestFocus) {
          n.requestFocus();
        }
      } catch (_) {}
    });
  }

  Future<void> notifyHeroPreviewFullscreenEnded() async {
    await liveHeroPreviewAudioStore.ensureLoaded();
    if (LivePreviewChannel.supported) {
      if (strictSinglePlayer) {
        LiveHeroPreviewCoordinator.markFullscreenRoutePopped();
      } else {
        try {
          await LivePreviewChannel.resumeAfterFullscreen();
          await LivePreviewChannel.setUserMuted(liveHeroPreviewAudioStore.muted);
        } catch (_) {}
      }
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      LiveHeroPreviewCoordinator.markFullscreenRoutePopped();
    }
  }

  if (isLive) {
    // Live: re-bootstrap hero preview after refocus; defer onPlayerClosed until layout settles.
    await notifyHeroPreviewFullscreenEnded();
    schedulePreviousFocusRestore();
    if (onPlayerClosed != null && context.mounted) {
      final r = restore;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onPlayerClosed(r);
        }
      });
    }
  } else {
    // VOD: run onPlayerClosed synchronously before preview resume so details
    // screens can mark "player just closed" before a duplicate system-back
    // pops the details route (browse ← details in one remote press).
    if (onPlayerClosed != null && context.mounted) {
      onPlayerClosed(restore);
    }
    await notifyHeroPreviewFullscreenEnded();
    schedulePreviousFocusRestore();
  }
}
