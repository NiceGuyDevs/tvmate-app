/// Add Playlist wizard — 1:1 port of `renderAddPlaylistPage()` in
/// settings.html (line 5871), plus `renderAddPlaylistForm` and the
/// test-connection strip renderer.
///
/// Layout:
///
///     [sub-page head]
///     .add-pl-wrap (max 720px centered)
///       section .add-pl-card  (Source type)
///         .card-head  h3 + hint
///         .add-pl-seg  two big segmented buttons (Xtream | M3U)
///       section .add-pl-card  (Xtream credentials / M3U URL)
///         .card-head  h3 + hint
///         .add-pl-form  — dynamic fields
///           • Xtream: Server URL / [User · Pass (reveal)] / Display name
///           • M3U: Display name / M3U URL
///         test strip (pending / ok / err)
///         .add-pl-actions  [status] · Cancel · Test connection · Add playlist
library;

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/device_memory_channel.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_auth_tv_wide.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsAddPlaylistPage extends StatefulWidget {
  const NsAddPlaylistPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onAdded,
  });

  final NewSettingsState state;
  final VoidCallback onBack;

  /// Fired after the user successfully adds a playlist. The screen
  /// pops the wizard and can then refocus the grid.
  final VoidCallback onAdded;

  @override
  State<NsAddPlaylistPage> createState() => _NsAddPlaylistPageState();
}

class _NsAddPlaylistPageState extends State<NsAddPlaylistPage> {
  // One controller + focus node per possible field. Kept on the state so
  // switching Xtream ↔ M3U keeps the caret + values steady (same reason
  // the HTML calls `addPlBindFormFields` instead of re-rendering).
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _nodes = {};

  /// Back-ladder interceptor. Sits above every form field and the
  /// source-type buttons. Fires before the shell-level back handler,
  /// so pressing Back inside a text field climbs up one step within
  /// the page (to the currently-selected source-type button) instead
  /// of popping the wizard outright.
  late final FocusNode _pageGuard;

  String _statusMsg = 'Fields marked with * are required.';
  bool _statusDanger = false;

  /// Names of nodes that count as "inside the form" — used by the
  /// Back-ladder to decide whether to move focus up to the source-type
  /// button rather than pop the page.
  static const Set<String> _fieldGroupIds = {
    'server', 'user', 'pass', 'pass_reveal', 'name', 'url',
  };

  /// Chromecast / leanback: fused card + [NsAuthTvKeyboard] (see
  /// [settings_add_playlist_with_keyboard.html] — matches settings.html
  /// layout; [settings_xtream_codes_login_with_keyboard.html] shares the
  /// same keyboard shell).
  bool get _useTvPad =>
      !kIsWeb &&
      Platform.isAndroid &&
      DeviceMemoryChannel.useInAppTextPadOnly;

  final _tvFormScroll = ScrollController();
  FocusNode? _firstKbdFocus;
  String _tvActiveLabel = 'Server URL';
  String? _tvActiveFieldId;

  bool get _tvKeyboardAside {
    if (!_useTvPad || !mounted) return false;
    // Same breakpoint as [NsAuthTvWideShell] and the HTML Wide layout
    // (viewport ≥ 780px → form | keyboard).
    return MediaQuery.sizeOf(context).width >= 780;
  }

  FocusNode _tvKeyboardLinkFocusNode() =>
      widget.state.addPlaylist.type == 'xtream'
          ? _node('name')
          : _node('url');

  void _syncTvActiveField() {
    if (!_useTvPad || !mounted) return;
    if (_nodes['pass_reveal']?.hasFocus == true) {
      setState(() {
        _tvActiveFieldId = 'pass';
        _tvActiveLabel = 'Password';
      });
      return;
    }
    for (final id in ['server', 'user', 'pass', 'name', 'url']) {
      if (_nodes[id]?.hasFocus == true) {
        setState(() {
          _tvActiveFieldId = id;
          _tvActiveLabel = _tvLabelForFieldId(id);
        });
        return;
      }
    }
  }

  static String _tvLabelForFieldId(String id) {
    switch (id) {
      case 'server':
        return 'Server URL';
      case 'user':
        return 'Username';
      case 'pass':
        return 'Password';
      case 'name':
        return 'Display name';
      case 'url':
        return 'M3U URL';
      default:
        return 'Field';
    }
  }

  KeyEventResult? _tvArrowRightToKbd(FocusNode n, KeyEvent ev) {
    if (ev is! KeyDownEvent) return null;
    if (ev.logicalKey != LogicalKeyboardKey.arrowRight) return null;
    if (!_tvKeyboardAside) return null;
    final k = _firstKbdFocus;
    if (k == null) return null;
    k.requestFocus();
    return KeyEventResult.handled;
  }

