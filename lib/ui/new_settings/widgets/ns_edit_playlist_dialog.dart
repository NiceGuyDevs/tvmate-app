/// Full "Edit playlist" dialog for new settings: display name, connection
/// fields, TV-friendly focus order, and writes through [libraryController]
/// (rename-only when admin credentials are hidden; otherwise
/// [LibraryController.updatePlaylistDetails] with cache evict + sync
/// when appropriate — matching legacy [MyPlaylists] edit form).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../data/device_memory_channel.dart';
import '../../../data/library_controller.dart';
import '../../../data/playlist_live_catalog_cache.dart';
import '../../../data/playlist_type.dart' show PlaylistType;
import '../../../data/stored_playlist.dart' show StoredPlaylist;
import '../../../data/xtream_catalog_cache_db.dart';
import '../../../data/xtream_catalog_repository.dart';
import '../../focus/tv_focusable.dart' show isDpadKeyRepeat;
import '../../settings/tv_remote_char_pad_overlay.dart' show showTvRemoteCharPad;
import '../../settings/tv_remote_keys.dart'
    show tvRemoteIsActivate, tvRemoteIsDpadDown, tvRemoteIsDpadUp;
import '../new_settings_theme.dart';
import 'ns_button.dart';
import 'ns_focusable.dart' show NsFocusAccentScope, NsFocusable;

/// Opens the edit sheet for a playlist in [libraryController] by [playlistId].
/// If the id is not found, shows a snackbar and does nothing.
Future<void> showNsEditPlaylistDialog(
  BuildContext context, {
  required String playlistId,
}) async {
  StoredPlaylist? target;
  for (final p in libraryController.playlists) {
    if (p.id == playlistId) {
      target = p;
      break;
    }
  }
  if (target == null) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Playlist not found'),
        ),
      );
    }
    return;
  }
  final playlist = target;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x99000000),
    builder: (ctx) => _NsEditPlaylistDialog(playlist: playlist),
  );
}

class _NsEditPlaylistDialog extends StatefulWidget {
  const _NsEditPlaylistDialog({required this.playlist});

  final StoredPlaylist playlist;

  @override
  State<_NsEditPlaylistDialog> createState() => _NsEditPlaylistDialogState();
}

