import 'package:flutter/material.dart';

import '../../theme/team_palette_theme.dart';
import 'vod_brushed_panel_fill.dart';

/// Brushed two-tone panel matching Subtitle settings / appearance family.
class ParentalPanelCard extends StatelessWidget {
  const ParentalPanelCard({
    super.key,
    required this.child,
    this.title,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    /// Tighter padding, smaller title — PIN / small prompts (~40% less visual weight).
    this.compact = false,
    /// When set (e.g. wide PIN plate: fields left + numpad right), overrides compact width clamp.
    this.maxWidthOverride,
  });

  final Widget child;
  final String? title;
  final double maxWidth;
  final EdgeInsets padding;
  final bool compact;
  final double? maxWidthOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final cardBorder = Color.alphaBlend(
      shell.accent.withValues(alpha: 0.28),
      Colors.white.withValues(alpha: 0.22),
    );
    const outerRadius = 12.0;
    final effectiveMaxWidth = maxWidthOverride ??
        (compact ? (maxWidth * 0.6).clamp(200.0, 320.0) : maxWidth);
    final effectivePadding = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 10)
        : padding;
    final titleSize = compact ? 13.5 : 17.0;
    final gapAfterTitle = compact ? 6.0 : 10.0;
    final gapAfterDivider = compact ? 6.0 : 10.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerRadius),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.topCenter,
            children: [
              const Positioned.fill(
                child: VodBrushedPanelFill(),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                ),
              ),
              Padding(
                padding: effectivePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: gapAfterTitle),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      SizedBox(height: gapAfterDivider),
                    ],
                    child,
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

/// Inner inset block (subtitle editor style).
Widget parentalPanelInsetBlock({required Widget child, bool compact = false}) {
  final pad = compact
      ? const EdgeInsets.fromLTRB(8, 6, 8, 8)
      : const EdgeInsets.fromLTRB(10, 8, 10, 10);
  final radius = compact ? 7.0 : 8.0;
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
      ),
      color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
    ),
    child: Padding(
      padding: pad,
      child: child,
    ),
  );
}
