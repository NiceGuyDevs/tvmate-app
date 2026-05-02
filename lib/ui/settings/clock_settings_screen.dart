import 'package:flutter/material.dart';

import '../../data/clock_overlay_settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'clock_position_adjust_screen.dart';
import 'player_settings_overlay_scope.dart';

/// ~20% smaller than original tile / icon metrics (TV clock options grid).
const double _kClockUiScale = 0.8;

/// Compact clock overlay options — matches main Settings icon grid.
class ClockSettingsScreen extends StatelessWidget {
  const ClockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          playerSettingsRouteBackdrop(context),
          SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: ListenableBuilder(
            listenable: clockOverlaySettingsStore,
            builder: (context, _) {
              final s = clockOverlaySettingsStore;
              final loc = AppLocalizations.of(context)!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TvFocusable(
                        focusPadding: const EdgeInsets.all(4),
                        onActivate: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14 * _kClockUiScale,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.settingsClock,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: context.teamPalette.surfaceElevated,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                      boxShadow: context.teamPalette.railCardRestShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 22,
                            color: context.teamPalette.accent.withOpacity(0.9),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              loc.clockInfoBanner,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.88),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView(
                      gridDelegate:
                          SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220 * _kClockUiScale,
                        mainAxisSpacing: 8 * _kClockUiScale,
                        crossAxisSpacing: 8 * _kClockUiScale,
                        childAspectRatio: 2.35,
                      ),
                      children: [
                        _toggleTile(
                          context,
                          title: s.enabled ? loc.clockToggleOn : loc.clockToggleOff,
                          subtitle: s.enabled ? loc.clockTapHide : loc.clockTapShow,
                          icon: s.enabled
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_outlined,
                          selected: s.enabled,
                          onActivate: () => s.setEnabled(!s.enabled),
                          autofocus: true,
                        ),
                        _toggleTile(
                          context,
                          title: s.framed ? loc.clockFrameOn : loc.clockFrameOff,
                          subtitle: s.framed
                              ? loc.clockFrameSubOn
                              : loc.clockFrameSubOff,
                          icon: s.framed
                              ? Icons.dashboard_customize_outlined
                              : Icons.crop_free_rounded,
                          selected: s.framed,
                          onActivate: () => s.setFramed(!s.framed),
                        ),
                        _optionTile(
                          context,
                          title: loc.clock12Hour,
                          subtitle: loc.clock12HourSub,
                          icon: Icons.schedule_rounded,
                          selected: !s.use24Hour,
                          onActivate: () => s.setUse24Hour(false),
                        ),
                        _optionTile(
                          context,
                          title: loc.clock24Hour,
                          subtitle: loc.clock24HourSub,
                          icon: Icons.av_timer_rounded,
                          selected: s.use24Hour,
                          onActivate: () => s.setUse24Hour(true),
                        ),
                        for (final sz in ClockSizePreset.values)
                          _optionTile(
                            context,
                            title: _sizeLabel(loc, sz),
                            subtitle: loc.clockSizeSubtitle,
                            icon: switch (sz) {
                              ClockSizePreset.small => Icons.looks_one,
                              ClockSizePreset.medium => Icons.looks_two,
                              ClockSizePreset.large => Icons.looks_3,
                            },
                            selected: s.size == sz,
                            onActivate: () => s.setSize(sz),
                          ),
                        _cornerTile(
                          context,
                          loc,
                          title: loc.clockCornerTopLeft,
                          corner: ClockCorner.topLeft,
                          icon: Icons.north_west_rounded,
                        ),
                        _cornerTile(
                          context,
                          loc,
                          title: loc.clockCornerTopRight,
                          corner: ClockCorner.topRight,
                          icon: Icons.north_east_rounded,
                        ),
                        _cornerTile(
                          context,
                          loc,
                          title: loc.clockCornerBottomLeft,
                          corner: ClockCorner.bottomLeft,
                          icon: Icons.south_west_rounded,
                        ),
                        _cornerTile(
                          context,
                          loc,
                          title: loc.clockCornerBottomRight,
                          corner: ClockCorner.bottomRight,
                          icon: Icons.south_east_rounded,
                        ),
                        _adjustPositionTile(context, loc),
                        _opacityTile(context, loc, 0.25),
                        _opacityTile(context, loc, 0.5),
                        _opacityTile(context, loc, 0.75),
                        _opacityTile(context, loc, 1.0),
                        for (var i = 0;
                            i <
                                ClockOverlaySettingsStore.presetColors.length;
                            i++)
                          _colorTile(context, loc, i),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
        ],
      ),
    );
  }

  static String _sizeLabel(AppLocalizations l10n, ClockSizePreset sz) =>
      switch (sz) {
        ClockSizePreset.small => l10n.clockSizeSmall,
        ClockSizePreset.medium => l10n.clockSizeMedium,
        ClockSizePreset.large => l10n.clockSizeLarge,
      };

  static double get _iconSize => 15 * _kClockUiScale;
  static double get _checkSize => 17 * _kClockUiScale;
  static double get _iconCircle => 26 * _kClockUiScale;

  Widget _toggleTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onActivate,
    bool autofocus = false,
  }) {
    final theme = Theme.of(context);
    return TvFocusable(
      autofocus: autofocus,
      onActivate: onActivate,
      focusPadding: EdgeInsets.symmetric(
        horizontal: 5 * _kClockUiScale,
        vertical: 5 * _kClockUiScale,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * _kClockUiScale,
          vertical: 8 * _kClockUiScale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(
            color: selected
                ? context.teamPalette.accent.withOpacity(0.62)
                : Colors.white.withOpacity(0.1),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: _iconCircle,
              height: _iconCircle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                icon,
                size: _iconSize,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            SizedBox(width: 8 * _kClockUiScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12.4 * _kClockUiScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2 * _kClockUiScale),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11 * _kClockUiScale,
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

  Widget _optionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onActivate,
  }) {
    final theme = Theme.of(context);
    return TvFocusable(
      onActivate: onActivate,
      focusPadding: EdgeInsets.symmetric(
        horizontal: 5 * _kClockUiScale,
        vertical: 5 * _kClockUiScale,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * _kClockUiScale,
          vertical: 8 * _kClockUiScale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(
            color: selected
                ? context.teamPalette.accent.withOpacity(0.62)
                : Colors.white.withOpacity(0.1),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: _iconCircle,
              height: _iconCircle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                icon,
                size: _iconSize,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            SizedBox(width: 8 * _kClockUiScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12.4 * _kClockUiScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2 * _kClockUiScale),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11 * _kClockUiScale,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: context.teamPalette.accent,
                size: _checkSize,
              ),
          ],
        ),
      ),
    );
  }

  Widget _cornerTile(
    BuildContext context,
    AppLocalizations loc, {
    required String title,
    required ClockCorner corner,
    required IconData icon,
  }) {
    final s = clockOverlaySettingsStore;
    final selected = s.corner == corner;
    return _optionTile(
      context,
      title: title,
      subtitle: loc.clockCornerSubtitle,
      icon: icon,
      selected: selected,
      onActivate: () => s.setCorner(corner),
    );
  }

  Widget _adjustPositionTile(BuildContext context, AppLocalizations loc) {
    final theme = Theme.of(context);
    return TvFocusable(
      onActivate: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const ClockPositionAdjustScreen(),
          ),
        );
      },
      focusPadding: EdgeInsets.symmetric(
        horizontal: 5 * _kClockUiScale,
        vertical: 5 * _kClockUiScale,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * _kClockUiScale,
          vertical: 8 * _kClockUiScale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: _iconCircle,
              height: _iconCircle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                Icons.open_with_rounded,
                size: _iconSize,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            SizedBox(width: 8 * _kClockUiScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.clockAdjustPosition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12.4 * _kClockUiScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2 * _kClockUiScale),
                  Text(
                    loc.clockAdjustPositionSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11 * _kClockUiScale,
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

  Widget _opacityTile(
    BuildContext context,
    AppLocalizations loc,
    double value,
  ) {
    final s = clockOverlaySettingsStore;
    final pct = (value * 100).round();
    const presets = [0.25, 0.5, 0.75, 1.0];
    final nearest = presets.reduce(
      (a, b) =>
          (s.opacity - a).abs() < (s.opacity - b).abs() ? a : b,
    );
    final selected = (value - nearest).abs() < 0.001;
    return _optionTile(
      context,
      title: loc.clockOpacityPercent(pct),
      subtitle: loc.clockOpacitySubtitle,
      icon: Icons.opacity_rounded,
      selected: selected,
      onActivate: () => s.setOpacity(value),
    );
  }

  Widget _colorTile(
    BuildContext context,
    AppLocalizations loc,
    int index,
  ) {
    final s = clockOverlaySettingsStore;
    final c = ClockOverlaySettingsStore.presetColors[index];
    final selected = s.colorIndex == index;
    final theme = Theme.of(context);
    return TvFocusable(
      onActivate: () => s.setColorIndex(index),
      focusPadding: EdgeInsets.symmetric(
        horizontal: 5 * _kClockUiScale,
        vertical: 5 * _kClockUiScale,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * _kClockUiScale,
          vertical: 8 * _kClockUiScale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(
            color: selected
                ? context.teamPalette.accent.withOpacity(0.62)
                : Colors.white.withOpacity(0.1),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: _iconCircle,
              height: _iconCircle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
            ),
            SizedBox(width: 8 * _kClockUiScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.clockColorPreset(index + 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12.4 * _kClockUiScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2 * _kClockUiScale),
                  Text(
                    loc.clockColorPresetSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11 * _kClockUiScale,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: context.teamPalette.accent,
                size: _checkSize,
              ),
          ],
        ),
      ),
    );
  }
}
