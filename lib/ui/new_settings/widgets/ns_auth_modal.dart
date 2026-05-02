/// HTML-styled Sign in / Create account modal for the new settings
/// Account page.
///
/// Visually mirrors the rest of the new-settings surface (cyan accent,
/// surface tokens, NsFocusable focus rings) while calling the same
/// `accountApi` / `accountStore` commands the old login and register
/// screens use — so the auth outcome is identical:
///
///   * `accountApi.login(email, password, deviceId:)`
///   * `accountApi.register(email, password, deviceId:)`
///   * `accountApi.googleLogin(idToken, deviceId:)`
///   * `accountStore.saveTokens(...)` + `accountStore.saveUser(...)`
///   * `libraryController.tagUntaggedPlaylistsForCurrentUser()`
///   * `libraryController.refreshVisibility()`
///   * `libraryController.pullAdminPlaylists()` → `startPeriodicSync()`
///
/// Returns `true` if the user successfully signed in or registered,
/// `false` if they cancelled.
library;

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../account/account_api.dart';
import '../../../account/account_store.dart';
import '../../../account/device_limit_dialog.dart';
import '../../../data/device_memory_channel.dart';
import '../../../data/library_controller.dart';
import '../new_settings_theme.dart';
import 'ns_auth_tv_wide.dart';
import 'ns_button.dart';
import 'ns_focusable.dart';

enum NsAuthMode { signIn, register }

