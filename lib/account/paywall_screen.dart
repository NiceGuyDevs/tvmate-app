import 'package:flutter/material.dart';

import '../shell/shell_destination.dart';
import '../shell/shell_navigation_hub.dart';
import '../ui/focus/tv_focusable.dart';

/// Full-screen paywall that can be used both as an overlay inside the shell
/// Stack and as a pushed route from anywhere in the app (e.g. movie/series
/// detail screens).
///
/// The in-app pricing/checkout flow has intentionally been removed: subscribing
/// happens on the website or in the Subscription section of the account
/// overlay.
class PaywallScreen extends StatelessWidget {
  final VoidCallback? onDismiss;
  const PaywallScreen({super.key, this.onDismiss});

  /// Push the paywall as a full-screen route on top of the current navigator.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PaywallScreen(
        onDismiss: () => Navigator.of(context).pop(),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.92),
      body: FocusScope(
        autofocus: true,
        child: FocusTraversalGroup(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: PaywallBody(onDismiss: onDismiss),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable paywall content (logo, message, action buttons).
///
/// Used both by [PaywallScreen] (full-screen route) and by the inline overlay
/// inside the main shell, so the message stays consistent.
class PaywallBody extends StatelessWidget {
  final VoidCallback? onDismiss;
  const PaywallBody({super.key, this.onDismiss});

  /// Navigate the user to the New Settings → Account page. Works whether the
  /// paywall is shown inline (shell overlay) or as a pushed route.
  void _openAccount(BuildContext context) {
    // Remove the paywall first: dismiss inline overlay if provided, then pop
    // any pushed routes so we end up at the shell root.
    onDismiss?.call();
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    // Shell defaults to active='account' when opening New Settings.
    ShellNavigationHub.instance.goTo(ShellDestination.newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/splash_logo.png',
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Subscription Required',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'To continue using TVMate Pro, please visit our website '
          'or open the Subscription section in your account to renew '
          'or add a subscription.',
          style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TvFocusable(
          autofocus: true,
          focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          focusScale: 1.0,
          parallaxSlide: 0,
          showFocusElevation: false,
          focusedBorderWidth: 1.4,
          onActivate: () => _openAccount(context),
          child: SizedBox(
            width: 260,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _openAccount(context),
              icon: const Icon(Icons.account_circle_outlined, size: 18),
              label: const Text(
                'View Account',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        if (onDismiss != null) ...[
          const SizedBox(height: 10),
          TvFocusable(
            focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            focusScale: 1.0,
            parallaxSlide: 0,
            showFocusElevation: false,
            focusedBorderWidth: 1.4,
            onActivate: onDismiss,
            child: SizedBox(
              width: 260,
              height: 40,
              child: TextButton(
                onPressed: onDismiss,
                child: const Text(
                  'Browse App',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
