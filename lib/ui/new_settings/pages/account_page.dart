/// Account sub-page — 1:1 port of `renderAccountPage()` in
/// settings.html (line 8461).
///
/// Layout:
///   [sub-page head]   title "Account" + subtitle (email · member
///     since … OR guest · free trial active), actions = Edit profile /
///     Sign out (logged in) or Sign in (guest).
///
///   .acc-hero   avatar + name + email + status pill + time-remaining.
///   .acc-tabs   Profile · Subscription · Devices.
///   .acc body (tab-specific).
library;

import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../data/vod_offline_library.dart';
import '../../../l10n/app_localizations.dart';
import '../../../player/player_navigation.dart';
import '../../../player/vod_download_helpers.dart';
import '../../../ui/widgets/tv_media_urls.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_auth_modal.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_confirm_dialog.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_new_settings_nav.dart';
import '../widgets/ns_sub_page_head.dart';
import '../widgets/ns_subscribe_checkout.dart';
import '../widgets/ns_text_prompt_dialog.dart';

class NsAccountPage extends StatefulWidget {
  const NsAccountPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.profileTabFocus,
    required this.subscriptionTabFocus,
    required this.devicesTabFocus,
    required this.downloadsTabFocus,
    required this.tabStripKey,
    required this.postTabsKey,
  });

  final NewSettingsState state;

  /// Nullable — when Account is rendered as a top-level rail
  /// destination (no push stack below it), pass `null` to hide the
  /// back button from the sub-page head. When Account is pushed from
  /// elsewhere (legacy path), the back button shows and pops the stack.
  final VoidCallback? onBack;

  /// Owned by [NewSettingsScreen] so rail **Right** / [FocusScope] can
  /// hand off into the page (the old in-page [FocusNode] + [initState]
  /// post-frame could never win over the shell rail focus on first open).
  final FocusNode profileTabFocus;
  final FocusNode subscriptionTabFocus;
  final FocusNode devicesTabFocus;
  final FocusNode downloadsTabFocus;

  final GlobalKey tabStripKey;
  final GlobalKey postTabsKey;

  @override
  State<NsAccountPage> createState() => _NsAccountPageState();
}

class _NsAccountPageState extends State<NsAccountPage> {
  /// Downloads tab is Android-only — matches the old
  /// [AndroidOfflineDownloadsScreen]'s platform gate. On every other
  /// platform the tab is omitted entirely (not just disabled).
  bool get _showDownloadsTab => !kIsWeb && Platform.isAndroid;

  /// Sub-page head actions — explicit L/R so D-pad **Left** from
  /// **Sign out** moves to **Edit profile** (not the categories rail).
  late final FocusNode _headEditProfileFocus;
  late final FocusNode _headSignOutFocus;
  late final FocusNode _headSignInFocus;

  NewSettingsState get state => widget.state;
  VoidCallback? get onBack => widget.onBack;

  @override
  void initState() {
    super.initState();
    _headEditProfileFocus = FocusNode(debugLabel: 'ns:acc:head:editProfile');
    _headSignOutFocus = FocusNode(debugLabel: 'ns:acc:head:signOut');
    _headSignInFocus = FocusNode(debugLabel: 'ns:acc:head:signIn');
  }

