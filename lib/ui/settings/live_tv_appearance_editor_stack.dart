import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_grid_columns_store.dart';
import '../../data/live_tv_hero_layout_store.dart';
import '../../data/live_tv_name_horizontal_bias_store.dart';
import '../../data/live_tv_name_vertical_bias_store.dart';
import '../../l10n/app_localizations.dart';
import '../focus/tv_focusable.dart';
import '../live_tv/live_tv_screen.dart';
import 'channel_grid_settings_panel.dart';
import 'live_tv_appearance_panel_widgets.dart';
import 'player_settings_overlay_scope.dart';
import 'tv_remote_keys.dart';

/// Full-screen **Live TV** preview + right-docked channel grid panel.
///
/// Used by [LiveTvEditScreen] (reached from both legacy and new settings
/// → Appearance → Live TV) so behavior stays one place when the legacy
/// settings route is removed.
class LiveTvAppearanceEditorStack extends StatefulWidget {
  const LiveTvAppearanceEditorStack({
    super.key,
    required this.showRouteBackdrop,
    required this.showTopHeaderBar,
    required this.onExit,
  });

  /// When true, paints [playerSettingsRouteBackdrop] behind the preview.
  final bool showRouteBackdrop;

  /// When true, shows the small back chip + “Live TV · Appearance” title row.
  final bool showTopHeaderBar;

  /// Footer **Exit**, header back, and panel `onExit` all call this.
  final VoidCallback onExit;

  @override
  State<LiveTvAppearanceEditorStack> createState() =>
      _LiveTvAppearanceEditorStackState();
}

class _LiveTvAppearanceEditorStackState extends State<LiveTvAppearanceEditorStack> {
  final FocusNode _railFocus = FocusNode();
  final GlobalKey<ChannelGridSettingsPanelHostState> _panelHostKey =
      GlobalKey<ChannelGridSettingsPanelHostState>();

  var _settingsPanelExpanded = true;

  var _section = 1;

  var _posterSubRow = 0;

  var _nameAdjustArmed = false;

  var _channelDisplayFocusIndex = 0;

  static const _kSectionHide = 0;
  static const _kSectionHero = 1;
  static const _kSectionChannels = 2;
  static const _kSectionPoster = 3;

  static int get _kFe => ChannelGridSettingsPanel.kSectionFooterExit;
  static int get _kFr => ChannelGridSettingsPanel.kSectionFooterReset;

