/// New Settings–styled parental PIN UI: shell, 8-dot progress, and numpad, for
/// [showDialog] with [nsIslandThemeData] from [../new_settings_palette.dart].
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/parental_control_store.dart' show ParentalControlStore;
import '../../../l10n/app_localizations.dart';
import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

// ── Shell (matches Ns pin card) ──────────────────────────────────────

class NsParentalDialogShell extends StatelessWidget {
  const NsParentalDialogShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.boxShadow,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// e.g. [NsShadow.s2] for the Live TV / scope modal preview
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: d.isCompact ? 14 : 18,
          vertical: d.isCompact ? 16 : 20,
        ),
        decoration: BoxDecoration(
          color: NsColors.surface,
          border: Border.all(color: NsColors.line2),
          borderRadius: BorderRadius.circular(NsRadius.card),
          boxShadow: boxShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: NsType.paneTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: d.sp(6)),
              Text(
                subtitle!,
                style: NsType.rowSub.copyWith(
                  color: NsColors.text2,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: d.isCompact ? 12 : 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Up to 8 dots (PIN length 4–8) ────────────────────────────────────

class NsParentalPindots extends StatelessWidget {
  const NsParentalPindots({super.key, required this.filled, this.maxDots = 8});
  final int filled;
  final int maxDots;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final n = maxDots.clamp(4, 8);
    final w = d.isCompact ? 9.0 : 10.0;
    return SizedBox(
      height: 28,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: NsEase.ease,
                width: w,
                height: w,
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
                    width: 1.2,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Numpad (aligned with [pin_page] _Keypad) ───────────────────────

class NsParentalNumpad extends StatelessWidget {
  const NsParentalNumpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    /// TV / D-pad: first focus in the numpad should land on the `1` key for
    /// the verify / single-PIN flow (the side-menu create flow instead focuses
    /// the "New PIN" / "Confirm" field strips first).
    this.autofocusOnFirstDigit = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool autofocusOnFirstDigit;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final keyW = d.isCompact ? 46.0 : 60.0;
    final keyH = d.isCompact ? 40.0 : 50.0;
    const gap = 8.0;

    Widget numK(String n, {bool af = false}) => _Npk(
          label: n,
          width: keyW,
          height: keyH,
          autofocus: af,
          onPressed: () => onDigit(n),
        );
    Widget actK(String l, VoidCallback p) => _Npk(
          label: l,
          width: keyW,
          height: keyH,
          isAction: true,
          onPressed: p,
        );

    final rows = <List<Widget>>[
      [numK('1', af: autofocusOnFirstDigit), numK('2'), numK('3')],
      [numK('4'), numK('5'), numK('6')],
      [numK('7'), numK('8'), numK('9')],
      [actK('Clear', onClear), numK('0'), actK('←', onBackspace)],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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

class _Npk extends StatelessWidget {
  const _Npk({
    required this.label,
    required this.width,
    required this.height,
    required this.onPressed,
    this.isAction = false,
    this.autofocus = false,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback onPressed;
  final bool isAction;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      autofocus: autofocus,
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

// ── Single PIN: verify / entry (4–8 digits) ──────────────────────────

class NsParentalSinglePinContent extends StatefulWidget {
  const NsParentalSinglePinContent({
    super.key,
    required this.title,
    this.subtitle,
    required this.onSubmit,
    required this.onCancel,
  });

  final String title;
  final String? subtitle;
  final void Function(String pin) onSubmit;
  final VoidCallback onCancel;

  @override
  State<NsParentalSinglePinContent> createState() =>
      _NsParentalSinglePinContentState();
}

class _NsParentalSinglePinContentState extends State<NsParentalSinglePinContent> {
  String _pin = '';

  void _append(String d) {
    if (_pin.length >= 8) return;
    setState(() => _pin += d);
  }

  void _bs() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _cl() {
    if (_pin.isEmpty) return;
    setState(() => _pin = '');
  }

  void _trySubmit() {
    if (!ParentalControlStore.isValidPinFormat(_pin)) return;
    widget.onSubmit(_pin.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = NsDensity.of(context);
    final can = ParentalControlStore.isValidPinFormat(_pin);
    return NsParentalDialogShell(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.parentalDialogPinLabel,
            style: NsType.rowSub.copyWith(
              color: NsColors.text2,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: d.isCompact ? 8 : 10),
          NsParentalPindots(filled: _pin.length, maxDots: 8),
          SizedBox(height: d.isCompact ? 10 : 12),
          NsParentalNumpad(
            onDigit: _append,
            onBackspace: _bs,
            onClear: _cl,
            autofocusOnFirstDigit: true,
          ),
          SizedBox(height: d.isCompact ? 12 : 14),
          Row(
            children: [
              Expanded(
                child: NsFocusable(
                  onActivate: can ? _trySubmit : () {},
                  builder: (c, f) => _PinRowAction(
                    label: l10n.parentalDialogSubmit,
                    strong: can,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NsFocusable(
                  onActivate: widget.onCancel,
                  builder: (c, f) => _PinRowAction(
                    label: l10n.commonCancel,
                    strong: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinRowAction extends StatelessWidget {
  const _PinRowAction({required this.label, required this.strong});
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          label,
          style: NsType.rowTitle.copyWith(
            color: strong ? NsColors.accent : NsColors.text2,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── First-time “remember your PIN” (no store access) ─────────────────

class NsParentalFirstTimeWarningContent extends StatelessWidget {
  const NsParentalFirstTimeWarningContent({super.key, required this.onOk});

  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NsParentalDialogShell(
      title: l10n.parentalSetupTitle,
      subtitle: l10n.parentalSetupWarning,
      child: NsFocusable(
        autofocus: true,
        onActivate: onOk,
        builder: (c, f) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.parentalDialogSubmit,
              style: NsType.rowTitle.copyWith(
                color: NsColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Side menu: new + confirm (used from player) ──────────────────────

class NsParentalSideMenuCreateContent extends StatefulWidget {
  const NsParentalSideMenuCreateContent({
    super.key,
    required this.onValidPin,
    required this.onCancel,
  });

  /// [pin] is trimmed; caller shows warning, persists, and dismisses the route.
  final Future<void> Function(String pin) onValidPin;
  final VoidCallback onCancel;

  @override
  State<NsParentalSideMenuCreateContent> createState() =>
      _NsParentalSideMenuCreateContentState();
}

class _NsParentalSideMenuCreateContentState
    extends State<NsParentalSideMenuCreateContent> {
  String _newP = '';
  String _conf = '';
  int _field = 0;

  String get _activeStr => _field == 0 ? _newP : _conf;
  int get _activeLen => _activeStr.length;

  void _append(String d) {
    if (_activeStr.length >= 8) return;
    setState(() {
      if (_field == 0) {
        _newP += d;
      } else {
        _conf += d;
      }
    });
  }

  void _bs() {
    if (_activeStr.isEmpty) return;
    setState(() {
      if (_field == 0) {
        _newP = _newP.substring(0, _newP.length - 1);
      } else {
        _conf = _conf.substring(0, _conf.length - 1);
      }
    });
  }

  void _cl() {
    if (_activeStr.isEmpty) return;
    setState(() {
      if (_field == 0) {
        _newP = '';
      } else {
        _conf = '';
      }
    });
  }

  Future<void> _trySave() async {
    final l10n = AppLocalizations.of(context);
    final a = _newP.trim();
    final b = _conf.trim();
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
    if (!mounted) return;
    await widget.onValidPin(a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = NsDensity.of(context);
    return NsParentalDialogShell(
      title: l10n.parentalSetupTitle,
      subtitle: l10n.parentalSideMenuSetupBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NsFocusable(
            autofocus: true,
            onFocusedChange: (has) {
              if (has) setState(() => _field = 0);
            },
            onActivate: () => setState(() => _field = 0),
            builder: (c, f) => _FieldStrip(
              label: l10n.parentalSetupPinLabel,
              selected: _field == 0,
              focused: f,
              filled: _newP.length,
            ),
          ),
          const SizedBox(height: 6),
          NsFocusable(
            onFocusedChange: (has) {
              if (has) setState(() => _field = 1);
            },
            onActivate: () => setState(() => _field = 1),
            builder: (c, f) => _FieldStrip(
              label: l10n.parentalSetupConfirmLabel,
              selected: _field == 1,
              focused: f,
              filled: _conf.length,
            ),
          ),
          const SizedBox(height: 8),
          NsParentalPindots(filled: _activeLen, maxDots: 8),
          const SizedBox(height: 8),
          NsParentalNumpad(
            onDigit: _append,
            onBackspace: _bs,
            onClear: _cl,
          ),
          SizedBox(height: d.isCompact ? 10 : 12),
          Row(
            children: [
              Expanded(
                child: NsFocusable(
                  onActivate: () => unawaited(_trySave()),
                  builder: (c, f) => _PinRowAction(
                    label: l10n.parentalSideMenuSetupSave,
                    strong: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NsFocusable(
                  onActivate: widget.onCancel,
                  builder: (c, f) => _PinRowAction(
                    label: l10n.commonCancel,
                    strong: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldStrip extends StatelessWidget {
  const _FieldStrip({
    required this.label,
    required this.selected,
    required this.filled,
    this.focused = false,
  });
  final String label;
  final bool selected;
  final int filled;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (selected || focused)
            ? NsColors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (selected || focused)
              ? NsColors.accentLine
              : NsColors.line,
          width: focused && !selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label · $filled/8',
          style: NsType.rowSub.copyWith(
            color: (selected || focused) ? NsColors.text : NsColors.text3,
            fontSize: 11.5,
            fontWeight: (selected || focused) ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
