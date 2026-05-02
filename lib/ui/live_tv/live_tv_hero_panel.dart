import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show Listenable, ValueListenable, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../data/library_controller.dart';
import '../../data/epg_time_display.dart';
import '../../data/parental_control_store.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/playlist_epg_timezone_store.dart';
import '../../data/live_epg_controller.dart';
import '../../data/live_tv_hero_appearance_store.dart';
import '../../data/live_tv_hero_layout_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../player/mock_stream_urls.dart';
import '../../theme/team_palette_theme.dart';
import '../widgets/hero_brush_overlay.dart';
import '../widgets/hero_solid_wash_overlay.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'hero_epg_script.dart';
import 'hero_live_preview.dart';
import 'mock_live_tv_data.dart';

const Color _kHeroProgressRed = Color(0xFFE53935);

String heroLiveStreamUrl(MockLiveChannel c) {
  if (c.isCatalogLoadingPlaceholder) return '';
  return c.streamUrl ?? mockLiveStreamUrlForChannel(c.id);
}

String liveCategoryLabelForChannel(MockLiveChannel ch) {
  final cats = libraryController.useDemoData
      ? kMockLiveCategories
      : xtreamCatalogRepository.liveCategories;
  final playlistId = libraryController.activePlaylistId;
  for (final c in cats) {
    if (c.id == ch.categoryId) {
      if (playlistId == null) return c.name;
      return playlistGroupVisibilityStore.categoryDisplayName(
        playlistId,
        PlaylistGroupSection.live,
        c.id,
        c.name,
      );
    }
  }
  return '';
}

