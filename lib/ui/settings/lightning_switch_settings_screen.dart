import 'package:flutter/material.dart';

import '../../data/lightning_switch_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shell/team_shell_backdrop.dart';
import '../focus/tv_focusable.dart';
import 'settings_category_tile.dart';

/// Enables leapfrog dual-decoder live switching on Full-quality devices.
class LightningSwitchSettingsScreen extends StatelessWidget {
  const LightningSwitchSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: lightningSwitchStore,
      builder: (context, _) {
        final on = lightningSwitchStore.enabled;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const SizedBox.expand(child: TeamShellBackdrop()),
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
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.95),
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.lightningSwitchScreenTitle,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.lightningSwitchScreenIntro,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final rowW = settingsCategoryListWidth(
                              constraints.maxWidth,
                            );
                            return ListView(
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: rowW),
                                    child: SettingsCategoryOptionTile(
                                      autofocus: !on,
                                      selected: !on,
                                      title: l10n.lightningSwitchModeOff,
                                      subtitle: l10n.lightningSwitchModeOffSubtitle,
                                      onActivate: () async {
                                        await lightningSwitchStore.setEnabled(false);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: rowW),
                                    child: SettingsCategoryOptionTile(
                                      autofocus: on,
                                      selected: on,
                                      title: l10n.lightningSwitchModeOn,
                                      subtitle: l10n.lightningSwitchModeOnSubtitle,
                                      onActivate: () async {
                                        await lightningSwitchStore.setEnabled(true);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.lightningSwitchLagSnack,
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
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
