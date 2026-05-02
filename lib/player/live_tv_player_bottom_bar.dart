import 'package:flutter/material.dart';

import '../ui/widgets/tv_catalog_image.dart';
import '../data/epg_time_display.dart';
import '../xtream/xtream_short_epg_parser.dart';

/// Index of the “anchor” slot: on-air now, or best guess from [listings].
int computeLiveEpgAnchorIndex(List<XtreamEpgListing> listings) {
  if (listings.isEmpty) return 0;
  final onAir = listings.indexWhere(listingIsOnAirNow);
  if (onAir >= 0) return onAir;
  final now = DateTime.now();
  for (var j = 0; j < listings.length; j++) {
    final e = listings[j];
    final s = e.start;
    final en = e.end;
    if (s != null && en != null && !now.isBefore(s) && now.isBefore(en)) {
      return j;
    }
  }
  for (var j = listings.length - 1; j >= 0; j--) {
    final s = listings[j].start;
    if (s != null && !now.isBefore(s)) return j;
  }
  return 0;
}

/// Second Down: **short** translucent dark bar (gradient over video), white multiview glyph.
class LiveTvMultiViewToolsDock extends StatelessWidget {
  const LiveTvMultiViewToolsDock({
    super.key,
    required this.accent,
    required this.stripFocused,
  });

  final Color accent;
  final bool stripFocused;

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
                Colors.black.withValues(alpha: 0.52),
                Colors.black.withValues(alpha: 0.82),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
            border: Border(
              top: BorderSide(
                color: accent.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MultiviewToolbarItem(focused: stripFocused),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiviewGlyph extends StatelessWidget {
  const _MultiviewGlyph({
    required this.color,
    this.size = 22,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final stroke = (s * 0.1).clamp(1.5, 2.5);
    return SizedBox(
      width: s * 1.2,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: s * 0.1,
            child: Container(
              width: s * 0.62,
              height: s * 0.76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.14),
                border: Border.all(color: color, width: stroke),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: s * 0.62,
              height: s * 0.76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.14),
                border: Border.all(color: color, width: stroke),
                color: color.withValues(alpha: 0.14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiviewToolbarItem extends StatelessWidget {
  const _MultiviewToolbarItem({required this.focused});

  final bool focused;

  @override
  Widget build(BuildContext context) {
    final glyph = Colors.white.withValues(alpha: focused ? 1.0 : 0.72);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MultiviewGlyph(color: glyph, size: 24),
        const SizedBox(height: 4),
        Text(
          'Multiview',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            color: Colors.white.withValues(alpha: focused ? 0.95 : 0.5),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.15,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

/// One **hero** EPG card (current window) + side arrows + channel logo on the right.
/// Left/Right on remote still moves the programme window in [PlayerScreen].
class LiveTvPlayerBottomBar extends StatelessWidget {
  const LiveTvPlayerBottomBar({
    super.key,
    required this.channelTitle,
    required this.listings,
    required this.centerIndex,
    required this.accent,
    required this.isLoading,
    this.channelIconUrl,
    this.playlistId,
    this.onEpgEarlier,
    this.onEpgLater,
  });

  final String channelTitle;
  final List<XtreamEpgListing> listings;
  final int centerIndex;
  final Color accent;
  final bool isLoading;

  /// Channel logo URL (grid); fallback to initial in hero.
  final String? channelIconUrl;

  /// Active Xtream playlist — EPG times follow per-playlist zone setting.
  final String? playlistId;

  /// Windows desktop live only; leave null on Android (display-only chevrons).
  final VoidCallback? onEpgEarlier;
  final VoidCallback? onEpgLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = channelTitle.trim();
    final runes = t.runes;
    final initial =
        runes.isEmpty ? '?' : String.fromCharCode(runes.first).toUpperCase();

    if (isLoading && listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Loading guide…',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
      );
    }

    if (listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'No EPG for this channel',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final c = centerIndex.clamp(0, listings.length - 1);
    final canPrev = c > 0;
    final canNext = c < listings.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = (constraints.maxWidth * 0.08).clamp(12.0, 56.0);
        return Padding(
          padding: EdgeInsets.fromLTRB(sideInset, 0, sideInset, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _EpgNavChevron(
                left: true,
                enabled: canPrev,
                onPressed: canPrev ? onEpgEarlier : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LiveEpgHeroCard(
                  listing: listings[c],
                  accent: accent,
                  channelInitial: initial,
                  channelIconUrl: channelIconUrl,
                  playlistId: playlistId,
                ),
              ),
              const SizedBox(width: 6),
              _EpgNavChevron(
                left: false,
                enabled: canNext,
                onPressed: canNext ? onEpgLater : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EpgNavChevron extends StatelessWidget {
  const _EpgNavChevron({
    required this.left,
    required this.enabled,
    this.onPressed,
  });

  final bool left;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = enabled
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.22);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          size: 36,
          color: c,
        ),
        const SizedBox(height: 2),
        Text(
          left ? 'Earlier' : 'Later',
          style: theme.textTheme.labelSmall?.copyWith(
            color: enabled
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.2),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onPressed != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: column,
          ),
        ),
      );
    }
    return column;
  }
}

class _LiveEpgHeroCard extends StatelessWidget {
  const _LiveEpgHeroCard({
    required this.listing,
    required this.accent,
    required this.channelInitial,
    this.channelIconUrl,
    this.playlistId,
  });

  final XtreamEpgListing listing;
  final Color accent;
  final String channelInitial;
  final String? channelIconUrl;
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        listing.title.trim().isNotEmpty ? listing.title.trim() : '—';
    final desc = listing.description.trim();
    final hasDesc = desc.isNotEmpty;
    final timeStr =
        formatEpgTimeRangeForPlaylist(listing, playlistId) ?? '—';
    final onAir = listingIsOnAirNow(listing);

    Border glowBorder;
    List<BoxShadow> glowShadow;
    if (onAir) {
      glowBorder = Border.all(
        width: 2.2,
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.92),
      );
      glowShadow = [
        BoxShadow(
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
          blurRadius: 14,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 10,
        ),
      ];
    } else {
      glowBorder = Border.all(
        color: accent.withValues(alpha: 0.5),
        width: 1.4,
      );
      glowShadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 8,
        ),
      ];
    }

    final url = channelIconUrl?.trim() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.72),
        border: glowBorder,
        boxShadow: glowShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: onAir
                            ? const Color(0xFFB71C1C).withValues(alpha: 0.55)
                            : accent.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        onAir ? 'LIVE' : 'GUIDE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                          letterSpacing: 0.85,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (hasDesc) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: url.isNotEmpty
                      ? TvCatalogImage(url: url)
                      : ColoredBox(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: Center(
                            child: Text(
                              channelInitial,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w900,
                              ),
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