String _fmtHeroClock(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String? _heroEndsInLabel(DateTime? end) {
  if (end == null) return null;
  final now = DateTime.now();
  if (!end.isAfter(now)) return null;
  final mins = end.difference(now).inMinutes;
  if (mins <= 0) return 'Ending soon';
  if (mins == 1) return 'Ends in 1 minute';
  return 'Ends in $mins minutes';
}

class HeroTiming {
  HeroTiming({
    required this.progress01,
    this.startLabel,
    this.endLabel,
    this.endsInLabel,
  });

  final double progress01;
  final String? startLabel;
  final String? endLabel;
  final String? endsInLabel;

  factory HeroTiming.from(
    MockLiveChannel ch,
    LiveNowEpgDisplay? d,
    String? playlistId,
  ) {
    if (d != null && d.programEnd != null) {
      final end = d.programEnd!;
      final start = d.programStart;
      String endLabel;
      String? startLabel;
      if (playlistId != null && playlistId.isNotEmpty) {
        endLabel = formatEpgProgramTime(
          end,
          d.programEndRaw,
          d.programEndUnix,
          playlistId,
        );
        startLabel = formatEpgProgramTime(
          start,
          d.programStartRaw,
          d.programStartUnix,
          playlistId,
        );
      } else {
        endLabel = _fmtHeroClock(end);
        startLabel = start != null ? _fmtHeroClock(start) : null;
      }
      return HeroTiming(
        progress01: d.progress01.clamp(0.0, 1.0),
        startLabel: startLabel,
        endLabel: endLabel,
        endsInLabel: _heroEndsInLabel(end),
      );
    }
    final now = DateTime.now();
    const slot = Duration(minutes: 30);
    final elapsed = ch.progress.clamp(0.0, 1.0);
    final start = now.subtract(
      Duration(milliseconds: (elapsed * slot.inMilliseconds).round()),
    );
    final end = start.add(slot);
    return HeroTiming(
      progress01: elapsed,
      startLabel: _fmtHeroClock(start),
      endLabel: _fmtHeroClock(end),
      endsInLabel: _heroEndsInLabel(end),
    );
  }
}

/// Live TV hero (preview + EPG + logo) — shared by Live TV and My space.
class LiveTvHeroPanel extends StatelessWidget {
  const LiveTvHeroPanel({
    super.key,
    required this.channelListenable,
    required this.viewCategoryId,
    this.categorySubtitleListenable,
    this.previewMode = false,
  });

  final ValueListenable<MockLiveChannel> channelListenable;
  /// Selected Live TV category pill (or favorite group id) — for parental hero blackout.
  final String viewCategoryId;
  /// Optional second line under program title (e.g. My space section name).
  final ValueListenable<String?>? categorySubtitleListenable;
  /// When true (appearance preview), parental hero blackout is disabled.
  final bool previewMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<MockLiveChannel>(
      valueListenable: channelListenable,
      builder: (context, ch, _) {
        if (categorySubtitleListenable != null) {
          return ValueListenableBuilder<String?>(
            valueListenable: categorySubtitleListenable!,
            builder: (context, sub, __) {
              final categoryLabel = (sub != null && sub.isNotEmpty)
                  ? sub
                  : liveCategoryLabelForChannel(ch);
              return _HeroBody(
                theme: theme,
                ch: ch,
                categoryLabel: categoryLabel,
                viewCategoryId: viewCategoryId,
                previewMode: previewMode,
              );
            },
          );
        }
        return _HeroBody(
          theme: theme,
          ch: ch,
          categoryLabel: liveCategoryLabelForChannel(ch),
          viewCategoryId: viewCategoryId,
          previewMode: previewMode,
        );
      },
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({
    required this.theme,
    required this.ch,
    required this.categoryLabel,
    required this.viewCategoryId,
    required this.previewMode,
  });

  final ThemeData theme;
  final MockLiveChannel ch;
  final String categoryLabel;
  final String viewCategoryId;
  final bool previewMode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LiveEpgController.instance,
        playlistEpgTimezoneStore,
      ]),
      builder: (context, _) {
        LiveNowEpgDisplay? epgDisplay;
        var epgLoading = false;
        if (!libraryController.useDemoData) {
          final epg = LiveEpgController.instance;
          epgDisplay = epg.lookupDisplay(ch.id);
          epgLoading = epg.isLoadingFor(ch.id);
        }

        var programTitle = ch.programTitle;
        var description = ch.description;
        if (epgDisplay != null) {
          programTitle = epgDisplay.isOnAir
              ? epgDisplay.title
              : 'Up next: ${epgDisplay.title}';
          description = epgDisplay.description;
        } else if (epgLoading) {
          programTitle = 'Loading program guide…';
          description = '';
        }

        final timing = HeroTiming.from(
          ch,
          epgDisplay,
          libraryController.activePlaylistId,
        );
        final hebrewDom = isHebrewDominantEpg(programTitle, description);

        return ListenableBuilder(
          listenable: liveTvHeroAppearanceStore,
          builder: (context, __) {
            final p = context.teamPalette;
            final shellBorder = Color.lerp(p.surface, p.canvas, 0.42) ?? p.canvas;
            return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: shellBorder),
            color: p.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.04),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 40,
                spreadRadius: -20,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.hardEdge,
              child: LayoutBuilder(
                builder: (context, outerConstraints) {
                  final a = p.accent;
                  final innerW = outerConstraints.maxWidth;
                  return ListenableBuilder(
                    listenable: liveTvHeroLayoutStore,
                    builder: (context, _) {
                      final scale =
                          liveTvHeroLayoutStore.heroHeightPercent / 100.0;
                      final baseH =
                          LiveTvHeroLayoutStore.baseHeroLogicalHeight;
                      final targetH = baseH * scale;
                      /// Windows: 2× hero inner layout (preview, type, gaps, in-TV timeline).
                      final layoutPlatformScale =
                          defaultTargetPlatform == TargetPlatform.windows
                              ? 2.0
                              : 1.0;
                      final heroLayoutPs = layoutPlatformScale;
                      final ps = heroLayoutPs;
                      /// Outer height must track [layoutPlatformScale]: inner row already
                      /// scales typography/preview/padding with [ps]; without this, Windows
                      /// stayed at Android logical height and the hero felt too small at 100%.
                      final outerHeroH = targetH * layoutPlatformScale;
                      return SizedBox(
                      height: outerHeroH,
                      width: innerW,
                      child: ClipRect(
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color.lerp(
                                            Colors.white,
                                            a,
                                            0.14,
                                          )!
                                              .withValues(
                                                alpha: 0.045,
                                              ),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.7],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.65,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: Alignment.topRight,
                                          radius: 1.4,
                                          colors: [
                                            a.withValues(alpha: 0.14),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.55],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (liveTvHeroAppearanceStore.showWashOverlay)
                                  Positioned.fill(
                                    child:
                                        liveTvHeroAppearanceStore.washMode ==
                                                LiveTvHeroAppearanceStore
                                                    .washModeSolid
                                            ? HeroSolidWashOverlay(
                                                wash: liveTvHeroAppearanceStore
                                                    .washColor,
                                                intensity01:
                                                    liveTvHeroAppearanceStore
                                                            .washIntensity /
                                                        100.0,
                                              )
                                            : HeroBrushOverlay(
                                                wash:
                                                    liveTvHeroAppearanceStore
                                                        .washColor,
                                                intensity01:
                                                    liveTvHeroAppearanceStore
                                                            .washIntensity /
                                                        100.0,
                                                style:
                                                    liveTvHeroAppearanceStore
                                                        .brushStyle,
                                              ),
                                  ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.04),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.18),
                                        ],
                                        stops: const [0.0, 0.45, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.black.withOpacity(0.06),
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.10),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14 * ps,
                                    vertical: 7 * ps,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                        final rowMaxH = constraints.maxHeight;
                        final layoutSlack = 2.0 * ps;
                        final previewH =
                            (rowMaxH - layoutSlack).clamp(56.0 * ps, 400.0 * ps);
                        var videoW = previewH * 16 / 9;
                        final capW = 312.0 * ps;
                        if (videoW > capW) {
                          videoW = capW;
                        }

                        final logoSide = math
                            .min(88.0 * ps, rowMaxH - 24 * ps)
                            .clamp(52.0 * ps, 88.0 * ps);

                        final timelineOverlay = _HeroPreviewTimelineOverlay(
                          theme: theme,
                          timing: timing,
                          layoutPlatformScale: layoutPlatformScale,
                        );

                        final preview = ListenableBuilder(
                          listenable: Listenable.merge([
                            parentalControlStore,
                            libraryController,
                          ]),
                          builder: (context, ___) {
                            final blocked = !previewMode &&
                                !ch.isCatalogLoadingPlaceholder &&
                                parentalControlStore.isLivePlaybackBlocked(
                                  playlistId:
                                      libraryController.activePlaylistId,
                                  viewCategoryId: viewCategoryId,
                                  channelId: ch.id,
                                  channelCategoryId: ch.categoryId,
                                );
                            return SizedBox(
                              width: videoW,
                              child: HeroLivePreview(
                                key: const ValueKey<String>(
                                  'tvmate_hero_live_preview',
                                ),
                                streamUrl: heroLiveStreamUrl(ch),
                                channel: ch,
                                width: videoW,
                                height: previewH,
                                bottomInsideScreen:
                                    blocked ? null : timelineOverlay,
                                useTvBezel:
                                    liveTvHeroAppearanceStore.tvFrameOn,
                                tvFrameStyle:
                                    liveTvHeroAppearanceStore.tvFrameStyle,
                                bezelFinish:
                                    liveTvHeroAppearanceStore.bezelFinish,
                                parentalBlackout: blocked,
                              ),
                            );
                          },
                        );

                        final epgBlock = Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10 * ps),
                            child: Directionality(
                              textDirection: hebrewDom
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: Column(
                                // Hebrew: logical start = screen right (against logo).
                                // English: end = screen right.
                                crossAxisAlignment: hebrewDom
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    programTitle,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: hebrewDom
                                        ? TextAlign.start
                                        : TextAlign.right,
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontSize: 22 * ps,
                                      height: 1.12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.015 * 22,
                                      color: p.shellTitleColor,
                                    ),
                                  ),
                                  if (categoryLabel.isNotEmpty) ...[
                                    SizedBox(height: 6 * ps),
                                    Text(
                                      categoryLabel.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: hebrewDom
                                          ? TextAlign.start
                                          : TextAlign.right,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontSize: 10 * ps,
                                        color: a,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.35,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 6 * ps),
                                  Expanded(
                                    child: Text(
                                      description.isEmpty
                                          ? (epgLoading
                                              ? 'Fetching program guide…'
                                              : 'No description available.')
                                          : description,
                                      maxLines: 8,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: hebrewDom
                                          ? TextAlign.start
                                          : TextAlign.right,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                        fontSize: 12 * ps,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                        color: p.shellBodyHint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                        final logoBlock = SizedBox(
                          width: 112 * ps,
                          height: rowMaxH,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: logoSide,
                                height: logoSide,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(14 * ps),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: p.shellLogoWell,
                                      border: Border.all(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(6 * ps),
                                      child: TvCatalogImage(
                                        url: liveChannelArtUrl(ch),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4 * ps),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    ch.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      fontSize: 13.5 * ps,
                                      fontWeight: FontWeight.w700,
                                      color: p.shellTitleColor,
                                      height: 1.12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        // Always LTR row: TV leading, EPG center (flush to logo), logo+name trailing.
                        return Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              preview,
                              SizedBox(width: 16 * ps),
                              epgBlock,
                              SizedBox(width: 16 * ps),
                              logoBlock,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                                ],
                              ),
                            ),
                      );
                    },
                  );
                },
              ),
            ),
            );
          },
        );
      },
    );
  }
}

