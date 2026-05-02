/// Small primitives shared by the Manage groups + Manage channels
/// pages. All 1:1 with `settings.html`:
///
///   * [NsChipBtn]   — `.chip-btn` (default / accent / danger variants).
///   * [NsTag]       — `.alias-tag` / `.before-tag` (accent cyan pill).
///   * [NsHiddenTag] — `.hidden-tag` (warn-yellow pill).
///   * [NsVisPill]   — `.vis-pill` toggle (30×18 compact).
///   * [NsInlineEdit] — `.inline-edit` rename / URL panel with Save /
///     Cancel / (optional) Reset actions.
///
/// Tightened for TV density compared to the HTML (HTML targets desktop
/// at 1× text). Sizes picked so every label still reads at typical
/// viewing distance.
library;

import 'package:flutter/material.dart';

import '../new_settings_theme.dart';
import 'ns_focusable.dart';

// ═══════════════════════════════════════════════════════════════════════
//  ChipBtn — tiny icon-label button used inside compact rows / cards.
//  HTML `.chip-btn` (settings.html 3139). Padding 6/9 in HTML; 8/5 here.
// ═══════════════════════════════════════════════════════════════════════

enum NsChipVariant { defaultVariant, accent, danger }

class NsChipBtn extends StatelessWidget {
  const NsChipBtn({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.variant = NsChipVariant.defaultVariant,
    this.tooltip,
    this.focusNode,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final NsChipVariant variant;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final child = NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: tooltip ?? label,
      focusAccentRadius: 6,
      builder: (context, focused) {
        final (Color bg, Color border, Color fg) =
            _colorsFor(variant, focused);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: TextStyle(
                    color: fg,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }

  static (Color bg, Color border, Color fg) _colorsFor(
    NsChipVariant v,
    bool focused,
  ) {
    switch (v) {
      case NsChipVariant.accent:
        return (
          NsColors.accentSoft,
          NsColors.accentLine,
          NsColors.accent,
        );
      case NsChipVariant.danger:
        return (
          const Color(0x14F87171),
          const Color(0x40F87171),
          NsColors.danger,
        );
      case NsChipVariant.defaultVariant:
        return (
          focused ? NsColors.surface2 : NsColors.bg2,
          focused ? NsColors.line2 : NsColors.line,
          focused ? NsColors.text : NsColors.text2,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  NsTag — accent cyan label pill (`.alias-tag` / `.before-tag`).
// ═══════════════════════════════════════════════════════════════════════

class NsTag extends StatelessWidget {
  const NsTag({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: NsColors.accentSoft,
        border: Border.all(color: NsColors.accentLine),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NsColors.accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// `.hidden-tag` — warn-yellow variant used on hidden channels.
class NsHiddenTag extends StatelessWidget {
  const NsHiddenTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x1AFBBF24),
        border: Border.all(color: const Color(0x59FBBF24)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'HIDDEN',
        style: TextStyle(
          color: NsColors.warn,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  NsVisPill — visibility toggle pill (`.vis-pill`).
// ═══════════════════════════════════════════════════════════════════════

class NsVisPill extends StatelessWidget {
  const NsVisPill({
    super.key,
    required this.on,
    required this.onPressed,
    this.focusNode,
  });
  final bool on;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: on ? 'Visible' : 'Hidden',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: NsEase.ease,
        width: 30,
        height: 18,
        decoration: BoxDecoration(
          color: on ? NsColors.accent : NsColors.line2,
          borderRadius: BorderRadius.circular(999),
          boxShadow: focused
              ? const [
                  BoxShadow(
                    color: NsColors.accentSoft,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: NsEase.ease,
              top: 2,
              left: on ? 14 : 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: on ? Colors.white : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  NsInlineEdit — `.inline-edit` rename panel (accent border, bg-2).
//  Generic: caller supplies the label, placeholder / help, and the
//  Save / Cancel / Reset callbacks.
// ═══════════════════════════════════════════════════════════════════════

class NsInlineEdit extends StatelessWidget {
  const NsInlineEdit({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.helpText,
    required this.onSave,
    required this.onCancel,
    this.keyboardType,
    this.onReset,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final String helpText;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final TextInputType? keyboardType;

  /// When non-null, a "Reset" chip is shown that clears the override.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: NsColors.bg2,
          border: Border.all(color: NsColors.accentLine),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSave(),
              style: const TextStyle(
                color: NsColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.15,
                decoration: TextDecoration.none,
              ),
              cursorColor: NsColors.accent,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: NsColors.bg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                hintText: placeholder,
                hintStyle: const TextStyle(
                  color: NsColors.text4,
                  fontSize: 11.5,
                  decoration: TextDecoration.none,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: NsColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: NsColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide:
                      const BorderSide(color: NsColors.accentLine),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              helpText,
              style: const TextStyle(
                color: NsColors.text4,
                fontSize: 10.5,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                NsChipBtn(
                  icon: Icons.check_rounded,
                  label: 'Save',
                  variant: NsChipVariant.accent,
                  onPressed: onSave,
                ),
                NsChipBtn(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onPressed: onCancel,
                ),
                if (onReset != null)
                  NsChipBtn(
                    icon: Icons.restart_alt_rounded,
                    label: 'Reset',
                    variant: NsChipVariant.danger,
                    onPressed: onReset!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