  @override
  void dispose() {
    _headEditProfileFocus.dispose();
    _headSignOutFocus.dispose();
    _headSignInFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final a = state.account.data;
        final tab = state.account.tab;
        final subtitle = a.isLoggedIn
            ? '${a.email} · Member since ${a.memberSince}'
            : 'Guest · Free trial active';
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Account',
              subtitle: subtitle,
              onBack: onBack,
              // Suppress the default autofocus on the back button —
              // we want the `Profile` tab to claim focus instead so
              // the user lands directly on the page's content.
              autofocusBack: false,
              actions: a.isLoggedIn
                  ? [
                      NsButton(
                        focusNode: _headEditProfileFocus,
                        focusRightNeighbor: _headSignOutFocus,
                        label: 'Edit profile',
                        icon: Icons.edit_rounded,
                        variant: NsButtonVariant.ghost,
                        onPressed: () => _editName(context, a),
                      ),
                      NsButton(
                        focusNode: _headSignOutFocus,
                        focusLeftNeighbor: _headEditProfileFocus,
                        label: 'Sign out',
                        icon: Icons.logout_rounded,
                        variant: NsButtonVariant.danger,
                        onPressed: () => _confirmSignOut(context),
                      ),
                    ]
                  : [
                      NsButton(
                        focusNode: _headSignInFocus,
                        label: 'Sign in',
                        icon: Icons.login_rounded,
                        variant: NsButtonVariant.primary,
                        onPressed: () => _openAuthGate(
                          context,
                          startOnRegister: false,
                        ),
                      ),
                    ],
            ),
            _Hero(account: a),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: widget.tabStripKey,
              child: _Tabs(
                activeTab: tab,
                onPick: state.setAccountTab,
                profileFocus: widget.profileTabFocus,
                subscriptionFocus: widget.subscriptionTabFocus,
                devicesFocus: widget.devicesTabFocus,
                downloadsFocus: widget.downloadsTabFocus,
                showDownloads: _showDownloadsTab,
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: widget.postTabsKey,
              child: tab == 'subscription'
                  ? _SubscriptionTab(state: state)
                  : tab == 'devices'
                      ? _DevicesTab(state: state)
                      : tab == 'downloads' && _showDownloadsTab
                          ? const _DownloadsTab()
                          : _ProfileTab(state: state),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editName(BuildContext context, NsAccount a) async {
    final name = await showNsTextPromptDialog(
      context,
      title: 'Edit display name',
      initial: a.name,
      confirmLabel: 'Save',
      help: 'Up to 50 characters.',
    );
    if (name == null) return;
    try {
      await state.accountRenameSelf(name);
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to update name: $e');
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final r = await showNsConfirmDialog(
      context,
      title: 'Sign out of TVMate?',
      message:
          'You will need to sign in again to access your '
          'subscription, channels and synced settings.',
      confirmLabel: 'Sign out',
      isDanger: true,
    );
    if (r == NsConfirmResult.confirmed && context.mounted) {
      await state.accountSignOut();
    }
  }
}

/// Open the HTML-styled sign in / register modal — stays inside the
/// new-settings surface so the user never sees the old login screens.
/// Under the hood this calls the same `accountApi.login` / `register` /
/// `googleLogin` commands the old [AuthGateScreen] uses.
Future<void> _openAuthGate(
  BuildContext context, {
  required bool startOnRegister,
}) async {
  // Snapshot the state ChangeNotifier off the enclosing page widget so
  // we can reload `/me` + `/devices` after the gate closes without
  // risking a stale BuildContext lookup when sub-dialogs interpose.
  final pageEl = context.findAncestorWidgetOfExactType<NsAccountPage>();
  await showNsAuthModal(
    context,
    initialMode:
        startOnRegister ? NsAuthMode.register : NsAuthMode.signIn,
  );
  // Re-pull /me + /devices whether the user signed in or cancelled —
  // cheap network call, keeps the UI consistent with backend state.
  await pageEl?.state.reloadAccount();
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  Hero card — avatar / name / email / right-side status pill.
// ═══════════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  const _Hero({required this.account});
  final NsAccount account;

  @override
  Widget build(BuildContext context) {
    final remaining = nsAccFormatRemaining(
      account.accessUntil ?? account.trialEndsAt,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NsColors.surface2, NsColors.surface],
        ),
        boxShadow: NsShadow.s1,
      ),
      child: Row(
        children: [
          _Avatar(
            initials: account.isLoggedIn ? account.initials : 'G',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.isLoggedIn ? account.name : 'Guest',
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.12,
                    height: 1.15,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.isLoggedIn
                      ? account.email
                      : 'Sign in to keep your subscription, channels '
                          'and devices in sync across all your TVs.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 9.5,
                    height: 1.35,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPill(
                variant: !account.isLoggedIn
                    ? _StatusVariant.trial
                    : (account.isTrial
                        ? _StatusVariant.trial
                        : _StatusVariant.active),
                label: !account.isLoggedIn
                    ? 'Free trial'
                    : (account.isTrial ? 'Trial' : 'Active'),
              ),
              const SizedBox(height: 2),
              Text(
                remaining,
                style: const TextStyle(
                  color: NsColors.text3,
                  fontSize: 9.5,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NsColors.accent2, NsColors.accent],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: NsColors.accentGlow,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF001017),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

enum _StatusVariant { active, trial, muted }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.variant, required this.label});
  final _StatusVariant variant;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border) = switch (variant) {
      _StatusVariant.active => (
          NsColors.success,
          NsColors.successSoft,
          const Color(0x594ADE80),
        ),
      _StatusVariant.trial => (
          NsColors.warn,
          const Color(0x1AFBBF24),
          const Color(0x59FBBF24),
        ),
      _StatusVariant.muted => (
          NsColors.text3,
          NsColors.bg2,
          NsColors.line,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fg,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Tab switcher.
// ═══════════════════════════════════════════════════════════════════════

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.activeTab,
    required this.onPick,
    required this.profileFocus,
    required this.subscriptionFocus,
    required this.devicesFocus,
    required this.downloadsFocus,
    required this.showDownloads,
  });
  final String activeTab;
  final void Function(String tab) onPick;
  final FocusNode profileFocus;
  final FocusNode subscriptionFocus;
  final FocusNode devicesFocus;
  final FocusNode downloadsFocus;
  final bool showDownloads;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(
          icon: Icons.person_rounded,
          label: 'Profile',
          selected: activeTab == 'profile',
          focusNode: profileFocus,
          onPressed: () => onPick('profile'),
          leftNeighbor: null,
          rightNeighbor: subscriptionFocus,
        ),
        const SizedBox(width: 6),
        _Tab(
          icon: Icons.workspace_premium_rounded,
          label: 'Subscription',
          selected: activeTab == 'subscription',
          focusNode: subscriptionFocus,
          onPressed: () => onPick('subscription'),
          leftNeighbor: profileFocus,
          rightNeighbor: devicesFocus,
        ),
        const SizedBox(width: 6),
        _Tab(
          icon: Icons.live_tv_rounded,
          label: 'Devices',
          selected: activeTab == 'devices',
          focusNode: devicesFocus,
          onPressed: () => onPick('devices'),
          leftNeighbor: subscriptionFocus,
          rightNeighbor: showDownloads ? downloadsFocus : null,
        ),
        if (showDownloads) ...[
          const SizedBox(width: 6),
          _Tab(
            icon: Icons.download_rounded,
            label: 'Downloads',
            selected: activeTab == 'downloads',
            focusNode: downloadsFocus,
            onPressed: () => onPick('downloads'),
            leftNeighbor: devicesFocus,
            rightNeighbor: null,
          ),
        ],
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onPressed,
    required this.leftNeighbor,
    required this.rightNeighbor,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final FocusNode? leftNeighbor;
  final FocusNode? rightNeighbor;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: label,
      onKeyIntercept: (node, event) {
        if (event is! KeyDownEvent) return null;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (leftNeighbor != null) {
            if (leftNeighbor!.canRequestFocus) leftNeighbor!.requestFocus();
            return KeyEventResult.handled;
          }
          // Leftmost tab — exit to the categories rail, not a header row.
          final nav =
              node.context?.findAncestorWidgetOfExactType<NsNewSettingsNav>();
          if (nav != null && nav.railCanRequestFocus) {
            nav.onLeftFromRootMainToRail();
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          if (rightNeighbor != null) {
            if (rightNeighbor!.canRequestFocus) rightNeighbor!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return null;
      },
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? NsColors.accentSoft
              : (focused ? NsColors.surface2 : NsColors.bg2),
          border: Border.all(
            color: selected
                ? NsColors.accentLine
                : (focused ? NsColors.line2 : NsColors.line),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: selected ? NsColors.accent : NsColors.text2,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? NsColors.accent : NsColors.text2,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Profile tab — 2-column grid (Account details | Device access).
// ═══════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.state});
  final NewSettingsState state;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final FocusNode _fGoogle;
  late final FocusNode _fEdit;
  late final FocusNode _fAddDevice;

  @override
  void initState() {
    super.initState();
    _fGoogle = FocusNode(debugLabel: 'ns:profile:google');
    _fEdit = FocusNode(debugLabel: 'ns:profile:editName');
    _fAddDevice = FocusNode(debugLabel: 'ns:profile:addDevice');
  }

  @override
  void dispose() {
    _fGoogle.dispose();
    _fEdit.dispose();
    _fAddDevice.dispose();
    super.dispose();
  }

  NewSettingsState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final a = state.account.data;
    if (!a.isLoggedIn) return _GuestCard(state: state);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lowered from 760 → 520 so Android-TV detail panes (rail eats
        // ~260 px of a 1280-px screen) keep the HTML's side-by-side
        // `Account details | Device access` layout. We only fall back
        // to a stacked column below ~520 px (phone portrait / heavily
        // split-screen scenarios).
        final stacked = constraints.maxWidth < 520;
        final details = _SectionCard(
          title: 'Account details',
          actions: [
            NsButton(
              focusNode: _fGoogle,
              focusRightNeighbor: _fEdit,
              label: a.googleLinked
                  ? 'Google linked'
                  : 'Connect Google',
              icon: Icons.g_mobiledata_rounded,
              variant: NsButtonVariant.primary,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Google link coming soon'),
                  ),
                );
              },
            ),
            NsButton(
              focusNode: _fEdit,
              focusLeftNeighbor: _fGoogle,
              focusRightNeighbor: _fAddDevice,
              label: 'Edit name',
              icon: Icons.edit_rounded,
              onPressed: () => _editName(context),
            ),
          ],
          body: _AccountDetailRows(a: a),
        );
        final devices = _SectionCard(
          title: 'Device access',
          actions: [
            NsButton(
              focusNode: _fAddDevice,
              focusLeftNeighbor: _fEdit,
              label: 'Add device',
              icon: Icons.add_rounded,
              variant: NsButtonVariant.primary,
              onPressed: () => state.setAccountTab('devices'),
            ),
          ],
          body: _DeviceAccess(a: a),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: 8),
              devices,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: details),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: devices),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName(BuildContext context) async {
    final name = await showNsTextPromptDialog(
      context,
      title: 'Edit display name',
      initial: state.account.data.name,
      confirmLabel: 'Save',
      help: 'Up to 50 characters.',
    );
    if (name == null) return;
    try {
      await state.accountRenameSelf(name);
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to update name: $e');
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.actions,
    required this.body,
  });
  final String title;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.06,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: NsColors.surface,
            border: Border.all(color: NsColors.line),
            borderRadius: BorderRadius.circular(10),
            boxShadow: NsShadow.s1,
          ),
          clipBehavior: Clip.antiAlias,
          child: body,
        ),
      ],
    );
  }
}