/// Clocks + programme progress along the **bottom inside** the TV screen.
class _HeroPreviewTimelineOverlay extends StatelessWidget {
  const _HeroPreviewTimelineOverlay({
    required this.theme,
    required this.timing,
    this.layoutPlatformScale = 1.0,
  });

  final ThemeData theme;
  final HeroTiming timing;

  /// Same as [LiveTvHeroPanel] inner row — **Windows: 2.0**, else **1.0**.
  final double layoutPlatformScale;

  @override
  Widget build(BuildContext context) {
    final ps = layoutPlatformScale;
    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9.5 * ps,
      height: 1.0,
      color: Colors.white.withOpacity(0.88),
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.88),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4 * ps, 10 * ps, 4 * ps, 4 * ps),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(timing.startLabel ?? '—', style: timeStyle),
                  Expanded(
                    child: timing.endsInLabel != null
                        ? Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 4 * ps),
                            child: Text(
                              timing.endsInLabel!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9.5 * ps,
                                height: 1.05,
                                color: Colors.white.withOpacity(0.92),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Text(timing.endLabel ?? '—', style: timeStyle),
                ],
              ),
              SizedBox(height: 2 * ps),
              ClipRRect(
                borderRadius: BorderRadius.circular(2 * ps),
                child: LinearProgressIndicator(
                  value: timing.progress01.clamp(0.0, 1.0),
                  minHeight: 3 * ps,
                  backgroundColor: Colors.white.withOpacity(0.14),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    _kHeroProgressRed,
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
