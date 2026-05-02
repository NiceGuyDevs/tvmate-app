import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'account_api.dart';
import 'account_store.dart';
import 'android_offline_downloads_screen.dart';
import 'access_gate.dart';
import 'auth_gate_screen.dart';
import '../data/library_controller.dart';

/// TV-friendly spacing/sizes for the account overlay (1080p safe).
class _AccTv {
  static const double sidebarWidth = 236;
  static const EdgeInsets mainPadding = EdgeInsets.fromLTRB(12, 6, 12, 10);
  static const double pageTitleSize = 17;
  static const double pageSubtitleSize = 11;
  static const double cardPadding = 10;
  static const double cardRadius = 12;
}

/// Dark account dashboard palette (matches standalone account UI spec).
class _AccColors {
  static const Color bgPrimary = Color(0xFF0A0A0C);
  static const Color bgSecondary = Color(0xFF131316);
  static const Color bgTertiary = Color(0xFF1E1E24);
  static const Color borderColor = Color.fromARGB(153, 63, 63, 70);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textTertiary = Color(0xFF71717A);
  static const Color accentPrimary = Color(0xFF6366F1);
  static const Color accentSecondary = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF22C55E);
  static const Color successGlow = Color.fromARGB(51, 34, 197, 94);
  static const Color danger = Color(0xFFEF4444);
}

class AccountOverlay extends StatefulWidget {
  const AccountOverlay({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AccountOverlay()),
    );
  }

  @override
  State<AccountOverlay> createState() => _AccountOverlayState();
}

enum _AccTab { profile, subscription, devices }

