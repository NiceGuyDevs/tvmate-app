import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/library_controller.dart';
import '../ui/focus/tv_focusable.dart';
import 'account_api.dart';
import 'account_store.dart';
import 'device_limit_dialog.dart';
import 'tv_field.dart';

/// TV-friendly login screen — compact layout with D-pad keyboard support.
class LoginScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onRegister;
  const LoginScreen({super.key, required this.onSuccess, required this.onRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _signInFocus = FocusNode();
  final _googleFocus = FocusNode();
  final _registerFocus = FocusNode();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scheduleRequestFocusWhenReady(_emailFocus);
    });
  }

  Future<void> _submit({String? removeDeviceId}) async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await accountApi.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        deviceId: accountStore.deviceId,
        removeDeviceId: removeDeviceId,
      );
      await accountStore.saveTokens(res['accessToken'] as String, res['refreshToken'] as String);
      if (res['user'] != null) await accountStore.saveUser(res['user'] as Map<String, dynamic>);
      await libraryController.tagUntaggedPlaylistsForCurrentUser();
      await libraryController.refreshVisibility();
      libraryController.pullAdminPlaylists().then((_) => libraryController.startPeriodicSync());
      widget.onSuccess();
    } on ApiException catch (e) {
      if (e.code == 'MAX_DEVICES' && e.data != null && mounted) {
        final devices = (e.data!['devices'] as List?) ?? const <dynamic>[];
        final limit = (e.data!['deviceLimit'] as num?)?.toInt() ?? 5;
        if (mounted) setState(() { _loading = false; });
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
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = 'Connection error. Please try again.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      final gsi = GoogleSignIn(scopes: ['email']);
      final account = await gsi.signIn();
      if (account == null) {
        if (mounted) setState(() { _googleLoading = false; });
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) setState(() { _error = 'Google sign-in failed: no ID token'; _googleLoading = false; });
        return;
      }
      await _completeGoogleSignIn(idToken);
    } catch (e) {
      setState(() { _error = 'Google sign-in failed. Please try again.'; });
    } finally {
      if (mounted) setState(() { _googleLoading = false; });
    }
  }

  Future<void> _completeGoogleSignIn(String idToken, {String? removeDeviceId}) async {
    try {
      final res = await accountApi.googleLogin(
        idToken,
        deviceId: accountStore.deviceId,
        removeDeviceId: removeDeviceId,
      );
      await accountStore.saveTokens(res['accessToken'] as String, res['refreshToken'] as String);
      if (res['user'] != null) await accountStore.saveUser(res['user'] as Map<String, dynamic>);
      await libraryController.tagUntaggedPlaylistsForCurrentUser();
      await libraryController.refreshVisibility();
      libraryController.pullAdminPlaylists().then((_) => libraryController.startPeriodicSync());
      widget.onSuccess();
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
      setState(() { _error = e.message; });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _signInFocus.dispose();
    _googleFocus.dispose();
    _registerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/splash_logo.png',
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Sign in to TVMate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                    ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: TvField(
                      controller: _emailCtrl,
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      focusNode: _emailFocus,
                      textInputAction: TextInputAction.next,
                      nextFocus: _passFocus,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TvField(
                      controller: _passCtrl,
                      hint: 'Password',
                      obscure: true,
                      focusNode: _passFocus,
                      textInputAction: TextInputAction.done,
                      nextFocus: _signInFocus,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        focusNode: _signInFocus,
                        onPressed: _loading ? null : () => _submit(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        focusNode: _googleFocus,
                        onPressed: _googleLoading ? null : _googleSignIn,
                        icon: _googleLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Image.asset('assets/images/google_logo.png', height: 18,
                                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 20)),
                        label: const Text('Sign in with Google', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(5),
                    child: TextButton(
                      focusNode: _registerFocus,
                      onPressed: widget.onRegister,
                      child: const Text("Don't have an account? Create one", style: TextStyle(color: Color(0xFF818CF8), fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
