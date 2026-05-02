import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';
import 'tv_media_urls.dart';

/// One shared look for missing or failed live channel logos and VOD posters.
class TvUniversalMediaPlaceholder extends StatelessWidget {
  const TvUniversalMediaPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    return LayoutBuilder(
      builder: (context, c) {
        final side = (!c.maxWidth.isFinite || !c.maxHeight.isFinite)
            ? 56.0
            : math.min(c.maxWidth, c.maxHeight);
        final iconSize = (side * 0.4).clamp(24.0, 56.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                p.surfaceElevated,
                Color.lerp(p.surfaceElevated, p.accent, 0.14)!,
                p.surface,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.live_tv_rounded,
              size: iconSize,
              color: p.accent.withOpacity(0.44),
            ),
          ),
        );
      },
    );
  }
}

/// Neutral placeholder when poster / icon fails or is absent.
class TvImagePlaceholder extends StatelessWidget {
  const TvImagePlaceholder({
    super.key,
    this.icon = Icons.image_not_supported_outlined,
    this.iconSize = 36,
  });

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    return ColoredBox(
      color: p.surfaceElevated,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: TeamPalette.textMuted.withOpacity(0.65),
        ),
      ),
    );
  }
}

/// Subtle diagonal shimmer while a remote image loads.
class TvImageShimmer extends StatefulWidget {
  const TvImageShimmer({super.key});

  @override
  State<TvImageShimmer> createState() => _TvImageShimmerState();
}

class _TvImageShimmerState extends State<TvImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        final p = context.teamPalette;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.2 + t * 2.4, -0.2),
                  end: Alignment(-0.2 + t * 2.4, 0.8),
                  colors: [
                    p.surfaceElevated,
                    p.surface.withOpacity(0.88),
                    p.surfaceElevated,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.accent.withOpacity(0.55),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Network image with shimmer loading and [TvUniversalMediaPlaceholder] fallback.
class TvCatalogImage extends StatelessWidget {
  const TvCatalogImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const TvUniversalMediaPlaceholder();
    }

    if (catalogArtIsBundledAsset(trimmed)) {
      return Image.asset(
        trimmed,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const TvUniversalMediaPlaceholder(),
      );
    }

    return Image.network(
      trimmed,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const TvImageShimmer();
      },
      errorBuilder: (_, __, ___) => const TvUniversalMediaPlaceholder(),
    );
  }
}
