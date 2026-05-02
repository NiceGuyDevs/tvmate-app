import 'package:flutter/material.dart';

import '../../data/performance_tier_store.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../l10n/app_localizations.dart';
import '../focus/tv_focusable.dart';
import 'settings_category_tile.dart';

/// Full quality vs optimized vs automatic (RAM-based) — for strong vs weak TV streamers.
class PerformanceSettingsScreen extends StatelessWidget {
  const PerformanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: performanceTierStore,
      builder: (context, _) {
        final current = performanceTierStore.mode;
        final ram = performanceTierStore.totalRamMb;
        final modes = PerformanceTierMode.values;
        final focusIdx = modes.indexOf(current);
        final autofocusIndex = focusIdx >= 0 ? focusIdx : 0;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const SizedBox.expand(
                child: TeamShellBackdrop(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TvFocusable(
                            onActivate: () => Navigator.of(context).pop(),
                            focusPadding: const EdgeInsets.all(4),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.performanceScreenTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.performanceScreenIntro,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (ram != null)
                        Text(
                          l10n.performanceDetectedRam(ram.toString()),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        )
                      else
                        Text(
                          l10n.performanceDetectedRamUnknown,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      if (current == PerformanceTierMode.auto) ...[
                        const SizedBox(height: 6),
                        Text(
                          performanceTierStore.isOptimizedEffective
                              ? l10n.performanceAutoCurrentlyUsingOptimized
                              : l10n.performanceAutoCurrentlyUsingFull,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.9,
                            ),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final rowW = settingsCategoryListWidth(
                              constraints.maxWidth,
                            );
                            return ListView.separated(
                              itemCount: modes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final mode = modes[index];
                                final selected = mode == current;
                                late final String title;
                                late final String subtitle;
                                switch (mode) {
                                  case PerformanceTierMode.auto:
                                    title = l10n.performanceModeAuto;
                                    subtitle =
                                        l10n.performanceModeAutoSubtitle;
                                    break;
                                  case PerformanceTierMode.full:
                                    title = l10n.performanceModeFull;
                                    subtitle =
                                        l10n.performanceModeFullSubtitle;
                                    break;
                                  case PerformanceTierMode.optimized:
                                    title = l10n.performanceModeOptimized;
                                    subtitle =
                                        l10n.performanceModeOptimizedSubtitle;
                                    break;
                                }
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: rowW),
                                    child: SettingsCategoryOptionTile(
                                      autofocus: index == autofocusIndex,
                                      selected: selected,
                                      title: title,
                                      subtitle: subtitle,
                                      onActivate: () async {
                                        await performanceTierStore.setMode(mode);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