class _AccountDetailRows extends StatelessWidget {
  const _AccountDetailRows({required this.a});
  final NsAccount a;

  @override
  Widget build(BuildContext context) {
    final remaining = nsAccFormatRemaining(
      a.accessUntil ?? a.trialEndsAt,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DetailRow(label: 'Email address', value: a.email),
        _Div(),
        _DetailRow(label: 'Display name', value: a.name),
        _Div(),
        _DetailRow(label: 'Member since', value: a.memberSince),
        _Div(),
        _DetailRow(label: 'Role', value: a.role),
        _Div(),
        _DetailRow(
          label: 'Account status',
          valueWidget: _StatusPill(
            variant: _StatusVariant.active,
            label: a.status == 'active' ? 'Active' : a.status,
          ),
        ),
        _Div(),
        _DetailRow(
          label: 'Access / trial',
          value: remaining,
          dim: a.isTrial,
        ),
        _Div(),
        _DetailRow(label: 'Device ID', value: a.deviceId, mono: true),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.mono = false,
    this.dim = false,
  });
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool mono;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            // Widget values (e.g. the `_StatusPill` chip) would otherwise
            // stretch to fill the Expanded's width because their outer
            // Container has no explicit size. Aligning them to the right
            // preserves the HTML's "value hugs the right edge" look and
            // keeps the pill's natural size.
            child: valueWidget != null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: valueWidget,
                  )
                : Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: dim ? NsColors.text3 : NsColors.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: mono ? 'monospace' : null,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ],
      ),
    );
  }
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: NsColors.line);
}

