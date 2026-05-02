import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/team_palette_theme.dart';
import '../../data/epg_time_display.dart';
import '../../data/library_controller.dart';
import '../../data/live_epg_controller.dart';
import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_name_horizontal_bias_store.dart';
import '../../data/live_tv_name_vertical_bias_store.dart';
import '../focus/tv_focusable.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'mock_live_tv_data.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Widget _favoriteOrderBadge(
  BuildContext context,
  int order, {
  required Color accent,
}) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 3,
        ),
      ],
    ),
    child: Text(
      '$order',
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    ),
  );
}

Widget _buildProgressBar(
  double progress01, {
  double height = 3,
  required Color accent,
}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: Colors.white.withValues(alpha: 0.06),
    ),
    clipBehavior: Clip.antiAlias,
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: progress01.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              Color.lerp(accent, Colors.white, 0.25)!,
              accent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _gradientDivider({
  EdgeInsetsGeometry? margin,
  required Color accent,
}) {
  final mid = accent.withValues(alpha: 0.5);
  return Container(
    height: 1,
    margin: margin,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, mid, Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ),
    ),
  );
}

String _formatHm(DateTime? dt) {
  if (dt == null) return '';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Detects text direction from the first strong directional character.
ui.TextDirection _detectTextDirection(String text) {
  for (final c in text.runes) {
    if ((c >= 0x0590 && c <= 0x08FF) ||
        (c >= 0xFB50 && c <= 0xFDFF) ||
        (c >= 0xFE70 && c <= 0xFEFF)) {
      return ui.TextDirection.rtl;
    }
    if (c >= 0x0041 && c <= 0x024F) return ui.TextDirection.ltr;
  }
  return ui.TextDirection.ltr;
}

// ---------------------------------------------------------------------------
// LiveChannelBrowseTile — outer chrome (surface / border / glow)
// ---------------------------------------------------------------------------

class LiveChannelBrowseTile extends StatefulWidget {
  const LiveChannelBrowseTile({
    super.key,
    required this.channel,
    required this.onFocused,
    required this.onPlay,
    required this.onKeyIntercept,
    this.focusNode,
    this.favoriteOrderIndex,
    this.compact = false,
    this.onDesktopTap,
    this.onLongPress,
  });

  final MockLiveChannel channel;
  final VoidCallback onFocused;
  final VoidCallback onPlay;
  final FocusNode? focusNode;

  /// When non-null on Windows/macOS, enables two-step mouse on the grid tile
  /// (see [TvFocusable.onDesktopTap]). Unused on Android / TV.
  final VoidCallback? onDesktopTap;

  /// Long-press callback for mobile touch (context menu, favorites, etc.).
  final VoidCallback? onLongPress;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onKeyIntercept;

  /// 1-based order within the selected **favorite** category (matches setup picker).
  final int? favoriteOrderIndex;

  /// Tighter padding and type — use in Favorite picker grids / strip so logos
  /// are not clipped.
  final bool compact;

  @override
  State<LiveChannelBrowseTile> createState() => _LiveChannelBrowseTileState();
}

class _LiveChannelBrowseTileState extends State<LiveChannelBrowseTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    final a = p.accent;
    final style = liveTvCardStyleStore.style;
    final isFullCard = style == LiveTvCardStyle.logoNameEpg;
    final radius = isFullCard ? 10.0 : 6.0;

    return TvFocusable(
      focusNode: widget.focusNode,
      onDesktopTap: widget.onDesktopTap,
      onLongPress: widget.onLongPress,
      parallaxSlide: 0,
      focusScale: 1.0,
      showFocusElevation: false,
      focusBackgroundColor: a.withValues(alpha: 0.08),
      focusedBorderWidth: 0,
      focusBorderColor: p.defaultFocusRingColor,
      focusPadding: const EdgeInsets.all(1.0),
      onFocusedChange: (hasFocus) {
        setState(() => _focused = hasFocus);
        if (hasFocus) widget.onFocused();
      },
      onActivate: widget.onPlay,
      onKeyIntercept: widget.onKeyIntercept,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          liveTvNameVerticalBiasStore,
          liveTvNameHorizontalBiasStore,
        ]),
        builder: (context, _) {
          final restBorder = Color.lerp(p.surface, p.canvas, 0.42) ?? p.canvas;
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.hardEdge,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: _focused
                    ? Color.lerp(p.surface, p.surfaceElevated, 0.58) ?? p.surface
                    : p.surface,
                border: Border.all(
                  color: _focused
                      ? a.withValues(alpha: 0.5)
                      : restBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 40,
                    spreadRadius: -20,
                    offset: const Offset(0, 16),
                  ),
                  if (_focused) ...[
                    BoxShadow(
                      color: a.withValues(alpha: 0.22),
                      blurRadius: 28,
                    ),
                    BoxShadow(
                      color: a.withValues(alpha: 0.22),
                      spreadRadius: 1,
                    ),
                  ],
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: switch (style) {
                LiveTvCardStyle.nameOnly => _TextOnlyCard(
                    channel: widget.channel,
                    favoriteOrderIndex: widget.favoriteOrderIndex,
                    compact: widget.compact,
                  ),
                LiveTvCardStyle.logoNameEpg => _LogoNameEpgCard(
                    channel: widget.channel,
                    favoriteOrderIndex: widget.favoriteOrderIndex,
                    compact: widget.compact,
                  ),
                LiveTvCardStyle.logoNameOnly => _LogoNameCard(
                    channel: widget.channel,
                    favoriteOrderIndex: widget.favoriteOrderIndex,
                    compact: widget.compact,
                  ),
                LiveTvCardStyle.logoOnly => _LogoOnlyCard(
                    channel: widget.channel,
                    favoriteOrderIndex: widget.favoriteOrderIndex,
                    compact: widget.compact,
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LiveBadge — pulsing red dot + "LIVE" label
// ---------------------------------------------------------------------------

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: const Color(0xFFFF4D4F),
            boxShadow: const [
              BoxShadow(color: Color(0xB3FF4D4F), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          'LIVE',
          style: TextStyle(
            color: Color(0xFFFF8A8C),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10 * 8,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _LogoNameEpgCard — full card: logo + LIVE badge + EPG + name + progress bar
// ---------------------------------------------------------------------------

class _LogoNameEpgCard extends StatelessWidget {
  const _LogoNameEpgCard({
    required this.channel,
    this.favoriteOrderIndex,
    this.compact = false,
  });

  final MockLiveChannel channel;
  final int? favoriteOrderIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = context.teamPalette.accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (libraryController.useDemoData)
          _buildLayout(
            context,
            accent: accent,
            epgTitle: channel.programTitle,
            epgTime: null,
            progress01: channel.progress,
            isOnAir: channel.progress > 0,
            startLabel: '',
            endLabel: '',
          )
        else
          ListenableBuilder(
            listenable: LiveEpgController.instance,
            builder: (context, _) {
              final d =
                  LiveEpgController.instance.lookupDisplay(channel.id);
              final pid = libraryController.activePlaylistId;
              late final String sLabel;
              late final String eLabel;
              if (d != null && pid != null && pid.isNotEmpty) {
                sLabel = formatEpgProgramTime(
                  d.programStart,
                  d.programStartRaw,
                  d.programStartUnix,
                  pid,
                );
                eLabel = formatEpgProgramTime(
                  d.programEnd,
                  d.programEndRaw,
                  d.programEndUnix,
                  pid,
                );
              } else {
                sLabel = _formatHm(d?.programStart);
                eLabel = _formatHm(d?.programEnd);
              }
              return _buildLayout(
                context,
                accent: accent,
                epgTitle: d?.title ?? channel.programTitle,
                epgTime: d?.timeRange,
                progress01: d?.progress01 ?? 0,
                isOnAir: d?.isOnAir ?? false,
                startLabel: sLabel,
                endLabel: eLabel,
              );
            },
          ),
        if (favoriteOrderIndex != null)
          Positioned(
            top: compact ? 3 : 6,
            right: compact ? 3 : 6,
            child: _favoriteOrderBadge(
              context,
              favoriteOrderIndex!,
              accent: accent,
            ),
          ),
      ],
    );
  }

  Widget _buildLayout(
    BuildContext context, {
    required Color accent,
    required String epgTitle,
    required String? epgTime,
    required double progress01,
    required bool isOnAir,
    required String startLabel,
    required String endLabel,
  }) {
    final logoSize = compact ? 32.0 : 44.0;
    final hasFooter = isOnAir && progress01 > 0;
    final nameDir = _detectTextDirection(channel.name);
    final epgDir = _detectTextDirection(epgTitle);

    return Padding(
      padding: EdgeInsets.all(compact ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Top row: logo + EPG info ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: -10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: TvCatalogImage(
                  url: liveChannelArtUrl(channel),
                  fit: BoxFit.cover,
                ),
              ),

              SizedBox(width: compact ? 4 : 5),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOnAir)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: _LiveBadge(),
                      ),
                    if (isOnAir) const SizedBox(height: 2),
                    Text(
                      epgTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: epgDir,
                      textAlign: epgDir == ui.TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFA8B0BD),
                        height: 1.25,
                      ),
                    ),
                    if (epgTime != null && epgTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        epgTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ---- Channel name ----
          Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: nameDir,
            textAlign: nameDir == ui.TextDirection.rtl
                ? TextAlign.right
                : TextAlign.left,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEEF2F7),
              letterSpacing: -0.008 * 9,
            ),
          ),

          const SizedBox(height: 3),
          _gradientDivider(accent: accent),

          if (hasFooter) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                if (startLabel.isNotEmpty)
                  Text(
                    startLabel,
                    style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                if (startLabel.isNotEmpty) const SizedBox(width: 4),
                Expanded(
                  child: _buildProgressBar(
                    progress01,
                    accent: accent,
                  ),
                ),
                if (endLabel.isNotEmpty) const SizedBox(width: 4),
                if (endLabel.isNotEmpty)
                  Text(
                    endLabel,
                    style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LogoNameCard — same logo treatment as [_LogoOnlyCard] (inset, contain),
// with a name band below. The logo area uses [Expanded] so the art matches
// logo-only proportions instead of a fixed 52/74 cover box.
// ---------------------------------------------------------------------------

class _LogoNameCard extends StatelessWidget {
  const _LogoNameCard({
    required this.channel,
    this.favoriteOrderIndex,
    this.compact = false,
  });

  final MockLiveChannel channel;
  final int? favoriteOrderIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = context.teamPalette.accent;
    final o = compact ? 3.0 : 5.0;
    const topR = BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    );

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(o, o, o, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: topR,
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 37,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: topR,
                    child: Padding(
                      padding: EdgeInsets.all(o),
                      child: TvCatalogImage(
                        url: liveChannelArtUrl(channel),
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(o, 3, o, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _gradientDivider(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    accent: accent,
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEEF2F7),
                        letterSpacing: -0.008 * 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: o),
          ],
        ),
        if (favoriteOrderIndex != null)
          Positioned(
            top: compact ? 3 : 6,
            right: compact ? 3 : 6,
            child: _favoriteOrderBadge(
              context,
              favoriteOrderIndex!,
              accent: accent,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _LogoOnlyCard — centered logo with neon halo
// ---------------------------------------------------------------------------

class _LogoOnlyCard extends StatelessWidget {
  const _LogoOnlyCard({
    required this.channel,
    this.favoriteOrderIndex,
    this.compact = false,
  });

  final MockLiveChannel channel;
  final int? favoriteOrderIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = context.teamPalette.accent;
    final o = compact ? 3.0 : 5.0;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.all(o),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 37,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(o),
              child: TvCatalogImage(
                url: liveChannelArtUrl(channel),
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
        if (favoriteOrderIndex != null)
          Positioned(
            top: compact ? 3 : 6,
            right: compact ? 3 : 6,
            child: _favoriteOrderBadge(
              context,
              favoriteOrderIndex!,
              accent: accent,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TextOnlyCard — centered channel name, no artwork
// ---------------------------------------------------------------------------

class _TextOnlyCard extends StatelessWidget {
  const _TextOnlyCard({
    required this.channel,
    this.favoriteOrderIndex,
    this.compact = false,
  });

  final MockLiveChannel channel;
  final int? favoriteOrderIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = context.teamPalette.accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF131822),
          child: Align(
            alignment: Alignment(
              liveTvNameHorizontalBiasStore.textOnlyAlignmentX,
              liveTvNameVerticalBiasStore.textOnlyAlignmentY,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 5,
                vertical: compact ? 3 : 4,
              ),
              child: Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: compact ? 9 : 11,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEEF2F7),
                    ),
              ),
            ),
          ),
        ),
        if (favoriteOrderIndex != null)
          Positioned(
            top: compact ? 3 : 6,
            right: compact ? 3 : 6,
            child: _favoriteOrderBadge(
              context,
              favoriteOrderIndex!,
              accent: accent,
            ),
          ),
      ],
    );
  }
}
