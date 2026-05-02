import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shell/shell_destination.dart';
import '../../theme/team_palette_theme.dart';

/// Demo copy only — replaced by real IPTV data later.
class DemoPlaceholderPage extends StatelessWidget {
  const DemoPlaceholderPage({
    super.key,
    required this.destination,
  });

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final p = context.teamPalette;
    return ColoredBox(
      color: p.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  l10n.settingsDemoModeAbout,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                destination.icon,
                size: 40,
                color: p.accent.withValues(alpha: 0.95),
              ),
              const SizedBox(height: 20),
              Text(
                destination.labelL10n(l10n),
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 36),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  _blurbFor(l10n, destination),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _blurbFor(AppLocalizations l10n, ShellDestination d) => switch (d) {
      ShellDestination.liveTv => l10n.demoBlurbLiveTv,
      ShellDestination.movies => l10n.demoBlurbMovies,
      ShellDestination.series => l10n.demoBlurbSeries,
      ShellDestination.recording => l10n.demoBlurbRecording,
      ShellDestination.team => l10n.demoBlurbTeam,
      ShellDestination.settings => l10n.demoBlurbSettings,
      _ => l10n.demoBlurbOptional,
    };
