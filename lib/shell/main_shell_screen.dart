import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../account/access_gate.dart';
import '../account/account_api.dart';
import '../account/account_overlay.dart';
import '../account/account_store.dart';
import '../account/paywall_screen.dart';
import '../data/app_session_restore_store.dart';
import '../data/top_menu_store.dart';
import '../player/player_session_restore_marker.dart';
import 'live_tv_session_snapshot.dart';
import '../ui/live_tv/live_preview_channel.dart';
import '../ui/live_tv/live_tv_favorites_screen.dart';
import '../ui/live_tv/live_tv_screen.dart';
import '../ui/movies/movies_screen.dart';
import '../ui/recording/recording_screen.dart';
import '../ui/series/series_screen.dart';
import '../ui/settings/backup_screen.dart';
import '../ui/settings/clock_settings_screen.dart';
import '../ui/settings/edit_settings_screen.dart';
import '../ui/settings/language_settings_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/new_settings/new_settings_screen.dart';
import '../ui/team/team_screen.dart';
import 'app_top_bar.dart';
import '../theme/team_palette_theme.dart';
import 'team_shell_backdrop.dart';
import 'navigation_policy.dart';
import 'shell_back_coordinator.dart';
import 'shell_content_focus_registry.dart';
import 'shell_destination.dart';
import 'shell_navigation_hub.dart';

/// Main Android TV shell: top nav + full-width underline + content.
class MainShellScreen extends StatefulWidget {
  /// Optional override for the shell's starting destination. When `null`
  /// (default), the session-restore store decides. Used e.g. by the "View
  /// Account" button on the trial-expired kicked screen to land the user
  /// directly on New Settings → Account.
  final ShellDestination? initialDestination;

  const MainShellScreen({super.key, this.initialDestination});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  late ShellDestination _destination;

  /// True after Back from a root browse screen: focus primary menu.
  var _menuOpenedFromBack = false;

  /// While [_menuOpenedFromBack], first Back arms exit; second Back closes the app.
  var _shellBackPressTowardExit = 0;

  late final Map<ShellDestination, FocusNode> _topNavFocus;

  /// Top bar: hero preview mute (before Live TV tab); only used while [LiveTvScreen] is shown.
  late final FocusNode _liveHeroMuteNavFocus;

  Timer? _accessCheckTimer;
  bool _showPaywall = false;
  // Sticky: once the user dismisses the inline paywall, the periodic access
  // check must not auto-resurface it. Reset only when subscription becomes
  // valid again (so a future expiry can show it once more).
  bool _paywallDismissed = false;

