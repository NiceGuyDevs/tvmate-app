import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data/epg_time_display.dart';
import '../data/playlist_epg_timezone_store.dart';
import '../theme/team_palette_theme.dart';
import '../ui/focus/tv_focusable.dart';
import '../xtream/xtream_short_epg_parser.dart';

/// Bumped when the fullscreen TV overlay layout changes (verify you see this in debug).
const int kPlayerTvOverlayBuild = 51;

/// Visual tokens — compact TV chrome (bottom-heavy, minimal video obscuring).
abstract final class PlayerTvOverlayTheme {
  static const Duration fadeDuration = Duration(milliseconds: 260);
  static const Duration autoHideDuration = Duration(seconds: 5);

  /// Max fraction of screen height for bottom gradient + controls.
  static const double bottomChromeHeightFraction = 0.32;
  static const double bottomChromeMinHeight = 168;
  static const double bottomChromeMaxHeight = 340;

  /// “On air” / “next” EPG accents (readable on dark cards).
  static const Color epgNowAccent = Color(0xFFE53935);
  static const Color epgNextAccent = Color(0xFF1E88E5);

  static const double headerTitleSize = 19;
  static const double metaFontSize = 13;
  static const double timeFontSize = 16;

  static const double seekTrackHeight = 10;
  static const double seekThumbRadius = 13;
  static const double playButtonSize = 58;
  static const double playIconSize = 34;

  /// VOD bottom strip — fat progress bar (user reference).
  static const double vodTimeFontSize = 13;
  static const double vodTitleSize = 15;
  static const double vodFatBarHeight = 15;

  /// Compact minute-jump row under the VOD timeline (TV D-pad tier 2).
  static const double vodJumpButtonSize = 36;
  static const double vodJumpPlaySize = 40;
  static const double vodJumpLabelFontSize = 11;
  static const double vodJumpRowTopPadding = 10;

  /// Trailing **Settings** control (same idea as Live TV right strip) — far right.
  static const double vodSettingsButtonSize = 40;
}

/// Bottom gradient behind live TV chrome.
///
/// Default (**Android TV / non-Windows**): original fixed-height slab (unchanged layout).
/// **Windows live** ([shrinkWrapWithMaxHeight]): gradient height follows content only.
class PlayerTvBottomSheetChrome extends StatelessWidget {
  const PlayerTvBottomSheetChrome({
    super.key,
    required this.child,
    this.shrinkWrapWithMaxHeight = false,
  });

  final Widget child;

  /// `true` only for Windows desktop live fullscreen — do not use on Android.
  final bool shrinkWrapWithMaxHeight;

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final maxH = (sh * PlayerTvOverlayTheme.bottomChromeHeightFraction).clamp(
      PlayerTvOverlayTheme.bottomChromeMinHeight,
      PlayerTvOverlayTheme.bottomChromeMaxHeight,
    );

