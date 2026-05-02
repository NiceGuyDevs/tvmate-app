import 'package:flutter/material.dart';

import '../../data/library_controller.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';

/// Centered loading for Xtream catalog fetch — skeleton-style hint + spinner.
class CatalogLoadingBody extends StatelessWidget {
  const CatalogLoadingBody({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    return ColoredBox(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: p.glassPanelFill,
              border: Border.all(
                color: p.neonLine.withOpacity(0.24),
                width: 1.2,
              ),
              boxShadow: p.glassFloatShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CatalogSkeletonBlock(width: double.infinity, height: 18),
                const SizedBox(height: 14),
                _CatalogSkeletonBlock(width: 280, height: 14),
                const SizedBox(height: 28),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: p.accent,
                    strokeWidth: 2.8,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few seconds…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: TeamPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogSkeletonBlock extends StatelessWidget {
  const _CatalogSkeletonBlock({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.teamPalette.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
      ),
    );
  }
}

/// Builds [CatalogErrorBody] for Xtream fetch failures.
///
/// Auth-style errors (bad credentials, HTTP 404 on player_api, etc.) use
/// [errorMessage] as the main headline so users see e.g. "Bad PlayList Login"
/// instead of a generic title plus the same text as a subtitle.
CatalogErrorBody catalogXtreamErrorBody({
  required XtreamBrowseErrorKind kind,
  required String? errorMessage,
  required String Function() titleForKind,
}) {
  if (kind == XtreamBrowseErrorKind.auth &&
      errorMessage != null &&
      errorMessage.trim().isNotEmpty) {
    return CatalogErrorBody(message: errorMessage.trim(), subtitle: null);
  }
  return CatalogErrorBody(message: titleForKind(), subtitle: errorMessage);
}

/// Friendly error with retry (re-runs [XtreamCatalogRepository.syncFromLibrary]).
class CatalogErrorBody extends StatelessWidget {
  const CatalogErrorBody({
    super.key,
    required this.message,
    this.subtitle,
  });

  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    return ColoredBox(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: p.glassPanelFill,
              border: Border.all(
                color: p.neonLine.withOpacity(0.24),
                width: 1.2,
              ),
              boxShadow: p.glassFloatShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: TeamPalette.textMuted.withOpacity(0.85),
                ),
                const SizedBox(height: 22),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: TeamPalette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                TvFocusable(
                  autofocus: true,
                  onActivate: () =>
                      xtreamCatalogRepository.syncFromLibrary(libraryController),
                  focusPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.focusBorderRadius),
                      color: p.accent.withOpacity(0.14),
                      border: Border.all(
                        color: p.accent.withOpacity(0.45),
                      ),
                    ),
                    child: Text(
                      'Try again',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty category or empty row hint.
class CatalogEmptyBody extends StatelessWidget {
  const CatalogEmptyBody({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    return ColoredBox(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: p.glassPanelFill,
            border: Border.all(
              color: p.neonLine.withOpacity(0.22),
              width: 1.2,
            ),
            boxShadow: p.glassFloatShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 52,
                color: TeamPalette.textMuted.withOpacity(0.75),
              ),
              const SizedBox(height: 20),
              Text(
                'Nothing here yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: TeamPalette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