class _DeviceAccess extends StatelessWidget {
  const _DeviceAccess({required this.a});
  final NsAccount a;

  @override
  Widget build(BuildContext context) {
    final used = a.devices.length;
    final max = a.deviceLimit;
    final pct = max == 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: NsColors.text2,
                fontSize: 10.5,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
              children: [
                TextSpan(
                  text: '$used',
                  style: const TextStyle(
                    color: NsColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' of '),
                TextSpan(
                  text: '$max',
                  style: const TextStyle(
                    color: NsColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: used == 1 ? ' device' : ' devices',
                ),
                const TextSpan(
                  text: ' registered on your current plan.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$used',
                style: const TextStyle(
                  color: NsColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: NsColors.bg,
                    border: Border.all(color: NsColors.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [NsColors.accent, NsColors.accent2],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$max',
                style: const TextStyle(
                  color: NsColors.text3,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.state});
  final NewSettingsState state;

  @override
  Widget build(BuildContext context) {
    final a = state.account.data;
    final remaining = nsAccFormatRemaining(a.trialEndsAt);
    return _SectionCard(
      title: 'Account details',
      actions: const [],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(
              label: 'Account',
              value: 'Guest (Free trial)',
            ),
            _Div(),
            _DetailRow(
              label: 'Status',
              valueWidget: const _StatusPill(
                variant: _StatusVariant.trial,
                label: 'Trial',
              ),
            ),
            _Div(),
            _DetailRow(
              label: 'Device ID',
              value: a.deviceId,
              mono: true,
            ),
            _Div(),
            _DetailRow(label: 'Time left', value: remaining),
            const SizedBox(height: 14),
            const Text(
              'Create an account to keep your subscription after your '
              'trial ends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NsColors.text3,
                fontSize: 11,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                NsButton(
                  label: 'Sign in',
                  icon: Icons.login_rounded,
                  variant: NsButtonVariant.primary,
                  onPressed: () => _openAuthGate(
                    context,
                    startOnRegister: false,
                  ),
                ),
                NsButton(
                  label: 'Create account',
                  icon: Icons.person_add_rounded,
                  onPressed: () => _openAuthGate(
                    context,
                    startOnRegister: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Subscription tab — hero + duration seg control + plans grid.
// ═══════════════════════════════════════════════════════════════════════

class _SubscriptionTab extends StatefulWidget {
  const _SubscriptionTab({required this.state});
  final NewSettingsState state;

  @override
  State<_SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<_SubscriptionTab> {
  late final List<FocusNode> _durFocus;
  late final List<FocusNode> _planFocus;

  @override
  void initState() {
    super.initState();
    _durFocus = List<FocusNode>.generate(
      kNsAccDurations.length,
      (i) => FocusNode(debugLabel: 'ns:acc:dur:$i'),
    );
    _planFocus = List<FocusNode>.generate(
      kNsAccPlans.length,
      (i) => FocusNode(debugLabel: 'ns:acc:plan:$i'),
    );
  }

  @override
  void dispose() {
    for (final n in _durFocus) {
      n.dispose();
    }
    for (final n in _planFocus) {
      n.dispose();
    }
    super.dispose();
  }

  NewSettingsState get state => widget.state;

  /// HTML `accSubscribe(planId)` port (settings.html line 8932) wired to
  /// the real `accountApi.createCheckout` — same command path as the old
  /// ACC overlay's `_handleSubscribe` → `_showStripeCheckout`. The
  /// HTML-styled checkout modal now fetches the Stripe URL itself and
  /// renders a live QR, so we just need to gate on login here.
  Future<void> _openCheckout(
    BuildContext context,
    NsAccPlan plan,
  ) async {
    final a = state.account.data;
    if (!a.isLoggedIn) {
      final r = await showNsConfirmDialog(
        context,
        title: 'Account required',
        message:
            'You need to sign in or create an account before subscribing '
            'to a plan.',
        confirmLabel: 'Sign in',
      );
      if (r == NsConfirmResult.confirmed && context.mounted) {
        await _openAuthGate(context, startOnRegister: true);
      }
      return;
    }
    final duration = kNsAccDurations.firstWhere(
      (d) => d.id == state.account.selectedDuration,
      orElse: () => kNsAccDurations.first,
    );
    await showNsSubscribeCheckout(
      context,
      plan: plan,
      duration: duration,
      deviceIdSeed: a.deviceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = state.account.data;
    final sel = kNsAccDurations.firstWhere(
      (d) => d.id == state.account.selectedDuration,
      orElse: () => kNsAccDurations.first,
    );
    final selDurI = kNsAccDurations.indexWhere((d) => d.id == sel.id);
    final selectedDurNode =
        _durFocus[selDurI >= 0 ? selDurI : 0];
    final remaining = nsAccFormatRemaining(
      a.accessUntil ?? a.trialEndsAt,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubHero(
          isTrial: a.isTrial,
          isLoggedIn: a.isLoggedIn,
          remaining: remaining,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < kNsAccDurations.length; i++)
              _DurationPill(
                duration: kNsAccDurations[i],
                selected: kNsAccDurations[i].id == sel.id,
                onPressed: () => state.setAccountDuration(kNsAccDurations[i].id),
                focusNode: _durFocus[i],
                leftNeighbor: i > 0 ? _durFocus[i - 1] : null,
                rightNeighbor: i < kNsAccDurations.length - 1
                    ? _durFocus[i + 1]
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Same-size plan cards — match the HTML's
            // `grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
            //  align-items: stretch;` behaviour. Wrap gives each card its
            // intrinsic size (different content = different height /
            // width); `IntrinsicHeight + Row + Expanded` fixes both axes:
            //
            //   * Expanded → equal width (shared space, identical flex)
            //   * IntrinsicHeight → tallest card sets the row's height and
            //     every Expanded child stretches to fill it
            //
            // Below ~540 px (TV narrow / phone portrait) we stack into a
            // single column — each card still stretches to the container
            // width so they stay consistent vertically.
            const gap = 7.0;
            const stackBreakpoint = 540.0;
            final stacked = constraints.maxWidth < stackBreakpoint;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < kNsAccPlans.length; i++) ...[
                    if (i != 0) const SizedBox(height: gap),
                    _PlanCard(
                      plan: kNsAccPlans[i],
                      duration: sel,
                      onPressed: () => _openCheckout(context, kNsAccPlans[i]),
                      focusNode: _planFocus[i],
                      // Stacked = full-width cards: Left always jumps to the
                      // duration row, not a horizontal neighbor.
                      leftNeighbor: null,
                      rightNeighbor: null,
                      stacked: true,
                      selectedDurationForStackedLeft: selectedDurNode,
                    ),
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < kNsAccPlans.length; i++) ...[
                    if (i != 0) const SizedBox(width: gap),
                    Expanded(
                      child: _PlanCard(
                        plan: kNsAccPlans[i],
                        duration: sel,
                        onPressed: () =>
                            _openCheckout(context, kNsAccPlans[i]),
                        focusNode: _planFocus[i],
                        leftNeighbor: i > 0 ? _planFocus[i - 1] : null,
                        rightNeighbor: i < kNsAccPlans.length - 1
                            ? _planFocus[i + 1]
                            : null,
                        stacked: false,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SubHero extends StatelessWidget {
  const _SubHero({
    required this.isTrial,
    required this.isLoggedIn,
    required this.remaining,
  });
  final bool isTrial;
  final bool isLoggedIn;
  final String remaining;

  @override
  Widget build(BuildContext context) {
    final badgeText =
        isTrial ? (isLoggedIn ? 'TRIAL' : 'FREE TRIAL') : 'PREMIUM';
    final desc = isTrial
        ? (isLoggedIn
            ? 'Your trial gives you full access to all features.'
            : 'Enjoy full access during your free trial. Create an '
                'account to manage your subscription.')
        : 'Your premium subscription is active. Renew or change plan '
            'below.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isTrial
              ? const [Color(0x33FBBF24), Color(0x0AFBBF24)]
              : const [NsColors.accentSoft, Color(0x0A4DD0E1)],
        ),
        border: Border.all(
          color: isTrial
              ? const Color(0x59FBBF24)
              : NsColors.accentLine,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isTrial
                        ? const Color(0x33FBBF24)
                        : NsColors.accentSoft,
                    border: Border.all(
                      color: isTrial
                          ? const Color(0x66FBBF24)
                          : NsColors.accentLine,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: isTrial
                          ? NsColors.warn
                          : NsColors.accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  remaining,
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.14,
                    height: 1.15,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 10,
                    height: 1.35,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isTrial
                ? Icons.hourglass_top_rounded
                : Icons.workspace_premium_rounded,
            size: 30,
            color: isTrial ? NsColors.warn : NsColors.accent,
          ),
        ],
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({
    required this.duration,
    required this.selected,
    required this.onPressed,
    required this.focusNode,
    required this.leftNeighbor,
    required this.rightNeighbor,
  });
  final NsAccDuration duration;
  final bool selected;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final FocusNode? leftNeighbor;
  final FocusNode? rightNeighbor;

  @override
  Widget build(BuildContext context) {
    final off = (duration.discount * 100).round();
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: duration.label,
      onKeyIntercept: (node, event) {
        if (event is! KeyDownEvent) return null;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (leftNeighbor != null) {
            if (leftNeighbor!.canRequestFocus) leftNeighbor!.requestFocus();
            return KeyEventResult.handled;
          }
          final nav =
              node.context?.findAncestorWidgetOfExactType<NsNewSettingsNav>();
          if (nav != null && nav.railCanRequestFocus) {
            nav.onLeftFromRootMainToRail();
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          if (rightNeighbor != null) {
            if (rightNeighbor!.canRequestFocus) rightNeighbor!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return null;
      },
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? NsColors.accentSoft
              : (focused ? NsColors.surface2 : NsColors.bg2),
          border: Border.all(
            color: selected
                ? NsColors.accentLine
                : (focused ? NsColors.line2 : NsColors.line),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              duration.label,
              style: TextStyle(
                color: selected ? NsColors.accent : NsColors.text2,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
            if (off > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1A4ADE80),
                  border: Border.all(
                    color: const Color(0x594ADE80),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$off% OFF',
                  style: const TextStyle(
                    color: NsColors.success,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 0.3,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.duration,
    required this.onPressed,
    required this.focusNode,
    this.leftNeighbor,
    this.rightNeighbor,
    this.stacked = false,
    this.selectedDurationForStackedLeft,
  });
  final NsAccPlan plan;
  final NsAccDuration duration;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final FocusNode? leftNeighbor;
  final FocusNode? rightNeighbor;
  final bool stacked;
  final FocusNode? selectedDurationForStackedLeft;

  @override
  Widget build(BuildContext context) {
    final price = nsAccPriceCombo(plan.baseCents, duration);
    final featured = plan.badge != null;
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: 'Subscribe to ${plan.name}',
      onKeyIntercept: (node, event) {
        if (event is! KeyDownEvent) return null;
        final k = event.logicalKey;
        if (stacked &&
            k == LogicalKeyboardKey.arrowLeft &&
            selectedDurationForStackedLeft != null) {
          if (selectedDurationForStackedLeft!.canRequestFocus) {
            selectedDurationForStackedLeft!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (leftNeighbor != null) {
            if (leftNeighbor!.canRequestFocus) leftNeighbor!.requestFocus();
            return KeyEventResult.handled;
          }
          final nav =
              node.context?.findAncestorWidgetOfExactType<NsNewSettingsNav>();
          if (nav != null && nav.railCanRequestFocus) {
            nav.onLeftFromRootMainToRail();
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          if (rightNeighbor != null) {
            if (rightNeighbor!.canRequestFocus) rightNeighbor!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return null;
      },
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: featured
                ? _withAlpha(plan.accent, 0.6)
                : (focused ? NsColors.line2 : NsColors.line),
            width: featured ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: featured
              ? [
                  BoxShadow(
                    color: _withAlpha(plan.accent, 0.22),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ]
              : NsShadow.s1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.06,
                      height: 1.15,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (plan.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _withAlpha(plan.accent, 0.15),
                      border: Border.all(
                        color: _withAlpha(plan.accent, 0.45),
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      plan.badge!,
                      style: TextStyle(
                        color: plan.accent,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        fontFamily: 'monospace',
                        height: 1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    price.monthly,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: plan.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      height: 1.1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (price.total.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      price.total,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NsColors.text3,
                        fontSize: 9.5,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            for (final f in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: NsColors.success,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: NsColors.text2,
                          fontSize: 10,
                          height: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Spacer eats the slack when IntrinsicHeight forces this card
            // taller than its intrinsic content — pins the CTA to the
            // bottom so all three cards' "Subscribe" buttons line up on
            // the same baseline, matching the HTML's grid behaviour.
            const Spacer(),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: _withAlpha(plan.accent, 0.18),
                border: Border.all(
                  color: _withAlpha(plan.accent, 0.45),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Subscribe',
                    style: TextStyle(
                      color: plan.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 12,
                    color: plan.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Devices tab — linked devices grid with rename / remove.
// ═══════════════════════════════════════════════════════════════════════

class _DevicesTab extends StatefulWidget {
  const _DevicesTab({required this.state});
  final NewSettingsState state;

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  final Map<String, FocusNode> _rename = {};
  final Map<String, FocusNode> _remove = {};

  NewSettingsState get state => widget.state;

  void _syncNodes(List<NsAccDevice> devices) {
    final wanted = {for (final d in devices) d.id};
    for (final id in _rename.keys.toList()) {
      if (!wanted.contains(id)) {
        _rename.remove(id)?.dispose();
      }
    }
    for (final id in _remove.keys.toList()) {
      if (!wanted.contains(id)) {
        _remove.remove(id)?.dispose();
      }
    }
    for (final d in devices) {
      _rename.putIfAbsent(
        d.id,
        () => FocusNode(debugLabel: 'ns:dev:rename:${d.id}'),
      );
      if (!d.current) {
        _remove.putIfAbsent(
          d.id,
          () => FocusNode(debugLabel: 'ns:dev:remove:${d.id}'),
        );
      } else {
        _remove.remove(d.id)?.dispose();
      }
    }
  }

  @override
  void dispose() {
    for (final n in _rename.values) {
      n.dispose();
    }
    for (final n in _remove.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// First flat index of this device's **Rename** control in
  /// row-major (rename, [remove?], …) order.
  int _flatIndexRename(int di, List<NsAccDevice> devs) {
    var o = 0;
    for (var j = 0; j < di; j++) {
      o += 1;
      if (!devs[j].current) o += 1;
    }
    return o;
  }

  int _flatLen(List<NsAccDevice> devs) {
    var o = 0;
    for (final d in devs) {
      o += 1;
      if (!d.current) o += 1;
    }
    return o;
  }

  FocusNode? _flatAt(List<NsAccDevice> devs, int fi) {
    if (fi < 0) return null;
    var f = 0;
    for (var j = 0; j < devs.length; j++) {
      final d = devs[j];
      if (f == fi) return _rename[d.id]!;
      f += 1;
      if (!d.current) {
        if (f == fi) return _remove[d.id]!;
        f += 1;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final a = state.account.data;
    final used = a.devices.length;
    final max = a.deviceLimit;
    final devs = a.devices;
    _syncNodes(devs);
    final fLen = _flatLen(devs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Linked devices',
                  style: TextStyle(
                    color: NsColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: NsColors.bg2,
                  border: Border.all(color: NsColors.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$used / $max',
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        if (a.devices.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'No devices linked to this account.',
              style: TextStyle(
                color: NsColors.text3,
                fontSize: 11.5,
                decoration: TextDecoration.none,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // HTML paints the `Linked devices` grid as **exactly two
              // columns** (see picture 1). Lock it to 2 — wider panes
              // do not spill into a 3-column layout. Tile width is
              // derived from the actual pane width so the two tiles
              // always span the full card width with no leftover gap.
              const gap = 7.0;
              const cols = 2;
              final tileW =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;
              final fTotal = fLen;
              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var di = 0; di < devs.length; di++)
                      SizedBox(
                        width: tileW,
                        child: _DeviceTile(
                          device: devs[di],
                          onRename: () =>
                              _renameDevice(context, devs[di]),
                          onRemove: () =>
                              _removeDevice(context, devs[di]),
                          renameFocus: _rename[devs[di].id]!,
                          removeFocus: devs[di].current
                              ? null
                              : _remove[devs[di].id]!,
                          renameL: (() {
                            final iR = _flatIndexRename(di, devs);
                            return iR > 0 ? _flatAt(devs, iR - 1) : null;
                          })(),
                          renameR: (() {
                            final d0 = devs[di];
                            final iR = _flatIndexRename(di, devs);
                            final rm =
                                d0.current ? null : _remove[d0.id]!;
                            if (!d0.current && rm != null) {
                              return rm;
                            }
                            if (iR + 1 < fTotal) {
                              return _flatAt(devs, iR + 1);
                            }
                            return null;
                          })(),
                          renameU: di >= cols
                              ? _rename[devs[di - cols].id]!
                              : null,
                          renameD: di + cols < devs.length
                              ? _rename[devs[di + cols].id]!
                              : null,
                          removeL: devs[di].current
                              ? null
                              : _rename[devs[di].id]!,
                          removeR: (() {
                            if (devs[di].current) return null;
                            final iR = _flatIndexRename(di, devs);
                            final iRm0 = iR + 1;
                            if (iRm0 + 1 < fTotal) {
                              return _flatAt(devs, iRm0 + 1);
                            }
                            return null;
                          })(),
                          removeU: devs[di].current
                              ? null
                              : _rename[devs[di].id]!,
                          removeD: devs[di].current
                              ? null
                              : (di + cols < devs.length
                                  ? _rename[devs[di + cols].id]!
                                  : null),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 3),
          child: Text(
            'Device limit can be adjusted from the admin dashboard or '
            'your subscription plan.',
            style: TextStyle(
              color: NsColors.text4,
              fontSize: 9.5,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _renameDevice(
    BuildContext context,
    NsAccDevice d,
  ) async {
    final name = await showNsTextPromptDialog(
      context,
      title: 'Rename device',
      initial: d.label,
      confirmLabel: 'Rename',
    );
    if (name == null) return;
    try {
      await state.accountRenameDevice(d.id, name);
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to rename device: $e');
      }
    }
  }

  Future<void> _removeDevice(
    BuildContext context,
    NsAccDevice d,
  ) async {
    final r = await showNsConfirmDialog(
      context,
      title: 'Remove "${d.label}"?',
      message:
          'This device will need to re-pair next time it opens the '
          'app.',
      confirmLabel: 'Remove',
      isDanger: true,
    );
    if (r == NsConfirmResult.confirmed && context.mounted) {
      try {
        await state.accountRemoveDevice(d.id);
      } catch (e) {
        if (context.mounted) {
          _showError(context, 'Failed to remove device: $e');
        }
      }
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onRename,
    required this.onRemove,
    required this.renameFocus,
    this.removeFocus,
    this.renameL,
    this.renameR,
    this.renameU,
    this.renameD,
    this.removeL,
    this.removeR,
    this.removeU,
    this.removeD,
  });
  final NsAccDevice device;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final FocusNode renameFocus;
  final FocusNode? removeFocus;
  final FocusNode? renameL;
  final FocusNode? renameR;
  final FocusNode? renameU;
  final FocusNode? renameD;
  final FocusNode? removeL;
  final FocusNode? removeR;
  final FocusNode? removeU;
  final FocusNode? removeD;

  @override
  Widget build(BuildContext context) {
    final icon = switch (device.type) {
      NsAccDeviceType.tv => Icons.live_tv_rounded,
      NsAccDeviceType.phone => Icons.smartphone_rounded,
      NsAccDeviceType.laptop => Icons.laptop_rounded,
      NsAccDeviceType.unknown => Icons.devices_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: device.current
            ? NsColors.accentSoft
            : NsColors.surface,
        border: Border.all(
          color: device.current ? NsColors.accentLine : NsColors.line,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: device.current ? null : NsShadow.s1,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.bg2,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 13, color: NsColors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        device.label,
                        style: const TextStyle(
                          color: NsColors.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.current) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: NsColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'THIS',
                          style: TextStyle(
                            color: Color(0xFF001017),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  nsAccLastSeen(device.lastSeen),
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 9.5,
                    height: 1.25,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          _IconBtn(
            focusNode: renameFocus,
            focusLeftNeighbor: renameL,
            focusRightNeighbor: renameR,
            focusUpNeighbor: renameU,
            focusDownNeighbor: renameD,
            icon: Icons.edit_rounded,
            tooltip: 'Rename device',
            onPressed: onRename,
          ),
          if (!device.current && removeFocus != null) ...[
            const SizedBox(width: 3),
            _IconBtn(
              focusNode: removeFocus!,
              focusLeftNeighbor: removeL,
              focusRightNeighbor: removeR,
              focusUpNeighbor: removeU,
              focusDownNeighbor: removeD,
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove device',
              danger: true,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.focusNode,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusUpNeighbor,
    this.focusDownNeighbor,
  });
  final FocusNode focusNode;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusUpNeighbor;
  final FocusNode? focusDownNeighbor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: NsFocusable(
        focusNode: focusNode,
        onActivate: onPressed,
        semanticLabel: tooltip,
        focusLeftNeighbor: focusLeftNeighbor,
        focusRightNeighbor: focusRightNeighbor,
        focusUpNeighbor: focusUpNeighbor,
        focusDownNeighbor: focusDownNeighbor,
        builder: (context, focused) {
          final fg = danger ? NsColors.danger : NsColors.text2;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: NsEase.ease,
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focused
                  ? (danger
                      ? NsColors.dangerSoft
                      : NsColors.surface2)
                  : Colors.transparent,
              border: Border.all(
                color: focused
                    ? (danger ? NsColors.danger : NsColors.line2)
                    : NsColors.line,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 11, color: fg),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Downloads tab (Android-only) — ports AndroidOfflineDownloadsScreen
//  but rendered in the new HTML-cyan style. Backed by the exact same
//  [VodOfflineLibrary] store the old screen uses.
// ═══════════════════════════════════════════════════════════════════════

class _DownloadsTab extends StatefulWidget {
  const _DownloadsTab();

  @override
  State<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<_DownloadsTab> {
  @override
  void initState() {
    super.initState();
    // Same sync path as [AndroidOfflineDownloadsScreen] — reload from
    // disk and drop entries whose backing file has been removed.
    _sync();
  }

  Future<void> _sync() async {
    await VodOfflineLibrary.instance.reload();
    await VodOfflineLibrary.instance.pruneMissingFiles();
  }

  Future<void> _confirmDelete(VodOfflineItem item) async {
    final l10n = AppLocalizations.of(context);
    final r = await showNsConfirmDialog(
      context,
      title: l10n.accountOfflineDownloadsDeleteTitle,
      message: l10n.accountOfflineDownloadsDeleteBody,
      confirmLabel: l10n.accountOfflineDownloadsDeleteConfirm,
      isDanger: true,
    );
    if (r == NsConfirmResult.confirmed && mounted) {
      await VodOfflineLibrary.instance.remove(item.id);
    }
  }

  Future<void> _play(VodOfflineItem item) async {
    if (!File(item.filePath).existsSync()) {
      await _sync();
      return;
    }
    if (!mounted) return;
    await openTvMatePlayer(
      context,
      title: item.title,
      streamUrl: Uri.file(item.filePath).toString(),
      isLive: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: VodOfflineLibrary.instance,
      builder: (context, _) {
        final items = VodOfflineLibrary.instance.items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Small header row with subtitle + count pill — mirrors the
            // "Linked devices" tab head style already used in Devices.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.accountOfflineDownloadsTitle,
                      style: const TextStyle(
                        color: NsColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NsColors.bg2,
                      border: Border.all(color: NsColors.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: NsColors.text3,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        height: 1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (items.isEmpty)
              _DownloadsEmpty(message: l10n.accountOfflineDownloadsEmpty)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i != 0) const SizedBox(height: 7),
                    _DownloadRow(
                      item: items[i],
                      onPlay: () => _play(items[i]),
                      onDelete: () => _confirmDelete(items[i]),
                      playLabel: l10n.accountOfflineDownloadsPlay,
                      deleteLabel: l10n.accountOfflineDownloadsDelete,
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                l10n.accountOfflineDownloadsSubtitle,
                style: const TextStyle(
                  color: NsColors.text4,
                  fontSize: 9.5,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadsEmpty extends StatelessWidget {
  const _DownloadsEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_download_outlined,
            size: 28,
            color: NsColors.text4,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NsColors.text3,
              fontSize: 10.5,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.item,
    required this.onPlay,
    required this.onDelete,
    required this.playLabel,
    required this.deleteLabel,
  });
  final VodOfflineItem item;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final String playLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_Hm();
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(10),
        boxShadow: NsShadow.s1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 96,
              height: 54,
              child: _DownloadThumb(posterUrl: item.posterUrl),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _DownloadMetaChip(
                      icon: Icons.storage_rounded,
                      label: vodDownloadFormatBytes(item.sizeBytes),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: _DownloadMetaChip(
                        icon: Icons.event_rounded,
                        label: dateFmt.format(item.savedAt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    NsButton(
                      label: playLabel,
                      icon: Icons.play_arrow_rounded,
                      variant: NsButtonVariant.primary,
                      onPressed: onPlay,
                    ),
                    NsButton(
                      label: deleteLabel,
                      icon: Icons.delete_outline_rounded,
                      variant: NsButtonVariant.danger,
                      onPressed: onDelete,
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
}

class _DownloadMetaChip extends StatelessWidget {
  const _DownloadMetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: NsColors.text3),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadThumb extends StatelessWidget {
  const _DownloadThumb({this.posterUrl});
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final u = posterUrl?.trim() ?? '';
    const fallback = ColoredBox(
      color: NsColors.bg2,
      child: Icon(
        Icons.movie_outlined,
        color: NsColors.text4,
        size: 26,
      ),
    );
    if (u.isEmpty || !catalogArtUrlLooksLoadable(u)) {
      return fallback;
    }
    if (catalogArtIsBundledAsset(u)) {
      return Image.asset(
        u,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

Color _withAlpha(Color c, double a) {
  return Color.fromRGBO(
    (c.r * 255.0).round(),
    (c.g * 255.0).round(),
    (c.b * 255.0).round(),
    a,
  );
}