class _AccountOverlayState extends State<AccountOverlay> {
  _AccTab _tab = _AccTab.profile;
  Map<String, dynamic>? _profile;
  List<dynamic> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (accountStore.isLoggedIn) {
        final results = await Future.wait([
          accountApi.getMe(),
          accountApi.getDevices(),
        ]);
        _profile = results[0] as Map<String, dynamic>;
        _devices = results[1] as List<dynamic>;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeRemaining() {
    if (_accessExpired) return 'No Active Subscription';
    if (_profile == null) {
      final gate = accessGate.lastResult;
      if (gate?.trialEndsAt != null) {
        return _formatRemaining(DateTime.tryParse(gate!.trialEndsAt!));
      }
      if (gate?.accessGrantedUntil != null) {
        return _formatRemaining(DateTime.tryParse(gate!.accessGrantedUntil!));
      }
      return 'Free Trial Active';
    }
    final end = _profile!['accessGrantedUntil'] ?? _profile!['trialEndsAt'];
    if (end == null) return 'No active subscription';
    return _formatRemaining(DateTime.tryParse(end.toString()));
  }

  /// True when the user has no active trial AND no active subscription.
  /// For guests, trusts `accessGate.lastResult.needsSubscription` (which the
  /// backend sets when device.trialConsumed=true or trial time has passed).
  /// Also treats unknown / unauthenticated / network-error states as expired
  /// so we never falsely advertise an active trial.
  bool get _accessExpired {
    if (_profile != null) {
      final end = _profile!['accessGrantedUntil'] ?? _profile!['trialEndsAt'];
      if (end == null) return true;
      final dt = DateTime.tryParse(end.toString());
      return dt == null || dt.isBefore(DateTime.now());
    }
    final gate = accessGate.lastResult;
    if (gate == null) return true;
    if (gate.needsSubscription) return true;
    const unknown = {'NO_TOKEN', 'NETWORK_ERROR', 'UNKNOWN'};
    if (!gate.allowed && unknown.contains(gate.reason)) return true;
    return false;
  }

  String _formatRemaining(DateTime? end) {
    if (end == null) return 'Unknown';
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final totalDays = diff.inDays;
    if (totalDays >= 365) {
      final years = totalDays ~/ 365;
      final remaining = totalDays % 365;
      final label = years == 1 ? '1 Year' : '$years Years';
      return remaining > 0 ? '$label, $remaining Days remaining' : '$label remaining';
    }
    if (totalDays >= 30) {
      final months = totalDays ~/ 30;
      final remaining = totalDays % 30;
      final label = months == 1 ? '1 Month' : '$months Months';
      return remaining > 0 ? '$label, $remaining Days remaining' : '$label remaining';
    }
    if (totalDays > 0) return '$totalDays Days remaining';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    return '${diff.inMinutes}m remaining';
  }

  bool get _isTrial {
    if (_accessExpired) return false;
    if (_profile == null) return true;
    return _profile!['accessGrantedUntil'] == null;
  }

  Future<void> _signOut() async {
    try {
      if (accountStore.refreshToken != null) {
        await accountApi.logout(accountStore.refreshToken!);
      }
    } catch (_) {}
    await accountStore.clearAuth();
    // Stop pulling admin playlists for the previous user and immediately
    // hide their playlists from the UI (visibility filter re-runs against
    // the now-anonymous current user).
    libraryController.stopPeriodicSync();
    await libraryController.refreshVisibility();
    if (!mounted) return;
    // Close the account overlay only — leave the app running so the user
    // returns to the main shell in a logged-out (freemium) state. The next
    // playback attempt will trigger the paywall via player_navigation.
    Navigator.of(context).pop();
    // Trigger an access re-check so paywall/freemium state updates immediately.
    unawaited(accessGate.check());
  }

  String _displayName() {
    if (!accountStore.isLoggedIn) return 'Guest';
    final name = _profile?['name'] ?? accountStore.user?['name'];
    if (name != null && name.toString().isNotEmpty) return name.toString();
    return (accountStore.user?['email'] ?? 'User').toString().split('@').first;
  }

  String _tabTitle() {
    return switch (_tab) {
      _AccTab.profile => 'Profile',
      _AccTab.subscription => 'Subscription',
      _AccTab.devices => 'Devices',
    };
  }

  String _tabSubtitle() {
    return switch (_tab) {
      _AccTab.profile => 'Manage your account information and preferences',
      _AccTab.subscription => 'View your plan and upgrade options',
      _AccTab.devices => 'Manage devices linked to your account',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _AccColors.bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: _AccColors.accentPrimary,
          surface: _AccColors.bgSecondary,
        ),
      ),
      child: Scaffold(
        backgroundColor: _AccColors.bgPrimary,
        body: SafeArea(
          // Reading-order traversal visits the full left sidebar before the main panel
          // (Row → sidebar Column before Expanded main). Do not use OrderedTraversalPolicy
          // here: unordered focusables in the main panel can incorrectly sort ahead of sidebar.
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _AccTv.sidebarWidth,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _AccColors.bgSecondary,
                      border: Border(
                        right: BorderSide(color: _AccColors.borderColor),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSidebarBackRow(),
                        const _AccSidebarHeader(),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AccSidebarItem(
                                  icon: Icons.person,
                                  label: 'Profile',
                                  active: _tab == _AccTab.profile,
                                  onPressed: () => setState(() => _tab = _AccTab.profile),
                                ),
                                _AccSidebarItem(
                                  icon: Icons.card_membership,
                                  label: 'Subscription',
                                  active: _tab == _AccTab.subscription,
                                  onPressed: () => setState(() => _tab = _AccTab.subscription),
                                ),
                                _AccSidebarItem(
                                  icon: Icons.devices_other,
                                  label: 'Devices',
                                  active: _tab == _AccTab.devices,
                                  onPressed: () => setState(() => _tab = _AccTab.devices),
                                ),
                                if (Platform.isAndroid)
                                  _AccSidebarItem(
                                    icon: Icons.download_for_offline_rounded,
                                    label: 'Offline downloads',
                                    active: false,
                                    onPressed: () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AndroidOfflineDownloadsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                _AccSidebarItem(
                                  icon: Icons.logout,
                                  label: 'Sign Out',
                                  active: false,
                                  danger: true,
                                  onPressed: _signOut,
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _AccUserPreview(
                            name: _displayName(),
                            email: accountStore.isLoggedIn
                                ? (accountStore.user?['email']?.toString() ?? '—')
                                : 'Not signed in',
                            activeLabel: accountStore.isLoggedIn ? 'Active' : 'Trial',
                            activeColor: accountStore.isLoggedIn ? _AccColors.success : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _buildMainPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarBackRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: _TvSidebarMaterialButton(
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(),
        backgroundColor: _AccColors.bgSecondary,
        foregroundColor: _AccColors.textSecondary,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 17, color: _AccColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'Back',
              style: TextStyle(
                color: _AccColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _AccColors.accentPrimary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: _AccTv.mainPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccPageHeader(title: _tabTitle(), subtitle: _tabSubtitle()),
          const SizedBox(height: 8),
          _buildTabBody(),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_tab) {
      _AccTab.profile => _buildProfileBody(),
      _AccTab.subscription => _buildSubscriptionBody(),
      _AccTab.devices => _buildDevicesBody(),
    };
  }

  // ── Profile Tab ──────────────────────────────────────────────────

  Widget _buildProfileBody() {
    final isGuest = !accountStore.isLoggedIn;
    if (isGuest) {
      return _buildGuestProfile();
    }
    return _buildLoggedInProfileCards();
  }

  Widget _buildGuestProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _AccColors.bgTertiary,
            borderRadius: BorderRadius.circular(_AccTv.cardRadius),
            border: Border.all(color: _AccColors.borderColor),
          ),
          padding: const EdgeInsets.all(_AccTv.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Account Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _AccColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _accDetailRow('Account', Text('Guest (Free Trial)', style: _accValueStyle())),
              _accDetailRow('Status', Text('Active', style: _accValueStyle())),
              _accDetailRow(
                'Device ID',
                Text(
                  accountStore.deviceId?.substring(0, 8) ?? 'N/A',
                  style: _accValueStyle(),
                ),
              ),
              _accDetailRow('Time left', Text(_timeRemaining(), style: _accValueStyle())),
              const SizedBox(height: 12),
              Text(
                'Create an account to keep your subscription after your trial ends.',
                style: TextStyle(color: _AccColors.textSecondary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              _AccGradientButton(
                label: 'Sign In',
                icon: Icons.login,
                expanded: true,
                compact: true,
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => AuthGateScreen(
                        startOnRegister: false,
                        onAuthenticated: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AccOutlinedButton(
                label: 'Create Account',
                icon: Icons.person_add,
                expanded: true,
                compact: true,
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => AuthGateScreen(
                        startOnRegister: true,
                        onAuthenticated: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _accValueStyle() => const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        color: _AccColors.textPrimary,
      );

  Widget _buildLoggedInProfileCards() {
    final email = accountStore.user?['email'] ?? 'Unknown';
    final profileName = _profile?['name']?.toString() ?? '';
    final role = _profile?['role'] ?? 'user';
    final status = _profile?['status'] ?? 'active';
    final created = _profile?['createdAt'] ?? _profile?['created_at'];
    String memberSince = '—';
    if (created != null) {
      final d = DateTime.tryParse(created.toString());
      if (d != null) {
        memberSince = '${_monthName(d.month)} ${d.day}, ${d.year}';
      }
    }
    final limit = _profile?['deviceLimit'] ?? 5;
    final used = _devices.length;
    final maxD = limit is int ? limit : int.tryParse(limit.toString()) ?? 5;
    final progress = maxD > 0 ? (used / maxD).clamp(0.0, 1.0) : 0.0;
    final trialWarn = _isTrial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountDetailsCard(
          email: email.toString(),
          displayName: profileName.isEmpty ? '—' : profileName,
          memberSince: memberSince,
          statusText: _capitalize(status.toString()),
          roleText: _capitalize(role.toString()),
          trialLine: _timeRemaining(),
          showTrialWarning: trialWarn,
          onConnectGoogle: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google link coming soon')),
            );
          },
          onEditProfile: () => _editName(profileName),
        ),
        const SizedBox(height: 10),
        _buildDeviceAccessCard(
          used: used,
          maxDevices: maxD,
          progress: progress,
          onAddDevice: () => setState(() => _tab = _AccTab.devices),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsCard({
    required String email,
    required String displayName,
    required String memberSince,
    required String statusText,
    required String roleText,
    required String trialLine,
    required bool showTrialWarning,
    required VoidCallback onConnectGoogle,
    required VoidCallback onEditProfile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _AccColors.bgTertiary,
        borderRadius: BorderRadius.circular(_AccTv.cardRadius),
        border: Border.all(color: _AccColors.borderColor),
      ),
      padding: const EdgeInsets.all(_AccTv.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Account Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _AccColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  _AccGradientButton(
                    label: 'Connect Google',
                    icon: Icons.g_translate,
                    compact: true,
                    onPressed: onConnectGoogle,
                  ),
                  _AccOutlinedButton(
                    label: 'Edit Profile',
                    icon: Icons.edit,
                    compact: true,
                    onPressed: onEditProfile,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _accDetailRow('Email address', Text(email, style: _accValueStyle())),
          _accDetailRow('Display name', Text(displayName, style: _accValueStyle())),
          _accDetailRow('Member since', Text(memberSince, style: _accValueStyle())),
          _accDetailRow('Role', Text(roleText, style: _accValueStyle())),
          _accDetailRow(
            'Account status',
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _AccColors.successGlow,
                border: Border.all(color: _AccColors.success.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _AccColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _AccColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _accDetailRow(
            'Access / trial',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    trialLine,
                    style: _accValueStyle(),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (showTrialWarning) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.warning, size: 15, color: _AccColors.danger),
                ],
              ],
            ),
          ),
          _accDetailRow(
            'Device ID',
            Text(
              accountStore.deviceId?.substring(0, 8) ?? 'N/A',
              style: _accValueStyle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accDetailRow(String label, Widget value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _AccColors.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: _AccColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceAccessCard({
    required int used,
    required int maxDevices,
    required double progress,
    required VoidCallback onAddDevice,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _AccColors.bgTertiary,
        borderRadius: BorderRadius.circular(_AccTv.cardRadius),
        border: Border.all(color: _AccColors.borderColor),
      ),
      padding: const EdgeInsets.all(_AccTv.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Device Access',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _AccColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have $used devices registered out of the maximum $maxDevices allowed on your subscription plan.',
            style: const TextStyle(
              fontSize: 11,
              color: _AccColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$used',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _AccColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    valueColor: const AlwaysStoppedAnimation<Color>(_AccColors.accentPrimary),
                    backgroundColor: _AccColors.bgSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$maxDevices',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _AccColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AccGradientButton(
            label: 'Add New Device',
            icon: Icons.add,
            expanded: true,
            compact: true,
            onPressed: onAddDevice,
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    if (m < 1 || m > 12) return '';
    return names[m - 1];
  }

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final focusNode = FocusNode();

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (focusNode.hasFocus) {
            SystemChannels.textInput.invokeMethod('TextInput.show');
          }
        });
      }
    });

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _AccColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Display Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                maxLength: 50,
                enableInteractiveSelection: true,
                showCursor: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _AccColors.bgTertiary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _AccColors.accentPrimary, width: 2),
                  ),
                  counterStyle: const TextStyle(color: Colors.white38),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AccColors.accentPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    focusNode.dispose();
    if (result == null) return;
    try {
      final updated = await accountApi.updateProfile(name: result);
      await accountStore.saveUser({...?accountStore.user, ...updated});
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
      }
    }
  }

  // ── Subscription Tab ─────────────────────────────────────────────

  String _selectedDuration = '3yr';

  static const _durations = [
    {'id': '1mo', 'label': '1 Month', 'months': 1, 'discount': 0.0},
    {'id': '3mo', 'label': '3 Months', 'months': 3, 'discount': 0.15},
    {'id': '1yr', 'label': '1 Year', 'months': 12, 'discount': 0.40},
    {'id': '3yr', 'label': '3 Years', 'months': 36, 'discount': 0.50},
  ];

  static const _plans = [
    {'id': 'starter', 'name': 'Starter', 'devices': 1, 'baseCents': 499, 'features': ['All channels', '1 device', 'HD streaming', 'Basic support']},
    {'id': 'professional', 'name': 'Professional', 'devices': 3, 'baseCents': 999, 'features': ['All channels', '3 devices', 'FHD streaming', 'Priority support']},
    {'id': 'premium', 'name': 'Premium', 'devices': 5, 'baseCents': 1499, 'features': ['All channels', '5 devices', '4K streaming', '24/7 support', 'Early access']},
  ];

  static const _planAccents = {
    'starter': _AccColors.accentPrimary,
    'professional': Color(0xFF8B5CF6),
    'premium': Color(0xFFD97706),
  };
  static const _planBadges = {
    'professional': 'POPULAR',
    'premium': 'BEST VALUE',
  };

  String _priceForCombo(int baseCents, Map<String, dynamic> dur) {
    final months = dur['months'] as int;
    final discount = dur['discount'] as double;
    final total = (baseCents * months * (1 - discount)).round();
    final monthly = (total / months).round();
    return '\$${(monthly / 100).toStringAsFixed(2)}/mo';
  }

  String _totalForCombo(int baseCents, Map<String, dynamic> dur) {
    final months = dur['months'] as int;
    final discount = dur['discount'] as double;
    final total = (baseCents * months * (1 - discount)).round();
    return '\$${(total / 100).toStringAsFixed(2)}';
  }

  Widget _buildSubscriptionBody() {
    final selectedDur = _durations.firstWhere((d) => d['id'] == _selectedDuration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_AccTv.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_AccTv.cardRadius),
            color: _AccColors.bgTertiary,
            border: Border.all(color: _AccColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _accessExpired
                          ? Colors.redAccent.withOpacity(0.15)
                          : (_isTrial
                              ? Colors.amber.withOpacity(0.15)
                              : _AccColors.accentPrimary.withOpacity(0.15)),
                    ),
                    child: Text(
                      _accessExpired
                          ? 'EXPIRED'
                          : (_isTrial
                              ? (accountStore.isLoggedIn ? 'TRIAL' : 'FREE TRIAL')
                              : 'PREMIUM'),
                      style: TextStyle(
                        color: _accessExpired
                            ? Colors.redAccent
                            : (_isTrial ? Colors.amber : _AccColors.accentPrimary),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _accessExpired
                        ? Icons.error_outline
                        : (_isTrial ? Icons.hourglass_bottom_rounded : Icons.verified_rounded),
                    color: _accessExpired
                        ? Colors.redAccent
                        : (_isTrial ? Colors.amber : _AccColors.accentPrimary),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _timeRemaining(),
                style: const TextStyle(
                  color: _AccColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _accessExpired
                    ? 'Your access has ended. Subscribe to continue using TVMate Pro.'
                    : (_isTrial
                        ? (accountStore.isLoggedIn
                            ? 'Your trial gives you full access to all features.'
                            : 'Enjoy full access during your free trial. Create an account to manage your subscription.')
                        : 'Your premium subscription is active.'),
                style: const TextStyle(color: _AccColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Upgrade Your Plan',
          style: TextStyle(
            color: _AccColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        // Duration tabs
        Container(
          decoration: BoxDecoration(
            color: _AccColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AccColors.borderColor),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: _durations.map((dur) {
              final isSelected = dur['id'] == _selectedDuration;
              final discount = dur['discount'] as double;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDuration = dur['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _AccColors.accentPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dur['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _AccColors.textSecondary,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${(discount * 100).round()}% OFF',
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : const Color(0xFF22C55E),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Plan cards
        ..._plans.map((plan) {
          final planId = plan['id'] as String;
          final accent = _planAccents[planId] ?? _AccColors.accentPrimary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AccPlanCard(
              name: plan['name'] as String,
              price: _priceForCombo(plan['baseCents'] as int, selectedDur),
              totalPrice: _totalForCombo(plan['baseCents'] as int, selectedDur),
              durationLabel: selectedDur['label'] as String,
              features: List<String>.from(plan['features'] as List),
              accent: accent,
              badge: _planBadges[planId],
              onTap: () => _handleSubscribe(context, planId, plan['name'] as String),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _handleSubscribe(BuildContext context, String planId, String planName) async {
    if (!accountStore.isLoggedIn) {
      _showSignInRequiredDialog(context);
      return;
    }
    _showStripeCheckout(context, planId, planName);
  }

  void _showSignInRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _AccColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_rounded, color: _AccColors.accentPrimary, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Account Required',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'You need to sign in or create an account before subscribing.',
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AuthGateScreen(
                          startOnRegister: true,
                          onAuthenticated: () {
                            Navigator.of(context).pop();
                            _loadData();
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AccColors.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AuthGateScreen(
                          startOnRegister: false,
                          onAuthenticated: () {
                            Navigator.of(context).pop();
                            _loadData();
                          },
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showStripeCheckout(BuildContext context, String planId, String planName) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _AccColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: _AccColors.accentPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Preparing $planName checkout...',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await accountApi.createCheckout(planId, durationId: _selectedDuration);
      if (!context.mounted) return;
      Navigator.of(context).pop();

      final url = result['url'] as String?;
      if (url == null || url.isEmpty) throw Exception('No checkout URL returned');

      _showQrCheckoutDialog(context, url, planName);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: _AccColors.bgSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                const SizedBox(height: 12),
                const Text('Checkout Failed', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showQrCheckoutDialog(BuildContext context, String url, String planName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _AccColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2_rounded, color: _AccColors.accentPrimary, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Subscribe to $planName',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scan this QR code with your phone to complete payment',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square),
                    dataModuleStyle: const QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Payment Link', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AccColors.accentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close', style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Devices Tab ──────────────────────────────────────────────────

  Widget _buildDevicesBody() {
    final limit = _profile?['deviceLimit'] ?? 5;
    final maxD = limit is int ? limit : int.tryParse(limit.toString()) ?? 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _AccColors.successGlow,
                border: Border.all(color: _AccColors.success.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_devices.length} / $maxD',
                style: const TextStyle(
                  color: _AccColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _devices.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No devices linked to this account.',
                    style: TextStyle(color: _AccColors.textSecondary, fontSize: 14),
                  ),
                ),
              )
            : Column(
                children: _devices.asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _accDeviceTile(d, i),
                  );
                }).toList(),
              ),
        const SizedBox(height: 12),
        Text(
          'Device limit can be adjusted from the admin dashboard or per subscription plan.',
          style: TextStyle(color: _AccColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _accDeviceTile(Map<String, dynamic> d, int i) {
    final deviceId = d['deviceId']?.toString() ?? '';
    final label = d['label'] ?? d['deviceKey']?.toString().substring(0, 8) ?? 'Device ${i + 1}';
    final lastSeen = d['lastSeenAt'];
    final isCurrentDevice = deviceId == accountStore.deviceId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _AccColors.bgTertiary,
        border: Border.all(
          color: isCurrentDevice ? _AccColors.accentPrimary.withOpacity(0.35) : _AccColors.borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tv_rounded,
            color: isCurrentDevice ? _AccColors.accentPrimary : _AccColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label.toString(),
                        style: const TextStyle(
                          color: _AccColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentDevice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _AccColors.accentPrimary.withOpacity(0.2),
                        ),
                        child: const Text(
                          'THIS DEVICE',
                          style: TextStyle(
                            color: _AccColors.accentPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (lastSeen != null)
                  Text(
                    'Last active: ${_formatDate(lastSeen.toString())}',
                    style: const TextStyle(color: _AccColors.textTertiary, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (deviceId.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                focusColor: _AccColors.accentPrimary.withValues(alpha: 0.25),
                highlightColor: _AccColors.accentPrimary.withValues(alpha: 0.1),
                onTap: () => _promptRenameDevice(deviceId, label.toString()),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.edit_outlined, color: _AccColors.accentPrimary, size: 20),
                ),
              ),
            ),
          if (!isCurrentDevice && deviceId.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                focusColor: Colors.redAccent.withValues(alpha: 0.25),
                highlightColor: Colors.redAccent.withValues(alpha: 0.1),
                onTap: () => _confirmRemoveDevice(deviceId, label.toString()),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _promptRenameDevice(String deviceId, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _AccColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.edit_outlined, color: _AccColors.accentPrimary, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Rename Device',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'This name will be visible everywhere this account is signed in.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: _AccColors.accentPrimary,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                decoration: InputDecoration(
                  hintText: 'Device name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _AccColors.bgTertiary,
                  counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _AccColors.accentPrimary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AccColors.accentPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (newLabel == null) return;
    final trimmed = newLabel.trim();
    if (trimmed.isEmpty || trimmed == currentLabel) return;
    try {
      await accountApi.renameDevice(deviceId, trimmed);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$trimmed"'),
            backgroundColor: _AccColors.accentPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename device: $e')),
        );
      }
    }
  }

  Future<void> _confirmRemoveDevice(String deviceId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _AccColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Remove Device?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove "$label" from your account? This device will need to be re-linked to use your subscription.',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await accountApi.removeDevice(deviceId);
      await _loadData();
      // Refresh admin-pushed playlists immediately after device change
      libraryController.pullAdminPlaylists().catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device removed'),
            backgroundColor: _AccColors.accentPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove device: $e')));
      }
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Demo-style widgets ─────────────────────────────────────────────

/// TV remote: Material [ElevatedButton] gets reliable focus + strong overlays (InkWell alone does not).
class _TvSidebarMaterialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool autofocus;
  final Color backgroundColor;
  final Color foregroundColor;

  const _TvSidebarMaterialButton({
    required this.onPressed,
    required this.child,
    required this.backgroundColor,
    required this.foregroundColor,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      autofocus: autofocus,
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        minimumSize: const Size.fromHeight(36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return _AccColors.accentPrimary.withValues(alpha: 0.45);
          }
          if (states.contains(WidgetState.pressed)) {
            return _AccColors.accentPrimary.withValues(alpha: 0.28);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: _AccColors.accentPrimary.withValues(alpha: 0.95),
              width: 2.5,
            );
          }
          return BorderSide.none;
        }),
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _AccSidebarHeader extends StatelessWidget {
  const _AccSidebarHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.star, color: _AccColors.accentPrimary, size: 18),
          SizedBox(width: 8),
          Text(
            'AccountHub',
            style: TextStyle(
              color: _AccColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onPressed;

  const _AccSidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? _AccColors.danger : _AccColors.accentPrimary;
    final iconColor = danger ? _AccColors.danger : (active ? _AccColors.accentPrimary : _AccColors.textSecondary);
    final textColor = danger ? _AccColors.danger : (active ? _AccColors.textPrimary : _AccColors.textSecondary);
    final bg = active && !danger ? _AccColors.bgTertiary : _AccColors.bgSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          minimumSize: const Size.fromHeight(36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: bg,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: active && !danger
                ? BorderSide(color: _AccColors.accentPrimary.withValues(alpha: 0.35))
                : BorderSide.none,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.42);
            }
            if (states.contains(WidgetState.pressed)) {
              return accent.withValues(alpha: 0.28);
            }
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: accent.withValues(alpha: 0.95), width: 2.5);
            }
            if (active && !danger) {
              return BorderSide(color: _AccColors.accentPrimary.withValues(alpha: 0.35));
            }
            return BorderSide.none;
          }),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccUserPreview extends StatelessWidget {
  final String name;
  final String email;
  final String activeLabel;
  final Color activeColor;

  const _AccUserPreview({
    required this.name,
    required this.email,
    required this.activeLabel,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AccColors.bgTertiary.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AccColors.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            alignment: Alignment.center,
            child: Text(
              (name.isNotEmpty ? name[0] : email.isNotEmpty ? email[0] : '?').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _AccColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: _AccColors.textTertiary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeLabel,
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
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

class _AccPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AccPageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: _AccTv.pageTitleSize,
            fontWeight: FontWeight.w700,
            color: _AccColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: _AccTv.pageSubtitleSize,
            color: _AccColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _AccGradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool expanded;
  final bool compact;

  const _AccGradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    final fs = compact ? 12.0 : 14.0;
    final iconSize = compact ? 14.0 : 16.0;
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_AccColors.accentPrimary, _AccColors.accentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: pad,
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: Colors.white),
            SizedBox(width: compact ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fs,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        focusColor: Colors.white.withValues(alpha: 0.55),
        highlightColor: Colors.white.withValues(alpha: 0.35),
        splashColor: Colors.white.withValues(alpha: 0.45),
        onTap: onPressed,
        child: button,
      ),
    );
  }
}

class _AccOutlinedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool expanded;
  final bool compact;

  const _AccOutlinedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    final fs = compact ? 12.0 : 14.0;
    final iconSize = compact ? 14.0 : 16.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        focusColor: _AccColors.accentPrimary.withValues(alpha: 0.52),
        highlightColor: _AccColors.accentPrimary.withValues(alpha: 0.32),
        splashColor: _AccColors.accentPrimary.withValues(alpha: 0.4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AccColors.accentPrimary.withValues(alpha: 0.4)),
          ),
          padding: pad,
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: _AccColors.accentPrimary),
              SizedBox(width: compact ? 6 : 8),
              Text(
                label,
                style: TextStyle(
                  color: _AccColors.accentPrimary,
                  fontSize: fs,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccPlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String totalPrice;
  final String durationLabel;
  final List<String> features;
  final Color accent;
  final String? badge;
  final VoidCallback onTap;

  const _AccPlanCard({
    required this.name,
    required this.price,
    required this.totalPrice,
    required this.durationLabel,
    required this.features,
    required this.accent,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        focusColor: _AccColors.accentPrimary.withValues(alpha: 0.48),
        highlightColor: _AccColors.accentPrimary.withValues(alpha: 0.28),
        splashColor: _AccColors.accentPrimary.withValues(alpha: 0.35),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _AccColors.bgTertiary,
            border: Border.all(color: _AccColors.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: _AccColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: accent.withOpacity(0.2),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$totalPrice total · $durationLabel',
                          style: const TextStyle(color: _AccColors.textTertiary, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: features
                          .map(
                            (f) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 12, color: _AccColors.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  f,
                                  style: const TextStyle(color: _AccColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: accent.withOpacity(0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
