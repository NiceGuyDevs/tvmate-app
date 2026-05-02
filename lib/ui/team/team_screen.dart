import 'package:flutter/material.dart';

import '../../data/team_visual_store.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../shell/shell_destination.dart';
import '../../shell/shell_navigation_hub.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette.dart';
import '../focus/tv_focusable.dart';

/// Linear scale for theme option tiles (~60% smaller than original: 40% of size).
const double _kTeamOptionsLayoutScale = 0.4;

/// How much of the available width the centered grid may use (remaining margin on both sides).
const double _kTeamGridWidthFraction = 0.78;

/// Pick visual team (backdrop + chrome). Functionality unchanged.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final FocusNode _settingsStyleFocus;
  late final FocusNode _emberFocus;
  late final FocusNode _nocturneFocus;

  @override
  void initState() {
    super.initState();
    _settingsStyleFocus = FocusNode(debugLabel: 'teamSettingsStyle');
    _emberFocus = FocusNode(debugLabel: 'teamEmber');
    _nocturneFocus = FocusNode(debugLabel: 'teamNocturne');
    ShellContentFocusRegistry.register(
      ShellDestination.team,
      _requestShellPrimaryFocus,
    );
  }

  FocusNode _focusForTeam(AppVisualTeam team) => switch (team) {
        AppVisualTeam.settingsStyle => _settingsStyleFocus,
        AppVisualTeam.ember => _emberFocus,
        AppVisualTeam.nocturne => _nocturneFocus,
      };

  void _requestShellPrimaryFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = _focusForTeam(teamVisualStore.team);
      if (n.canRequestFocus) n.requestFocus();
    });
  }

  void _selectThemeAndGoLive(AppVisualTeam team) {
    teamVisualStore.setTeam(team).then((_) {
      ShellNavigationHub.instance.goTo(ShellDestination.liveTv);
    });
  }

  @override
  void dispose() {
    ShellContentFocusRegistry.unregister(ShellDestination.team);
    _settingsStyleFocus.dispose();
    _emberFocus.dispose();
    _nocturneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pushed = Navigator.of(context).canPop();
    return ListenableBuilder(
      listenable: teamVisualStore,
      builder: (context, _) {
        final current = teamVisualStore.team;
        final body = Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 24, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Settings style, Ember, or Nocturne — same layout, different colours.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: TeamPalette.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gridW = constraints.maxWidth *
                            _kTeamGridWidthFraction;
                        const s = _kTeamOptionsLayoutScale;
                        final crossSpacing = 10.0 * s;
                        final mainSpacing = 8.0 * s;
                        // Keep enough height for title + two-line subtitle after scaling.
                        final tileHeight =
                            (76.0 * s).clamp(52.0, 76.0);
                        final tileWidth =
                            (gridW - 2 * crossSpacing) / 3;
                        final aspect = tileWidth / tileHeight;
                        return SizedBox(
                          width: gridW,
                          child: GridView(
                            padding: EdgeInsets.zero,
                            physics: const ClampingScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: crossSpacing,
                              mainAxisSpacing: mainSpacing,
                              childAspectRatio: aspect,
                            ),
                            children: [
                          _TeamOptionTile(
                            focusNode: _settingsStyleFocus,
                            title: AppVisualTeam.settingsStyle.label,
                            subtitle:
                                'Cyan chrome + settings.html backdrop',
                            selected: current == AppVisualTeam.settingsStyle,
                            preview: AppVisualTeam.settingsStyle.palette,
                            onActivate: () => _selectThemeAndGoLive(
                              AppVisualTeam.settingsStyle,
                            ),
                          ),
                          _TeamOptionTile(
                            focusNode: _emberFocus,
                            title: AppVisualTeam.ember.label,
                            subtitle:
                                'Warm shell + coral / ember focus',
                            selected: current == AppVisualTeam.ember,
                            preview: AppVisualTeam.ember.palette,
                            onActivate: () => _selectThemeAndGoLive(
                              AppVisualTeam.ember,
                            ),
                          ),
                          _TeamOptionTile(
                            focusNode: _nocturneFocus,
                            title: AppVisualTeam.nocturne.label,
                            subtitle: 'Dark purple–rose + neon-pink focus',
                            selected: current == AppVisualTeam.nocturne,
                            preview: AppVisualTeam.nocturne.palette,
                            onActivate: () => _selectThemeAndGoLive(
                              AppVisualTeam.nocturne,
                            ),
                          ),
                        ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
        );
        if (!pushed) {
          return ColoredBox(
            color: Colors.transparent,
            child: body,
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const SizedBox.expand(
                child: TeamShellBackdrop(),
              ),
              SafeArea(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _TeamOptionTile extends StatelessWidget {
  const _TeamOptionTile({
    required this.focusNode,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.preview,
    required this.onActivate,
  });

  final FocusNode focusNode;
  final String title;
  final String subtitle;
  final bool selected;
  final TeamPalette preview;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = preview;
    final accent = p.accent;
    final magenta = p.nebulaMagenta;
    const s = _kTeamOptionsLayoutScale;
    final swatch = 26.0 * s;
    final swatchRadius = 8.0 * s;
    final padH = 8.0 * s;
    final padV = 8.0 * s;
    final gapAfterSwatch = 8.0 * s;
    final borderRadius = 12.0 * s;
    final titleSize = (14.0 * s).clamp(11.0, 14.0);
    final subtitleSize = (11.0 * s).clamp(9.5, 11.0);
    final checkSize = (18.0 * s).clamp(14.0, 18.0);

    return TvFocusable(
      focusNode: focusNode,
      onActivate: onActivate,
      focusPadding: EdgeInsets.symmetric(vertical: 2 * s, horizontal: 4 * s),
      child: AnimatedContainer(
        duration: AppTheme.focusAnimationDuration,
        curve: AppTheme.focusAnimationCurve,
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: Colors.white.withOpacity(selected ? 0.07 : 0.035),
          border: Border.all(
            color: selected
                ? accent.withOpacity(0.5)
                : Colors.white.withOpacity(0.09),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.16),
                    blurRadius: 12 * s,
                    offset: Offset(0, 4 * s),
                  ),
                  BoxShadow(
                    color: magenta.withOpacity(0.08),
                    blurRadius: 14 * s,
                    offset: Offset(0, 5 * s),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: swatch,
              height: swatch,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(swatchRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(0.88),
                    magenta.withOpacity(0.78),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.28),
                    blurRadius: 6 * s,
                    offset: Offset(0, 2 * s),
                  ),
                ],
              ),
            ),
            SizedBox(width: gapAfterSwatch),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: titleSize,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 2 * s),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: TeamPalette.textMuted,
                      fontSize: subtitleSize,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: EdgeInsets.only(left: 2 * s),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: accent,
                  size: checkSize,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
