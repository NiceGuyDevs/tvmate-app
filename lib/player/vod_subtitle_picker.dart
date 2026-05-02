import 'package:flutter/material.dart';

import '../subtitles/opensubtitles_client.dart';
import '../theme/team_palette.dart';
import '../theme/team_palette_theme.dart';
import 'vod_subtitle_dcard_chrome.dart';

/// Taller panel — matches HTML sample proportions (~max 500 logical wide).
const double _kPanelScale = 0.7;

const double _kPanelHeightBoost = 1.2;

const double _kRowRadius = 10;
const double _kChipRadius = 6;

/// Full-screen dimmed panel: languages (left) + files (right).
class VodSubtitlePickerPanel extends StatefulWidget {
  const VodSubtitlePickerPanel({
    super.key,
    required this.loading,
    required this.errorMessage,
    required this.groups,
    required this.searchQueryController,
    required this.searchFocusNode,
    required this.searchFieldFocused,
    required this.searchHintDpadIndex,
    required this.searchHints,
    required this.searchHintsLoading,
    required this.onSearchSubmitted,
    required this.onSearchHintSelected,
    required this.langIndex,
    required this.fileIndex,
    required this.focusColumn,
    required this.accent,
    required this.clearEnabled,
    required this.title,
    required this.hintLoading,
    required this.hintEmpty,
    required this.hintPickLanguage,
    required this.labelLanguages,
    required this.labelFiles,
    required this.actionClear,
    required this.labelExit,
    required this.labelSelectFooter,
  });

  final bool loading;
  final String? errorMessage;
  final List<OpenSubtitlesLanguageGroup> groups;
  final TextEditingController searchQueryController;
  final FocusNode searchFocusNode;
  final bool searchFieldFocused;
  /// D-pad highlight in the API hint list; -1 = on text field / none.
  final int searchHintDpadIndex;
  final List<String> searchHints;
  final bool searchHintsLoading;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onSearchHintSelected;
  final int langIndex;
  final int fileIndex;

  /// 0 = languages column, 1 = files column.
  final int focusColumn;
  final Color accent;
  final bool clearEnabled;

  final String title;
  final String hintLoading;
  final String hintEmpty;
  final String hintPickLanguage;
  final String labelLanguages;
  final String labelFiles;
  final String actionClear;

  final String labelExit;
  final String labelSelectFooter;

  @override
  State<VodSubtitlePickerPanel> createState() => _VodSubtitlePickerPanelState();
}

class _VodSubtitlePickerPanelState extends State<VodSubtitlePickerPanel> {
  final ScrollController _langScroll = ScrollController();
  final ScrollController _fileScroll = ScrollController();

  final GlobalKey _langSelectedRowKey = GlobalKey();
  final GlobalKey _fileSelectedRowKey = GlobalKey();
  final GlobalKey _hintDpadItemKey = GlobalKey();

  @override
  void dispose() {
    _langScroll.dispose();
    _fileScroll.dispose();
    super.dispose();
  }

