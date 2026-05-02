import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/subtitle_settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shell/team_shell_backdrop.dart';
import '../focus/tv_focusable.dart';
import 'settings_category_tile.dart';

/// Default subtitle language for OpenSubtitles search ordering.
class SubtitleSettingsScreen extends StatefulWidget {
  const SubtitleSettingsScreen({super.key});

  static const subtitleLanguageCodes = <String>[
    'en',
    'he',
    'es',
    'fr',
    'ar',
    'de',
    'it',
    'pt',
    'ru',
    'nl',
    'pl',
    'tr',
  ];

  @override
  State<SubtitleSettingsScreen> createState() => _SubtitleSettingsScreenState();
}

class _SubtitleSettingsScreenState extends State<SubtitleSettingsScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() async {
      await SubtitleSettingsStore.instance.ensureLoaded();
      if (mounted) setState(() {});
    });
  }

  String _labelForLang(String code, AppLocalizations l10n) {
    switch (code) {
      case 'en':
        return l10n.languageEnglish;
      case 'he':
        return l10n.languageHebrew;
      case 'fr':
        return l10n.languageFrench;
      case 'es':
        return l10n.languageSpanish;
      case 'ar':
        return l10n.languageArabic;
      default:
        return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: SubtitleSettingsStore.instance,
      builder: (context, _) {
        final current = SubtitleSettingsStore.instance.defaultLanguageCode;
        final focusIdx = SubtitleSettingsScreen.subtitleLanguageCodes
            .indexOf(current)
            .clamp(0, SubtitleSettingsScreen.subtitleLanguageCodes.length - 1);

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
                              l10n.subtitleSettingsTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.subtitleSettingsDefaultLanguageHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final rowW =
                                settingsCategoryListWidth(constraints.maxWidth);
                            return ListView.separated(
                              itemCount: SubtitleSettingsScreen
                                  .subtitleLanguageCodes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final code = SubtitleSettingsScreen
                                    .subtitleLanguageCodes[index];
                                final selected = code == current;
                                final label =
                                    '${_labelForLang(code, l10n)} ($code)';
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: rowW),
                                    child: SettingsCategoryOptionTile(
                                      autofocus: index == focusIdx,
                                      selected: selected,
                                      title: label,
                                      onActivate: () async {
                                        await SubtitleSettingsStore.instance
                                            .setDefaultLanguageCode(code);
                                        if (mounted) setState(() {});
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