  static bool _tvActivateKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    return k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.numpadEnter;
  }

  @override
  void initState() {
    super.initState();
    _channelDisplayFocusIndex = _channelDisplayStyleIndex();
  }

  @override
  void dispose() {
    _railFocus.dispose();
    super.dispose();
  }

  Future<void> _resetLiveTvDefaults() async {
    await liveTvHeroLayoutStore.setHeroHeightPercent(
      LiveTvHeroLayoutStore.defaultHeightPercent,
    );
    await liveTvGridColumnsStore.setColumns(
      LiveTvGridColumnsStore.defaultColumns,
    );
    await liveTvNameVerticalBiasStore.setStep(
      LiveTvNameVerticalBiasStore.defaultStep,
    );
    await liveTvNameHorizontalBiasStore.setStep(
      LiveTvNameHorizontalBiasStore.defaultStep,
    );
    await liveTvCardStyleStore.setStyle(LiveTvCardStyle.logoNameEpg);
    if (mounted) {
      setState(() {
        _channelDisplayFocusIndex = kChannelGridDisplayStyleOrder.indexOf(
          LiveTvCardStyle.logoNameEpg,
        );
      });
    }
  }

  int _channelDisplayStyleIndex() {
    final i = kChannelGridDisplayStyleOrder.indexOf(liveTvCardStyleStore.style);
    return i >= 0 ? i : 0;
  }

  Future<void> _setChannelDisplayStyleIndex(int index) async {
    final order = kChannelGridDisplayStyleOrder;
    final j = index.clamp(0, order.length - 1);
    await liveTvCardStyleStore.setStyle(order[j]);
  }

  KeyEventResult _onRailKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (!_settingsPanelExpanded) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        return KeyEventResult.ignored;
      }
      if (_tvActivateKey(event)) {
        _panelHostKey.currentState?.expandPanel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_tvActivateKey(event)) {
      if (_section == _kFe) {
        widget.onExit();
        return KeyEventResult.handled;
      }
      if (_section == _kFr) {
        unawaited(_resetLiveTvDefaults());
        return KeyEventResult.handled;
      }
      if (_section == _kSectionHide) {
        _panelHostKey.currentState?.collapsePanel();
        return KeyEventResult.handled;
      }
      if (_section == _kSectionPoster && _posterSubRow == 0) {
        unawaited(_setChannelDisplayStyleIndex(_channelDisplayFocusIndex));
        return KeyEventResult.handled;
      }
      if (_section == _kSectionPoster && _posterSubRow == 1) {
        setState(() => _nameAdjustArmed = !_nameAdjustArmed);
        return KeyEventResult.handled;
      }
    }

    if (tvRemoteIsDpadUp(event)) {
      if (_section == _kFe || _section == _kFr) {
        setState(() {
          _section = _kSectionPoster;
          _posterSubRow = 1;
          _nameAdjustArmed = false;
        });
        return KeyEventResult.handled;
      }
      if (_section == _kSectionHero) {
        setState(() => _section = _kSectionHide);
        return KeyEventResult.handled;
      }
      if (_section == _kSectionPoster && _posterSubRow == 1) {
        if (_nameAdjustArmed) {
          unawaited(liveTvNameVerticalBiasStore.adjustStep(-1));
          return KeyEventResult.handled;
        }
        setState(() {
          _posterSubRow = 0;
          _nameAdjustArmed = false;
        });
        return KeyEventResult.handled;
      }
      if (_section == _kSectionPoster && _posterSubRow == 0) {
        final idx = _channelDisplayFocusIndex;
        if (idx >= 2) {
          setState(() => _channelDisplayFocusIndex = idx - 2);
          return KeyEventResult.handled;
        }
      }
      if (_section > _kSectionHide) {
        setState(() {
          _section--;
          _posterSubRow = 0;
          _nameAdjustArmed = false;
        });
      }
      return KeyEventResult.handled;
    }
    if (tvRemoteIsDpadDown(event)) {
      if (_section == _kSectionHide) {
        setState(() => _section = _kSectionHero);
        return KeyEventResult.handled;
      }
      if (_section == _kSectionPoster && _posterSubRow == 0) {
        final idx = _channelDisplayFocusIndex;
        if (idx < 2) {
          setState(() => _channelDisplayFocusIndex = idx + 2);
          return KeyEventResult.handled;
        }
        setState(() => _posterSubRow = 1);
        return KeyEventResult.handled;
      }
      if (_section == _kSectionPoster && _posterSubRow == 1) {
        if (_nameAdjustArmed) {
          unawaited(liveTvNameVerticalBiasStore.adjustStep(1));
          return KeyEventResult.handled;
        }
        setState(() {
          _section = _kFe;
          _nameAdjustArmed = false;
        });
        return KeyEventResult.handled;
      }
      if (_section == _kFe) {
        setState(() => _section = _kFr);
        return KeyEventResult.handled;
      }
      if (_section < _kSectionPoster) {
        setState(() {
          _section++;
          _posterSubRow = 0;
          _nameAdjustArmed = false;
          if (_section == _kSectionPoster) {
            _channelDisplayFocusIndex = _channelDisplayStyleIndex();
          }
        });
      }
      return KeyEventResult.handled;
    }

    if (tvRemoteIsDpadLeft(event) || tvRemoteIsDpadRight(event)) {
      if (_section == _kFe && tvRemoteIsDpadRight(event)) {
        setState(() => _section = _kFr);
        return KeyEventResult.handled;
      }
      if (_section == _kFr && tvRemoteIsDpadLeft(event)) {
        setState(() => _section = _kFe);
        return KeyEventResult.handled;
      }
    }

    if (_section == _kSectionHide) {
      return KeyEventResult.handled;
    }

    switch (_section) {
      case _kSectionHero:
        if (tvRemoteIsDpadRight(event)) {
          unawaited(
            liveTvHeroLayoutStore.adjustHeroHeightPercent(
              LiveTvHeroLayoutStore.heightPercentStep,
            ),
          );
          return KeyEventResult.handled;
        }
        if (tvRemoteIsDpadLeft(event)) {
          unawaited(
            liveTvHeroLayoutStore.adjustHeroHeightPercent(
              -LiveTvHeroLayoutStore.heightPercentStep,
            ),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case _kSectionChannels:
        if (tvRemoteIsDpadRight(event)) {
          unawaited(liveTvGridColumnsStore.adjustColumns(1));
          return KeyEventResult.handled;
        }
        if (tvRemoteIsDpadLeft(event)) {
          unawaited(liveTvGridColumnsStore.adjustColumns(-1));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case _kSectionPoster:
        if (_posterSubRow == 1) {
          if (!_nameAdjustArmed) {
            return KeyEventResult.handled;
          }
          if (tvRemoteIsDpadRight(event)) {
            unawaited(liveTvNameHorizontalBiasStore.adjustStep(1));
            return KeyEventResult.handled;
          }
          if (tvRemoteIsDpadLeft(event)) {
            unawaited(liveTvNameHorizontalBiasStore.adjustStep(-1));
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        final idx = _channelDisplayFocusIndex;
        if (tvRemoteIsDpadRight(event)) {
          if (idx == 0) {
            setState(() => _channelDisplayFocusIndex = 1);
            return KeyEventResult.handled;
          }
          if (idx == 2) {
            setState(() => _channelDisplayFocusIndex = 3);
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        if (tvRemoteIsDpadLeft(event)) {
          if (idx == 1) {
            setState(() => _channelDisplayFocusIndex = 0);
            return KeyEventResult.handled;
          }
          if (idx == 3) {
            setState(() => _channelDisplayFocusIndex = 2);
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  Widget _liveTvAppearanceRailFocus({
    required double designW,
    required double targetW,
    required AppLocalizations loc,
  }) {
    return Focus(
      focusNode: _railFocus,
      autofocus: _settingsPanelExpanded,
      canRequestFocus: true,
      onKeyEvent: _onRailKey,
      child: ChannelGridSettingsPanelHost(
        key: _panelHostKey,
        designW: designW,
        targetW: targetW,
        section: _section,
        posterSubRow: _posterSubRow,
        channelDisplayFocusIndex: _channelDisplayFocusIndex,
        nameAdjustArmed: _nameAdjustArmed,
        tooltipFor: (s) => liveTvPosterLabel(loc, s),
        onExit: widget.onExit,
        onResetDefaults: _resetLiveTvDefaults,
        onPanelVisibilityChanged: (expanded) {
          setState(() {
            _settingsPanelExpanded = expanded;
            if (!expanded) _nameAdjustArmed = false;
          });
          if (expanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _railFocus.requestFocus();
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final designW = math.min(460.0, constraints.maxWidth * 0.44);
        final targetW = designW * 0.65;
        final mq = MediaQuery.of(context);
        final panelTop = mq.padding.top + 4;
        final panelBottom = mq.padding.bottom + 12;
        const panelRight = 12.0;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (widget.showRouteBackdrop)
              Positioned.fill(
                child: playerSettingsRouteBackdrop(context),
              ),
            const Positioned.fill(
              child: ExcludeFocus(
                excluding: true,
                child: LiveTvScreen(previewMode: true),
              ),
            ),
            if (widget.showTopHeaderBar)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Row(
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: TvFocusable(
                          focusPadding: const EdgeInsets.all(4),
                          onActivate: widget.onExit,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              'Live TV · Appearance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: panelTop,
              right: panelRight,
              bottom: _settingsPanelExpanded ? panelBottom : null,
              child: _settingsPanelExpanded
                  ? Align(
                      alignment: Alignment.topRight,
                      child: _liveTvAppearanceRailFocus(
                        designW: designW,
                        targetW: targetW,
                        loc: loc,
                      ),
                    )
                  : _liveTvAppearanceRailFocus(
                      designW: designW,
                      targetW: targetW,
                      loc: loc,
                    ),
            ),
          ],
        );
      },
    );
  }
}
