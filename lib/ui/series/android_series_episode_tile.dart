import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'mock_series_data.dart';

const double kAndroidSeriesEpisodeTileRadius = 12;

/// Title strip under the 16:9 thumbnail — shorter bar, same text size as before.
const double kAndroidEpisodeCaptionStripHeight = 27.0;

/// Landscape "TV" episode card: 16:9 still on top, caption bar below (Android series details).
class AndroidSeriesEpisodeTile extends StatelessWidget {
  const AndroidSeriesEpisodeTile({
    super.key,
    required this.series,
    required this.episode,
    required this.focused,
  });

  final MockSeries series;
  final MockEpisode episode;
  final bool focused;

  static String imageUrlForEpisode(MockSeries s, MockEpisode e) {
    final still = episodeStillUrl(s, e).trim();
    final poster = seriesPosterUrl(s).trim();
    final raw = still.isNotEmpty ? still : poster;
    return catalogPosterHiResUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final thumbH = w * 9 / 16;
        return SizedBox(
          width: w,
          height: thumbH + kAndroidEpisodeCaptionStripHeight,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(kAndroidSeriesEpisodeTileRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: thumbH,
                  child: TvCatalogImage(
                    url: imageUrlForEpisode(series, episode),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                SizedBox(
                  height: kAndroidEpisodeCaptionStripHeight,
                  child: _AndroidEpisodeCaptionBar(
                    label: episode.codename,
                    focused: focused,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dark bar when unfocused; white bar + dark text + optional marquee when focused.
class _AndroidEpisodeCaptionBar extends StatefulWidget {
  const _AndroidEpisodeCaptionBar({
    required this.label,
    required this.focused,
  });

  final String label;
  final bool focused;

  @override
  State<_AndroidEpisodeCaptionBar> createState() =>
      _AndroidEpisodeCaptionBarState();
}

class _AndroidEpisodeCaptionBarState extends State<_AndroidEpisodeCaptionBar>
    with SingleTickerProviderStateMixin {
  AnimationController? _marquee;
  double _overflow = 0;

  @override
  void didUpdateWidget(covariant _AndroidEpisodeCaptionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focused != oldWidget.focused) {
      if (!widget.focused) {
        _marquee?.dispose();
        _marquee = null;
        _overflow = 0;
      }
      _syncMarquee();
    }
    if (widget.label != oldWidget.label) {
      _overflow = 0;
      _marquee?.dispose();
      _marquee = null;
    }
  }

  @override
  void dispose() {
    _marquee?.dispose();
    super.dispose();
  }

  void _syncMarquee() {
    if (!widget.focused || _overflow <= 1) {
      _marquee?.dispose();
      _marquee = null;
      return;
    }
    _marquee ??= AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (8000 + _overflow * 12).clamp(8000, 20000).round(),
      ),
    )..repeat();
  }

  void _scheduleMeasureOverflow(double maxWidth, TextStyle style) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tp = TextPainter(
        text: TextSpan(text: widget.label, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: double.infinity);
      final next = (tp.width - maxWidth).clamp(0.0, double.infinity);
      if ((next - _overflow).abs() > 0.5) {
        setState(() => _overflow = next);
        _syncMarquee();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      fontSize: 12.5,
      height: 1.05,
    );

    final unfocusedStyle = baseStyle?.copyWith(
      color: Colors.white.withValues(alpha: 0.95),
    );
    final focusedStyle = baseStyle?.copyWith(
      color: const Color(0xFF0A0A0C),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(kAndroidSeriesEpisodeTileRadius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.focused
              ? Colors.white
              : Colors.black.withValues(alpha: 0.72),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth - 16;
            if (widget.focused) {
              _scheduleMeasureOverflow(maxW, focusedStyle!);
            }

            final text = Text(
              widget.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: widget.focused ? focusedStyle : unfocusedStyle,
            );

            if (!widget.focused || _overflow <= 1 || _marquee == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: text,
                ),
              );
            }

            return AnimatedBuilder(
              animation: _marquee!,
              builder: (context, _) {
                final t = _marquee!.value;
                final u = 0.5 - 0.5 * math.cos(2 * math.pi * t);
                final x = -_overflow * u;
                return ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Transform.translate(
                        offset: Offset(x, 0),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          style: focusedStyle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
