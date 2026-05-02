import 'package:flutter/material.dart';

import '../../data/parental_control_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'parental_numeric_pin_plate.dart';
import 'parental_panel_shell.dart';
import 'parental_pin_dialog.dart';
import 'parental_restricted_rules_screen.dart';

/// Parental control: reference layout — row1: status + 3 locks + PIN tile;
/// row2: How it works (+ Clear). First visit: menu visible; only “Create your key”
/// is focusable until activated; then the PIN overlay opens.
///
class ParentalControlSettingsScreen extends StatefulWidget {
  const ParentalControlSettingsScreen({super.key});

  @override
  State<ParentalControlSettingsScreen> createState() =>
      _ParentalControlSettingsScreenState();
}

class _ParentalControlSettingsScreenState
    extends State<ParentalControlSettingsScreen> {
  late final TextEditingController _newPin;
  late final TextEditingController _confirmPin;
  late final FocusNode _pinNewFocus;
  late final FocusNode _pinConfirmFocus;
  late final FocusNode _savePinFocus;

  /// When no PIN yet: `false` until user selects “Create your key”, then PIN card opens.
  bool _pinSetupOverlayOpen = false;

  /// Which PIN field receives digits when numpad is focused (0=new, 1=confirm).
  var _pinOverlayActiveField = 0;

  void _onPinOverlayFieldFocusChanged() {
    if (!mounted) return;
    if (_pinConfirmFocus.hasFocus) {
      if (_pinOverlayActiveField != 1) {
        setState(() => _pinOverlayActiveField = 1);
      }
    } else if (_pinNewFocus.hasFocus) {
      if (_pinOverlayActiveField != 0) {
        setState(() => _pinOverlayActiveField = 0);
      }
    }
  }

  void _appendPinOverlayDigit(String d) {
    final c = _pinOverlayActiveField == 0 ? _newPin : _confirmPin;
    if (c.text.length >= 8) return;
    c.text += d;
    setState(() {});
  }

  void _pinOverlayBackspace() {
    final c = _pinOverlayActiveField == 0 ? _newPin : _confirmPin;
    if (c.text.isEmpty) return;
    c.text = c.text.substring(0, c.text.length - 1);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _newPin = TextEditingController();
    _confirmPin = TextEditingController();
    _pinNewFocus = FocusNode(debugLabel: 'parentalPinNew');
    _pinConfirmFocus = FocusNode(debugLabel: 'parentalPinConfirm');
    _savePinFocus = FocusNode(debugLabel: 'parentalPinSave');
    _pinNewFocus.addListener(_onPinOverlayFieldFocusChanged);
    _pinConfirmFocus.addListener(_onPinOverlayFieldFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await parentalControlStore.ensureLoaded();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pinNewFocus.removeListener(_onPinOverlayFieldFocusChanged);
    _pinConfirmFocus.removeListener(_onPinOverlayFieldFocusChanged);
    _newPin.dispose();
    _confirmPin.dispose();
    _pinNewFocus.dispose();
    _pinConfirmFocus.dispose();
    _savePinFocus.dispose();
    super.dispose();
  }

  Future<void> _showFirstTimeWarning() async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        alignment: Alignment.center,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ParentalPanelCard(
          compact: true,
          title: l10n.parentalSetupTitle,
          maxWidth: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.parentalSetupWarning,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 12),
              TvFocusable(
                focusScale: 1.0,
                parallaxSlide: 0,
                showFocusElevation: false,
                onActivate: () => Navigator.of(ctx).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Text(
                      l10n.parentalDialogSubmit,
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
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

  Future<void> _showHelpDialog() async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ParentalPanelCard(
          title: l10n.parentalHelpTitle,
          maxWidth: 520,
          child: Text(
            l10n.parentalHelpBody,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.4,
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveNewPin() async {
    final l10n = AppLocalizations.of(context);
    final a = _newPin.text.trim();
    final b = _confirmPin.text.trim();
    if (!ParentalControlStore.isValidPinFormat(a)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.parentalDialogPinLabel)),
      );
      return;
    }
    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.parentalMismatch)),
      );
      return;
    }
    await _showFirstTimeWarning();
    if (!mounted) return;
    final ok = await parentalControlStore.setPin(a);
    if (!mounted) return;
    if (ok) {
      _newPin.clear();
      _confirmPin.clear();
      _pinSetupOverlayOpen = false;
      await parentalControlStore.setEnabled(true);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.parentalLockSaved)),
      );
    }
  }

  Future<void> _toggleEnabled(bool v) async {
    if (!parentalControlStore.isPinConfigured) return;
    if (!v && parentalControlStore.enabled) {
      final ok = await showParentalPinVerifyDialog(context);
      if (!ok || !mounted) return;
    }
    await parentalControlStore.setEnabled(v);
    if (mounted) setState(() {});
  }

  Future<void> _changePin() async {
    final ok = await showParentalPinVerifyDialog(context);
    if (!ok || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final a = await showParentalPinEntryDialog(
      context,
      title: l10n.parentalSetupPinLabel,
    );
    if (a == null || !mounted) return;
    final b = await showParentalPinEntryDialog(
      context,
      title: l10n.parentalSetupConfirmLabel,
    );
    if (b == null || !mounted) return;
    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.parentalMismatch)),
      );
      return;
    }
    await parentalControlStore.setPin(a);
    if (mounted) setState(() {});
  }

  Future<void> _clearAll() async {
    final ok = await showParentalPinVerifyDialog(context);
    if (!ok || !mounted) return;
    await parentalControlStore.clearPinAndRules();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: TeamShellBackdrop(),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: parentalControlStore,
              builder: (context, _) {
                final configured = parentalControlStore.isPinConfigured;
                return PopScope(
                  canPop: configured || !_pinSetupOverlayOpen,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    if (!configured && _pinSetupOverlayOpen) {
                      setState(() {
                        _pinSetupOverlayOpen = false;
                        _newPin.clear();
                        _confirmPin.clear();
                      });
                    }
                  },
                  child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  TvFocusable(
                                    focusScale: 1.0,
                                    parallaxSlide: 0,
                                    showFocusElevation: false,
                                    onActivate: () {
                                      if (!configured &&
                                          _pinSetupOverlayOpen) {
                                        setState(() {
                                          _pinSetupOverlayOpen = false;
                                          _newPin.clear();
                                          _confirmPin.clear();
                                        });
                                        return;
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    focusPadding: const EdgeInsets.all(4),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.14,
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        size: 20,
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.parentalSettingsTitle,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.parentalSettingsSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.65),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.none,
                              children: [
                                ExcludeFocus(
                                  excluding:
                                      !configured && _pinSetupOverlayOpen,
                                  child: Opacity(
                                    opacity: configured
                                        ? 1.0
                                        : (_pinSetupOverlayOpen
                                            ? 0.5
                                            : 0.52),
                                    child: _ParentalMenuLayout(
                                      configured: configured,
                                      pinSetupOverlayOpen:
                                          _pinSetupOverlayOpen,
                                      onToggleEnabled: _toggleEnabled,
                                      onLockLive: () async {
                                        await parentalControlStore
                                            .setLockAllLive(
                                          !parentalControlStore.lockAllLive,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      onLockMovies: () async {
                                        await parentalControlStore
                                            .setLockAllMovies(
                                          !parentalControlStore
                                              .lockAllMovies,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      onLockSeries: () async {
                                        await parentalControlStore
                                            .setLockAllSeries(
                                          !parentalControlStore
                                              .lockAllSeries,
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      onManageRules: () =>
                                          openParentalRestrictedRulesScreen(
                                            context,
                                          ),
                                      onPinTile: configured
                                          ? _changePin
                                          : () {
                                              setState(() {
                                                _pinSetupOverlayOpen = true;
                                                _pinOverlayActiveField = 0;
                                              });
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                if (mounted &&
                                                    _pinNewFocus
                                                        .canRequestFocus) {
                                                  _pinNewFocus.requestFocus();
                                                }
                                              });
                                            },
                                      onHowItWorks: _showHelpDialog,
                                      onClearAll: _clearAll,
                                    ),
                                  ),
                                ),
                                if (!configured && _pinSetupOverlayOpen)
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.black.withValues(
                                        alpha: 0.52,
                                      ),
                                      child: Center(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 440,
                                            ),
                                            child: ParentalPanelCard(
                                              title: l10n.parentalSetupTitle,
                                              maxWidth: 440,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    l10n.parentalSetupWarning,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      fontSize: 11.5,
                                                      color: Colors
                                                          .amber.shade200,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ParentalNumericPinPlate(
                                                    dense: true,
                                                    fields: [
                                                      ParentalPinFieldData(
                                                        label: l10n
                                                            .parentalSetupPinLabel,
                                                        controller: _newPin,
                                                        focusNode: _pinNewFocus,
                                                      ),
                                                      ParentalPinFieldData(
                                                        label: l10n
                                                            .parentalSetupConfirmLabel,
                                                        controller:
                                                            _confirmPin,
                                                        focusNode:
                                                            _pinConfirmFocus,
                                                      ),
                                                    ],
                                                    onDigit: _appendPinOverlayDigit,
                                                    onBackspace:
                                                        _pinOverlayBackspace,
                                                  ),
                                                  const SizedBox(height: 14),
                                                  TvFocusable(
                                                    focusNode: _savePinFocus,
                                                    focusScale: 1.0,
                                                    parallaxSlide: 0,
                                                    showFocusElevation: false,
                                                    onActivate: _saveNewPin,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        color: context
                                                            .teamPalette
                                                            .accent
                                                            .withValues(
                                                          alpha: 0.22,
                                                        ),
                                                        border: Border.all(
                                                          color: context
                                                              .teamPalette
                                                              .accent
                                                              .withValues(
                                                            alpha: 0.55,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          l10n.parentalSetPinCta,
                                                          style: theme
                                                              .textTheme
                                                              .labelLarge
                                                              ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800,
                                                            fontSize: 14,
                                                            color: context
                                                                .teamPalette
                                                                .accent,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Reference grid: 5 tiles row1; row2 = How it works (col1) + Clear (col2).
class _ParentalMenuLayout extends StatelessWidget {
  const _ParentalMenuLayout({
    required this.configured,
    required this.pinSetupOverlayOpen,
    required this.onToggleEnabled,
    required this.onLockLive,
    required this.onLockMovies,
    required this.onLockSeries,
    required this.onManageRules,
    required this.onPinTile,
    required this.onHowItWorks,
    required this.onClearAll,
  });

  final bool configured;
  /// True while the first-time PIN entry card is visible over the menu.
  final bool pinSetupOverlayOpen;
  final void Function(bool) onToggleEnabled;
  final VoidCallback onLockLive;
  final VoidCallback onLockMovies;
  final VoidCallback onLockSeries;
  final VoidCallback onManageRules;
  final VoidCallback onPinTile;
  final VoidCallback onHowItWorks;
  final VoidCallback onClearAll;

  bool _tileInteractive(bool isPinTile) {
    if (configured) return true;
    if (pinSetupOverlayOpen) return false;
    return isPinTile;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = context.teamPalette.accent;
    final on = l10n.heroAppearanceOn;
    final off = l10n.heroAppearanceOff;

    String lockLine(bool locked) => locked ? on : off;

    final gateMode = !configured && !pinSetupOverlayOpen;
    final pinTitle = configured
        ? l10n.parentalChangePin
        : l10n.parentalCreateYourKeyTile;
    final pinSubtitle =
        configured ? l10n.parentalSetupPinLabel : l10n.parentalCreateYourKeySubtitle;

    Widget row1Child(Widget child) => Expanded(
          child: child,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final gap = narrow ? 8.0 : 12.0;

        if (narrow) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ParentalHubTile(
                  interactive: _tileInteractive(false),
                  icon: Icons.live_tv_rounded,
                  title: l10n.parentalLockAllLive,
                  subtitle: lockLine(parentalControlStore.lockAllLive),
                  accent: accent,
                  onActivate: onLockLive,
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  interactive: _tileInteractive(false),
                  icon: Icons.movie_outlined,
                  title: l10n.parentalLockAllMovies,
                  subtitle: lockLine(parentalControlStore.lockAllMovies),
                  accent: accent,
                  onActivate: onLockMovies,
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  interactive: _tileInteractive(false),
                  icon: Icons.play_circle_outline_rounded,
                  title: l10n.parentalLockAllSeries,
                  subtitle: lockLine(parentalControlStore.lockAllSeries),
                  accent: accent,
                  onActivate: onLockSeries,
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  interactive: _tileInteractive(false),
                  icon: Icons.list_alt_rounded,
                  title: l10n.parentalManageRestrictedRules,
                  subtitle: l10n.parentalManageRestrictedRulesSubtitle,
                  accent: accent,
                  onActivate: onManageRules,
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  autofocus: configured,
                  interactive: _tileInteractive(false),
                  icon: Icons.shield_rounded,
                  title: l10n.parentalSettingsTitle,
                  subtitle: parentalControlStore.enabled ? on : off,
                  accent: accent,
                  onActivate: () => onToggleEnabled(
                    !parentalControlStore.enabled,
                  ),
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  autofocus: gateMode,
                  interactive: _tileInteractive(true),
                  icon: Icons.lock_outline_rounded,
                  title: pinTitle,
                  subtitle: pinSubtitle,
                  accent: accent,
                  onActivate: onPinTile,
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  interactive: _tileInteractive(false),
                  icon: Icons.help_outline_rounded,
                  title: l10n.parentalHelpTitle,
                  subtitle: l10n.parentalSettingsSubtitle,
                  accent: accent,
                  onActivate: onHowItWorks,
                ),
                SizedBox(height: gap),
                _ParentalHubTile(
                  interactive: _tileInteractive(false),
                  icon: Icons.delete_forever_outlined,
                  title: l10n.parentalClearAll,
                  subtitle: l10n.parentalDialogPinLabel,
                  accent: Colors.redAccent,
                  destructive: true,
                  onActivate: onClearAll,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row1Child(
                  _ParentalHubTile(
                    interactive: _tileInteractive(false),
                    icon: Icons.live_tv_rounded,
                    title: l10n.parentalLockAllLive,
                    subtitle: lockLine(parentalControlStore.lockAllLive),
                    accent: accent,
                    onActivate: onLockLive,
                  ),
                ),
                SizedBox(width: gap),
                row1Child(
                  _ParentalHubTile(
                    interactive: _tileInteractive(false),
                    icon: Icons.movie_outlined,
                    title: l10n.parentalLockAllMovies,
                    subtitle: lockLine(parentalControlStore.lockAllMovies),
                    accent: accent,
                    onActivate: onLockMovies,
                  ),
                ),
                SizedBox(width: gap),
                row1Child(
                  _ParentalHubTile(
                    interactive: _tileInteractive(false),
                    icon: Icons.play_circle_outline_rounded,
                    title: l10n.parentalLockAllSeries,
                    subtitle: lockLine(parentalControlStore.lockAllSeries),
                    accent: accent,
                    onActivate: onLockSeries,
                  ),
                ),
                SizedBox(width: gap),
                row1Child(
                  _ParentalHubTile(
                    interactive: _tileInteractive(false),
                    icon: Icons.list_alt_rounded,
                    title: l10n.parentalManageRestrictedRules,
                    subtitle: l10n.parentalManageRestrictedRulesSubtitle,
                    accent: accent,
                    onActivate: onManageRules,
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row1Child(
                  _ParentalHubTile(
                    autofocus: configured,
                    interactive: _tileInteractive(false),
                    icon: Icons.shield_rounded,
                    title: l10n.parentalSettingsTitle,
                    subtitle: parentalControlStore.enabled ? on : off,
                    accent: accent,
                    onActivate: () => onToggleEnabled(
                      !parentalControlStore.enabled,
                    ),
                  ),
                ),
                SizedBox(width: gap),
                row1Child(
                  _ParentalHubTile(
                    autofocus: gateMode,
                    interactive: _tileInteractive(true),
                    icon: Icons.lock_outline_rounded,
                    title: pinTitle,
                    subtitle: pinSubtitle,
                    accent: accent,
                    onActivate: onPinTile,
                  ),
                ),
                SizedBox(width: gap),
                row1Child(
                  _ParentalHubTile(
                    interactive: _tileInteractive(false),
                    icon: Icons.help_outline_rounded,
                    title: l10n.parentalHelpTitle,
                    subtitle: l10n.parentalSettingsSubtitle,
                    accent: accent,
                    onActivate: onHowItWorks,
                  ),
                ),
                SizedBox(width: gap),
                row1Child(
                  _ParentalHubTile(
                    interactive: _tileInteractive(false),
                    icon: Icons.delete_forever_outlined,
                    title: l10n.parentalClearAll,
                    subtitle: l10n.parentalDialogPinLabel,
                    accent: Colors.redAccent,
                    destructive: true,
                    onActivate: onClearAll,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ParentalHubTile extends StatelessWidget {
  const _ParentalHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onActivate,
    required this.interactive,
    this.autofocus = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onActivate;
  final bool interactive;
  final bool autofocus;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      canRequestFocus: interactive,
      onActivate: interactive ? onActivate : () {},
      focusScale: 1.0,
      parallaxSlide: 0,
      showFocusElevation: false,
      focusPadding: const EdgeInsets.all(3),
      child: _ParentalHubTileShell(
        icon: icon,
        title: title,
        subtitle: subtitle,
        accent: accent,
        destructive: destructive,
      ),
    );
  }
}

class _ParentalHubTileShell extends StatelessWidget {
  const _ParentalHubTileShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = destructive
        ? Colors.redAccent.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.18);
    final bg = destructive
        ? Colors.redAccent.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.07);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        color: bg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: destructive ? Colors.redAccent : accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.96),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.58),
                    height: 1.2,
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