class _NsEditPlaylistDialogState extends State<_NsEditPlaylistDialog>
    with WidgetsBindingObserver {
  late final TextEditingController _name;
  late final TextEditingController _server;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _m3u;

  late final FocusNode _serverFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  late final FocusNode _passRevealFocus;
  late final FocusNode _nameFocus;
  late final FocusNode _m3uFocus;
  late final FocusNode _cancelFocus;
  late final FocusNode _saveFocus;

  bool _showPass = false;
  bool _submitting = false;

  StoredPlaylist get _p => widget.playlist;

  /// Matches legacy: empty server+username on Xtream ⇒ admin-pushed, rename-only.
  bool get _credentialsHidden =>
      _p.isXtream &&
      (_p.serverUrl == null || _p.serverUrl!.isEmpty) &&
      (_p.username == null || _p.username!.isEmpty);

  bool get _useTvCharPad =>
      !kIsWeb && Platform.isAndroid && DeviceMemoryChannel.useInAppTextPadOnly;

  FocusNode get _lastFormField {
    if (_credentialsHidden) return _nameFocus;
    if (_p.type == PlaylistType.m3u) return _m3uFocus;
    return _nameFocus;
  }

  @override
  void initState() {
    super.initState();
    final p = _p;
    _name = TextEditingController(text: p.name);
    _server = TextEditingController(text: p.serverUrl ?? '');
    _user = TextEditingController(text: p.username ?? '');
    _pass = TextEditingController(text: p.password ?? '');
    _m3u = TextEditingController(text: p.m3uUrl ?? '');

    _serverFocus = FocusNode(debugLabel: 'nsEditPl:server');
    _userFocus = FocusNode(debugLabel: 'nsEditPl:user');
    _passFocus = FocusNode(debugLabel: 'nsEditPl:pass');
    _passRevealFocus = FocusNode(debugLabel: 'nsEditPl:reveal');
    _nameFocus = FocusNode(debugLabel: 'nsEditPl:name');
    _m3uFocus = FocusNode(debugLabel: 'nsEditPl:m3u');
    _cancelFocus = FocusNode(debugLabel: 'nsEditPl:cancel');
    _saveFocus = FocusNode(debugLabel: 'nsEditPl:save');

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_credentialsHidden) {
        _nameFocus.requestFocus();
      } else if (p.isXtream) {
        _serverFocus.requestFocus();
      } else {
        _nameFocus.requestFocus();
      }
    });
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    _m3u.dispose();
    _serverFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _passRevealFocus.dispose();
    _nameFocus.dispose();
    _m3uFocus.dispose();
    _cancelFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final name = _name.text.trim();
      if (name.isEmpty) {
        _toast(l10n.dialogPlaylistEditInvalid);
        return;
      }

      if (_p.isXtream && _credentialsHidden) {
        await libraryController.renamePlaylist(_p.id, name);
      } else if (_p.isXtream) {
        if (_server.text.trim().isEmpty || _user.text.trim().isEmpty) {
          _toast(l10n.dialogPlaylistEditInvalid);
          return;
        }
        await libraryController.updatePlaylistDetails(
          id: _p.id,
          name: name,
          serverUrl: _server.text,
          username: _user.text,
          password: _pass.text,
        );
        await xtreamCatalogCacheDb.deleteForPlaylist(_p.id);
        playlistLiveCatalogCache.evict(_p.id);
        if (libraryController.activePlaylistId == _p.id) {
          await xtreamCatalogRepository.syncFromLibrary(libraryController);
        }
      } else {
        if (_m3u.text.trim().isEmpty) {
          _toast(l10n.dialogPlaylistEditInvalid);
          return;
        }
        await libraryController.updatePlaylistDetails(
          id: _p.id,
          name: name,
          m3uUrl: _m3u.text,
        );
        await xtreamCatalogCacheDb.deleteForPlaylist(_p.id);
        playlistLiveCatalogCache.evict(_p.id);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  KeyEventResult? _keyNavButtons(FocusNode node, KeyEvent event) {
    if (DeviceMemoryChannel.imeLikelyOpenForTvTextInput(context)) return null;
    if (isDpadKeyRepeat(event)) return KeyEventResult.handled;
    if (identical(node, _cancelFocus)) {
      if (tvRemoteIsDpadDown(event)) {
        _saveFocus.requestFocus();
        return KeyEventResult.handled;
      }
      if (tvRemoteIsDpadUp(event)) {
        _lastFormField.requestFocus();
        return KeyEventResult.handled;
      }
    } else if (identical(node, _saveFocus)) {
      if (tvRemoteIsDpadUp(event)) {
        _cancelFocus.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return null;
  }

  KeyEventResult? _keyNavReveal(FocusNode node, KeyEvent event) {
    if (DeviceMemoryChannel.imeLikelyOpenForTvTextInput(context)) return null;
    if (isDpadKeyRepeat(event)) return KeyEventResult.handled;
    if (tvRemoteIsDpadDown(event)) {
      _nameFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (tvRemoteIsDpadUp(event)) {
      _passFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _p;
    final xt = p.isXtream;
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    Widget body;
    if (xt) {
      if (_credentialsHidden) {
        body = _lockedXtreamForm(l10n);
      } else {
        body = _fullXtreamForm(l10n);
      }
    } else {
      body = _m3uForm(l10n);
    }

    // Edit playlist: comfortable size (~2× the over-tightened 256×198 pass) +
    // IME padding so the sheet rides above the soft keyboard. [NsFocusAccentScope]
    // enables the same orange “Hugging L” TV focus bar as the rest of new settings.
    return SafeArea(
      child: NsFocusAccentScope(
        enabled: true,
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 6, 12, 6 + kb),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 404,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  decoration: BoxDecoration(
                    color: NsColors.surface,
                    border: Border.all(color: NsColors.line),
                    borderRadius: BorderRadius.circular(NsRadius.card),
                    boxShadow: NsShadow.s2,
                  ),
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.dialogEditPlaylist,
                        style: const TextStyle(
                          color: NsColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: body,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FocusTraversalOrder(
                              order: const NumericFocusOrder(20),
                              child: NsButton(
                                label: l10n.dialogCancel,
                                variant: NsButtonVariant.ghost,
                                fillWidth: true,
                                focusNode: _cancelFocus,
                                focusRightNeighbor: _saveFocus,
                                enabled: !_submitting,
                                onPressed: () => Navigator.of(context).pop(),
                                onKeyIntercept: (n, e) => _keyNavButtons(n, e),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FocusTraversalOrder(
                              order: const NumericFocusOrder(21),
                              child: NsButton(
                                label: l10n.dialogSave,
                                variant: NsButtonVariant.primary,
                                fillWidth: true,
                                focusNode: _saveFocus,
                                focusLeftNeighbor: _cancelFocus,
                                enabled: !_submitting,
                                onPressed: () {
                                  if (_submitting) return;
                                  unawaited(_submit());
                                },
                                onKeyIntercept: (n, e) => _keyNavButtons(n, e),
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
          ),
        ),
        ),
      ),
    );
  }

  Widget _lockedXtreamForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _adminOnlyBanner(),
        const SizedBox(height: 4),
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: _NsTvFormTextField(
            label: l10n.dialogPlaylistNameHint,
            controller: _name,
            focusNode: _nameFocus,
            nextDpad: _cancelFocus,
            previousDpad: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _cancelFocus.requestFocus(),
            useTvCharPad: _useTvCharPad,
            labelForCharPad: l10n.dialogPlaylistNameHint,
            obscure: false,
          ),
        ),
      ],
    );
  }

  /// Placeholder: first field; previousDpad is unused in traversal.
  Widget _adminOnlyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: NsColors.warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: NsColors.warn.withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 13, color: NsColors.warn),
          SizedBox(width: 5),
          Expanded(
            child: Text(
              'Credentials managed by admin',
              style: TextStyle(
                color: NsColors.warn,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _m3uForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: _NsTvFormTextField(
            label: l10n.dialogPlaylistNameHint,
            controller: _name,
            focusNode: _nameFocus,
            nextDpad: _m3uFocus,
            previousDpad: null,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _m3uFocus.requestFocus(),
            useTvCharPad: _useTvCharPad,
            labelForCharPad: l10n.dialogPlaylistNameHint,
          ),
        ),
        const SizedBox(height: 4),
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: _NsTvFormTextField(
            label: l10n.dialogPlaylistM3uUrl,
            controller: _m3u,
            focusNode: _m3uFocus,
            nextDpad: _cancelFocus,
            previousDpad: _nameFocus,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _cancelFocus.requestFocus(),
            useTvCharPad: _useTvCharPad,
            labelForCharPad: l10n.dialogPlaylistM3uUrl,
          ),
        ),
      ],
    );
  }

  Widget _fullXtreamForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: _NsTvFormTextField(
            label: l10n.dialogPlaylistServerUrl,
            controller: _server,
            focusNode: _serverFocus,
            nextDpad: _userFocus,
            previousDpad: null,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _userFocus.requestFocus(),
            useTvCharPad: _useTvCharPad,
            labelForCharPad: l10n.dialogPlaylistServerUrl,
          ),
        ),
        const SizedBox(height: 4),
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: _NsTvFormTextField(
            label: l10n.dialogPlaylistUsername,
            controller: _user,
            focusNode: _userFocus,
            nextDpad: _passFocus,
            previousDpad: _serverFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passFocus.requestFocus(),
            useTvCharPad: _useTvCharPad,
            labelForCharPad: l10n.dialogPlaylistUsername,
          ),
        ),
        const SizedBox(height: 4),
        // Password row: field + separate focus for reveal.
        _passwordRow(l10n),
        const SizedBox(height: 4),
        FocusTraversalOrder(
          order: const NumericFocusOrder(5),
          child: _NsTvFormTextField(
            label: l10n.dialogPlaylistNameHint,
            controller: _name,
            focusNode: _nameFocus,
            nextDpad: _cancelFocus,
            previousDpad: _passRevealFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _cancelFocus.requestFocus(),
            useTvCharPad: _useTvCharPad,
            labelForCharPad: l10n.dialogPlaylistNameHint,
          ),
        ),
      ],
    );
  }

  Widget _passwordRow(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 2),
          child: Text(
            l10n.dialogPlaylistPassword.toUpperCase(),
            style: const TextStyle(
              color: NsColors.text3,
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: _NsTvFormTextField(
                  label: '', // label drawn above the row
                  labelAbove: false,
                  controller: _pass,
                  focusNode: _passFocus,
                  nextDpad: _passRevealFocus,
                  previousDpad: _userFocus,
                  obscure: !_showPass,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _nameFocus.requestFocus(),
                  useTvCharPad: _useTvCharPad,
                  labelForCharPad: l10n.dialogPlaylistPassword,
                ),
              ),
            ),
            const SizedBox(width: 6),
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: NsFocusable(
                focusNode: _passRevealFocus,
                semanticLabel:
                    _showPass ? 'Hide password' : 'Show password',
                isButton: true,
                onKeyIntercept: (n, e) => _keyNavReveal(n, e),
                onActivate: () => setState(() => _showPass = !_showPass),
                builder: (context, focused) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    curve: NsEase.ease,
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(bottom: 1),
                    decoration: BoxDecoration(
                      color: focused ? NsColors.surface2 : NsColors.bg2,
                      border: Border.all(
                        color: focused
                            ? NsColors.accentLine
                            : NsColors.line2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _showPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 15,
                      color: focused ? NsColors.text : NsColors.text3,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── TV text field: hardware D-pad when IME dismissed; [requestShowSoftInput] on focus.
class _NsTvFormTextField extends StatefulWidget {
  const _NsTvFormTextField({
    required this.label,
    this.labelAbove = true,
    required this.controller,
    required this.focusNode,
    required this.nextDpad,
    this.previousDpad,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.useTvCharPad = false,
    this.labelForCharPad = 'Field',
  });

  final String label;
  final bool labelAbove;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextDpad;
  final FocusNode? previousDpad;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool useTvCharPad;
  final String labelForCharPad;

  @override
  State<_NsTvFormTextField> createState() => _NsTvFormTextFieldState();
}

class _NsTvFormTextFieldState extends State<_NsTvFormTextField>
    with WidgetsBindingObserver {
  bool get _inAppField =>
      widget.useTvCharPad && DeviceMemoryChannel.useInAppTextPadOnly;

  void _onFocusChange() {
    final inApp = _inAppField;
    if (widget.focusNode.hasFocus && !inApp) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.focusNode.hasFocus) return;
        if (_inAppField) return;
        unawaited(DeviceMemoryChannel.requestShowSoftInput());
      });
    }
    if (mounted) setState(() {});
  }

  bool _hardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (!widget.focusNode.hasFocus) return false;
    if (_inAppField && tvRemoteIsActivate(event)) {
      unawaited(
        showTvRemoteCharPad(
          context,
          controller: widget.controller,
          fieldLabel: widget.labelForCharPad,
          obscure: widget.obscure,
        ),
      );
      return true;
    }
    if (DeviceMemoryChannel.imeLikelyOpenForTvTextInput(context)) {
      return false;
    }
    if (isDpadKeyRepeat(event)) return true;
    if (tvRemoteIsDpadDown(event)) {
      widget.nextDpad.requestFocus();
      return true;
    }
    if (tvRemoteIsDpadUp(event)) {
      final prev = widget.previousDpad;
      if (prev == null) return false;
      prev.requestFocus();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_onFocusChange);
    HardwareKeyboard.instance.addHandler(_hardwareKey);
  }

  @override
  void didUpdateWidget(covariant _NsTvFormTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_hardwareKey);
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final inApp = _inAppField;
    final field = TextField(
      focusNode: widget.focusNode,
      controller: widget.controller,
      readOnly: inApp,
      obscureText: widget.obscure,
      keyboardType: inApp ? TextInputType.none : widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: (v) {
        widget.onSubmitted?.call(v);
      },
      onTap: inApp
          ? () {
              unawaited(
                showTvRemoteCharPad(
                  context,
                  controller: widget.controller,
                  fieldLabel: widget.labelForCharPad,
                  obscure: widget.obscure,
                ),
              );
            }
          : null,
      style: const TextStyle(
        color: NsColors.text,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.12,
        decoration: TextDecoration.none,
      ),
      cursorColor: NsColors.accent,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: focused ? NsColors.surface : NsColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: focused ? NsColors.accentLine : NsColors.line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: focused ? NsColors.accentLine : NsColors.line,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(
            color: NsColors.accentLine,
            width: 1.2,
          ),
        ),
      ),
    );

    if (!widget.labelAbove) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 3),
            child: Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
        field,
      ],
    );
  }
}
