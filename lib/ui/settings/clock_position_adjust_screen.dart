import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/clock_overlay_settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';

/// D-pad adjusts the fine-tune offset for the **currently selected** [ClockCorner].
/// Each corner remembers its own nudge. Back returns to Clock settings (values persist).
class ClockPositionAdjustScreen extends StatefulWidget {
  const ClockPositionAdjustScreen({super.key});

  @override
  State<ClockPositionAdjustScreen> createState() =>
      _ClockPositionAdjustScreenState();
}

class _ClockPositionAdjustScreenState extends State<ClockPositionAdjustScreen> {
  static const double _step = 8.0;

  bool _onHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }

    final store = clockOverlaySettingsStore;
    final corner = store.corner;
    final o = store.offsetForCorner(corner);
    Offset? next;
    if (k == LogicalKeyboardKey.arrowLeft) {
      next = o.translate(-_step, 0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      next = o.translate(_step, 0);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = o.translate(0, -_step);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      next = o.translate(0, _step);
    } else {
      return false;
    }

    unawaited(store.setCornerOffset(corner, next));
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  String _cornerLabel(AppLocalizations l10n, ClockCorner c) => switch (c) {
        ClockCorner.topLeft => l10n.clockCornerTopLeft,
        ClockCorner.topRight => l10n.clockCornerTopRight,
        ClockCorner.bottomLeft => l10n.clockCornerBottomLeft,
        ClockCorner.bottomRight => l10n.clockCornerBottomRight,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  final o = s.offsetForCorner(s.corner);
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
                                size: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.clockPositionAdjustTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        loc.clockPositionCornerLine(
                          _cornerLabel(loc, s.corner),
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.clockPositionOffsetLine(
                          o.dx.round(),
                          o.dy.round(),
                          ClockOverlaySettingsStore.maxCornerOffsetLogical.round(),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                Icons.games_rounded,
                                size: 22,
                                color:
                                    context.teamPalette.accent.withOpacity(0.9),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.enabled
                                      ? loc.clockPositionHelpEnabled
                                      : loc.clockPositionHelpDisabled,
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
}
