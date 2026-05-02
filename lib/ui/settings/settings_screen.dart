import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../data/clock_overlay_settings_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/lightning_switch_store.dart';
import '../../data/performance_tier_store.dart';
import '../../data/live_tv_grid_columns_store.dart';
import '../../data/subtitle_settings_store.dart';
import '../../data/live_tv_hero_layout_store.dart';
import '../../data/library_controller.dart';
import '../../shell/app_top_bar.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../shell/shell_destination.dart';
import '../team/team_screen.dart';
import '../focus/tv_focusable.dart';
import '../live_tv/live_tv_favorites_screen.dart';
import 'add_playlist_screen.dart';
import 'backup_screen.dart';
import 'clock_settings_screen.dart';
import 'edit_settings_screen.dart';
import 'language_picker_english.dart';
import 'language_settings_screen.dart';
import 'my_playlists_screen.dart';
import 'parental_control_settings_screen.dart';
import 'lightning_switch_settings_screen.dart';
import 'performance_settings_screen.dart';
import 'subtitle_settings_screen.dart';
import 'player_settings_overlay_scope.dart';
import 'recording_edit_screen.dart';
import 'top_menu_manager_screen.dart';

/// Library & experience settings — TV focus first.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.registerShellFocus = true,
  });

  /// When **false** (e.g. fullscreen overlay on top of live TV), do not register
  /// with [ShellContentFocusRegistry] so the shell tab’s registry is unchanged.
  final bool registerShellFocus;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FocusNode _shellPrimaryFocus;

  @override
  void initState() {
    super.initState();
    _shellPrimaryFocus = FocusNode(debugLabel: 'settingsShellPrimary');
    if (widget.registerShellFocus) {
      ShellContentFocusRegistry.register(
        ShellDestination.settings,
        _requestShellPrimaryFocus,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SubtitleSettingsStore.instance.ensureLoaded());
    });
  }

  void _requestShellPrimaryFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_shellPrimaryFocus.canRequestFocus) {
        _shellPrimaryFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (widget.registerShellFocus) {
      ShellContentFocusRegistry.unregister(ShellDestination.settings);
    }
    _shellPrimaryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        libraryController,
        clockOverlaySettingsStore,
        liveTvHeroLayoutStore,
        SubtitleSettingsStore.instance,
        performanceTierStore,
        lightningSwitchStore,
        parentalControlStore,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);
        final count = libraryController.playlists.length;
        final demoOn = libraryController.useDemoData;
        final demoToggleSubtitle = count == 0
            ? l10n.settingsDemoModeSubtitleBrowseDemo
            : l10n.settingsDemoModeSubtitleRealChannels;
        final entries = <_SettingsEntry>[
          _SettingsEntry(
            icon: Icons.language_rounded,
            title: LanguagePickerEnglish.settingsTitle,
            subtitle: LanguagePickerEnglish.settingsSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const LanguageSettingsScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.speed_rounded,
            title: l10n.settingsPerformance,
            subtitle: l10n.settingsPerformanceSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const PerformanceSettingsScreen(),
              );
            },
          ),
          if (!performanceTierStore.isOptimizedEffective)
            _SettingsEntry(
              icon: Icons.bolt_rounded,
              title: l10n.settingsLightningSwitch,
              subtitle: l10n.settingsLightningSwitchSubtitle,
              onActivate: () {
                pushSettingsRoute<void>(
                  context,
                  (_) => const LightningSwitchSettingsScreen(),
                );
              },
            ),
          _SettingsEntry(
            icon: Icons.closed_caption_rounded,
            title: l10n.settingsSubtitles,
            subtitle: l10n.settingsSubtitlesSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const SubtitleSettingsScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.menu_rounded,
            title: l10n.settingsTopMenuManager,
            subtitle: l10n.settingsTopMenuManagerSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const TopMenuManagerScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: ShellDestination.team.icon,
            title: ShellDestination.team.labelL10n(l10n),
            subtitle: l10n.settingsShellThemeSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const TeamScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: ShellDestination.playlist.icon,
            title: ShellDestination.playlist.labelL10n(l10n),
            subtitle: l10n.settingsShellPlaylistSubtitle,
            onActivate: () => showPlaylistQuickSwitcher(context),
          ),
          _SettingsEntry(
            icon: Icons.add_to_queue_rounded,
            title: l10n.settingsAddPlaylist,
            subtitle: l10n.settingsAddPlaylistSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const AddPlaylistScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.library_books_rounded,
            title: l10n.settingsMyPlaylists,
            subtitle: l10n.settingsMyPlaylistsCount(count),
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const MyPlaylistsScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.star_rounded,
            title: l10n.settingsFavoriteSetup,
            subtitle: l10n.settingsFavoriteSetupSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const LiveTvFavoritesScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.schedule_rounded,
            title: l10n.settingsClock,
            subtitle: clockOverlaySettingsStore.enabled
                ? l10n.settingsClockOn
                : l10n.settingsClockOff,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => ClockSettingsScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.tune_rounded,
            title: l10n.settingsAppearance,
            subtitle: l10n.settingsAppearanceSubtitle(
              liveTvHeroLayoutStore.heroHeightPercent,
              liveTvGridColumnsStore.columns,
            ),
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => EditSettingsScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.fiber_smart_record_rounded,
            title: l10n.settingsRecordingEdit,
            subtitle: l10n.settingsRecordingEditSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const RecordingEditScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.lock_outline_rounded,
            title: l10n.parentalSettingsTitle,
            subtitle: l10n.parentalSettingsSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const ParentalControlSettingsScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: Icons.cloud_download_rounded,
            title: l10n.settingsBackup,
            subtitle: l10n.settingsBackupSubtitle,
            onActivate: () {
              pushSettingsRoute<void>(
                context,
                (_) => const BackupScreen(),
              );
            },
          ),
          _SettingsEntry(
            icon: demoOn ? Icons.theaters_rounded : Icons.playlist_play_rounded,
            title: l10n.settingsDemoMode,
            subtitle: demoToggleSubtitle,
            onActivate: null,
          ),
        ];

        return ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.14)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.settings_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.settingsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (demoOn) ...[
                  Text(
                    l10n.settingsDemoModeAbout,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.78),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Expanded(
                  child: GridView.builder(
                    itemCount: entries.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.35,
                    ),
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      return _IconSettingsTile(
                        entry: item,
                        focusNode:
                            index == 0 ? _shellPrimaryFocus : null,
                      );
                    },
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

class _SettingsEntry {
  const _SettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onActivate,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onActivate;
}

class _IconSettingsTile extends StatelessWidget {
  const _IconSettingsTile({
    required this.entry,
    this.focusNode,
  });

  final _SettingsEntry entry;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      onActivate: entry.onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                entry.icon,
                size: 15,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