  void _goTo(ShellDestination d) {
    // The top bar only exposes [newSettings] as **Settings**; treat legacy
    // [settings] the same so any older call sites open the new surface.
    final dest =
        d == ShellDestination.settings ? ShellDestination.newSettings : d;
    // Optional items without a full screen body open a pushed route instead.
    if (!dest.hasOwnScreen && dest != ShellDestination.playlist) {
      _openActionDestination(dest);
      return;
    }
    setState(() {
      _destination = dest;
      _menuOpenedFromBack = false;
      _shellBackPressTowardExit = 0;
    });
    _persistSessionSnapshot();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShellContentFocusRegistry.request(dest);
    });
  }

  void _openActionDestination(ShellDestination d) {
    final Widget? screen = switch (d) {
      ShellDestination.clock => ClockSettingsScreen(),
      ShellDestination.appearance => EditSettingsScreen(),
      ShellDestination.backup => const BackupScreen(),
      ShellDestination.favorites => const LiveTvFavoritesScreen(),
      ShellDestination.language => const LanguageSettingsScreen(),
      _ => null,
    };
    if (screen == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _stopPreviewAndExit() async {
    try {
      if (LivePreviewChannel.supported) {
        await LivePreviewChannel.dispose();
      }
    } catch (_) {}
    if (!mounted) return;
    SystemNavigator.pop();
  }

  void _onSystemBack() {
    // Pushed routes (details, player, etc.) handle Back first; this runs for
    // shell root only.
    //
    // Navigation policy (see documentation/tv-remote-navigation-spec.md §2):
    //  • Focus on top bar, launch tab → double Back → exit app.
    //  • Focus on top bar, other tab  → double Back → go to launch browse.
    //  • Focus on content              → let browse screen consume, then top bar.
    if (_menuOpenedFromBack) {
      _shellBackPressTowardExit++;
      if (_shellBackPressTowardExit >= 2) {
        final action = NavigationPolicy.shellDoubleBack(_destination);
        switch (action) {
          case ShellBackAction.exitApp:
            unawaited(_stopPreviewAndExit());
          case ShellBackAction.goHome:
            _shellBackPressTowardExit = 0;
            _goTo(NavigationPolicy.launchTab);
        }
        return;
      }
      return;
    }
    if (ShellBackCoordinator.tryConsumeBack()) {
      return;
    }
    _shellBackPressTowardExit = 0;
    setState(() => _menuOpenedFromBack = true);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _topNavFocus[_destination];
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  void _persistSessionSnapshot() {
    unawaited(
      AppSessionRestoreStore.instance.persistSession(
        shellDestination: _destination,
        liveCategoryId: LiveTvSessionSnapshot.categoryId,
        liveChannelId: LiveTvSessionSnapshot.channelId,
        liveFullscreen: PlayerSessionRestoreMarker.livePlayerOpen,
        vodFullscreen: PlayerSessionRestoreMarker.vodPlayerOpen,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _destination = widget.initialDestination ??
        AppSessionRestoreStore.instance.initialShellDestination(
          topMenuStore.fullMenu,
          topMenuStore.startup,
        );
    _topNavFocus = {
      for (final d in ShellDestination.values)
        d: FocusNode(debugLabel: 'topNav_${d.name}'),
    };
    _liveHeroMuteNavFocus =
        FocusNode(debugLabel: 'topNav_liveHeroMute');
    for (final n in _topNavFocus.values) {
      n.addListener(_onAnyTopNavFocusChanged);
    }
    _liveHeroMuteNavFocus.addListener(_onAnyTopNavFocusChanged);
    ShellContentFocusRegistry.registerTopNavFocus(_topNavFocus);
    ShellContentFocusRegistry.registerLiveHeroMuteNavFocus(_liveHeroMuteNavFocus);
    ShellNavigationHub.instance.bind(_goTo);
    topMenuStore.addListener(_onMenuChanged);
    // Instant ban/suspend detection from any API call
    accountApi.onBannedOrSuspended = _onBannedOrSuspended;
    _accessCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) => _recheckAccess());
    _recheckAccess();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ShellContentFocusRegistry.request(_destination);
      });
    });
  }

  void _onMenuChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// After Back moved focus to the top bar, clear the "menu from back" state when
  /// focus returns to content (e.g. D-pad Down) so Back again runs browse handlers.
  void _onAnyTopNavFocusChanged() {
    if (!mounted) return;
    final anyFocused = _topNavFocus.values.any((n) => n.hasFocus) ||
        _liveHeroMuteNavFocus.hasFocus;
    if (!anyFocused && _menuOpenedFromBack) {
      setState(() {
        _menuOpenedFromBack = false;
        _shellBackPressTowardExit = 0;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistSessionSnapshot();
    }
  }

  Future<void> _recheckAccess() async {
    try {
      final result = await accessGate.check();
      if (!mounted) return;

      // Hard block: bans and suspensions only (not NO_TOKEN — guest may use the app).
      final r = result.reason;
      if (!result.allowed &&
          (r.contains('BANNED') || r.contains('SUSPENDED'))) {
        _accessCheckTimer?.cancel();
        await accountStore.clearAuth();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => _KickedScreen(reason: result.reason),
          ),
          (_) => false,
        );
        return;
      }

      // Soft block: needs subscription (trial/sub expired). The backend tells
      // us via needsSubscription — this fires for both logged-in users whose
      // subscription expired AND guests on devices whose trial was consumed
      // (e.g. previously used by an account that has since signed out).
      final showWall = result.needsSubscription;
      if (showWall) {
        // Only auto-show if the user hasn't dismissed it for this session.
        if (!_showPaywall && !_paywallDismissed) {
          if (!mounted) return;
          setState(() { _showPaywall = true; });
        }
      } else {
        // Subscription is valid again: arm overlay for any future expiry.
        if (_showPaywall || _paywallDismissed) {
          if (!mounted) return;
          setState(() {
            _showPaywall = false;
            _paywallDismissed = false;
          });
        }
      }
    } catch (_) {}
  }

  /// Triggered instantly by any API call that receives a 403 banned/suspended.
  void _onBannedOrSuspended(String reason) {
    if (!mounted) return;
    _accessCheckTimer?.cancel();
    accountStore.clearAuth().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => _KickedScreen(reason: reason),
        ),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _accessCheckTimer?.cancel();
    accountApi.onBannedOrSuspended = null;
    WidgetsBinding.instance.removeObserver(this);
    topMenuStore.removeListener(_onMenuChanged);
    ShellNavigationHub.instance.unbind();
    ShellContentFocusRegistry.unregisterTopNavFocus();
    _liveHeroMuteNavFocus.removeListener(_onAnyTopNavFocusChanged);
    _liveHeroMuteNavFocus.dispose();
    for (final n in _topNavFocus.values) {
      n.removeListener(_onAnyTopNavFocusChanged);
      n.dispose();
    }
    super.dispose();
  }

  Widget _buildDestinationBody() {
    return switch (_destination) {
      ShellDestination.liveTv => const LiveTvScreen(),
      ShellDestination.movies => const MoviesScreen(),
      ShellDestination.series => const SeriesScreen(),
      ShellDestination.recording => const RecordingScreen(),
      ShellDestination.team => const TeamScreen(),
      ShellDestination.settings => const SettingsScreen(),
      ShellDestination.newSettings => const NewSettingsScreen(),
      // Optional items that don't have a full screen body show Settings.
      // Their top-bar tap opens a popup/action instead (handled in AppTopBar).
      _ => const SettingsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.teamPalette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onSystemBack();
      },
      // Suppress the freemium paywall when the user is on the new-settings
      // surface. Sign out from the new Account page would otherwise pop
      // the old paywall on top of our new guest view. The paywall still
      // fires for everything else (Live TV, movies, series, playback
      // attempts via `player_navigation`) — only the new-settings tab is
      // exempt so the user can manage / switch accounts without the
      // upsell scrim covering their HTML-styled surface.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(
          builder: (context) {
            final inNewSettings =
                _destination == ShellDestination.newSettings;
            final visiblePaywall = _showPaywall && !inNewSettings;
            return Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: TeamShellBackdrop()),
                // Block focus + pointer on the underlying shell while the inline
                // paywall overlay is visible so D-pad / clicks cannot leak through
                // to the buttons behind the dim scrim.
                ExcludeFocus(
                  excluding: visiblePaywall,
                  child: AbsorbPointer(
                    absorbing: visiblePaywall,
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FocusTraversalOrder(
                            order: NumericFocusOrder(0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTopBar(
                                  selected: _destination,
                                  onSelect: _goTo,
                                  navFocusByDestination: _topNavFocus,
                                  liveHeroMuteNavFocus: _liveHeroMuteNavFocus,
                                ),
                                Container(
                                  height: 2.25,
                                  width: double.infinity,
                                  color: chrome.neonLine
                                      .withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: FocusTraversalOrder(
                              order: NumericFocusOrder(1),
                              child: ColoredBox(
                                color: Colors.transparent,
                                child: FocusTraversalGroup(
                                  child: _buildDestinationBody(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (visiblePaywall)
                  _PaywallOverlay(
                    onDismiss: () {
                      if (!mounted) return;
                      setState(() {
                        _showPaywall = false;
                        _paywallDismissed = true;
                      });
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaywallOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const _PaywallOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.escape ||
              k == LogicalKeyboardKey.goBack ||
              k == LogicalKeyboardKey.browserBack) {
            onDismiss();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          // Opaque scrim swallows any pointer event that misses the buttons
          // so taps cannot reach the underlying shell.
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            color: Colors.black.withOpacity(0.92),
            child: FocusScope(
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
          ),
        ),
      ),
    );
  }
}

class _KickedScreen extends StatelessWidget {
  final String reason;
  const _KickedScreen({required this.reason});

  @override
  Widget build(BuildContext context) {
    final isExpired = reason == 'TRIAL_EXPIRED';
    final isSuspended = reason.contains('SUSPENDED');
    final isBanned = reason.contains('BANNED');
    final isDevice = reason.contains('DEVICE');

    final String title;
    final String subtitle;
    final IconData icon;
    final Color iconColor;
    final Color bgColor;

    if (isBanned) {
      title = isDevice ? 'Device Banned' : 'Account Banned';
      subtitle = isDevice
          ? 'This device has been permanently banned.'
          : 'This account has been permanently banned.';
      icon = Icons.gpp_bad_rounded;
      iconColor = Colors.red;
      bgColor = const Color(0xFF1A0000);
    } else if (isSuspended) {
      title = isDevice ? 'Device Suspended' : 'Account Suspended';
      subtitle = isDevice
          ? 'This device has been temporarily suspended.'
          : 'Your access has been temporarily suspended.';
      icon = Icons.pause_circle_filled_rounded;
      iconColor = Colors.amber;
      bgColor = Colors.black;
    } else if (isExpired) {
      title = 'Subscription Ended';
      subtitle = 'Your trial or subscription has expired.\nPlease renew to continue watching.';
      icon = Icons.timer_off_rounded;
      iconColor = const Color(0xFF818CF8);
      bgColor = Colors.black;
    } else {
      title = 'Access Denied';
      subtitle = 'You no longer have access.\nPlease renew your subscription or contact support.';
      icon = Icons.lock_rounded;
      iconColor = Colors.white54;
      bgColor = Colors.black;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBanned) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withAlpha(30),
                    border: Border.all(color: Colors.red.withAlpha(80), width: 2),
                  ),
                  child: const Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 56),
                ),
              ] else
                Icon(icon, color: iconColor, size: 72),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  color: isBanned ? Colors.red : Colors.white,
                  fontSize: isBanned ? 26 : 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
              if (isBanned || isSuspended) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: (isBanned ? Colors.red : Colors.amber).withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isBanned ? Colors.red : Colors.amber).withAlpha(40)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Contact customer support',
                        style: TextStyle(
                          color: isBanned ? Colors.red.shade200 : Colors.amber.shade200,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'support@tvmate.app',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (isExpired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                            builder: (_) => const MainShellScreen(
                              initialDestination: ShellDestination.newSettings,
                            ),
                          ),
                          (_) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('View Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => SystemNavigator.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBanned ? Colors.red.withAlpha(40) : Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close App', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
