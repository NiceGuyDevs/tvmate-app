import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/subtitle_appearance_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/team_palette.dart';
import '../theme/team_palette_theme.dart';
import 'vod_subtitle_dcard_chrome.dart';

/// VOD subtitle look editor: same d-card + list-well language as
/// [VodSubtitlePickerPanel] ([VodSubtitleDcardLayeredShell]).
/// `width: min(100%, 380px)` in vod-subtitle-style-editor-panel.html
const double _kStyleEditorMaxWidth = 380;

class VodSubtitleStylePanel extends StatefulWidget {
  const VodSubtitleStylePanel({
    super.key,
    required this.accent,
    required this.onClose,
    required this.onPositionDelta,
    this.onResetLayoutExtras,
  });

  final Color accent;
  final VoidCallback onClose;

  /// Nudge subtitle position in logical pixels (session-only; parent clamps).
  final void Function(Offset delta) onPositionDelta;

  /// Clear per-title subtitle position before [SubtitleAppearanceStore.resetToDefaults].
  final Future<void> Function()? onResetLayoutExtras;

  @override
  State<VodSubtitleStylePanel> createState() => _VodSubtitleStylePanelState();
}

class _VodGradientSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _VodGradientSliderTrackShape({
    required this.start,
    required this.end,
  });

  final Color start;
  final Color end;

  @override
  bool get isRounded => true;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [start, end],
      ).createShader(trackRect);
    final double r = trackRect.height / 2;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(r)),
      paint,
    );
  }
}