  String? _tvTargetFieldId() {
    final p = FocusManager.instance.primaryFocus;
    if (_nodes['pass_reveal'] == p) return 'pass';
    for (final id in ['server', 'user', 'pass', 'name', 'url']) {
      if (_nodes[id] == p) return id;
    }
    return _tvActiveFieldId;
  }

  void _tvInsert(String ch) {
    final id = _tvTargetFieldId();
    final c = id == null ? null : _ctrls[id];
    if (c == null || id == null) return;
    final v = c.value;
    final t = v.text;
    final sel = v.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final lo = start <= end ? start : end;
    final hi = start <= end ? end : start;
    final newText = t.replaceRange(lo, hi, ch);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lo + ch.length),
    );
    widget.state.setAddPlaylistField(id, newText);
  }

  void _tvBackspace() {
    final id = _tvTargetFieldId();
    final c = id == null ? null : _ctrls[id];
    if (c == null || id == null) return;
    final v = c.value;
    final t = v.text;
    final sel = v.selection;
    if (sel.isValid && sel.start != sel.end) {
      final lo = sel.start < sel.end ? sel.start : sel.end;
      final hi = sel.start < sel.end ? sel.end : sel.start;
      final newText = t.replaceRange(lo, hi, '');
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lo),
      );
      widget.state.setAddPlaylistField(id, newText);
      return;
    }
    final pos = sel.isValid ? sel.start : t.length;
    if (pos <= 0) return;
    final newText = t.replaceRange(pos - 1, pos, '');
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos - 1),
    );
    widget.state.setAddPlaylistField(id, newText);
  }

  void _tvClearActiveField() {
    final id = _tvTargetFieldId();
    final c = id == null ? null : _ctrls[id];
    if (c == null || id == null) return;
    c.value = const TextEditingValue();
    widget.state.setAddPlaylistField(id, '');
  }

  void _tvToggleObscure() {
    final d = widget.state.addPlaylist;
    widget.state.setAddPlaylistShowPass(!d.showPass);
  }

  /// TV pad “Next ↓” — advance to the next text field, then to **Test connection**.
  void _tvNextField() {
    if (!mounted) return;
    final draft = widget.state.addPlaylist;
    final order = _fieldOrder(draft.type);
    final p = FocusManager.instance.primaryFocus;
    if (_nodes['pass_reveal'] == p) {
      _node('name').requestFocus();
      return;
    }
    final i = order.indexWhere((n) => n == p);
    if (i >= 0 && i < order.length - 1) {
      order[i + 1].requestFocus();
      return;
    }
    if (i == order.length - 1) {
      _node('test').requestFocus();
      return;
    }
    final id = _tvTargetFieldId();
    if (id != null) {
      final j = order.indexWhere((n) => n == _node(id));
      if (j >= 0 && j < order.length - 1) {
        order[j + 1].requestFocus();
        return;
      }
      if (j == order.length - 1) {
        _node('test').requestFocus();
        return;
      }
    }
    if (order.isNotEmpty) {
      order.first.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _pageGuard = FocusNode(
      debugLabel: 'ns:addPl:pageGuard',
      skipTraversal: true,
      canRequestFocus: false,
    );
    _seedFields();
    if (_useTvPad) {
      for (final id in ['server', 'user', 'pass', 'name', 'url']) {
        _nodes[id]?.addListener(_syncTvActiveField);
      }
      _nodes['pass_reveal']?.addListener(_syncTvActiveField);
    }
    // Land focus on the currently-selected source-type button (Xtream
    // by default) so D-pad users can navigate between source types
    // right away and no text field steals focus first → soft keyboard
    // never opens on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final type = widget.state.addPlaylist.type;
      final target = _nodes[type == 'xtream' ? 'type_xtream' : 'type_m3u'];
      if (target != null && target.canRequestFocus) {
        target.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (_useTvPad) {
      for (final id in ['server', 'user', 'pass', 'name', 'url']) {
        _nodes[id]?.removeListener(_syncTvActiveField);
      }
      _nodes['pass_reveal']?.removeListener(_syncTvActiveField);
    }
    _tvFormScroll.dispose();
    _pageGuard.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// Returns true if the currently-focused node is one of the form
  /// fields (or the reveal-password button, which lives beside the
  /// password field).
  bool _focusIsInsideForm() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    for (final id in _fieldGroupIds) {
      if (_nodes[id] == primary) return true;
    }
    return false;
  }

  /// Back / Escape handler. If focus is inside a form field, climb
  /// up to the current source-type button and swallow the key.
  /// Otherwise fall through and let the shell pop the wizard.
  KeyEventResult _onPageKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k != LogicalKeyboardKey.escape &&
        k != LogicalKeyboardKey.goBack) {
      return KeyEventResult.ignored;
    }
    if (!_focusIsInsideForm()) return KeyEventResult.ignored;
    final type = widget.state.addPlaylist.type;
    final target =
        _nodes[type == 'xtream' ? 'type_xtream' : 'type_m3u'];
    if (target != null && target.canRequestFocus) {
      target.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _seedFields() {
    final d = widget.state.addPlaylist;
    _setCtrl('server', d.xtServer);
    _setCtrl('user', d.xtUser);
    _setCtrl('pass', d.xtPass);
    _setCtrl('name', d.type == 'xtream' ? d.xtName : d.m3uName);
    _setCtrl('url', d.m3uUrl);
    for (final id in const ['type_xtream', 'type_m3u', 'server', 'user',
        'pass', 'pass_reveal', 'name', 'url', 'cancel', 'test', 'save']) {
      _nodes[id] = FocusNode(debugLabel: 'ns:addPl:$id');
    }
  }

  void _setCtrl(String id, String value) {
    final c = _ctrls[id];
    if (c == null) {
      _ctrls[id] = TextEditingController(text: value);
    } else if (c.text != value) {
      c.text = value;
    }
  }

  FocusNode _node(String id) => _nodes[id]!;

  /// Current "tab order" among visible text fields — used by the form's
  /// D-pad Up/Down handlers to move focus between inputs.
  List<FocusNode> _fieldOrder(String type) {
    if (type == 'xtream') {
      return [
        _node('server'),
        _node('user'),
        _node('pass'),
        _node('name'),
      ];
    }
    return [_node('name'), _node('url')];
  }

  void _onTypeChange(String type) {
    if (widget.state.addPlaylist.type == type) return;
    widget.state.setAddPlaylistType(type);
    // Re-seed the display-name controller from whichever bag is now active.
    final d = widget.state.addPlaylist;
    _ctrls['name']?.text = type == 'xtream' ? d.xtName : d.m3uName;
    setState(() {
      _statusMsg = 'Fields marked with * are required.';
      _statusDanger = false;
    });
  }

  Future<void> _onTest() async {
    final ok = await widget.state.runAddPlaylistTest();
    if (!mounted) return;
    setState(() {
      if (!ok) {
        _statusMsg = 'Fix the highlighted fields, then test.';
        _statusDanger = true;
      } else {
        _statusMsg = 'Looks good — ready to add.';
        _statusDanger = false;
      }
    });
  }

  Future<void> _onSave() async {
    final valid = widget.state.validateAddPlaylist();
    if (!valid) {
      setState(() {
        _statusMsg = 'Fix the highlighted fields, then add.';
        _statusDanger = true;
      });
      return;
    }
    await widget.state.addPlaylistFromDraft();
    if (!mounted) return;
    widget.onAdded();
  }

  Widget _buildTvFusedAddPlaylistCard({
    required double shellWidth,
    required double shellHeight,
  }) {
    final draft = widget.state.addPlaylist;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: -80,
          right: -120,
          child: Container(
            width: 440,
            height: 200,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [NsColors.accentGlow, Color(0x00000000)],
                radius: 0.9,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: NsAuthTvWideShell(
            width: shellWidth,
            height: shellHeight,
            form: SingleChildScrollView(
              controller: _tvFormScroll,
              primary: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NsSubPageHead(
                    title: 'Add playlist',
                    subtitle:
                        'Connect a new IPTV source. Pick how you '
                        'authenticate, fill in the details, and test '
                        'before saving.',
                    onBack: widget.onBack,
                    autofocusBack: false,
                  ),
                  const SizedBox(height: 8),
                  _SourceTypeCard(
                    selectedType: draft.type,
                    xtreamFocusNode: _node('type_xtream'),
                    m3uFocusNode: _node('type_m3u'),
                    onPick: _onTypeChange,
                    onKeyIntercept: _tvArrowRightToKbd,
                  ),
                  const SizedBox(height: 8),
                  _CredentialsCard(
                    state: widget.state,
                    ctrls: _ctrls,
                    nodeOf: _node,
                    focusAfterLastField: _node('test'),
                    fieldOrder: _fieldOrder(draft.type),
                    statusMsg: _statusMsg,
                    statusDanger: _statusDanger,
                    onSetField: (id, v) =>
                        widget.state.setAddPlaylistField(id, v),
                    onToggleReveal: () => widget.state
                        .setAddPlaylistShowPass(!draft.showPass),
                    onCancel: widget.onBack,
                    onTest: _onTest,
                    onSave: _onSave,
                    tvOskMode: true,
                    tvArrowRightToKbd: _tvArrowRightToKbd,
                  ),
                ],
              ),
            ),
            keyboard: NsAuthTvKeyboard(
              activeFieldLabel: _tvActiveLabel,
              linkFocus: _tvKeyboardLinkFocusNode(),
              onInsert: _tvInsert,
              onBackspace: _tvBackspace,
              onClearField: _tvClearActiveField,
              onToggleObscure: _tvToggleObscure,
              onNextField: _tvNextField,
              onFirstKeyReady: (n) {
                if (_firstKbdFocus != n) {
                  setState(() => _firstKbdFocus = n);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Focus(
        focusNode: _pageGuard,
        onKeyEvent: _onPageKey,
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            if (_useTvPad) {
              return PrimaryScrollController.none(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, safeConstraints) {
                      const padH = 32.0;
                      const padV = 48.0;
                      final mq = MediaQuery.of(context);
                      final cw = safeConstraints.maxWidth.isFinite
                          ? safeConstraints.maxWidth
                          : mq.size.width;
                      final ch = safeConstraints.maxHeight.isFinite
                          ? safeConstraints.maxHeight
                          : (mq.size.height -
                                  mq.padding.vertical -
                                  mq.viewInsets.bottom)
                              .clamp(120.0, 4000.0);
                      final boxMaxW = math.max(200.0, cw - padH);
                      final boxMaxH = math.max(200.0, ch - padV);
                      final targetH =
                          (boxMaxH * 0.92).clamp(200.0, 900.0);
                      final h = math.min(targetH, boxMaxH);
                      final w = math.min(1100.0, boxMaxW);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: boxMaxW,
                              maxHeight: boxMaxH,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: w,
                                height: h,
                                child: _buildTvFusedAddPlaylistCard(
                                  shellWidth: w,
                                  shellHeight: h,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }

            final d = NsDensity.of(context);
            final draft = widget.state.addPlaylist;
            return LayoutBuilder(
              builder: (context, constraints) {
                // Standard TV + system keyboard: keep the form much narrower so
                // the soft keyboard obscures less of the card; Chromecast in-app
                // pad path keeps the wider reference width.
                final contentMaxWidth =
                    _useTvPad ? 480.0 : 280.0;
                final rightPad = (constraints.maxWidth -
                        d.listHorizontalPadding -
                        contentMaxWidth)
                    .clamp(d.listHorizontalPadding, double.infinity);
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    d.listHorizontalPadding,
                    d.listTopPadding,
                    rightPad,
                    d.listBottomPadding,
                  ),
                  children: [
                    NsSubPageHead(
                      title: 'Add playlist',
                      subtitle:
                          'Connect a new IPTV source. Pick how you '
                          'authenticate, fill in the details, and test '
                          'before saving.',
                      onBack: widget.onBack,
                      autofocusBack: false,
                    ),
                    _SourceTypeCard(
                      selectedType: draft.type,
                      xtreamFocusNode: _node('type_xtream'),
                      m3uFocusNode: _node('type_m3u'),
                      onPick: _onTypeChange,
                    ),
                    SizedBox(height: _useTvPad ? 10 : 5),
                    _CredentialsCard(
                      state: widget.state,
                      ctrls: _ctrls,
                      nodeOf: _node,
                      focusAfterLastField: _node('test'),
                      fieldOrder: _fieldOrder(draft.type),
                      statusMsg: _statusMsg,
                      statusDanger: _statusDanger,
                      onSetField: (id, v) =>
                          widget.state.setAddPlaylistField(id, v),
                      onToggleReveal: () => widget.state
                          .setAddPlaylistShowPass(!draft.showPass),
                      onCancel: widget.onBack,
                      onTest: _onTest,
                      onSave: _onSave,
                      // Standard (full system IME) boxes: tighter verticals so
                      // more of the form + actions stay above the TV keyboard.
                      denseForIme: !_useTvPad,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.add-pl-card` — reusable card chrome
//   background: linear-gradient(180deg, var(--surface), var(--surface-2));
//   border: 1px solid var(--line); border-radius: 14px;
//   padding: 18px 20px; box-shadow: var(--shadow-1);
// ═══════════════════════════════════════════════════════════════════════

class _AddPlCard extends StatelessWidget {
  const _AddPlCard({this.compact = false, required this.child});

  /// Tighter insets for [ _CredentialsCard.denseForIme ] (system keyboard path).
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NsColors.surface, NsColors.surface2],
        ),
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
        boxShadow: NsShadow.s1,
      ),
      child: child,
    );
  }
}

/// `.card-head`:
///   display: flex; align-items: baseline; justify-content: space-between;
///   gap: 12px; margin-bottom: 12px;
///   h3 { font-size: 13px; font-weight: 700; letter-spacing: 1.2px; uppercase; color: text-2 }
///   .hint { color: text-3; font-size: 12px; }
class _CardHead extends StatelessWidget {
  const _CardHead({required this.title, required this.hint, this.compact = false});

  final String title;
  final String hint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: NsColors.text2,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: NsColors.text3,
                fontSize: compact ? 9.5 : 10.5,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Source type segmented picker — `.add-pl-seg` (grid 1fr 1fr, gap 10)
// ═══════════════════════════════════════════════════════════════════════

class _SourceTypeCard extends StatelessWidget {
  const _SourceTypeCard({
    required this.selectedType,
    required this.xtreamFocusNode,
    required this.m3uFocusNode,
    required this.onPick,
    this.onKeyIntercept,
  });
  final String selectedType;
  final FocusNode xtreamFocusNode;
  final FocusNode m3uFocusNode;
  final void Function(String type) onPick;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return _AddPlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHead(
            title: 'Source type',
            hint: 'You can change this any time before saving.',
          ),
          // `grid-template-columns: 1fr 1fr; gap: 10px;` — CSS grid
          // stretches items to the taller cell, so we wrap in an
          // [IntrinsicHeight] to give both buttons the same rendered
          // height regardless of which one's label wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SegButton(
                    focusNode: xtreamFocusNode,
                    icon: Icons.dns_rounded,
                    title: 'Xtream Codes',
                    sub: 'Server URL · username · password',
                    selected: selectedType == 'xtream',
                    onPressed: () => onPick('xtream'),
                    onKeyIntercept: onKeyIntercept,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegButton(
                    focusNode: m3uFocusNode,
                    icon: Icons.link_rounded,
                    title: 'M3U / M3U8 URL',
                    sub: 'Direct playlist URL (no login)',
                    selected: selectedType == 'm3u',
                    onPressed: () => onPick('m3u'),
                    onKeyIntercept: onKeyIntercept,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.focusNode,
    required this.icon,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onPressed,
    this.onKeyIntercept,
  });
  final FocusNode focusNode;
  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onPressed;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onKeyIntercept: onKeyIntercept,
      semanticLabel: title,
      builder: (context, focused) {
        // `.add-pl-seg button` — padding 14/16 in HTML; tightened for TV.
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? NsColors.surface : NsColors.bg2,
            border: Border.all(
              color: selected
                  ? NsColors.accentLine
                  : (focused ? NsColors.line2 : NsColors.line),
            ),
            borderRadius: BorderRadius.circular(12),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [NsColors.accentSoft, Colors.transparent],
                    stops: [0, 0.8],
                  )
                : null,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: NsColors.accentSoft,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: Color(0x40000000),
                      offset: Offset(0, 8),
                      blurRadius: 24,
                    ),
                  ]
                : (focused
                    ? const [
                        BoxShadow(
                          color: NsColors.accentSoft,
                          spreadRadius: 3,
                        ),
                      ]
                    : null),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [NsColors.accent2, NsColors.accent],
                        )
                      : null,
                  color: selected ? null : NsColors.surface2,
                  border: Border.all(
                    color: selected ? Colors.transparent : NsColors.line,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: NsColors.accentGlow,
                            offset: Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: selected
                      ? const Color(0xFF001317)
                      : NsColors.text2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: NsColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.06,
                        height: 1.15,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        color: selected ? NsColors.text2 : NsColors.text3,
                        fontSize: 10,
                        height: 1.25,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Credentials card — form + test strip + actions row
// ═══════════════════════════════════════════════════════════════════════

class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard({
    required this.state,
    required this.ctrls,
    required this.nodeOf,
    /// First focus on the action strip after the last form field (TV: Test).
    required this.focusAfterLastField,
    required this.fieldOrder,
    required this.statusMsg,
    required this.statusDanger,
    required this.onSetField,
    required this.onToggleReveal,
    required this.onCancel,
    required this.onTest,
    required this.onSave,
    this.tvOskMode = false,
    this.tvArrowRightToKbd,
    this.denseForIme = false,
  });

  final NewSettingsState state;
  final Map<String, TextEditingController> ctrls;
  final FocusNode Function(String id) nodeOf;
  final FocusNode focusAfterLastField;
  final List<FocusNode> fieldOrder;
  final String statusMsg;
  final bool statusDanger;
  final void Function(String id, String v) onSetField;
  final VoidCallback onToggleReveal;
  final VoidCallback onCancel;
  final VoidCallback onTest;
  final VoidCallback onSave;
  final bool tvOskMode;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)?
      tvArrowRightToKbd;

  /// When true: standard TV path with system soft keyboard; tighten verticals.
  final bool denseForIme;

  @override
  Widget build(BuildContext context) {
    final d = state.addPlaylist;
    final isXt = d.type == 'xtream';
    return _AddPlCard(
      compact: denseForIme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHead(
            title: isXt ? 'Xtream credentials' : 'M3U URL',
            hint: isXt
                ? 'These are stored only on this device.'
                : 'A direct link to a .m3u / .m3u8 file.',
            compact: denseForIme,
          ),
          if (isXt) ..._xtreamFields() else ..._m3uFields(),
          if (d.test != null) ...[
            SizedBox(height: denseForIme ? 2 : 4),
            _TestStrip(test: d.test!),
          ],
          SizedBox(height: denseForIme ? 4 : 10),
          Container(
            padding: EdgeInsets.only(top: denseForIme ? 4 : 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: NsColors.line)),
            ),
            // One horizontal [status | Cancel | Test | Add] row overflowed on
            // narrow cards (~280px): the primary action sat in the overflow
            // region and never received taps. Stack status + [Wrap] actions.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: statusDanger
                        ? NsColors.danger
                        : NsColors.text3,
                    fontSize: denseForIme ? 10.5 : 12,
                    height: 1.25,
                    decoration: TextDecoration.none,
                  ),
                  child: Text.rich(
                    _statusSpan(statusMsg, statusDanger),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: denseForIme ? 6 : 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NsButton(
                      focusNode: nodeOf('cancel'),
                      label: 'Cancel',
                      variant: NsButtonVariant.ghost,
                      onPressed: onCancel,
                      onKeyIntercept: tvOskMode ? tvArrowRightToKbd : null,
                    ),
                    NsButton(
                      focusNode: nodeOf('test'),
                      label: 'Test connection',
                      icon: Icons.refresh_rounded,
                      onPressed: onTest,
                      onKeyIntercept: tvOskMode ? tvArrowRightToKbd : null,
                    ),
                    NsButton(
                      focusNode: nodeOf('save'),
                      label: 'Add playlist',
                      icon: Icons.check_rounded,
                      variant: NsButtonVariant.primary,
                      onPressed: onSave,
                      onKeyIntercept: tvOskMode ? tvArrowRightToKbd : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _statusSpan(String msg, bool danger) {
    // The HTML uses "Fields marked with <span style=color:var(--danger)>*</span>
    // are required." — we inline the same styling here.
    if (msg.startsWith('Fields marked with')) {
      return const TextSpan(
        children: [
          TextSpan(text: 'Fields marked with '),
          TextSpan(
            text: '*',
            style: TextStyle(color: NsColors.danger),
          ),
          TextSpan(text: ' are required.'),
        ],
      );
    }
    return TextSpan(text: msg);
  }

  List<Widget> _xtreamFields() {
    final d = state.addPlaylist;
    final gap = denseForIme ? 4.0 : 7.0;
    return [
      _Field(
        id: 'server',
        label: 'Server URL',
        placeholder: 'http://example.com:8080',
        help: 'Your provider\u2019s server address. Include the port if any.',
        error: d.errors['server'],
        controller: ctrls['server']!,
        focusNode: nodeOf('server'),
        fieldOrder: fieldOrder,
        focusAfterLastField: focusAfterLastField,
        keyboardType: TextInputType.url,
        onChanged: (v) => onSetField('server', v),
        tvOskMode: tvOskMode,
        tvArrowRightToKbd: tvArrowRightToKbd,
        dense: denseForIme,
      ),
      SizedBox(height: gap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Field(
              id: 'user',
              label: 'Username',
              placeholder: 'your-username',
              error: d.errors['user'],
              controller: ctrls['user']!,
              focusNode: nodeOf('user'),
              fieldOrder: fieldOrder,
              focusAfterLastField: focusAfterLastField,
              onChanged: (v) => onSetField('user', v),
              tvOskMode: tvOskMode,
              tvArrowRightToKbd: tvArrowRightToKbd,
              dense: denseForIme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Field(
              id: 'pass',
              label: 'Password',
              placeholder: '••••••••',
              error: d.errors['pass'],
              controller: ctrls['pass']!,
              focusNode: nodeOf('pass'),
              fieldOrder: fieldOrder,
              focusAfterLastField: focusAfterLastField,
              obscure: !d.showPass,
              trailing: _RevealButton(
                focusNode: nodeOf('pass_reveal'),
                showing: d.showPass,
                onPressed: onToggleReveal,
                onKeyIntercept: tvOskMode ? tvArrowRightToKbd : null,
              ),
              onChanged: (v) => onSetField('pass', v),
              tvOskMode: tvOskMode,
              tvArrowRightToKbd: tvArrowRightToKbd,
              dense: denseForIme,
            ),
          ),
        ],
      ),
      SizedBox(height: gap),
      _Field(
        id: 'name',
        label: 'Display name',
        placeholder: 'e.g. Family Pack',
        help: 'Shown in the playlists list. Pick anything you\u2019ll recognize.',
        error: d.errors['name'],
        controller: ctrls['name']!,
        focusNode: nodeOf('name'),
        fieldOrder: fieldOrder,
        focusAfterLastField: focusAfterLastField,
        onChanged: (v) => onSetField('name', v),
        tvOskMode: tvOskMode,
        tvArrowRightToKbd: tvArrowRightToKbd,
        dense: denseForIme,
      ),
    ];
  }

  List<Widget> _m3uFields() {
    final d = state.addPlaylist;
    final gap = denseForIme ? 4.0 : 7.0;
    return [
      _Field(
        id: 'name',
        label: 'Display name',
        placeholder: 'e.g. Backup playlist',
        help: 'Shown in the playlists list. Pick anything you\u2019ll recognize.',
        error: d.errors['name'],
        controller: ctrls['name']!,
        focusNode: nodeOf('name'),
        fieldOrder: fieldOrder,
        focusAfterLastField: focusAfterLastField,
        onChanged: (v) => onSetField('name', v),
        tvOskMode: tvOskMode,
        tvArrowRightToKbd: tvArrowRightToKbd,
        dense: denseForIme,
      ),
      SizedBox(height: gap),
      _Field(
        id: 'url',
        label: 'M3U URL',
        placeholder: 'http://example.com/list.m3u8',
        help: 'A direct link to a .m3u or .m3u8 playlist file.',
        error: d.errors['url'],
        controller: ctrls['url']!,
        focusNode: nodeOf('url'),
        fieldOrder: fieldOrder,
        focusAfterLastField: focusAfterLastField,
        keyboardType: TextInputType.url,
        onChanged: (v) => onSetField('url', v),
        tvOskMode: tvOskMode,
        tvArrowRightToKbd: tvArrowRightToKbd,
        dense: denseForIme,
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Form row — `.add-pl-row`
// ═══════════════════════════════════════════════════════════════════════

class _Field extends StatelessWidget {
  const _Field({
    required this.id,
    required this.label,
    required this.placeholder,
    required this.controller,
    required this.focusNode,
    required this.fieldOrder,
    required this.focusAfterLastField,
    required this.onChanged,
    this.help,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.tvOskMode = false,
    this.tvArrowRightToKbd,
    this.dense = false,
  });

  final String id;
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Ordered focus ring — D-pad Up/Down moves to prev / next.
  final List<FocusNode> fieldOrder;
  final FocusNode focusAfterLastField;

  final void Function(String value) onChanged;
  final String? help;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final bool tvOskMode;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)?
      tvArrowRightToKbd;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `.add-pl-row label` — uppercase, spacing 1.4px.
        Padding(
          padding: EdgeInsets.only(bottom: dense ? 2 : 4, left: 2),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: NsColors.text3,
                fontSize: dense ? 8.5 : 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: dense ? 0.9 : 1.2,
                height: 1,
                decoration: TextDecoration.none,
              ),
              children: [
                TextSpan(text: label.toUpperCase()),
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: NsColors.danger,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        // `.field-wrap` — input with optional trailing widget.
        Stack(
          alignment: Alignment.centerRight,
          children: [
            _TextInput(
              controller: controller,
              focusNode: focusNode,
              fieldOrder: fieldOrder,
              focusAfterLastField: focusAfterLastField,
              onChanged: onChanged,
              placeholder: placeholder,
              obscure: obscure,
              keyboardType: keyboardType,
              hasError: hasError,
              paddingRight: trailing == null ? 13 : 40,
              tvOskMode: tvOskMode,
              tvArrowRightToKbd: tvArrowRightToKbd,
              dense: dense,
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: trailing,
              ),
          ],
        ),
        if (hasError) ...[
          SizedBox(height: dense ? 2 : 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 11,
                color: NsColors.danger,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: NsColors.danger,
                    fontSize: 10.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ] else if (help != null && help!.isNotEmpty) ...[
          SizedBox(height: dense ? 2 : 4),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              help!,
              style: TextStyle(
                color: NsColors.text4,
                fontSize: dense ? 9.5 : 10.5,
                height: dense ? 1.2 : 1.35,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.controller,
    required this.focusNode,
    required this.fieldOrder,
    required this.focusAfterLastField,
    required this.onChanged,
    required this.placeholder,
    required this.hasError,
    required this.paddingRight,
    this.obscure = false,
    this.keyboardType,
    this.tvOskMode = false,
    this.tvArrowRightToKbd,
    this.dense = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<FocusNode> fieldOrder;
  final FocusNode focusAfterLastField;
  final void Function(String) onChanged;
  final String placeholder;
  final bool hasError;
  final double paddingRight;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool tvOskMode;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)?
      tvArrowRightToKbd;
  final bool dense;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_focused != widget.focusNode.hasFocus) {
      setState(() => _focused = widget.focusNode.hasFocus);
      if (widget.focusNode.hasFocus) _ensureVisibleAboveKeyboard();
    }
  }

  /// Auto-scroll the field above the soft keyboard when it gains
  /// focus. Runs on the next frame so the keyboard's view-insets are
  /// already committed to [MediaQuery], and uses an alignment near
  /// the top of the viewport so the label + input both stay visible.
  void _ensureVisibleAboveKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      if (!ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _goPrev() {
    final i = widget.fieldOrder.indexOf(widget.focusNode);
    if (i <= 0) return;
    widget.fieldOrder[i - 1].requestFocus();
  }

  void _goNext() {
    final i = widget.fieldOrder.indexOf(widget.focusNode);
    if (i < 0) return;
    if (i < widget.fieldOrder.length - 1) {
      widget.fieldOrder[i + 1].requestFocus();
      return;
    }
    // Last text field -> action row (Test connection), same as _tvNextField.
    widget.focusAfterLastField.requestFocus();
  }

  void _dispatchTvArrowRight() {
    final intercept = widget.tvArrowRightToKbd;
    if (intercept == null) return;
    intercept(
      widget.focusNode,
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowRight,
        logicalKey: LogicalKeyboardKey.arrowRight,
        timeStamp: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dense;
    final focusColor = widget.hasError
        ? NsColors.danger
        : (_focused ? NsColors.accentLine : NsColors.line);
    final focusBg = widget.hasError
        ? NsColors.dangerSoft
        : (_focused ? NsColors.surface : NsColors.bg);
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowUp): _goPrev,
      const SingleActivator(LogicalKeyboardKey.arrowDown): _goNext,
    };
    if (widget.tvArrowRightToKbd != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.arrowRight)] =
          _dispatchTvArrowRight;
    }
    return CallbackShortcuts(
      bindings: bindings,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        obscureText: widget.obscure,
        readOnly: widget.tvOskMode,
        keyboardType: widget.tvOskMode
            ? TextInputType.none
            : widget.keyboardType,
        enableInteractiveSelection: !widget.tvOskMode,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _goNext(),
        cursorColor: NsColors.accent,
        style: TextStyle(
          color: NsColors.text,
          fontSize: d ? 10.5 : 11.5,
          fontWeight: FontWeight.w500,
          height: 1.12,
          decoration: TextDecoration.none,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: focusBg,
          contentPadding: EdgeInsets.fromLTRB(
            d ? 7 : 9,
            d ? 4 : 6,
            widget.paddingRight,
            d ? 4 : 6,
          ),
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: NsColors.text4,
            fontSize: d ? 10.5 : 11.5,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(d ? 6 : 8),
            borderSide: BorderSide(color: focusColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(d ? 6 : 8),
            borderSide: BorderSide(color: focusColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(d ? 6 : 8),
            borderSide: BorderSide(color: focusColor, width: 1),
          ),
        ),
      ),
    );
  }
}

// `.reveal` — 28×28 transparent icon button, right:8 top:50%.
class _RevealButton extends StatelessWidget {
  const _RevealButton({
    required this.focusNode,
    required this.showing,
    required this.onPressed,
    this.onKeyIntercept,
  });
  final FocusNode focusNode;
  final bool showing;
  final VoidCallback onPressed;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onKeyIntercept: onKeyIntercept,
      semanticLabel: showing ? 'Hide password' : 'Show password',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          showing
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          size: 14,
          color: focused ? NsColors.text : NsColors.text3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Test-connection strip — `.add-pl-test`
// ═══════════════════════════════════════════════════════════════════════

class _TestStrip extends StatelessWidget {
  const _TestStrip({required this.test});
  final NsAddPlaylistTest test;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color tint, Color bg, Color border) =
        switch (test.status) {
      NsAddPlaylistTestStatus.pending => (
          Icons.sync_rounded,
          NsColors.warn,
          NsColors.bg2,
          NsColors.line2,
        ),
      NsAddPlaylistTestStatus.ok => (
          Icons.check_rounded,
          NsColors.success,
          NsColors.successSoft,
          const Color(0x594ADE80),
        ),
      NsAddPlaylistTestStatus.error => (
          Icons.warning_amber_rounded,
          NsColors.danger,
          NsColors.dangerSoft,
          const Color(0x66F87171),
        ),
    };
    final msg = switch (test.status) {
      NsAddPlaylistTestStatus.pending => 'Testing connection…',
      NsAddPlaylistTestStatus.ok => _okMessage(test.counts),
      NsAddPlaylistTestStatus.error => test.message ??
          'Could not connect. Check the details and try again.',
    };
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: tint,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _okMessage(Map<String, int>? c) {
    if (c == null || c.isEmpty) return 'Connected.';
    final parts = <String>[];
    final live = c['live'] ?? 0;
    final vod = c['vod'] ?? 0;
    final series = c['series'] ?? 0;
    if (live > 0) parts.add('${_fmt(live)} channels');
    if (vod > 0) parts.add('${_fmt(vod)} movies');
    if (series > 0) parts.add('${_fmt(series)} series');
    return parts.isEmpty
        ? 'Connected.'
        : 'Connected. ${parts.join(' · ')}';
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}