Future<bool> showNsAuthModal(
  BuildContext context, {
  NsAuthMode initialMode = NsAuthMode.signIn,
}) async {
  final leanbackFusedKbd = !kIsWeb &&
      Platform.isAndroid &&
      DeviceMemoryChannel.useInAppTextPadOnly;
  final r = await showGeneralDialog<bool>(
    context: context,
    // Nested navigator under the main shell: local overlay ordering can leave
    // the fused TV card under sibling layers. Root overlay matches user
    // expectation for a blocking auth gate.
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Sign in',
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a, b) => PrimaryScrollController.none(
          child: _AuthPage(initialMode: initialMode),
        ),
    // Scale+opacity on a large transformed subtree has caused partial paint
    // on some Android TV builds; fused keyboard path keeps a plain fade-in.
    transitionBuilder: (ctx, a, b, child) {
      if (leanbackFusedKbd) {
        return FadeTransition(opacity: a, child: child);
      }
      final curved = CurvedAnimation(parent: a, curve: NsEase.ease);
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.96 + 0.04 * curved.value,
          child: child,
        ),
      );
    },
  );
  return r == true;
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({required this.initialMode});
  final NsAuthMode initialMode;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  late NsAuthMode _mode;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailFocus = FocusNode(debugLabel: 'nsAuth:email');
  final _passFocus = FocusNode(debugLabel: 'nsAuth:pass');
  final _confirmFocus = FocusNode(debugLabel: 'nsAuth:confirm');
  final _submitFocus = FocusNode(debugLabel: 'nsAuth:submit');
  final _googleFocus = FocusNode(debugLabel: 'nsAuth:google');
  final _linkFocus = FocusNode(debugLabel: 'nsAuth:link');
  final _closeFocus = FocusNode(debugLabel: 'nsAuth:close');
  final _signInTabFocus = FocusNode(debugLabel: 'nsAuth:signInTab');
  final _registerTabFocus = FocusNode(debugLabel: 'nsAuth:registerTab');
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  /// Chromecast / leanback: no usable IME — wide fused card + on-screen keyboard.
  bool get _useTvPad =>
      !kIsWeb &&
      Platform.isAndroid &&
      DeviceMemoryChannel.useInAppTextPadOnly;

  FocusNode? _firstKbdFocus;
  String _tvActiveLabel = 'Email';
  bool _passObscured = true;
  bool _confirmObscured = true;

  bool get _tvKeyboardAside =>
      _useTvPad &&
      mounted &&
      MediaQuery.sizeOf(context).width >= 780;

  /// Own controller so the TV form [SingleChildScrollView] never binds to
  /// [PrimaryScrollController] (same object as the Account [ListView] behind
  /// this route on Android).
  final _tvFormScroll = ScrollController();

  void _onTvFieldFocus() => _syncTvActiveFieldLabel();

  void _syncTvActiveFieldLabel() {
    if (!mounted) return;
    if (_emailFocus.hasFocus) {
      _tvActiveLabel = 'Email';
    } else if (_passFocus.hasFocus) {
      _tvActiveLabel = 'Password';
    } else if (_confirmFocus.hasFocus && _mode == NsAuthMode.register) {
      _tvActiveLabel = 'Confirm password';
    }
    setState(() {});
  }

  TextEditingController _tvControllerForActiveLabel() {
    switch (_tvActiveLabel) {
      case 'Password':
        return _passCtrl;
      case 'Confirm password':
        return _confirmCtrl;
      default:
        return _emailCtrl;
    }
  }

  void _tvInsert(String ch) {
    final c = _tvControllerForActiveLabel();
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
  }

  void _tvBackspace() {
    final c = _tvControllerForActiveLabel();
    final v = c.value;
    final t = v.text;
    final sel = v.selection;
    if (sel.isValid && sel.start != sel.end) {
      final lo = sel.start < sel.end ? sel.start : sel.end;
      final hi = sel.start < sel.end ? sel.end : sel.start;
      c.value = TextEditingValue(
        text: t.replaceRange(lo, hi, ''),
        selection: TextSelection.collapsed(offset: lo),
      );
      return;
    }
    final pos = sel.isValid ? sel.start : t.length;
    if (pos <= 0) return;
    c.value = TextEditingValue(
      text: t.replaceRange(pos - 1, pos, ''),
      selection: TextSelection.collapsed(offset: pos - 1),
    );
  }

  void _tvClearField() {
    final c = _tvControllerForActiveLabel();
    c.value = const TextEditingValue();
  }

  void _tvToggleObscure() {
    setState(() {
      if (_tvActiveLabel == 'Confirm password') {
        _confirmObscured = !_confirmObscured;
      } else {
        _passObscured = !_passObscured;
      }
    });
  }

  /// TV pad “Next ↓” — same idea as soft-keyboard Enter / Next between fields.
  void _tvNextField() {
    if (!mounted) return;
    if (_emailFocus.hasFocus) {
      _passFocus.requestFocus();
    } else if (_passFocus.hasFocus) {
      if (_mode == NsAuthMode.register) {
        _confirmFocus.requestFocus();
      } else {
        _submitFocus.requestFocus();
      }
    } else if (_confirmFocus.hasFocus && _mode == NsAuthMode.register) {
      _submitFocus.requestFocus();
    } else {
      switch (_tvActiveLabel) {
        case 'Password':
          if (_mode == NsAuthMode.register) {
            _confirmFocus.requestFocus();
          } else {
            _submitFocus.requestFocus();
          }
          break;
        case 'Confirm password':
          _submitFocus.requestFocus();
          break;
        case 'Email':
          _passFocus.requestFocus();
          break;
        default:
          _emailFocus.requestFocus();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _emailFocus.addListener(_onTvFieldFocus);
    _passFocus.addListener(_onTvFieldFocus);
    _confirmFocus.addListener(_onTvFieldFocus);
    // After the first frame, land focus on the email field so the user
    // can type immediately (and the soft keyboard opens on Android).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onTvFieldFocus);
    _passFocus.removeListener(_onTvFieldFocus);
    _confirmFocus.removeListener(_onTvFieldFocus);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _submitFocus.dispose();
    _googleFocus.dispose();
    _linkFocus.dispose();
    _closeFocus.dispose();
    _signInTabFocus.dispose();
    _registerTabFocus.dispose();
    _tvFormScroll.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────

  Future<void> _submit({String? removeDeviceId}) async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }
    if (_mode == NsAuthMode.register) {
      if (pass != _confirmCtrl.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
      if (pass.length < 8) {
        setState(() => _error = 'Password must be at least 8 characters.');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = _mode == NsAuthMode.signIn
          ? await accountApi.login(
              email,
              pass,
              deviceId: accountStore.deviceId,
              removeDeviceId: removeDeviceId,
            )
          : await accountApi.register(
              email,
              pass,
              deviceId: accountStore.deviceId,
              removeDeviceId: removeDeviceId,
            );
      await _persistAndClose(res);
    } on ApiException catch (e) {
      if (e.code == 'MAX_DEVICES' && e.data != null && mounted) {
        final devices = (e.data!['devices'] as List?) ?? const <dynamic>[];
        final limit = (e.data!['deviceLimit'] as num?)?.toInt() ?? 5;
        if (mounted) setState(() => _loading = false);
        final chosen = await showDeviceLimitDialog(
          context,
          devices: devices,
          deviceLimit: limit,
        );
        if (chosen != null && mounted) {
          await _submit(removeDeviceId: chosen);
        }
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final gsi = GoogleSignIn(scopes: const ['email']);
      final account = await gsi.signIn();
      if (account == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _error = 'Google sign-in failed: no ID token';
            _googleLoading = false;
          });
        }
        return;
      }
      await _completeGoogleSignIn(idToken);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _completeGoogleSignIn(
    String idToken, {
    String? removeDeviceId,
  }) async {
    try {
      final res = await accountApi.googleLogin(
        idToken,
        deviceId: accountStore.deviceId,
        removeDeviceId: removeDeviceId,
      );
      await _persistAndClose(res);
    } on ApiException catch (e) {
      if (e.code == 'MAX_DEVICES' && e.data != null && mounted) {
        final devices = (e.data!['devices'] as List?) ?? const <dynamic>[];
        final limit = (e.data!['deviceLimit'] as num?)?.toInt() ?? 5;
        final chosen = await showDeviceLimitDialog(
          context,
          devices: devices,
          deviceLimit: limit,
        );
        if (chosen != null && mounted) {
          await _completeGoogleSignIn(idToken, removeDeviceId: chosen);
        }
        return;
      }
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Save tokens + user, run the same post-auth library bookkeeping the
  /// old login screen runs, then dismiss the modal with `true`.
  Future<void> _persistAndClose(Map<String, dynamic> res) async {
    await accountStore.saveTokens(
      res['accessToken'] as String,
      res['refreshToken'] as String,
    );
    if (res['user'] != null) {
      await accountStore.saveUser(res['user'] as Map<String, dynamic>);
    }
    await libraryController.tagUntaggedPlaylistsForCurrentUser();
    await libraryController.refreshVisibility();
    // Fire-and-forget — same as the old login screen.
    // ignore: unawaited_futures
    libraryController
        .pullAdminPlaylists()
        .then((_) => libraryController.startPeriodicSync());
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  // ── Build ───────────────────────────────────────────────────────

  /// D-pad handler used by mode-switch segments — Up stays put, Down
  /// drops into the email field. Left/Right stays inside the switch's
  /// internal segments (handled by NsFocusable's default traversal).
  KeyEventResult? _moduleSwitchKeyIntercept(FocusNode node, KeyEvent ev) {
    if (ev is! KeyDownEvent) return null;
    if (ev.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveDown(node);
      return KeyEventResult.handled;
    }
    return null;
  }

  /// D-pad handler used by text fields — Up/Down routes to neighbours.
  /// Wide fused layout: Right jumps to the on-screen keyboard (it's to the right).
  /// Read-only TV fields: Left/Right need not move the caret.
  KeyEventResult? _fieldKeyIntercept(
    FocusNode fieldNode,
    KeyEvent ev,
    FocusNode self,
  ) {
    if (ev is! KeyDownEvent) return null;
    if (ev.logicalKey == LogicalKeyboardKey.arrowRight &&
        _useTvPad &&
        _tvKeyboardAside &&
        _firstKbdFocus != null) {
      _firstKbdFocus!.requestFocus();
      return KeyEventResult.handled;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveDown(self);
      return KeyEventResult.handled;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveUp(self);
      return KeyEventResult.handled;
    }
    return null;
  }

  /// D-pad handler used by buttons (submit, google, link) — same Up/Down
  /// routing as fields; wide layout also uses Right → keyboard.
  KeyEventResult? _buttonKeyIntercept(
    FocusNode node,
    KeyEvent ev,
    FocusNode self,
  ) {
    if (ev is! KeyDownEvent) return null;
    if (ev.logicalKey == LogicalKeyboardKey.arrowRight &&
        _useTvPad &&
        _tvKeyboardAside &&
        _firstKbdFocus != null) {
      _firstKbdFocus!.requestFocus();
      return KeyEventResult.handled;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveDown(self);
      return KeyEventResult.handled;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveUp(self);
      return KeyEventResult.handled;
    }
    return null;
  }

  // ── D-pad routing helpers ───────────────────────────────────────

  /// Move focus to the next logical node, skipping confirm-password
  /// when we're in Sign in mode.
  void _moveDown(FocusNode current) {
    final isRegister = _mode == NsAuthMode.register;
    if (current == _signInTabFocus || current == _registerTabFocus) {
      _emailFocus.requestFocus();
    } else if (current == _emailFocus) {
      _passFocus.requestFocus();
    } else if (current == _passFocus) {
      if (isRegister) {
        _confirmFocus.requestFocus();
      } else {
        _submitFocus.requestFocus();
      }
    } else if (current == _confirmFocus) {
      _submitFocus.requestFocus();
    } else if (current == _submitFocus) {
      _googleFocus.requestFocus();
    } else if (current == _googleFocus) {
      _linkFocus.requestFocus();
    } else if (current == _linkFocus) {
      // Stacked (narrow) layout: Down reaches the keyboard. Wide layout: user
      // normally presses Right; we still handle Down so remotes that only
      // emit Down still work.
      if (_useTvPad && _firstKbdFocus != null) {
        _firstKbdFocus!.requestFocus();
      }
    }
  }

  void _moveUp(FocusNode current) {
    final isRegister = _mode == NsAuthMode.register;
    if (_useTvPad &&
        _firstKbdFocus != null &&
        current == _firstKbdFocus) {
      _linkFocus.requestFocus();
      return;
    }
    if (current == _emailFocus) {
      _signInTabFocus.requestFocus();
    } else if (current == _passFocus) {
      _emailFocus.requestFocus();
    } else if (current == _confirmFocus) {
      _passFocus.requestFocus();
    } else if (current == _submitFocus) {
      if (isRegister) {
        _confirmFocus.requestFocus();
      } else {
        _passFocus.requestFocus();
      }
    } else if (current == _googleFocus) {
      _submitFocus.requestFocus();
    } else if (current == _linkFocus) {
      _googleFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The Account page (and much of settings) uses a primary vertical
    // [ListView]. On Android, [SingleChildScrollView] with no controller
    // defaults to `primary` and reuses [PrimaryScrollController] from
    // [MaterialApp] — the *same* [ScrollPosition] as that list. The fused
    // auth + TV keyboard then inherits the list’s large scroll offset, so
    // the key grid is laid out above the viewport and only the fixed OSK
    // header is visible. [PrimaryScrollController.none] stops inheritance
    // for this entire modal subtree (see Flutter’s single_child_scroll_view.dart).
    return PrimaryScrollController.none(
      child: NsFocusAccentScope(
        enabled: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).pop(false),
          },
          child: Material(
          type: MaterialType.transparency,
          // [Center] loosens constraints to infinity — a [LayoutBuilder] under
          // Center+Padding never sees the real viewport height. We used to fall
          // back to `MediaQuery.size * 0.88` and `.clamp(320, 900)`, which often
          // made the fused card *taller* than the visible area. The route then
          // clipped the bottom: only the OSK header (top of the keyboard pane)
          // stayed on-screen and the key grid looked “missing”.
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, safeConstraints) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    // `FocusTraversalGroup(OrderedTraversalPolicy)` with explicit
                    // `FocusTraversalOrder` values ensures the Tab / arrow-key
                    // sequence is top-to-bottom regardless of widget build order.
                    // (Individual NsFocusable / TextField onKeyIntercept still
                    // routes D-pad Up/Down for fine-grained control.)
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: _useTvPad
                          ? Builder(
                              builder: (context) {
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
                                final targetH = (boxMaxH * 0.92)
                                    .clamp(200.0, 900.0);
                                final h = math.min(targetH, boxMaxH);
                                final w = math.min(1100.0, boxMaxW);
                                return ConstrainedBox(
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
                                      child: _buildTvWideCard(
                                        shellWidth: w,
                                        shellHeight: h,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 420),
                              child: _buildCard(),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final isRegister = _mode == NsAuthMode.register;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NsColors.line2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            offset: Offset(0, 18),
            blurRadius: 42,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Head(mode: _mode),
                  const SizedBox(height: 12),
                  _ModeSwitch(
                    mode: _mode,
                    signInFocus: _signInTabFocus,
                    registerFocus: _registerTabFocus,
                    onChanged: (m) {
                      setState(() {
                        _mode = m;
                        _error = null;
                      });
                    },
                    onKeyIntercept: _moduleSwitchKeyIntercept,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 10),
                  ],
                  _Field(
                    controller: _emailCtrl,
                    node: _emailFocus,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _passFocus.requestFocus(),
                    onKeyIntercept: (node, ev) =>
                        _fieldKeyIntercept(node, ev, _emailFocus),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _passCtrl,
                    node: _passFocus,
                    label: 'Password',
                    obscure: true,
                    onSubmitted: (_) {
                      if (isRegister) {
                        _confirmFocus.requestFocus();
                      } else {
                        _submit();
                      }
                    },
                    onKeyIntercept: (node, ev) =>
                        _fieldKeyIntercept(node, ev, _passFocus),
                  ),
                  if (isRegister) ...[
                    const SizedBox(height: 8),
                    _Field(
                      controller: _confirmCtrl,
                      node: _confirmFocus,
                      label: 'Confirm password',
                      obscure: true,
                      onSubmitted: (_) => _submit(),
                      onKeyIntercept: (node, ev) =>
                          _fieldKeyIntercept(node, ev, _confirmFocus),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _PrimaryCta(
                    label: isRegister ? 'Create account' : 'Sign in',
                    loading: _loading,
                    focusNode: _submitFocus,
                    onPressed: _loading ? null : () => _submit(),
                    onKeyIntercept: (n, ev) =>
                        _buttonKeyIntercept(n, ev, _submitFocus),
                  ),
                  const SizedBox(height: 8),
                  _GoogleCta(
                    loading: _googleLoading,
                    focusNode: _googleFocus,
                    onPressed: _googleLoading ? null : _googleSignIn,
                    onKeyIntercept: (n, ev) =>
                        _buttonKeyIntercept(n, ev, _googleFocus),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: _LinkButton(
                      label: isRegister
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Create one",
                      focusNode: _linkFocus,
                      onPressed: () {
                        setState(() {
                          _mode = isRegister
                              ? NsAuthMode.signIn
                              : NsAuthMode.register;
                          _error = null;
                        });
                      },
                      onKeyIntercept: (n, ev) =>
                          _buttonKeyIntercept(n, ev, _linkFocus),
                    ),
                  ),
                ],
              ),
            ),
            // Close (×) at the top-right.
            Positioned(
              top: 10,
              right: 10,
              child: _CloseButton(
                focusNode: _closeFocus,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single fused card — form | keyboard — matching Wide HTML reference.
  ///
  /// [shellWidth] / [shellHeight] must be explicit: the outer [Stack] sizes to
  /// its non-positioned child only; relying on [LayoutBuilder] + flex inside a
  /// loose [Stack] left the keyboard body at 0px height on some TV devices.
  Widget _buildTvWideCard({
    required double shellWidth,
    required double shellHeight,
  }) {
    final isRegister = _mode == NsAuthMode.register;
    // All stack children [Positioned]: size becomes [constraints.biggest] and
    // matches the parent [SizedBox]. A non-positioned shell let the stack
    // shrink to the shell’s intrinsic size, which broke the keyboard pane on TV.
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Head(mode: _mode),
                const SizedBox(height: 12),
                _ModeSwitch(
                  mode: _mode,
                  signInFocus: _signInTabFocus,
                  registerFocus: _registerTabFocus,
                  onChanged: (m) {
                    setState(() {
                      _mode = m;
                      _error = null;
                    });
                  },
                  onKeyIntercept: _moduleSwitchKeyIntercept,
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 10),
                ],
                _Field(
                  controller: _emailCtrl,
                  node: _emailFocus,
                  label: 'Email',
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _passFocus.requestFocus(),
                  onKeyIntercept: (node, ev) =>
                      _fieldKeyIntercept(node, ev, _emailFocus),
                ),
                const SizedBox(height: 8),
                _Field(
                  controller: _passCtrl,
                  node: _passFocus,
                  label: 'Password',
                  obscure: _passObscured,
                  readOnly: true,
                  onSubmitted: (_) {
                    if (isRegister) {
                      _confirmFocus.requestFocus();
                    } else {
                      _submit();
                    }
                  },
                  onKeyIntercept: (node, ev) =>
                      _fieldKeyIntercept(node, ev, _passFocus),
                ),
                if (isRegister) ...[
                  const SizedBox(height: 8),
                  _Field(
                    controller: _confirmCtrl,
                    node: _confirmFocus,
                    label: 'Confirm password',
                    obscure: _confirmObscured,
                    readOnly: true,
                    onSubmitted: (_) => _submit(),
                    onKeyIntercept: (node, ev) =>
                        _fieldKeyIntercept(node, ev, _confirmFocus),
                  ),
                ],
                const SizedBox(height: 14),
                _PrimaryCta(
                  label: isRegister ? 'Create account' : 'Sign in',
                  loading: _loading,
                  focusNode: _submitFocus,
                  onPressed: _loading ? null : () => _submit(),
                  onKeyIntercept: (n, ev) =>
                      _buttonKeyIntercept(n, ev, _submitFocus),
                ),
                const SizedBox(height: 8),
                _GoogleCta(
                  loading: _googleLoading,
                  focusNode: _googleFocus,
                  onPressed: _googleLoading ? null : _googleSignIn,
                  onKeyIntercept: (n, ev) =>
                      _buttonKeyIntercept(n, ev, _googleFocus),
                ),
                const SizedBox(height: 10),
                Center(
                  child: _LinkButton(
                    label: isRegister
                        ? 'Already have an account? Sign in'
                        : "Don't have an account? Create one",
                    focusNode: _linkFocus,
                    onPressed: () {
                      setState(() {
                        _mode = isRegister
                            ? NsAuthMode.signIn
                            : NsAuthMode.register;
                        _error = null;
                      });
                    },
                    onKeyIntercept: (n, ev) =>
                        _buttonKeyIntercept(n, ev, _linkFocus),
                  ),
                ),
              ],
            ),
          ),
          keyboard: NsAuthTvKeyboard(
            activeFieldLabel: _tvActiveLabel,
            linkFocus: _linkFocus,
            onInsert: _tvInsert,
            onBackspace: _tvBackspace,
            onClearField: _tvClearField,
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
        Positioned(
          top: 10,
          right: 10,
          child: _CloseButton(
            focusNode: _closeFocus,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────

class _Head extends StatelessWidget {
  const _Head({required this.mode});
  final NsAuthMode mode;
  @override
  Widget build(BuildContext context) {
    final title =
        mode == NsAuthMode.signIn ? 'Sign in to TVMate' : 'Create your account';
    final subtitle = mode == NsAuthMode.signIn
        ? 'Access your subscription, channels and devices.'
        : 'Keep your subscription after the free trial ends.';
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NsColors.accentSoft,
            border: Border.all(color: NsColors.accentLine),
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                color: NsColors.accentGlow,
                offset: Offset(0, 5),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(
            mode == NsAuthMode.signIn
                ? Icons.login_rounded
                : Icons.person_add_rounded,
            color: NsColors.accent,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: NsColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  height: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: NsColors.text3,
                  fontSize: 11,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.signInFocus,
    required this.registerFocus,
    required this.onChanged,
    required this.onKeyIntercept,
  });
  final NsAuthMode mode;
  final FocusNode signInFocus;
  final FocusNode registerFocus;
  final ValueChanged<NsAuthMode> onChanged;
  final KeyEventResult? Function(FocusNode, KeyEvent) onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: NsColors.bg2,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _seg(
              'Sign in',
              mode == NsAuthMode.signIn,
              signInFocus,
              () => onChanged(NsAuthMode.signIn),
            ),
            _seg(
              'Create account',
              mode == NsAuthMode.register,
              registerFocus,
              () => onChanged(NsAuthMode.register),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(
    String label,
    bool active,
    FocusNode node,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: NsFocusable(
        focusNode: node,
        focusAccentRadius: 8,
        onActivate: onTap,
        onKeyIntercept: onKeyIntercept,
        semanticLabel: label,
        builder: (context, focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: NsEase.ease,
          decoration: BoxDecoration(
            color: active
                ? NsColors.accent
                : (focused ? NsColors.surface2 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active
                  ? const Color(0xFF001317)
                  : (focused ? NsColors.text : NsColors.text2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.15,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: NsColors.dangerSoft,
        border: Border.all(color: NsColors.danger),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: NsColors.danger,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: NsColors.danger,
                fontSize: 11,
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
}

class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.node,
    required this.label,
    this.obscure = false,
    this.readOnly = false,
    this.keyboardType,
    this.onSubmitted,
    this.onKeyIntercept,
  });
  final TextEditingController controller;
  final FocusNode node;
  final String label;
  final bool obscure;
  final bool readOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final KeyEventResult? Function(FocusNode, KeyEvent)? onKeyIntercept;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.node.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    final now = widget.node.hasFocus;
    if (_focused != now) setState(() => _focused = now);
  }

  @override
  Widget build(BuildContext context) {
    // Do NOT wrap [TextField] in [Focus] with the same [focusNode] — two
    // widgets must not attach one [FocusNode] (debug assert / crash).
    // [CallbackShortcuts] runs before the field consumes arrow keys.
    KeyDownEvent synthArrowKey(LogicalKeyboardKey logical) {
      final PhysicalKeyboardKey physical;
      if (logical == LogicalKeyboardKey.arrowDown) {
        physical = PhysicalKeyboardKey.arrowDown;
      } else if (logical == LogicalKeyboardKey.arrowUp) {
        physical = PhysicalKeyboardKey.arrowUp;
      } else if (logical == LogicalKeyboardKey.arrowRight) {
        physical = PhysicalKeyboardKey.arrowRight;
      } else {
        physical = PhysicalKeyboardKey.arrowDown;
      }
      return KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      );
    }

    void dispatchArrow(LogicalKeyboardKey k) {
      final intercept = widget.onKeyIntercept;
      if (intercept == null) return;
      intercept(widget.node, synthArrowKey(k));
    }

    return FocusTraversalOrder(
      order: NumericFocusOrder(_orderForLabel(widget.label)),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              dispatchArrow(LogicalKeyboardKey.arrowDown),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              dispatchArrow(LogicalKeyboardKey.arrowUp),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              dispatchArrow(LogicalKeyboardKey.arrowRight),
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 40,
          decoration: BoxDecoration(
            color: _focused ? NsColors.surface2 : NsColors.bg2,
            border: Border.all(
              color: _focused ? NsColors.accentLine : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: NsColors.accentSoft,
                      spreadRadius: 3,
                      blurRadius: 0,
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.node,
                  readOnly: widget.readOnly,
                  obscureText: widget.obscure,
                  keyboardType: widget.readOnly
                      ? TextInputType.none
                      : widget.keyboardType,
                  enableInteractiveSelection: !widget.readOnly,
                  textInputAction: widget.onSubmitted != null
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: widget.onSubmitted,
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                  cursorColor: NsColors.accent,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.label,
                    hintStyle: const TextStyle(
                      color: NsColors.text3,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stable top-down ordering for `FocusTraversalOrder` — email = 2,
  /// password = 3, confirm = 4. (Mode switch is 1.)
  double _orderForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('email')) return 2;
    if (l.contains('confirm')) return 4;
    if (l.contains('password')) return 3;
    return 5;
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.loading,
    required this.focusNode,
    required this.onPressed,
    required this.onKeyIntercept,
  });
  final String label;
  final bool loading;
  final FocusNode focusNode;
  final VoidCallback? onPressed;
  final KeyEventResult? Function(FocusNode, KeyEvent) onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(10),
      child: NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed ?? () {},
      onKeyIntercept: onKeyIntercept,
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: NsEase.ease,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6BE3F0), NsColors.accent],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            const BoxShadow(
              color: NsColors.accentGlow,
              offset: Offset(0, 7),
              blurRadius: 18,
            ),
            if (focused)
              const BoxShadow(
                color: NsColors.accentSoft,
                spreadRadius: 3,
                blurRadius: 0,
              ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF001317),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF001317),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.05,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
        ),
      ),
      ),
    );
  }
}

class _GoogleCta extends StatelessWidget {
  const _GoogleCta({
    required this.loading,
    required this.focusNode,
    required this.onPressed,
    required this.onKeyIntercept,
  });
  final bool loading;
  final FocusNode focusNode;
  final VoidCallback? onPressed;
  final KeyEventResult? Function(FocusNode, KeyEvent) onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(11),
      child: NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed ?? () {},
      onKeyIntercept: onKeyIntercept,
      semanticLabel: 'Sign in with Google',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        height: 38,
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NsColors.text2,
                  ),
                )
              else
                const Icon(
                  Icons.g_mobiledata_rounded,
                  size: 18,
                  color: NsColors.text2,
                ),
              const SizedBox(width: 7),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  color: NsColors.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.focusNode,
    required this.onPressed,
    required this.onKeyIntercept,
  });
  final String label;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final KeyEventResult? Function(FocusNode, KeyEvent) onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(12),
      child: NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onKeyIntercept: onKeyIntercept,
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: focused ? NsColors.accent : NsColors.text3,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.focusNode, required this.onPressed});
  final FocusNode focusNode;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      focusAccentRadius: 7,
      onActivate: onPressed,
      semanticLabel: 'Close',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? NsColors.surface : NsColors.surface2,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 14,
          color: focused ? NsColors.text : NsColors.text3,
        ),
      ),
    );
  }
}

/// Tiny ghost button used where `NsButton` would be overkill.
class NsGhostPill extends StatelessWidget {
  const NsGhostPill({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return NsButton(label: label, onPressed: onPressed);
  }
}
