import 'package:flutter/material.dart';

import '../../data/parental_control_store.dart';
import '../../l10n/app_localizations.dart';
import '../new_settings/new_settings_palette.dart';
import '../new_settings/widgets/ns_focusable.dart';
import '../new_settings/widgets/ns_parental_pin_modals.dart';

/// Returns `true` if the user entered the correct PIN, `false` if cancelled or wrong.
Future<bool> showParentalPinVerifyDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  await parentalControlStore.ensureLoaded();
  if (!context.mounted) return false;
  if (!parentalControlStore.isPinConfigured) return true;

  final pin = await showParentalPinEntryDialog(
    context,
    title: l10n.parentalDialogEnterPin,
  );
  if (pin == null) return false;
  if (parentalControlStore.verifyPin(pin)) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.parentalPinWrong),
      ),
    );
  }
  return false;
}

/// Returns entered PIN string, or null if cancelled.
Future<String?> showParentalPinEntryDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
}) async {
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Theme(
      data: nsIslandThemeData(context),
      child: NsFocusAccentScope(
        overridePlatformGate: true,
        child: Dialog(
          alignment: Alignment.center,
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          child: NsParentalSinglePinContent(
            title: title,
            subtitle: subtitle,
            onSubmit: (p) => Navigator.of(ctx).pop(p),
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    ),
  );

  if (result == null || result.isEmpty) return null;
  if (!ParentalControlStore.isValidPinFormat(result)) return null;
  return result;
}

/// Live player side strip: compact first-time PIN (no full settings overlay).
/// Returns `true` if a PIN was created and saved.
Future<bool> showParentalSideMenuCreatePinDialog(BuildContext context) async {
  await parentalControlStore.ensureLoaded();
  if (!context.mounted) return false;
  if (parentalControlStore.isPinConfigured) return true;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Theme(
      data: nsIslandThemeData(context),
      child: NsFocusAccentScope(
        overridePlatformGate: true,
        child: Dialog(
          alignment: Alignment.center,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _ParentalSideMenuCreatePin(),
        ),
      ),
    ),
  );
  return ok == true;
}

class _ParentalSideMenuCreatePin extends StatelessWidget {
  const _ParentalSideMenuCreatePin();

  @override
  Widget build(BuildContext context) {
    return NsParentalSideMenuCreateContent(
      onCancel: () => Navigator.of(context).pop(false),
      onValidPin: (pin) => _onSideMenuValidPin(context, pin),
    );
  }

  Future<void> _onSideMenuValidPin(BuildContext context, String pin) async {
    await showParentalFirstTimePinSaveWarningDialog(context);
    if (!context.mounted) return;
    final ok = await parentalControlStore.setPin(pin);
    if (!context.mounted || !ok) return;
    await parentalControlStore.setEnabled(true);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }
}

/// Shown before saving a first-time PIN (same text as the legacy hub).
Future<void> showParentalFirstTimePinSaveWarningDialog(
  BuildContext context,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Theme(
      data: nsIslandThemeData(context),
      child: NsFocusAccentScope(
        overridePlatformGate: true,
        child: Dialog(
          alignment: Alignment.center,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: NsParentalFirstTimeWarningContent(
            onOk: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    ),
  );
}