  void _ensureVisible(GlobalKey key, {double alignment = 0.42}) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: Duration.zero,
      curve: Curves.linear,
    );
  }

  void _scheduleScrollSelectionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelectionVisible(0));
  }

  void _ensureSelectionVisible(int attempt) {
    if (!mounted || widget.loading) return;
    final langCtx = _langSelectedRowKey.currentContext;
    if (langCtx == null && attempt < 12) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectionVisible(attempt + 1);
      });
      return;
    }
    _ensureVisible(_langSelectedRowKey);
    if (widget.clearEnabled && widget.langIndex == 0) return;
    final gIdx = widget.clearEnabled ? widget.langIndex - 1 : widget.langIndex;
    if (gIdx >= 0 &&
        gIdx < widget.groups.length &&
        widget.groups[gIdx].files.isNotEmpty) {
      _ensureVisible(_fileSelectedRowKey);
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleScrollSelectionIntoView();
  }

  @override
  void didUpdateWidget(covariant VodSubtitlePickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final needScroll = oldWidget.langIndex != widget.langIndex ||
        oldWidget.fileIndex != widget.fileIndex ||
        (oldWidget.loading && !widget.loading) ||
        oldWidget.focusColumn != widget.focusColumn;
    if (needScroll) {
      _scheduleScrollSelectionIntoView();
    }
    if (oldWidget.searchHintDpadIndex != widget.searchHintDpadIndex &&
        widget.searchHintDpadIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = _hintDpadItemKey.currentContext;
        if (c != null) {
          Scrollable.ensureVisible(
            c,
            alignment: 0.35,
            duration: Duration.zero,
            curve: Curves.linear,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    final focusColor = p.defaultFocusRingColor;
    return Theme(
      data: theme.copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(0.0),
          thumbVisibility: WidgetStatePropertyAll(false),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const VodSubtitleDcardScrim(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
              final panelW = (constraints.maxWidth * 0.52 * _kPanelScale)
                  .clamp(280.0, 500.0);
              final panelH = (constraints.maxHeight * 0.78 * _kPanelScale * _kPanelHeightBoost)
                  .clamp(260.0, 600.0);
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: panelW,
                    maxHeight: panelH,
                  ),
                  child: VodSubtitleDcardLayeredShell(
                    borderRadius: kVodSubtitleDcardRadius,
                    child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: p.surfaceElevated.withValues(alpha: 0.9),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Text(
                                        'CC',
                                        style: TextStyle(
                                          color: p.shellTitleColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: p.shellTitleColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'OpenSubtitles',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: TeamPalette.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    letterSpacing: 0.08,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _searchStylingRow(context, p),
                                if (widget.searchHints.isNotEmpty ||
                                    widget.searchHintsLoading) ...[
                                  const SizedBox(height: 6),
                                  _searchHintsBlock(p),
                                ],
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                Expanded(
                                  child: widget.loading
                                      ? _buildLoadingColumns(p, focusColor)
                                      : Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: _columnChrome(
                                                p: p,
                                                label: widget.labelLanguages,
                                                count: _langCount,
                                                child: _buildLeft(p, focusColor),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 3,
                                              child: _columnChrome(
                                                p: p,
                                                label: widget.labelFiles,
                                                count: _fileCount,
                                                child: _buildRight(p, focusColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 6),
                                _footerRow(p, focusColor),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
          ],
        ),
      ),
    );
  }

  int get _langCount =>
      widget.groups.length + (widget.clearEnabled ? 1 : 0);

  int get _fileCount {
    if (widget.groups.isEmpty) return 0;
    if (widget.clearEnabled && widget.langIndex == 0) return 0;
    final gIdx = widget.clearEnabled ? widget.langIndex - 1 : widget.langIndex;
    if (gIdx < 0 || gIdx >= widget.groups.length) return 0;
    return widget.groups[gIdx].files.length;
  }

  Widget _searchStylingRow(BuildContext context, TeamPalette p) {
    final focusColor = p.defaultFocusRingColor;
    final qFocused = widget.searchFieldFocused;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: qFocused
              ? focusColor.withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.07),
          width: qFocused ? 1.2 : 1,
        ),
        boxShadow: qFocused
            ? [
                BoxShadow(
                  color: focusColor.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 16,
            color: p.shellBodyHint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: widget.searchQueryController,
              focusNode: widget.searchFocusNode,
              readOnly: !qFocused,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onSearchSubmitted(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TeamPalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
              cursorColor: widget.accent,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              'API',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: p.shellBodyHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchHintsBlock(TeamPalette p) {
    final focusColor = p.defaultFocusRingColor;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: widget.searchHintsLoading && widget.searchHints.isEmpty
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accent,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                physics: const ClampingScrollPhysics(),
                itemCount: widget.searchHints.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                itemBuilder: (context, i) {
                  final h = widget.searchHints[i];
                  final dpad = i == widget.searchHintDpadIndex;
                  final row = Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => widget.onSearchHintSelected(h),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: _hintRowBoxDecoration(
                          dpad: dpad,
                          focusColor: focusColor,
                        ),
                        child: Text(
                          h,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.shellTitleColor.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight:
                                dpad ? FontWeight.w700 : FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  );
                  if (dpad) {
                    return KeyedSubtree(
                      key: _hintDpadItemKey,
                      child: row,
                    );
                  }
                  return row;
                },
              ),
      ),
    );
  }

  BoxDecoration _hintRowBoxDecoration({
    required bool dpad,
    required Color focusColor,
  }) {
    if (dpad) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(_kRowRadius),
        border: Border.all(color: focusColor, width: 1.1),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            focusColor.withValues(alpha: 0.12),
            widget.accent.withValues(alpha: 0.05),
            focusColor.withValues(alpha: 0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: focusColor.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      );
    }
    return const BoxDecoration();
  }

  /// Same two-column shell as loaded state; used while OpenSubtitles search runs.
  Widget _buildLoadingColumns(TeamPalette p, Color focusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: _columnChrome(
            p: p,
            label: widget.labelLanguages,
            count: 0,
            child: _loadingColumnInterior(p, focusColor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _columnChrome(
            p: p,
            label: widget.labelFiles,
            count: 0,
            child: _loadingColumnInterior(p, focusColor),
          ),
        ),
      ],
    );
  }

  Widget _loadingColumnInterior(TeamPalette p, Color focusColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.hintLoading,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.shellTitleColor.withValues(alpha: 0.88),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerRow(TeamPalette p, Color focusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              color: p.shellTitleColor.withValues(alpha: 0.92),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              widget.labelExit,
              style: TextStyle(
                color: p.shellTitleColor.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kChipRadius),
            border: Border.all(
              color: Color.lerp(
                    focusColor,
                    widget.accent,
                    0.35,
                  )!
                  .withValues(alpha: 0.55),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.accent.withValues(alpha: 0.14),
                widget.accent.withValues(alpha: 0.06),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_rounded,
                color: widget.accent,
                size: 18,
              ),
            const SizedBox(width: 6),
            Text(
                widget.labelSelectFooter,
                style: TextStyle(
                  color: p.shellTitleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeft(TeamPalette p, Color focusColor) {
    final err = widget.errorMessage;
    if (err != null && err.isNotEmpty) {
      return Center(
        child: Text(
          err,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (widget.groups.isEmpty && !widget.clearEnabled) {
      return Center(
        child: Text(
          widget.hintEmpty,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    final total = _langCount;
    final li = widget.langIndex.clamp(0, total - 1);
    return ListView.builder(
      controller: _langScroll,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: total,
      itemBuilder: (context, i) {
        if (widget.clearEnabled && i == 0) {
          final selected = i == li;
          final focused = widget.focusColumn == 0 && selected;
          final cell = _langCell(
            p: p,
            focusColor: focusColor,
            selected: selected,
            focused: focused,
            child: Text(
              widget.actionClear,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: p.shellTitleColor.withValues(alpha: 0.88),
                fontSize: 12,
              ),
            ),
          );
          return i == li ? KeyedSubtree(key: _langSelectedRowKey, child: cell) : cell;
        }
        final gi = widget.clearEnabled ? i - 1 : i;
        final g = widget.groups[gi];
        final selected = i == li;
        final focused = widget.focusColumn == 0 && i == li;
        final cell = _langCell(
          p: p,
          focusColor: focusColor,
          selected: selected,
          focused: focused,
          child: Text(
            g.languageCode.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: p.shellTitleColor.withValues(alpha: selected ? 1.0 : 0.88),
              letterSpacing: 0.6,
            ),
          ),
        );
        return i == li ? KeyedSubtree(key: _langSelectedRowKey, child: cell) : cell;
      },
    );
  }

  Widget _buildRight(TeamPalette p, Color focusColor) {
    if (widget.errorMessage != null || widget.groups.isEmpty) {
      return const SizedBox.shrink();
    }
    if (widget.clearEnabled && widget.langIndex == 0) {
      return Center(
        child: Text(
          widget.hintPickLanguage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.shellTitleColor.withValues(alpha: 0.38),
          ),
        ),
      );
    }
    final gIdx = widget.clearEnabled ? widget.langIndex - 1 : widget.langIndex;
    final li = gIdx.clamp(0, widget.groups.length - 1);
    final files = widget.groups[li].files;
    if (files.isEmpty) {
      return Center(
        child: Text(
          widget.hintEmpty,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    final fi = widget.fileIndex.clamp(0, files.length - 1);
    return ListView.builder(
      key: ValueKey<String>('vod_sub_files_$li'),
      controller: _fileScroll,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        final selected = i == fi;
        final focused = widget.focusColumn == 1 && i == fi;
        final rel = f.release?.trim() ?? '';
        final cell = _fileCell(
          p: p,
          focusColor: focusColor,
          selected: selected,
          focused: focused,
          fileName: f.fileName,
          release: rel,
        );
        return i == fi ? KeyedSubtree(key: _fileSelectedRowKey, child: cell) : cell;
      },
    );
  }

  Widget _columnChrome({
    required TeamPalette p,
    required String label,
    required int count,
    required Widget child,
  }) {
    // .list: gradient + --line border + inset top sheen (HTML sample).
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x33000000),
            Color(0x59000000),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: p.shellBodyHint,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: TeamPalette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                // .list { box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04) }
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 1,
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.04),
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

  BoxDecoration _cellStyle({
    required bool focused,
    required bool selected,
    required Color focusColor,
  }) {
    if (focused) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(_kRowRadius),
        border: Border.all(
          color: focusColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: focusColor.withValues(alpha: 0.2),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            focusColor.withValues(alpha: 0.1),
            widget.accent.withValues(alpha: 0.05),
            focusColor.withValues(alpha: 0.02),
          ],
        ),
      );
    }
    if (selected) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(_kRowRadius),
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.4),
          width: 1,
        ),
        color: widget.accent.withValues(alpha: 0.06),
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_kRowRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1,
      ),
      color: Colors.white.withValues(alpha: 0.04),
    );
  }

  Widget _langCell({
    required TeamPalette p,
    required Color focusColor,
    required bool selected,
    required bool focused,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: _cellStyle(
          focused: focused,
          selected: selected,
          focusColor: focusColor,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (focused) ...[
              Container(
                width: 3,
                margin: const EdgeInsets.only(left: 4, right: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [focusColor, widget.accent],
                  ),
                ),
                height: 20,
              ),
            ] else
              const SizedBox(width: 3),
            Expanded(
              child: Center(child: child),
            ),
            if (focused) ...[
              Icon(
                Icons.chevron_left,
                size: 14,
                color: focusColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileCell({
    required TeamPalette p,
    required Color focusColor,
    required bool selected,
    required bool focused,
    required String fileName,
    required String release,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: _cellStyle(
          focused: focused,
          selected: selected,
          focusColor: focusColor,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (focused) ...[
              Container(
                width: 3,
                margin: const EdgeInsets.only(right: 4, top: 2),
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [focusColor, widget.accent],
                  ),
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? p.shellTitleColor
                          : p.shellTitleColor.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  if (release.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        release,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: p.shellBodyHint.withValues(
                            alpha: selected ? 0.7 : 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 0),
                child: Icon(
                  Icons.check_rounded,
                  color: widget.accent,
                  size: 18,
                ),
              ),
            if (focused) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: focusColor.withValues(alpha: 0.85),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