class _VodSubtitleStylePanelState extends State<VodSubtitleStylePanel> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'vodSubtitleStylePanel');
  final SubtitleAppearanceStore store = SubtitleAppearanceStore.instance;

  /// 0=subtitles, 1=bg, 2=opacity, 3=text, 4=size, 5=position, 6=exit, 7=reset
  int _row = 0;

  static const double _opacityStep = 0.04;

  /// Focused swatch index while on row 1 or 2.
  int _swatch = 0;

  /// Row 5: first **Select** enters move mode; D-pad moves subtitle; second **Select** exits.
  bool _positionAdjustActive = false;

  @override
  void initState() {
    super.initState();
    _swatch = store.backgroundColorIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _syncSwatchFromRow() {
    if (_row == 1) _swatch = store.backgroundColorIndex;
    if (_row == 3) _swatch = store.textColorIndex;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      if (_positionAdjustActive) {
        setState(() => _positionAdjustActive = false);
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_row == 5 && _positionAdjustActive) {
        widget.onPositionDelta(const Offset(0, -12));
      } else if (_row == 6) {
        setState(() => _row = 5);
      } else if (_row == 7) {
        setState(() => _row = 6);
      } else if (_row > 0) {
        setState(() {
          _row--;
          if (_row != 5) _positionAdjustActive = false;
          _syncSwatchFromRow();
        });
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      if (_row == 5 && _positionAdjustActive) {
        widget.onPositionDelta(const Offset(0, 12));
      } else if (_row == 5) {
        setState(() {
          _row = 6;
          _positionAdjustActive = false;
        });
      } else if (_row == 6) {
        setState(() => _row = 7);
      } else if (_row < 5) {
        setState(() {
          _row++;
          if (_row != 5) _positionAdjustActive = false;
          _syncSwatchFromRow();
        });
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_row == 7) {
        setState(() => _row = 6);
        return KeyEventResult.handled;
      }
      _handleLeft();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_row == 6) {
        setState(() => _row = 7);
        return KeyEventResult.handled;
      }
      _handleRight();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      if (_row == 0) {
        unawaited(store.setSubtitlesEnabled(!store.subtitlesEnabled));
        setState(() {});
      } else if (_row == 5) {
        setState(() => _positionAdjustActive = !_positionAdjustActive);
      } else if (_row == 6) {
        widget.onClose();
      } else if (_row == 7) {
        unawaited(() async {
          if (widget.onResetLayoutExtras != null) {
            await widget.onResetLayoutExtras!();
          }
          await store.resetToDefaults();
          if (!mounted) return;
          setState(() {
            _swatch = store.backgroundColorIndex;
            _positionAdjustActive = false;
          });
        }());
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  void _handleLeft() {
    switch (_row) {
      case 1:
        if (_swatch > 0) {
          setState(() => _swatch--);
          unawaited(store.setBackgroundColorIndex(_swatch));
        }
        break;
      case 2:
        unawaited(
          store.setBackgroundOpacity(store.backgroundOpacity - _opacityStep),
        );
        setState(() {});
        break;
      case 3:
        if (_swatch > 0) {
          setState(() => _swatch--);
          unawaited(store.setTextColorIndex(_swatch));
        }
        break;
      case 4:
        unawaited(store.setFontSizeSp(store.fontSizeSp - 1));
        setState(() {});
        break;
      case 5:
        if (_positionAdjustActive) {
          widget.onPositionDelta(const Offset(-12, 0));
        }
        break;
      default:
        break;
    }
  }

  void _handleRight() {
    switch (_row) {
      case 1:
        if (_swatch < SubtitleAppearanceStore.paletteColors.length - 1) {
          setState(() => _swatch++);
          unawaited(store.setBackgroundColorIndex(_swatch));
        }
        break;
      case 2:
        unawaited(
          store.setBackgroundOpacity(store.backgroundOpacity + _opacityStep),
        );
        setState(() {});
        break;
      case 3:
        if (_swatch < SubtitleAppearanceStore.paletteColors.length - 1) {
          setState(() => _swatch++);
          unawaited(store.setTextColorIndex(_swatch));
        }
        break;
      case 4:
        unawaited(store.setFontSizeSp(store.fontSizeSp + 1));
        setState(() {});
        break;
      case 5:
        if (_positionAdjustActive) {
          widget.onPositionDelta(const Offset(12, 0));
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    // Panel: matches Html Sampels/vod-subtitle-style-editor-panel.html layers.
    final focusColor = shell.defaultFocusRingColor;
    // .track transparency row: linear-gradient(90deg, #7B1FA2, var(--accent))
    const transGradStart = Color(0xFF7B1FA2);
    final transGradEnd = shell.accent;
    const sizeGradStart = Color(0xFF2d3344);
    final sizeGradEnd = shell.accent;

    return Theme(
      data: theme.copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(0.0),
          thumbVisibility: WidgetStatePropertyAll(false),
        ),
      ),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              if (w <= 0 || h <= 0) {
                return const SizedBox.shrink();
              }

              // .ov-scrim { padding: 20px 16px; … } — top-right card
              const topInset = 20.0;
              const rightInset = 16.0;
              final panelW = math
                  .min(_kStyleEditorMaxWidth, w - 16)
                  .clamp(260.0, _kStyleEditorMaxWidth)
                  .toDouble();
              final panelH = (h * 0.9).clamp(240.0, 520.0);

              return Material(
                type: MaterialType.transparency,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const VodSubtitleDcardScrim(),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: topInset,
                            right: rightInset,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: panelW,
                              maxHeight: panelH,
                            ),
                            child: VodSubtitleDcardLayeredShell(
                              borderRadius: kVodSubtitleStyleEditorCardRadius,
                              child: Material(
                                color: Colors.transparent,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // .style-head
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _headerRow(
                                            l10n,
                                            shell,
                                            theme,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n
                                                .subtitleAppearanceVodPanelTitle,
                                            style: theme
                                                .textTheme.labelSmall?.copyWith(
                                              color: TeamPalette.textSecondary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 9.5,
                                              letterSpacing: 0.06,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                    // .style-body
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          0,
                                          10,
                                          8,
                                        ),
                                        physics:
                                            const ClampingScrollPhysics(),
                                        children: [
                                          AnimatedBuilder(
                                            animation: store,
                                            builder: (context, _) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _appearanceSection(
                                                            shell: shell,
                                                            active: _row == 1,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                _rowLabel(
                                                                  l10n
                                                                      .subtitleAppearanceLabelSubtitleBackground,
                                                                ),
                                                                _colorRow(
                                                                  focusColor:
                                                                      focusColor,
                                                                  focused:
                                                                      _row ==
                                                                          1,
                                                                  selectedIndex:
                                                                      store
                                                                          .backgroundColorIndex,
                                                                  focusIndex: _row ==
                                                                          1
                                                                      ? _swatch
                                                                      : store
                                                                          .backgroundColorIndex,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          _sliderValueRow(
                                                            shell: shell,
                                                            label: l10n
                                                                .subtitleAppearanceLabelTransparency,
                                                            valueText:
                                                                '${(store.backgroundOpacity * 100).round().clamp(0, 100)}%',
                                                            focused: _row == 2,
                                                            child: _gradientSlider(
                                                              value: store
                                                                  .backgroundOpacity
                                                                  .clamp(
                                                                SubtitleAppearanceStore
                                                                    .backgroundOpacityMin,
                                                                SubtitleAppearanceStore
                                                                    .backgroundOpacityMax,
                                                              ),
                                                              min:
                                                                  SubtitleAppearanceStore
                                                                      .backgroundOpacityMin,
                                                              max:
                                                                  SubtitleAppearanceStore
                                                                      .backgroundOpacityMax,
                                                              gradStart:
                                                                  transGradStart,
                                                              gradEnd: transGradEnd,
                                                              focused: _row == 2,
                                                              onChanged: (x) {
                                                                unawaited(store
                                                                    .setBackgroundOpacity(
                                                                        x));
                                                                setState(
                                                                  () {},
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          _appearanceSection(
                                                            shell: shell,
                                                            active: _row == 3,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                _rowLabel(
                                                                  '${l10n.subtitleAppearanceTextColor}:',
                                                                ),
                                                                _colorRow(
                                                                  focusColor:
                                                                      focusColor,
                                                                  focused:
                                                                      _row ==
                                                                          3,
                                                                  selectedIndex:
                                                                      store
                                                                          .textColorIndex,
                                                                  focusIndex: _row ==
                                                                          3
                                                                      ? _swatch
                                                                      : store
                                                                          .textColorIndex,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          _sliderValueRow(
                                                            shell: shell,
                                                            label:
                                                                '${l10n.subtitleAppearanceSize}:',
                                                            valueText:
                                                                '${store.fontSizeSp.round()} px',
                                                            focused: _row == 4,
                                                            child: _gradientSlider(
                                                              value: store
                                                                  .fontSizeSp
                                                                  .clamp(
                                                                SubtitleAppearanceStore
                                                                    .fontSizeMin,
                                                                SubtitleAppearanceStore
                                                                    .fontSizeMax,
                                                              ),
                                                              min:
                                                                  SubtitleAppearanceStore
                                                                      .fontSizeMin,
                                                              max:
                                                                  SubtitleAppearanceStore
                                                                      .fontSizeMax,
                                                              gradStart: sizeGradStart,
                                                              gradEnd: sizeGradEnd,
                                                              focused: _row == 4,
                                                              onChanged: (x) {
                                                                unawaited(
                                                                  store
                                                                      .setFontSizeSp(
                                                                    x,
                                                                  ),
                                                                );
                                                                setState(
                                                                  () {},
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          _previewPositionRow(
                                                            l10n: l10n,
                                                            shell: shell,
                                                            focusColor:
                                                                focusColor,
                                                            focused:
                                                                _row == 5,
                                                            adjusting:
                                                                _positionAdjustActive,
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          _footerWell(
                                                            shell: shell,
                                                            focusColor:
                                                                focusColor,
                                                            l10n: l10n,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _appearanceSection({
    required TeamPalette shell,
    required bool active,
    required Widget child,
  }) {
    // .well: padding 8px, inset 0 1px 0 rgba(255,255,255,0.04) (HTML)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: vodSubtitleDcardListWellDecoration(
        focused: active,
        focusColor: shell.defaultFocusRingColor,
        borderRadius: 8,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: ColoredBox(
              color: Color(0x0AFFFFFF),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _footerWell({
    required TeamPalette shell,
    required Color focusColor,
    required AppLocalizations l10n,
  }) {
    return _appearanceSection(
      shell: shell,
      active: _row == 6 || _row == 7,
      child: _footerActionsRow(
        l10n,
        shell,
        focusColor,
      ),
    );
  }

  Widget _headerRow(
    AppLocalizations l10n,
    TeamPalette shell,
    ThemeData theme,
  ) {
    final on = store.subtitlesEnabled;
    final smallCtrl = BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
    return _appearanceSection(
      shell: shell,
      active: _row == 0,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              'CC',
              style: TextStyle(
                color: shell.shellTitleColor,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.subtitleAppearanceSubtitles,
              style: theme.textTheme.titleSmall?.copyWith(
                color: shell.shellTitleColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: smallCtrl,
            child: Icon(
              Icons.tune_rounded,
              size: 16,
              color: shell.shellBodyHint,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: on
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [
                        widget.accent,
                        Color.lerp(
                          widget.accent,
                          const Color(0xFF0C1018),
                          0.25,
                        )!,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  )
                : smallCtrl,
            child: Icon(
              Icons.check_rounded,
              size: 16,
              color: on ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  /// Exit + Reset — pinned below scroll; two equal controls in one row.
  Widget _footerActionsRow(
    AppLocalizations l10n,
    TeamPalette shell,
    Color focusColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _footerChip(
            label: l10n.subtitleAppearanceExitMenu,
            icon: Icons.close_rounded,
            focused: _row == 6,
            shell: shell,
            focusColor: focusColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _footerChip(
            label: l10n.subtitleAppearanceResetDefaults,
            icon: Icons.restore_rounded,
            focused: _row == 7,
            shell: shell,
            focusColor: focusColor,
          ),
        ),
      ],
    );
  }

  Widget _footerChip({
    required String label,
    required IconData icon,
    required bool focused,
    required TeamPalette shell,
    required Color focusColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: focused
              ? focusColor.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.08),
          width: focused ? 1.5 : 1,
        ),
        color: focused
            ? focusColor.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: focusColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: focused ? focusColor : shell.shellTitleColor.withValues(
                  alpha: 0.75,
                ),
            size: 18,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: shell.shellTitleColor.withValues(
                  alpha: focused ? 0.95 : 0.82,
                ),
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowLabel(String text) {
    // .row-label in vod-subtitle-style-editor-panel.html
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: TeamPalette.textSecondary,
          letterSpacing: 1.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _sliderValueRow({
    required TeamPalette shell,
    required String label,
    required String valueText,
    required bool focused,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: vodSubtitleDcardListWellDecoration(
        focused: focused,
        focusColor: shell.defaultFocusRingColor,
        borderRadius: 8,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: ColoredBox(color: Color(0x0AFFFFFF)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: shell.shellTitleColor.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                Expanded(child: child),
                SizedBox(
                  width: 44,
                  child: Text(
                    valueText,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: shell.shellTitleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientSlider({
    required double value,
    required double min,
    required double max,
    required Color gradStart,
    required Color gradEnd,
    required bool focused,
    required ValueChanged<double> onChanged,
  }) {
    final ring = context.teamPalette.defaultFocusRingColor;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        trackShape: _VodGradientSliderTrackShape(
          start: gradStart,
          end: gradEnd,
        ),
        thumbColor: Colors.white,
        overlayColor: ring.withValues(alpha: 0.22),
        // Non-transparent so [BaseSliderTrackShape] keeps a real track height.
        activeTrackColor: gradStart.withValues(alpha: 0.06),
        inactiveTrackColor: gradEnd.withValues(alpha: 0.06),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }

  Widget _colorRow({
    required Color focusColor,
    required bool focused,
    required int selectedIndex,
    required int focusIndex,
  }) {
    const colors = SubtitleAppearanceStore.paletteColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < colors.length; i++)
            _colorDot(
              focusColor,
              colors[i],
              selected: i == selectedIndex,
              focused: focused && i == focusIndex,
            ),
        ],
      ),
    );
  }

  Widget _colorDot(
    Color focusColor,
    Color c, {
    required bool selected,
    required bool focused,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: selected ? 22 : 21,
      height: selected ? 22 : 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(selected ? 6 : 20),
        border: Border.all(
          color: focused
              ? focusColor
              : (selected
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.2)),
          width: focused ? 2.5 : (selected ? 2 : 1),
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: focusColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Container(
        width: selected ? 16 : 15,
        height: selected ? 16 : 15,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  /// Mockup: left = preview copy, right = position D-pad (no extra “Position” line).
  Widget _previewPositionRow({
    required AppLocalizations l10n,
    required TeamPalette shell,
    required Color focusColor,
    required bool focused,
    required bool adjusting,
  }) {
    return _appearanceSection(
      shell: shell,
      active: focused || adjusting,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              l10n.subtitleAppearancePreviewLine,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: shell.shellTitleColor.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _dPadVisual(
            focusColor: focusColor,
            accent: widget.accent,
            focused: focused,
            adjusting: adjusting,
            iconSize: 14,
          ),
        ],
      ),
    );
  }

  Widget _dPadVisual({
    required Color focusColor,
    required Color accent,
    required bool focused,
    required bool adjusting,
    double iconSize = 22,
  }) {
    final dim = Colors.white.withValues(alpha: 0.32);
    final hot =
        adjusting ? accent.withValues(alpha: 0.9) : focusColor.withValues(
              alpha: 0.8,
            );
    final pad = iconSize * 0.35;
    final center = iconSize * 0.92;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_drop_up_rounded,
            color: focused ? hot : dim,
            size: iconSize,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_left_rounded,
                color: focused ? hot : dim,
                size: iconSize,
              ),
              SizedBox(width: pad * 0.45),
              Container(
                width: center,
                height: center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: adjusting
                        ? accent.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
              SizedBox(width: pad * 0.45),
              Icon(
                Icons.arrow_right_rounded,
                color: focused ? hot : dim,
                size: iconSize,
              ),
            ],
          ),
          Icon(
            Icons.arrow_drop_down_rounded,
            color: focused ? hot : dim,
            size: iconSize,
          ),
        ],
      ),
    );
  }
}