    final gradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.44),
          Colors.black.withValues(alpha: 0.74),
          Colors.black.withValues(alpha: 0.94),
        ],
        stops: const [0.0, 0.32, 1.0],
      ),
    );

    if (shrinkWrapWithMaxHeight) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: DecoratedBox(
              decoration: gradient,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  primary: false,
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [child],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: maxH,
      width: double.infinity,
      child: DecoratedBox(
        decoration: gradient,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                primary: false,
                clipBehavior: Clip.hardEdge,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [child],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Channel name + optional “now playing” one-liner (live).
class PlayerTvLiveIdentityRow extends StatelessWidget {
  const PlayerTvLiveIdentityRow({
    super.key,
    required this.channelTitle,
    this.programLine,
  });

  final String channelTitle;
  final String? programLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = channelTitle.trim();
    final runes = t.runes;
    final initial =
        runes.isEmpty ? '?' : String.fromCharCode(runes.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.14),
                child: Text(
                  initial.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.98),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    if (programLine != null && programLine!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          programLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.82),
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _EpgHighlight { now, next, other }

_EpgHighlight _epgHighlightFor(int index, List<XtreamEpgListing> list) {
  final onIdx = list.indexWhere(listingIsOnAirNow);
  if (onIdx >= 0) {
    if (index == onIdx) return _EpgHighlight.now;
    if (index == onIdx + 1 && onIdx + 1 < list.length) {
      return _EpgHighlight.next;
    }
    return _EpgHighlight.other;
  }
  if (index == 0 && list.isNotEmpty) return _EpgHighlight.next;
  return _EpgHighlight.other;
}

/// Horizontal EPG rail — dark cards; **red** = on-air now, **blue** = next slot.
class PlayerTvEpgStrip extends StatelessWidget {
  const PlayerTvEpgStrip({
    super.key,
    required this.listings,
    this.playlistId,
  });

  final List<XtreamEpgListing> listings;
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: SizedBox(
            height: 76,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < listings.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _EpgCard(
                        listing: listings[i],
                        highlight: _epgHighlightFor(i, listings),
                        theme: theme,
                        playlistId: playlistId,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpgCard extends StatelessWidget {
  const _EpgCard({
    required this.listing,
    required this.highlight,
    required this.theme,
    this.playlistId,
  });

  final XtreamEpgListing listing;
  final _EpgHighlight highlight;
  final ThemeData theme;
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    late final Color border;
    late final Color fill;
    late final Color accentText;
    final String? badge;
    switch (highlight) {
      case _EpgHighlight.now:
        border = PlayerTvOverlayTheme.epgNowAccent;
        fill = const Color(0xCC1A0A0A);
        accentText = PlayerTvOverlayTheme.epgNowAccent;
        badge = 'NOW';
      case _EpgHighlight.next:
        border = PlayerTvOverlayTheme.epgNextAccent;
        fill = const Color(0xCC0A121A);
        accentText = PlayerTvOverlayTheme.epgNextAccent;
        badge = 'NEXT';
      case _EpgHighlight.other:
        border = Colors.white.withOpacity(0.14);
        fill = const Color(0xB3000000);
        accentText = Colors.white.withOpacity(0.55);
        badge = null;
    }

    final timeStr =
        formatEpgTimeRangeForPlaylist(listing, playlistId) ?? '—';

    return TvFocusable(
      showFocusElevation: false,
      parallaxSlide: 0,
      focusScale: 1.02,
      focusedBorderWidth: 1.4,
      onActivate: () {},
      focusPadding: const EdgeInsets.all(2),
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: highlight == _EpgHighlight.other ? 1 : 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: accentText.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentText,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                if (timeStr != null)
                  Expanded(
                    child: Text(
                      timeStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (badge != null || timeStr != null) const SizedBox(height: 6),
            Expanded(
              child: Text(
                listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.94),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontSize: 12.5,
                  shadows: const [
                    Shadow(blurRadius: 5, color: Colors.black87),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// VOD playback speed presets (session-only; resets when the player route is closed).
const List<double> kVodPlaybackSpeedPresets = [
  0.25,
  0.5,
  1.0,
  1.5,
  2.0,
  2.5,
  3.0,
];

String playerTvFormatVodAudioDelayLabel(int ms) {
  if (ms == 0) return '0 ms';
  return ms > 0 ? '+$ms ms' : '$ms ms';
}

/// Label for VOD **subtitle** time offset (same format as A/V; separate control).
String playerTvFormatVodSubtitleDelayLabel(int ms) =>
    playerTvFormatVodAudioDelayLabel(ms);

String playerTvFormatVodSpeedLabel(double s) {
  if ((s - 0.25).abs() < 0.01) return '0.25×';
  if ((s - 0.5).abs() < 0.01) return '0.5×';
  if ((s - 1.0).abs() < 0.01) return '1×';
  if ((s - 1.5).abs() < 0.01) return '1.5×';
  if ((s - 2.0).abs() < 0.01) return '2×';
  if ((s - 2.5).abs() < 0.01) return '2.5×';
  if ((s - 3.0).abs() < 0.01) return '3×';
  return '${s}×';
}

String playerTvFormatBitrate(int? bitrate) {
  if (bitrate == null || bitrate <= 0) return '';
  final kbps = bitrate / 1000.0;
  if (kbps >= 1000) {
    return '${(kbps / 1000).toStringAsFixed(1)} Mb/s';
  }
  return '${kbps.round()} kb/s';
}

String playerTvFormatResolution(int? w, int? h) {
  if (w == null || h == null || w <= 0 || h <= 0) return '';
  // Common labels
  if (h >= 2160) return '4K';
  if (h >= 1440) return '1440p';
  if (h >= 1080) return '1080p';
  if (h >= 720) return '720p';
  if (h >= 576) return '576p';
  if (h >= 480) return '480p';
  return '${w}×$h';
}

/// Resolution + bitrate chips (optional native stats).
class PlayerTvStreamMetaChips extends StatelessWidget {
  const PlayerTvStreamMetaChips({
    super.key,
    required this.videoWidth,
    required this.videoHeight,
    required this.bitrate,
  });

  final int? videoWidth;
  final int? videoHeight;
  final int? bitrate;

  @override
  Widget build(BuildContext context) {
    final res = playerTvFormatResolution(videoWidth, videoHeight);
    final br = playerTvFormatBitrate(bitrate);
    if (res.isEmpty && br.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          if (res.isNotEmpty) _Chip(text: res),
          if (br.isNotEmpty) _Chip(text: br),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w600,
              fontSize: PlayerTvOverlayTheme.metaFontSize,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class PlayerTvTimecodeText extends StatelessWidget {
  const PlayerTvTimecodeText({
    super.key,
    required this.positionMs,
    required this.durationMs,
  });

  final int positionMs;
  final int durationMs;

  static String formatMs(int ms) {
    if (ms < 0) ms = 0;
    final t = Duration(milliseconds: ms);
    final h = t.inHours;
    final m = t.inMinutes.remainder(60);
    final s = t.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pos = positionMs;
    final dur = durationMs <= 0 ? 0 : durationMs;
    return Text(
      '${formatMs(pos)} / ${formatMs(dur)}',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w700,
            fontSize: PlayerTvOverlayTheme.timeFontSize,
            letterSpacing: 0.5,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            shadows: const [
              Shadow(blurRadius: 12, color: Colors.black87),
            ],
          ),
    );
  }
}

/// Short bottom gradient for VOD — no tall bottom sheet.
class PlayerTvVodBottomChrome extends StatelessWidget {
  const PlayerTvVodBottomChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.96),
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Translucent title / meta (Up on remote).
class PlayerTvVodInfoBanner extends StatelessWidget {
  const PlayerTvVodInfoBanner({
    super.key,
    required this.title,
    this.description,
    this.videoWidth,
    this.videoHeight,
    this.bitrate,
  });

  final String title;
  final String? description;
  final int? videoWidth;
  final int? videoHeight;
  final int? bitrate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = playerTvFormatResolution(videoWidth, videoHeight);
    final br = playerTvFormatBitrate(bitrate);
    final desc = description?.trim() ?? '';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.trim().isEmpty ? '—' : title.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.96),
                fontWeight: FontWeight.w800,
                fontSize: PlayerTvOverlayTheme.vodTitleSize,
                height: 1.2,
                shadows: const [
                  Shadow(blurRadius: 10, color: Colors.black87),
                ],
              ),
            ),
            if (desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      desc,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                        height: 1.38,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            if (res.isNotEmpty || br.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: desc.isNotEmpty ? 10 : 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (res.isNotEmpty) _vodMetaChip(text: res),
                    if (br.isNotEmpty) _vodMetaChip(text: br),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Jump row: **CC** + **Style** + **Subtitle timing** (turtle, left); −15s … +15s + play (center); **A/V**, **Speed**, **Settings**, optional **Download** (right).
/// Indices: **0** CC, **1** Style, **2** subtitle offset, **3–11** center seek/play, **12** A/V, **13** speed, **14** settings, **15** download (when [showDownloadButton]).
class PlayerTvVodJumpStrip extends StatelessWidget {
  const PlayerTvVodJumpStrip({
    super.key,
    required this.stripFocused,
    required this.focusIndex,
    required this.playing,
    required this.audioDelayMs,
    required this.subtitleDelayMs,
    required this.playbackSpeed,
    this.ccActive = false,
    this.showDownloadButton = false,
    this.onJumpSeek,
    this.onTogglePlayPause,
    this.onCcTap,
    this.onStyleTap,
    this.onAudioTap,
    this.onSubtitleDelayTap,
    this.onSpeedTap,
    this.onSettingsTap,
    this.onDownloadTap,
  });

  /// When false, no focus highlight (tier A: L/R still scrubs).
  final bool stripFocused;

  /// **0** CC, **1** Style, **2** subtitle timing, **3–11** center, **12** A/V, **13** speed, **14** Settings, **15** Download (if shown).
  final int focusIndex;

  /// Windows / Android VOD: show trailing download chip (index **15**).
  final bool showDownloadButton;

  final bool playing;

  /// Current A/V sync offset for the label (ms).
  final int audioDelayMs;

  /// External subtitle time offset (ms) for the turtle chip.
  final int subtitleDelayMs;

  /// Current playback speed for the label.
  final double playbackSpeed;

  /// External subtitles attached (CC chip accent).
  final bool ccActive;

  /// Called with milliseconds to seek (negative = rewind, positive = forward).
  final void Function(int deltaMs)? onJumpSeek;
  final VoidCallback? onTogglePlayPause;
  final VoidCallback? onCcTap;
  final VoidCallback? onStyleTap;
  final VoidCallback? onAudioTap;
  final VoidCallback? onSubtitleDelayTap;
  final VoidCallback? onSpeedTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onDownloadTap;

  @override
  Widget build(BuildContext context) {
    final maxIdx = showDownloadButton ? 15 : 14;
    final idx = focusIndex.clamp(0, maxIdx);
    final centerChipIdx = (idx >= 3 && idx <= 11) ? idx - 3 : -1;
    final accent = context.teamPalette.accent;
    return Padding(
      padding: const EdgeInsets.only(
        top: PlayerTvOverlayTheme.vodJumpRowTopPadding,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onCcTap,
                child: _VodCcChip(
                  focused: stripFocused && idx == 0,
                  accent: accent,
                  active: ccActive,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onStyleTap,
                child: _VodStyleChip(
                  focused: stripFocused && idx == 1,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onSubtitleDelayTap,
                child: _VodSubtitleDelayChip(
                  focused: stripFocused && idx == 2,
                  accent: accent,
                  label: playerTvFormatVodSubtitleDelayLabel(subtitleDelayMs),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _jumpChip(
                      label: '−15',
                      subtitle: 'sec',
                      focused: stripFocused && centerChipIdx == 0,
                      onTap: onJumpSeek != null ? () => onJumpSeek!(-15000) : null,
                    ),
                    for (var i = 0; i < 3; i++)
                      _jumpChip(
                        label: '−${i + 1}',
                        subtitle: 'min',
                        focused: stripFocused && centerChipIdx == 1 + i,
                        onTap: onJumpSeek != null ? () => onJumpSeek!(-(i + 1) * 60000) : null,
                      ),
                    _playChip(
                      focused: stripFocused && centerChipIdx == 4,
                      playing: playing,
                      onTap: onTogglePlayPause,
                    ),
                    for (var i = 0; i < 3; i++)
                      _jumpChip(
                        label: '+${3 - i}',
                        subtitle: 'min',
                        focused: stripFocused && centerChipIdx == 5 + i,
                        onTap: onJumpSeek != null ? () => onJumpSeek!((3 - i) * 60000) : null,
                      ),
                    _jumpChip(
                      label: '+15',
                      subtitle: 'sec',
                      focused: stripFocused && centerChipIdx == 8,
                      onTap: onJumpSeek != null ? () => onJumpSeek!(15000) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAudioTap,
            child: _VodAudioChip(
              focused: stripFocused && idx == 12,
              accent: accent,
              label: playerTvFormatVodAudioDelayLabel(audioDelayMs),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSpeedTap,
            child: _VodSpeedChip(
              focused: stripFocused && idx == 13,
              accent: accent,
              label: playerTvFormatVodSpeedLabel(playbackSpeed),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSettingsTap,
            child: _VodSettingsChip(
              focused: stripFocused && idx == 14,
              accent: accent,
            ),
          ),
          if (showDownloadButton) ...[
            const SizedBox(width: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onDownloadTap,
                child: _VodDownloadChip(
                  focused: stripFocused && idx == 15,
                  accent: accent,
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _jumpChip({
    required String label,
    required String subtitle,
    required bool focused,
    VoidCallback? onTap,
  }) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodJumpButtonSize,
      height: PlayerTvOverlayTheme.vodJumpButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
        border: Border.all(
          color: focused
              ? Colors.white.withOpacity(0.85)
              : Colors.white.withOpacity(0.2),
          width: focused ? 1.6 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w800,
              fontSize: PlayerTvOverlayTheme.vodJumpLabelFontSize,
              height: 1,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w600,
              fontSize: 8,
              height: 1,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: onTap != null
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onTap, child: chip),
            )
          : chip,
    );
  }

  Widget _playChip({required bool focused, required bool playing, VoidCallback? onTap}) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodJumpPlaySize,
      height: PlayerTvOverlayTheme.vodJumpPlaySize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.18 : 0.08),
        border: Border.all(
          color: focused
              ? Colors.white.withOpacity(0.9)
              : Colors.white.withOpacity(0.22),
          width: focused ? 1.65 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: onTap != null
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onTap, child: chip),
            )
          : chip,
    );
  }
}

class _VodCcChip extends StatelessWidget {
  const _VodCcChip({
    required this.focused,
    required this.accent,
    required this.active,
  });

  final bool focused;
  final Color accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: PlayerTvOverlayTheme.vodSettingsButtonSize,
        height: PlayerTvOverlayTheme.vodSettingsButtonSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
          border: Border.all(
            color: focused
                ? accent.withOpacity(0.95)
                : (active
                    ? accent.withOpacity(0.55)
                    : Colors.white.withOpacity(0.2)),
            width: focused ? 1.65 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          'CC',
          style: TextStyle(
            color: active ? accent.withOpacity(0.98) : Colors.white.withOpacity(0.88),
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _VodStyleChip extends StatelessWidget {
  const _VodStyleChip({
    required this.focused,
    required this.accent,
  });

  final bool focused;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: PlayerTvOverlayTheme.vodSettingsButtonSize,
        height: PlayerTvOverlayTheme.vodSettingsButtonSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
          border: Border.all(
            color: focused
                ? accent.withOpacity(0.95)
                : Colors.white.withOpacity(0.2),
            width: focused ? 1.65 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.palette_outlined,
          color: focused ? accent.withOpacity(0.98) : Colors.white.withOpacity(0.88),
          size: 20,
        ),
      ),
    );
  }
}

/// A/V sync — Left/Right nudge ms when focused (handled in [PlayerScreen]).
class _VodAudioChip extends StatelessWidget {
  const _VodAudioChip({
    required this.focused,
    required this.accent,
    required this.label,
  });

  final bool focused;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodSettingsButtonSize,
      height: PlayerTvOverlayTheme.vodSettingsButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
        border: Border.all(
          color: focused
              ? accent.withOpacity(0.95)
              : Colors.white.withOpacity(0.2),
          width: focused ? 1.65 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.av_timer_rounded,
            color: focused ? accent : Colors.white.withOpacity(0.85),
            size: 17,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w700,
              fontSize: 7.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtitle time offset (turtle) — Left/Right nudge ms in [PlayerScreen] when the panel is open.
class _VodSubtitleDelayChip extends StatelessWidget {
  const _VodSubtitleDelayChip({
    required this.focused,
    required this.accent,
    required this.label,
  });

  final bool focused;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodSettingsButtonSize,
      height: PlayerTvOverlayTheme.vodSettingsButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
        border: Border.all(
          color: focused
              ? accent.withOpacity(0.95)
              : Colors.white.withOpacity(0.2),
          width: focused ? 1.65 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets_rounded,
            color: focused ? accent : Colors.white.withOpacity(0.85),
            size: 17,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w700,
              fontSize: 7.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _VodSpeedChip extends StatelessWidget {
  const _VodSpeedChip({
    required this.focused,
    required this.accent,
    required this.label,
  });

  final bool focused;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodSettingsButtonSize,
      height: PlayerTvOverlayTheme.vodSettingsButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
        border: Border.all(
          color: focused
              ? accent.withOpacity(0.95)
              : Colors.white.withOpacity(0.2),
          width: focused ? 1.65 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speed_rounded,
            color: focused ? accent : Colors.white.withOpacity(0.85),
            size: 18,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w800,
              fontSize: 9,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small A/V sync panel — opened with OK on the A/V chip; Left/Right adjusts in [PlayerScreen].
class PlayerTvVodAudioOffsetPopup extends StatelessWidget {
  const PlayerTvVodAudioOffsetPopup({
    super.key,
    required this.delayMs,
    required this.accent,
  });

  final int delayMs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = playerTvFormatVodAudioDelayLabel(delayMs);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A/V sync',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.85)),
                      color: accent.withOpacity(0.12),
                    ),
                    child: Text(
                      '−',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white.withOpacity(0.98),
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.85)),
                      color: accent.withOpacity(0.12),
                    ),
                    child: Text(
                      '+',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Left / Right — adjust   ·   OK / Back — close',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// External subtitle timing (turtle control) — **when** cues appear vs the video (not playback speed).
/// Left/Right in [PlayerScreen]: negative ms = show text earlier, positive = later.
class PlayerTvVodSubtitleDelayPopup extends StatelessWidget {
  const PlayerTvVodSubtitleDelayPopup({
    super.key,
    required this.delayMs,
    required this.accent,
  });

  final int delayMs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = playerTvFormatVodSubtitleDelayLabel(delayMs);
    final sub = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withOpacity(0.55),
          fontWeight: FontWeight.w600,
          height: 1.25,
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Material(
        color: Colors.black.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Subtitle sync',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withOpacity(0.72),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'When the text appears — not video speed (use Speed for that).',
                textAlign: TextAlign.center,
                style: sub,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(0.85)),
                          color: accent.withOpacity(0.12),
                        ),
                        child: Text(
                          '−',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Earlier',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white.withOpacity(0.98),
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'offset vs file',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(0.85)),
                          color: accent.withOpacity(0.12),
                        ),
                        child: Text(
                          '+',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Later',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '±250 ms per step (¼ s) · applies shortly after you stop nudging, or when you press Back / OK',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TV menu for choosing a session [playbackSpeed] preset.
class PlayerTvVodSpeedPicker extends StatelessWidget {
  const PlayerTvVodSpeedPicker({
    super.key,
    required this.focusIndex,
    required this.accent,
  });

  /// Whole picker ~15% smaller than the original layout.
  static const double _kUiScale = 0.85;

  final int focusIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const s = _kUiScale;
    final titleFs =
        (Theme.of(context).textTheme.labelLarge?.fontSize ?? 14) * s;
    final rowFs =
        (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * s;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 280 * s),
      child: Material(
        color: Colors.black.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14 * s),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10 * s, horizontal: 12 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Playback speed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      fontSize: titleFs,
                    ),
              ),
              SizedBox(height: 4 * s),
              Text(
                'Video only — not subtitle timing',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.48),
                      fontWeight: FontWeight.w600,
                      fontSize: (11 * s),
                    ),
              ),
              SizedBox(height: 8 * s),
              for (var i = 0; i < kVodPlaybackSpeedPresets.length; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4 * s),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10 * s),
                      border: Border.all(
                        color: focusIndex == i
                            ? accent
                            : Colors.white.withOpacity(0.12),
                        width: focusIndex == i ? 2 * s : 1,
                      ),
                      color: focusIndex == i
                          ? accent.withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16 * s,
                        vertical: 12 * s,
                      ),
                      child: Text(
                        playerTvFormatVodSpeedLabel(kVodPlaybackSpeedPresets[i]),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.96),
                              fontWeight: FontWeight.w800,
                              fontSize: rowFs,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trailing download (Windows VOD) — matches [_VodSettingsChip] size.
class _VodDownloadChip extends StatelessWidget {
  const _VodDownloadChip({
    required this.focused,
    required this.accent,
  });

  final bool focused;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodSettingsButtonSize,
      height: PlayerTvOverlayTheme.vodSettingsButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
        border: Border.all(
          color: focused
              ? accent.withOpacity(0.95)
              : Colors.white.withOpacity(0.2),
          width: focused ? 1.65 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.download_rounded,
        color: focused ? accent : Colors.white.withOpacity(0.85),
        size: 22,
      ),
    );
  }
}

/// Trailing Settings affordance — visually separate from jump chips (far right).
class _VodSettingsChip extends StatelessWidget {
  const _VodSettingsChip({
    required this.focused,
    required this.accent,
  });

  final bool focused;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: PlayerTvOverlayTheme.vodSettingsButtonSize,
      height: PlayerTvOverlayTheme.vodSettingsButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(focused ? 0.16 : 0.07),
        border: Border.all(
          color: focused
              ? accent.withOpacity(0.95)
              : Colors.white.withOpacity(0.2),
          width: focused ? 1.65 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.settings_rounded,
        color: focused ? accent : Colors.white.withOpacity(0.85),
        size: 22,
      ),
    );
  }
}

/// Fat rectangular progress (elapsed white / remainder dim) + times outside bar.
class PlayerTvVodTimelineStrip extends StatelessWidget {
  const PlayerTvVodTimelineStrip({
    super.key,
    required this.positionMs,
    required this.durationMs,
    this.videoWidth,
    this.videoHeight,
    this.onSeek,
  });

  final int positionMs;
  final int durationMs;
  final int? videoWidth;
  final int? videoHeight;

  /// Called with a target position in milliseconds when the bar is clicked.
  final void Function(int targetMs)? onSeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.titleSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: PlayerTvOverlayTheme.vodTimeFontSize,
      height: 1.05,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      shadows: const [
        Shadow(blurRadius: 6, color: Colors.black87),
      ],
    );
    final progress = PlayerTvSeekTrack._vodProgress01(positionMs, durationMs);
    final res = playerTvFormatResolution(videoWidth, videoHeight);
    // Right label: time remaining (countdown). Left: elapsed (unchanged bar geometry).
    final remainingMs = durationMs <= 0
        ? 0
        : (durationMs - positionMs).clamp(0, durationMs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (res.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(child: _vodMetaChip(text: res)),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(PlayerTvTimecodeText.formatMs(positionMs), style: timeStyle),
              const SizedBox(width: 14),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final h = PlayerTvOverlayTheme.vodFatBarHeight;
                      final bar = SizedBox(
                        height: h,
                        width: c.maxWidth,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            ColoredBox(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progress,
                                heightFactor: 1,
                                alignment: Alignment.centerLeft,
                                child: const ColoredBox(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (onSeek != null && durationMs > 0) {
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              final fraction = (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0);
                              onSeek!((fraction * durationMs).round());
                            },
                            onHorizontalDragUpdate: (details) {
                              final fraction = (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0);
                              onSeek!((fraction * durationMs).round());
                            },
                            child: bar,
                          ),
                        );
                      }
                      return bar;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                PlayerTvTimecodeText.formatMs(remainingMs),
                style: timeStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _vodMetaChip({required String text}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.88),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

/// D-pad-friendly progress strip (no touch [Slider]; always LTR so the thumb matches time).
class PlayerTvSeekTrack extends StatelessWidget {
  const PlayerTvSeekTrack({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.bufferedMs,
    required this.focused,
  });

  final int positionMs;
  final int durationMs;
  final int bufferedMs;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final accent = context.teamPalette.accent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = math.max(
          36.0,
          PlayerTvOverlayTheme.seekThumbRadius * 2 +
              PlayerTvOverlayTheme.seekTrackHeight,
        );
        return SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _SeekTrackPainter(
              progress: _fraction(positionMs, durationMs),
              buffered: _fraction(bufferedMs, durationMs),
              focused: focused,
              accent: accent,
            ),
          ),
        );
      },
    );
  }

  static double _fraction(int valueMs, int durationMs) {
    if (durationMs <= 0) return 0;
    return (valueMs / durationMs).clamp(0.0, 1.0);
  }

  /// Same as [_fraction]; used by VOD fat bar layout.
  static double _vodProgress01(int positionMs, int durationMs) =>
      _fraction(positionMs, durationMs);
}

class _SeekTrackPainter extends CustomPainter {
  _SeekTrackPainter({
    required this.progress,
    required this.buffered,
    required this.focused,
    required this.accent,
  });

  final double progress;
  final double buffered;
  final bool focused;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final trackH = PlayerTvOverlayTheme.seekTrackHeight;
    final thumbR = PlayerTvOverlayTheme.seekThumbRadius;
    final cy = size.height / 2;
    final w = size.width;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - trackH / 2, w, trackH),
      Radius.circular(trackH / 2),
    );

    final bg = Paint()..color = Colors.white.withOpacity(0.2);
    canvas.drawRRect(rect, bg);

    final bufEnd = (w * buffered).clamp(0.0, w);
    if (bufEnd > 2) {
      final bufRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - trackH / 2, bufEnd, trackH),
        Radius.circular(trackH / 2),
      );
      canvas.drawRRect(
        bufRect,
        Paint()..color = accent.withOpacity(0.38),
      );
    }

    final progEnd = (w * progress).clamp(0.0, w);
    if (progEnd > 2) {
      final progRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - trackH / 2, progEnd, trackH),
        Radius.circular(trackH / 2),
      );
      canvas.drawRRect(
        progRect,
        Paint()..color = Colors.white.withOpacity(0.95),
      );
    }

    final cx = (w * progress).clamp(thumbR, w - thumbR);
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), thumbR, thumbPaint);
    canvas.drawCircle(
      Offset(cx, cy),
      thumbR,
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (focused) {
      final fr = Rect.fromLTRB(
        -3,
        cy - trackH / 2 - 3,
        w + 3,
        cy + trackH / 2 + 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          fr,
          Radius.circular(trackH / 2 + 3),
        ),
        Paint()
          ..color = accent.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeekTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.buffered != buffered ||
        oldDelegate.focused != focused ||
        oldDelegate.accent != accent;
  }
}

/// Hint row for live channel switching (single compact line).
class PlayerTvLiveHints extends StatelessWidget {
  const PlayerTvLiveHints({
    super.key,
    required this.showChannelSwitch,
    this.showGuideHints = true,
  });

  final bool showChannelSwitch;

  /// When true, show ◀ ▶ guide and ↓ more (live wireframe).
  final bool showGuideHints;

  @override
  Widget build(BuildContext context) {
    if (!showChannelSwitch && !showGuideHints) {
      return const SizedBox.shrink();
    }
    final a = showGuideHints ? '◀ ▶ — columns' : '';
    final b = showChannelSwitch ? '↑ — channel' : '';
    final c = showGuideHints ? '↓ — tools' : '';
    final parts = <String>[a, b, c].where((e) => e.isNotEmpty).join('   ·   ');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        parts,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withOpacity(0.42),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
      ),
    );
  }
}

/// Fullscreen **live**: fat programme bar + start/end clocks (non-Android desktop
/// path uses [formatEpgProgramStartEndLabels] + [playlistEpgTimezoneStore]).
class PlayerTvLiveProgramTimelineStrip extends StatelessWidget {
  const PlayerTvLiveProgramTimelineStrip({
    super.key,
    required this.listing,
    required this.playlistId,
    required this.legacyAndroid,
  });

  final XtreamEpgListing listing;
  final String? playlistId;

  /// **Android**: device-local HH:mm only; **else**: playlist EPG rules + tz store.
  final bool legacyAndroid;

  @override
  Widget build(BuildContext context) {
    Widget streamStrip() {
      final (String startLabel, String endLabel) = legacyAndroid
          ? (
              playerTvFormatClockLocal(listing.start),
              playerTvFormatClockLocal(listing.end),
            )
          : formatEpgProgramStartEndLabels(listing, playlistId);
      final progress = liveListingProgress01(listing);
      final theme = Theme.of(context);
      final timeStyle = theme.textTheme.titleSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: PlayerTvOverlayTheme.vodTimeFontSize,
        height: 1.05,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        shadows: const [
          Shadow(blurRadius: 6, color: Colors.black87),
        ],
      );
      return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.52),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(startLabel, style: timeStyle),
                const SizedBox(width: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return SizedBox(
                        height: PlayerTvOverlayTheme.vodFatBarHeight,
                        width: c.maxWidth,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            ColoredBox(
                              color: Colors.white.withOpacity(0.22),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progress.clamp(0.0, 1.0),
                                heightFactor: 1,
                                child: const ColoredBox(
                                  color: PlayerTvOverlayTheme.epgNowAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Text(endLabel, style: timeStyle),
              ],
            ),
          ),
    );
    }

    if (legacyAndroid) {
      return streamStrip();
    }
    return ListenableBuilder(
      listenable: playlistEpgTimezoneStore,
      builder: (context, __) => streamStrip(),
    );
  }
}
