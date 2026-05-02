/// "Parental PIN" sub-page — same layout as the HTML port; [ParentalControlStore]
/// for all persisted PIN state.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/parental_control_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/parental_pin_dialog.dart';
import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_confirm_dialog.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsPinPage extends StatefulWidget {
  const NsPinPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NsPinPage> createState() => _NsPinPageState();
}

/// Change-PIN: verify → new → confirm, all on the 4-dot numpad.
enum _PinChangeStep { verify, newPin, confirm }

class _NsPinPageState extends State<NsPinPage> {
  String _draft = '';
  _PinChangeStep? _changeStep;
  String? _pendingNewPin;

  @override
  void initState() {
    super.initState();
    parentalControlStore.addListener(_onParentalStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    parentalControlStore.removeListener(_onParentalStore);
    super.dispose();
  }

  void _onParentalStore() {
    if (!mounted) return;
    if (!parentalControlStore.isPinConfigured) {
      setState(() {
        _changeStep = null;
        _pendingNewPin = null;
        _draft = '';
      });
    } else if (_changeStep == null) {
      setState(() {
        _changeStep = _PinChangeStep.verify;
        _draft = '';
      });
    }
  }

  Future<void> _bootstrap() async {
    await parentalControlStore.ensureLoaded();
    if (!mounted) return;
    if (parentalControlStore.isPinConfigured && _changeStep == null) {
      setState(() => _changeStep = _PinChangeStep.verify);
    }
  }

  void _appendDigit(String d) {
    if (_draft.length >= 4) return;
    setState(() => _draft += d);
    if (_draft.length == 4) {
      unawaited(_onFourDigits());
    }
  }

  Future<void> _onFourDigits() async {
    final pin = _draft;
    if (!parentalControlStore.isPinConfigured) {
      await _commitCreate(pin);
      return;
    }

    final step = _changeStep ?? _PinChangeStep.verify;
    if (step == _PinChangeStep.verify) {
      if (parentalControlStore.verifyPin(pin)) {
        if (mounted) {
          setState(() {
            _draft = '';
            _changeStep = _PinChangeStep.newPin;
          });
        }
        return;
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.parentalPinWrong)),
        );
        setState(() => _draft = '');
      }
      return;
    }
    if (step == _PinChangeStep.newPin) {
      setState(() {
        _pendingNewPin = pin;
        _draft = '';
        _changeStep = _PinChangeStep.confirm;
      });
      return;
    }
    if (step == _PinChangeStep.confirm) {
      if (pin == _pendingNewPin) {
        await parentalControlStore.setPin(pin);
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          setState(() {
            _draft = '';
            _pendingNewPin = null;
            _changeStep = _PinChangeStep.verify;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.parentalLockSaved)),
          );
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.parentalMismatch)),
          );
          setState(() {
            _draft = '';
            _changeStep = _PinChangeStep.newPin;
            _pendingNewPin = null;
          });
        }
      }
    }
  }

  Future<void> _commitCreate(String pin) async {
    if (!context.mounted) return;
    await showParentalFirstTimePinSaveWarningDialog(context);
    if (!context.mounted) return;
    final ok = await parentalControlStore.setPin(pin);
    if (ok) {
      await parentalControlStore.setEnabled(true);
    }
    if (mounted) {
      setState(() => _draft = '');
      final l10n = AppLocalizations.of(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.parentalLockSaved)),
        );
        setState(() {
          _changeStep = _PinChangeStep.verify;
        });
      }
    }
  }

  void _backspace() {
    if (_draft.isEmpty) return;
    setState(
      () => _draft = _draft.substring(0, _draft.length - 1),
    );
  }

  void _clear() {
    if (_draft.isEmpty) return;
    setState(() => _draft = '');
  }

  Future<void> _removePin() async {
    final r = await showNsConfirmDialog(
      context,
      title: 'Remove the PIN?',
      message:
          'Wipes the PIN and every restriction rule. This cannot be undone.',
      confirmLabel: 'Remove',
      isDanger: true,
    );
    if (r != NsConfirmResult.confirmed || !mounted) return;
    final ok = await showParentalPinVerifyDialog(context);
    if (ok && mounted) {
      await parentalControlStore.clearPinAndRules();
      if (mounted) {
        setState(() {
          _changeStep = null;
          _draft = '';
          _pendingNewPin = null;
        });
      }
    }
  }

  String _pinCardHint(AppLocalizations l10n) {
    if (!parentalControlStore.isPinConfigured) {
      return 'Choose a new PIN';
    }
    switch (_changeStep ?? _PinChangeStep.verify) {
      case _PinChangeStep.verify:
        return 'Enter current PIN to change';
      case _PinChangeStep.newPin:
        return l10n.parentalSetupPinLabel;
      case _PinChangeStep.confirm:
        return l10n.parentalSetupConfirmLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final l10n = AppLocalizations.of(context);
    final isSet = parentalControlStore.isPinConfigured;

    final pinCard = _PinCard(
      lineLabel: _pinCardHint(l10n),
      filled: _draft.length,
      onDigit: _appendDigit,
      onBackspace: _backspace,
      onClear: _clear,
    );

    final infoCard = _InfoCard(
      isSet: isSet,
      onRemove: _removePin,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const splitBreakpoint = 680;
        final canSplit = constraints.maxWidth >= splitBreakpoint;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Parental PIN',
              subtitle: isSet
                  ? 'A PIN is set. Enter it to change or remove it.'
                  : 'Choose a 4-digit PIN. You\'ll need it to unlock '
                      'restrictions.',
              onBack: widget.onBack,
            ),
            if (canSplit)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 14, child: pinCard),
                  const SizedBox(width: 18),
                  Expanded(flex: 9, child: infoCard),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pinCard,
                  SizedBox(height: d.interGroupGap),
                  infoCard,
                ],
              ),
          ],
        );
      },
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.lineLabel,
    required this.filled,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final String lineLabel;
  final int filled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: d.isCompact ? 14 : 18,
        vertical: d.isCompact ? 16 : 22,
      ),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            lineLabel,
            style: NsType.rowSub.copyWith(
              color: NsColors.text2,
              fontSize: d.isCompact ? 11.5 : 13,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: d.isCompact ? 14 : 18),
          _PinDots(filled: filled),
          SizedBox(height: d.isCompact ? 14 : 18),
          _Keypad(
            onDigit: onDigit,
            onBackspace: onBackspace,
            onClear: onClear,
          ),
        ],
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled});
  final int filled;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final size = d.isCompact ? 12.0 : 14.0;
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(width: d.isCompact ? 10 : 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: NsEase.ease,
              width: size,
              height: size,
              transformAlignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                i < filled ? 1.1 : 1.0,
                i < filled ? 1.1 : 1.0,
                1.0,
              ),
              decoration: BoxDecoration(
                color: i < filled ? NsColors.accent : Colors.transparent,
                border: Border.all(
                  color: i < filled ? NsColors.accent : NsColors.text3,
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final keyW = d.isCompact ? 46.0 : 60.0;
    final keyH = d.isCompact ? 40.0 : 50.0;
    const gap = 8.0;

    Widget num(String n) => _PinKey(
          label: n,
          width: keyW,
          height: keyH,
          onPressed: () => onDigit(n),
        );

    Widget action(String label, VoidCallback onPressed) => _PinKey(
          label: label,
          width: keyW,
          height: keyH,
          isAction: true,
          onPressed: onPressed,
        );

    final rows = <List<Widget>>[
      [num('1'), num('2'), num('3')],
      [num('4'), num('5'), num('6')],
      [num('7'), num('8'), num('9')],
      [action('Clear', onClear), num('0'), action('←', onBackspace)],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                rows[r][c],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.width,
    required this.height,
    required this.onPressed,
    this.isAction = false,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback onPressed;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: label,
      onKeyIntercept: (node, event) {
        if (event is KeyDownEvent && !isAction) {
          final c = event.character;
          if (c == label) {
            onPressed();
            return KeyEventResult.handled;
          }
        }
        return null;
      },
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? NsColors.surface2 : NsColors.surface,
            border: Border.all(
              color: focused ? NsColors.line2 : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isAction
                  ? (focused ? NsColors.text : NsColors.text3)
                  : NsColors.text,
              fontSize: isAction ? 12.5 : 16,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isSet, required this.onRemove});
  final bool isSet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: d.isCompact ? 14 : 18,
        vertical: d.isCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomCenter,
          colors: [Color(0x0A4DD0E1), Color(0x00000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why a PIN?',
            style: NsType.groupLabel.copyWith(
              fontSize: d.isCompact ? 10 : 11,
              color: NsColors.accent,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: d.isCompact ? 8 : 10),
          Text(
            'The PIN protects locked categories, locked tabs, and the '
            'parental controls toggle itself. Without it, no one on this '
            'device can disable parental restrictions you\'ve set.',
            style: NsType.rowSub.copyWith(
              color: NsColors.text2,
              fontSize: d.isCompact ? 11.5 : 13,
              height: 1.5,
            ),
          ),
          SizedBox(height: d.isCompact ? 8 : 12),
          Text(
            "We don't sync this PIN to any server. It's stored only on "
            'this device.',
            style: NsType.rowSub.copyWith(
              color: NsColors.text3,
              fontSize: d.isCompact ? 11 : 12.5,
              height: 1.5,
            ),
          ),
          if (isSet) ...[
            SizedBox(height: d.isCompact ? 12 : 16),
            _DangerButton(
              label: 'Remove PIN',
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: label,
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: focused
                ? const Color(0x2EF87171)
                : NsColors.dangerSoft,
            border: Border.all(color: const Color(0x40F87171)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: NsColors.danger,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: NsColors.danger,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
