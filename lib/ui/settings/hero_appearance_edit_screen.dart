import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../data/live_tv_hero_appearance_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import '../live_tv/hero_tv_bezel_frame.dart';
import '../live_tv/live_tv_screen.dart';
import '../widgets/hero_hsv_color_card.dart';
import 'player_settings_overlay_scope.dart';
import 'vod_brushed_panel_fill.dart';

/// Same inset fill/border as [VodSubtitlePickerPanel] columns / [MovieGridSettingsPanel].
BoxDecoration _heroInsetPanelDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
  );
}

/// Hero background editor: **D-pad safe** (only [TvFocusable] + step rows), two columns,
/// [FittedBox] scales to one view. Sheet is **above** the back button in the tree so focus
/// hits controls first. No [Slider], no gesture rings.
class HeroAppearanceEditScreen extends StatefulWidget {
  const HeroAppearanceEditScreen({super.key});

  @override
  State<HeroAppearanceEditScreen> createState() =>
      _HeroAppearanceEditScreenState();
}

class _HeroAppearanceEditScreenState extends State<HeroAppearanceEditScreen> {
  var _exitArmed = false;
  var _controlsVisible = true;

  /// Opening this screen: TV frame starts on (user can turn it off). Same UI otherwise.
  static const _panelScale = 0.75; // 25% smaller than the fitted design size.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      liveTvHeroAppearanceStore.setTvFrameOn(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final loc = AppLocalizations.of(context);
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final edgePadW = size.width * 0.02;
    final edgePadH = size.height * 0.02;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_exitArmed) {
          setState(() => _exitArmed = true);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: playerSettingsRouteBackdrop(context),
            ),
            const Positioned.fill(
              child: ExcludeFocus(
                excluding: true,
                child: LiveTvScreen(previewMode: true),
              ),
            ),
            if (_controlsVisible)
              Positioned(
                right: pad.right + edgePadW,
                bottom: pad.bottom + edgePadH,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width - pad.left - pad.right - edgePadW,
                    maxHeight: size.height -
                        pad.top -
                        pad.bottom -
                        edgePadH -
                        44,
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: LayoutBuilder(
                      builder: (context, boxConstraints) {
                        final maxW = min(boxConstraints.maxWidth, 720.0);
                        final maxH = boxConstraints.maxHeight;
                        return Transform.scale(
                          scale: _panelScale,
                          alignment: Alignment.bottomRight,
                          filterQuality: FilterQuality.medium,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomRight,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxW,
                                maxHeight: maxH,
                              ),
                              child: _HeroAppearanceSheet(
                                onReset: () =>
                                    liveTvHeroAppearanceStore.resetToDefault(),
                                onHide: () =>
                                    setState(() => _controlsVisible = false),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom + 8,
                child: Center(
                  child: TvFocusable(
                    onActivate: () => setState(() => _controlsVisible = true),
                    focusPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: shell.accent.withValues(alpha: 0.45),
                        ),
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          loc.heroAppearanceShowControls,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                child: Row(
                  children: [
                    TvFocusable(
                      focusPadding: const EdgeInsets.all(4),
                      onActivate: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.heroAppearanceScreenTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroAppearanceSheet extends StatelessWidget {
  const _HeroAppearanceSheet({
    required this.onReset,
    required this.onHide,
  });

  final VoidCallback onReset;
  final VoidCallback onHide;

  static const _designW = 640.0;
  static const _designH = 472.0;
  static const _r = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final loc = AppLocalizations.of(context);

    final cardBorder = Color.alphaBlend(
      shell.accent.withValues(alpha: 0.28),
      Colors.white.withValues(alpha: 0.22),
    );

    return ListenableBuilder(
      listenable: liveTvHeroAppearanceStore,
      builder: (context, _) {
        final store = liveTvHeroAppearanceStore;
        final brushMode =
            store.washMode == LiveTvHeroAppearanceStore.washModeBrush;

        return SizedBox(
          width: _designW,
          height: _designH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_r),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(child: VodBrushedPanelFill()),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            shell.accent.withValues(alpha: 0.85),
                            shell.nebulaMagenta.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: FocusTraversalGroup(
                      policy: WidgetOrderTraversalPolicy(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HelpAndPreviewRow(
                              store: store,
                              loc: loc,
                              theme: theme,
                              shell: shell,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            _FrameSection(
                              store: store,
                              shell: shell,
                              loc: loc,
                              theme: theme,
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 300,
                                    child: DecoratedBox(
                                      decoration: _heroInsetPanelDecoration(),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          6,
                                          8,
                                          8,
                                        ),
                                        child: _LeftColumn(
                                          store: store,
                                          shell: shell,
                                          loc: loc,
                                          theme: theme,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: _heroInsetPanelDecoration(),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          6,
                                          8,
                                          8,
                                        ),
                                        child: _RightColumn(
                                          store: store,
                                          shell: shell,
                                          loc: loc,
                                          theme: theme,
                                          brushMode: brushMode,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TvFocusable(
                                    onActivate: onReset,
                                    focusPadding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    focusedBorderWidth: 1.35,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: shell.accent.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        loc.heroAppearanceReset,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TvFocusable(
                                    onActivate: onHide,
                                    focusPadding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    focusedBorderWidth: 1.35,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: shell.nebulaMagenta.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        loc.heroAppearanceHideControls,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HelpAndPreviewRow extends StatelessWidget {
  const _HelpAndPreviewRow({
    required this.store,
    required this.loc,
    required this.theme,
    required this.shell,
  });

  final LiveTvHeroAppearanceStore store;
  final AppLocalizations loc;
  final ThemeData theme;
  final TeamPalette shell;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.heroAppearanceHelpIntro,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                loc.heroAppearanceHintShort,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: TeamPalette.textMuted,
                  fontSize: 8,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _ColorPreviewTile(
          label: loc.heroAppearancePreviewBackgroundLabel,
          color: store.baseColor,
          accent: shell.accent,
          theme: theme,
        ),
        const SizedBox(width: 6),
        _ColorPreviewTile(
          label: loc.heroAppearancePreviewOverlayLabel,
          color: store.washColor,
          accent: shell.nebulaMagenta,
          theme: theme,
        ),
      ],
    );
  }
}

class _ColorPreviewTile extends StatelessWidget {
  const _ColorPreviewTile({
    required this.label,
    required this.color,
    required this.accent,
    required this.theme,
  });

  final String label;
  final Color color;
  final Color accent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.5),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: TeamPalette.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _FrameSection extends StatelessWidget {
  const _FrameSection({
    required this.store,
    required this.shell,
    required this.loc,
    required this.theme,
  });

  final LiveTvHeroAppearanceStore store;
  final TeamPalette shell;
  final AppLocalizations loc;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _heroInsetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.tv_rounded,
                    size: 17,
                    color: shell.accent.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.heroAppearanceFrameBanner,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        loc.heroAppearanceFrameExplain,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: TeamPalette.textMuted,
                          fontSize: 8,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TvFocusable(
                  onActivate: () =>
                      liveTvHeroAppearanceStore.setTvFrameOn(!store.tvFrameOn),
                  focusPadding: const EdgeInsets.all(2),
                  focusedBorderWidth: 1.35,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: store.tvFrameOn
                            ? shell.accent
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                      color: store.tvFrameOn
                          ? shell.accent.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Text(
                      store.tvFrameOn
                          ? loc.heroAppearanceOn
                          : loc.heroAppearanceOff,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (store.tvFrameOn) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.heroAppearanceFrameProfile,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 8.5,
                        color: TeamPalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: _FrameChip(
                        label: [
                          loc.heroAppearanceFrameSlim,
                          loc.heroAppearanceFrameClassic,
                          loc.heroAppearanceFrameBold,
                          loc.heroAppearanceFrameMinimal,
                        ][i],
                        selected: store.tvFrameStyle == i,
                        shell: shell,
                        onTap: () =>
                            liveTvHeroAppearanceStore.setTvFrameStyle(i),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                loc.heroAppearanceBezelFinish,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8.5,
                  color: TeamPalette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var f = 0; f <= HeroTvBezelFrame.finishMax; f++)
                    TvFocusable(
                      onActivate: () =>
                          liveTvHeroAppearanceStore.setBezelFinish(f),
                      focusPadding: const EdgeInsets.all(2),
                      focusedBorderWidth: 1.35,
                      child: _FinishOrb(
                        size: 24,
                        colors:
                            HeroTvBezelFrame.heroBezelOuterGradientColors(f),
                        selected: store.bezelFinish == f,
                        shell: shell,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.store,
    required this.shell,
    required this.loc,
    required this.theme,
  });

  final LiveTvHeroAppearanceStore store;
  final TeamPalette shell;
  final AppLocalizations loc;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.heroAppearanceSectionBackground,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 2),
        HeroColorTvSteppers(
          title: loc.heroAppearanceBase,
          color: store.baseColor,
          onColorChanged: (c) => liveTvHeroAppearanceStore.setBaseColor(c),
          hueRowLabel: loc.heroAppearanceHueRow,
          satRowLabel: loc.heroAppearanceSatRow,
          briRowLabel: loc.heroAppearanceBriRow,
          hueExplain: loc.heroAppearanceHueExplain,
          satExplain: loc.heroAppearanceSatExplain,
          briExplain: loc.heroAppearanceBriExplain,
        ),
        const SizedBox(height: 2),
        _IntStepRow(
          label: loc.heroAppearanceGradientDepth,
          value: store.gradientDepth,
          min: 10,
          max: 55,
          step: 2,
          onChanged: (v) => liveTvHeroAppearanceStore.setGradientDepth(v),
          shell: shell,
          theme: theme,
        ),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.store,
    required this.shell,
    required this.loc,
    required this.theme,
    required this.brushMode,
  });

  final LiveTvHeroAppearanceStore store;
  final TeamPalette shell;
  final AppLocalizations loc;
  final ThemeData theme;
  final bool brushMode;

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.heroAppearanceTabOverlay,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: loc.heroAppearanceWashModeBrush,
                  selected: brushMode,
                  shell: shell,
                  onTap: () => liveTvHeroAppearanceStore.setWashMode(
                        LiveTvHeroAppearanceStore.washModeBrush,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ModeChip(
                  label: loc.heroAppearanceWashModeSolid,
                  selected: !brushMode,
                  shell: shell,
                  onTap: () => liveTvHeroAppearanceStore.setWashMode(
                        LiveTvHeroAppearanceStore.washModeSolid,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          HeroColorTvSteppers(
            title: loc.heroAppearanceWash,
            color: store.washColor,
            onColorChanged: (c) => liveTvHeroAppearanceStore.setWashColor(c),
            hueRowLabel: loc.heroAppearanceHueRow,
            satRowLabel: loc.heroAppearanceSatRow,
            briRowLabel: loc.heroAppearanceBriRow,
            hueExplain: loc.heroAppearanceHueExplain,
            satExplain: loc.heroAppearanceSatExplain,
            briExplain: loc.heroAppearanceBriExplain,
          ),
          const SizedBox(height: 1),
          _IntStepRow(
            label: loc.heroAppearanceIntensity,
            value: store.washIntensity,
            min: 0,
            max: 100,
            step: 5,
            suffix: '%',
            onChanged: (v) => liveTvHeroAppearanceStore.setWashIntensity(v),
            shell: shell,
            theme: theme,
          ),
          if (brushMode) ...[
            const SizedBox(height: 4),
            Text(
              loc.heroAppearanceBrushStyle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List.generate(
                LiveTvHeroAppearanceStore.brushStyleMax + 1,
                (i) {
                  final sel = store.brushStyle == i;
                  return TvFocusable(
                    onActivate: () =>
                        liveTvHeroAppearanceStore.setBrushStyle(i),
                    focusPadding: const EdgeInsets.all(2),
                    focusedBorderWidth: 1.35,
                    child: Container(
                      width: 32,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: sel
                              ? shell.accent
                              : Colors.white.withValues(alpha: 0.18),
                          width: sel ? 2 : 1,
                        ),
                        color: sel
                            ? shell.accent.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.04),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
    );
  }
}

class _IntStepRow extends StatelessWidget {
  const _IntStepRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.shell,
    required this.theme,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final TeamPalette shell;
  final ThemeData theme;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: TeamPalette.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TvFocusable(
            onActivate: () => onChanged((value - step).clamp(min, max)),
            focusPadding: const EdgeInsets.all(2),
            focusedBorderWidth: 1.35,
            child: _MiniStepIcon(icon: Icons.remove_rounded),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value$suffix',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          TvFocusable(
            onActivate: () => onChanged((value + step).clamp(min, max)),
            focusPadding: const EdgeInsets.all(2),
            focusedBorderWidth: 1.35,
            child: _MiniStepIcon(icon: Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _MiniStepIcon extends StatelessWidget {
  const _MiniStepIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.shell,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TeamPalette shell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onActivate: onTap,
      focusPadding: const EdgeInsets.all(2),
      focusedBorderWidth: 1.35,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? shell.accent : Colors.white.withValues(alpha: 0.18),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? shell.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}

class _FrameChip extends StatelessWidget {
  const _FrameChip({
    required this.label,
    required this.selected,
    required this.shell,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TeamPalette shell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onActivate: onTap,
      focusPadding: const EdgeInsets.all(1),
      focusedBorderWidth: 1.35,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? shell.accent : Colors.white.withValues(alpha: 0.16),
          ),
          color: selected
              ? shell.accent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 9,
              ),
        ),
      ),
    );
  }
}

class _FinishOrb extends StatelessWidget {
  const _FinishOrb({
    required this.size,
    required this.colors,
    required this.selected,
    required this.shell,
  });

  final double size;
  final List<Color> colors;
  final bool selected;
  final TeamPalette shell;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? shell.accent : Colors.white.withValues(alpha: 0.22),
          width: selected ? 2 : 1,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }
}
