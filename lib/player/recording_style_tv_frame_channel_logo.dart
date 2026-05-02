import 'package:flutter/material.dart';

import '../theme/team_palette_theme.dart';
import '../ui/widgets/tv_catalog_image.dart';

/// Recording catch-up style: channel logo in the “TV screen” area, with optional
/// [recording_tv_frame.png] bezel on top. A light bezel is always drawn so the
/// control reads on dark overlays even if the PNG is subtle or slow to load.
///
/// Pass [accent] when the widget is built in a route where [TeamPaletteTheme]
/// may not resolve the same palette as the underlying player (e.g. EPG overlay).
class RecordingStyleTvFrameChannelLogo extends StatelessWidget {
  const RecordingStyleTvFrameChannelLogo({
    super.key,
    required this.iconUrl,
    this.accent,
  });

  final String? iconUrl;

  /// Optional; defaults to [context.teamPalette.accent].
  final Color? accent;

  static const double slotW = 72;
  static const double slotH = 56;

  @override
  Widget build(BuildContext context) {
    final u = iconUrl?.trim();
    final accentColor = accent ?? context.teamPalette.accent;

    return SizedBox(
      width: slotW,
      height: slotH,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          // Always-visible outline + inner “screen” so the widget never reads empty.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.white30,
                  width: 1.25,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Same asset as Recording EPG rows (drawn on top of the base bezel).
          Positioned.fill(
            child: Image.asset(
              'assets/images/recording_tv_frame.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 8),
              child: Center(
                child: _LogoInScreen(iconUrl: u, accent: accentColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoInScreen extends StatelessWidget {
  const _LogoInScreen({
    required this.iconUrl,
    required this.accent,
  });

  final String? iconUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final u = iconUrl?.trim();
    if (u == null || u.isEmpty) {
      return Icon(
        Icons.live_tv_rounded,
        size: 30,
        color: accent.withValues(alpha: 0.92),
      );
    }
    return TvCatalogImage(
      url: u,
      fit: BoxFit.contain,
      alignment: Alignment.center,
    );
  }
}
