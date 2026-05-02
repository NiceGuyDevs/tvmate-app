import 'package:flutter/material.dart';

import '../../data/app_locale_store.dart';
import '../../shell/team_shell_backdrop.dart';
import 'language_picker_english.dart';
import '../focus/tv_focusable.dart';
import 'settings_category_tile.dart';

/// Pick interface language (English, Hebrew, French, Spanish, Arabic).
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const _codes = AppLocaleStore.supportedLanguageCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = appLocaleStore.languageCode;
    final focusIndex = _codes.indexOf(current);
    final autofocusIdx = focusIndex >= 0 ? focusIndex : 0;

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
                      Text(
                        LanguagePickerEnglish.screenTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final rowW =
                            settingsCategoryListWidth(constraints.maxWidth);
                        return ListView.separated(
                          itemCount: _codes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final code = _codes[index];
                            final selected = code == current;
                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: rowW),
                                child: SettingsCategoryOptionTile(
                                  autofocus: index == autofocusIdx,
                                  selected: selected,
                                  title: LanguagePickerEnglish.nameForCode(code),
                                  onActivate: () async {
                                    await appLocaleStore.setLanguageCode(code);
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
  }
}
