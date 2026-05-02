import 'package:flutter/material.dart';

import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';

/// Target width for TV settings option rows (~half screen), centered — see Language /
/// Performance / Subtitles reference layouts.
double settingsCategoryListWidth(double screenWidth) =>
    (screenWidth * 0.52).clamp(280.0, 540.0);

/// Single- or two-line option row: rounded, semi-transparent, accent when selected.
class SettingsCategoryOptionTile extends StatelessWidget {
  const SettingsCategoryOptionTile({
    super.key,
    required this.selected,
    required this.onActivate,
    required this.title,
    this.subtitle,
    this.autofocus = false,
  });

  final bool selected;
  final VoidCallback onActivate;
  final String title;
  final String? subtitle;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.teamPalette.accent;
    final hasSub = subtitle != null && subtitle!.isNotEmpty;

    return TvFocusable(
      autofocus: autofocus,
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: hasSub ? 12 : 13,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.38),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment:
              hasSub ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  if (hasSub) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.28,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: EdgeInsets.only(left: 8, top: hasSub ? 2 : 0),
                child: Icon(
                  Icons.check_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
