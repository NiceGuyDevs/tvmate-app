import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/focus/tv_focusable.dart';
import '../ui/new_settings/new_settings_theme.dart';
import 'account_store.dart';

/// Shows a dialog listing all registered devices when the user hits the device
/// limit during login/register. Returns the deviceId the user chose to remove,
/// or null if they cancelled.
///
/// Visually aligned with [`ns_auth_modal.dart`] — cyan accent, dark surface,
/// rounded icon tile with glow, sleek cyan gradient primary CTA. Adapts
/// width/height to the viewport so it never overflows on Google TV Streamer,
/// NVIDIA Shield, Chromecast or small PC windows.
Future<String?> showDeviceLimitDialog(
  BuildContext context, {
  required List<dynamic> devices,
  required int deviceLimit,
}) {
  return showGeneralDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Device limit',
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a, b) => _DeviceLimitPage(
      devices: devices,
      deviceLimit: deviceLimit,
    ),
    transitionBuilder: (ctx, a, b, child) {
      final curved = CurvedAnimation(parent: a, curve: NsEase.ease);
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.96 + 0.04 * curved.value,
          child: child,
        ),
      );
    },
  );
}

class _DeviceLimitPage extends StatefulWidget {
  final List<dynamic> devices;
  final int deviceLimit;
  const _DeviceLimitPage({
    required this.devices,
    required this.deviceLimit,
  });

  @override
  State<_DeviceLimitPage> createState() => _DeviceLimitPageState();
}

class _DeviceLimitPageState extends State<_DeviceLimitPage> {
  String? _selectedId;

  void _pop([String? value]) => Navigator.of(context).pop(value);

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _pop(null),
      },
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sw = MediaQuery.sizeOf(context).width;
              final sh = MediaQuery.sizeOf(context).height;
              final maxW = math.min(560.0, sw * 0.88);
              final maxH = math.min(720.0, sh * 0.88);
              final narrow = maxW < 460;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: _DialogCard(
                      devices: widget.devices,
                      deviceLimit: widget.deviceLimit,
                      selectedId: _selectedId,
                      onSelect: (id) => setState(() => _selectedId = id),
                      onCancel: () => _pop(null),
                      onConfirm: () => _pop(_selectedId),
                      onUpgrade: () => _pop(null),
                      formatDate: _formatDate,
                      narrow: narrow,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.devices,
    required this.deviceLimit,
    required this.selectedId,
    required this.onSelect,
    required this.onCancel,
    required this.onConfirm,
    required this.onUpgrade,
    required this.formatDate,
    required this.narrow,
  });

  final List<dynamic> devices;
  final int deviceLimit;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onUpgrade;
  final String Function(String) formatDate;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NsColors.line2),
        boxShadow: NsShadow.s2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned(
              top: -80,
              right: -120,
              child: _CornerGlow(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Head(deviceLimit: deviceLimit),
                  const SizedBox(height: 14),
                  Flexible(
                    child: _DeviceList(
                      devices: devices,
                      selectedId: selectedId,
                      onSelect: onSelect,
                      formatDate: formatDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: NsColors.line),
                  const SizedBox(height: 12),
                  _Footer(
                    narrow: narrow,
                    canConfirm: selectedId != null,
                    onCancel: onCancel,
                    onConfirm: onConfirm,
                    onUpgrade: onUpgrade,
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

class _CornerGlow extends StatelessWidget {
  const _CornerGlow();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      height: 200,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [NsColors.accentGlow, Color(0x00000000)],
          radius: 0.9,
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.deviceLimit});
  final int deviceLimit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NsColors.accentSoft,
            border: Border.all(color: NsColors.accentLine),
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                color: NsColors.accentGlow,
                offset: Offset(0, 5),
                blurRadius: 14,
              ),
            ],
          ),
          child: const Icon(
            Icons.devices_other_rounded,
            color: NsColors.accent,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Device Limit Reached',
                style: TextStyle(
                  color: NsColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  height: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'You have $deviceLimit devices linked to this account. '
                'Remove one to sign in on this device.',
                style: const TextStyle(
                  color: NsColors.text3,
                  fontSize: 11,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.selectedId,
    required this.onSelect,
    required this.formatDate,
  });

  final List<dynamic> devices;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String Function(String) formatDate;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: Scrollbar(
        thumbVisibility: false,
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: devices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final dev = devices[index] as Map<String, dynamic>;
            final deviceId = dev['deviceId']?.toString() ?? '';
            final rawLabel = dev['label'];
            final deviceKey = dev['deviceKey']?.toString();
            final label = (rawLabel != null &&
                    rawLabel.toString().trim().isNotEmpty)
                ? rawLabel.toString()
                : (deviceKey != null && deviceKey.length >= 8
                    ? deviceKey.substring(0, 8)
                    : 'Unknown device');
            final lastSeen = dev['lastSeenAt'];
            final isCurrent = deviceId == accountStore.deviceId;
            final isSelected = selectedId == deviceId;

            // Autofocus the first row that's not the current device.
            final firstSelectable = !isCurrent &&
                devices.take(index).every((d) =>
                    (d as Map<String, dynamic>)['deviceId']?.toString() ==
                    accountStore.deviceId);

            return _DeviceRow(
              label: label,
              lastSeen: lastSeen?.toString(),
              isCurrent: isCurrent,
              isSelected: isSelected,
              autofocus: firstSelectable,
              onTap: isCurrent ? null : () => onSelect(deviceId),
              formatDate: formatDate,
            );
          },
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.label,
    required this.lastSeen,
    required this.isCurrent,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
    required this.formatDate,
  });

  final String label;
  final String? lastSeen;
  final bool isCurrent;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback? onTap;
  final String Function(String) formatDate;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      focusPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      focusScale: 1.0,
      parallaxSlide: 0,
      showFocusElevation: false,
      focusedBorderWidth: 1.4,
      canRequestFocus: !isCurrent,
      onActivate: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? NsColors.accentSoft : NsColors.surface2,
          border: Border.all(
            color: isSelected
                ? NsColors.accentLine
                : (isCurrent ? NsColors.accentSoft : NsColors.line),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: NsColors.accentSoft,
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected
                  ? NsColors.accent
                  : (isCurrent ? NsColors.text4 : NsColors.text3),
              size: 18,
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.tv_rounded,
              color: isCurrent ? NsColors.accent : NsColors.text2,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? NsColors.text3
                                : NsColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: NsColors.accentSoft,
                            border:
                                Border.all(color: NsColors.accentLine),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'THIS DEVICE',
                            style: TextStyle(
                              color: NsColors.accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              height: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (lastSeen != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Last active: ${formatDate(lastSeen!)}',
                      style: const TextStyle(
                        color: NsColors.text4,
                        fontSize: 10.5,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.narrow,
    required this.canConfirm,
    required this.onCancel,
    required this.onConfirm,
    required this.onUpgrade,
  });

  final bool narrow;
  final bool canConfirm;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final cancelBtn = _GhostButton(
      label: 'Cancel',
      onPressed: onCancel,
      fullWidth: narrow,
      order: 10,
    );
    final confirmBtn = _PrimaryButton(
      label: 'Remove & Sign In',
      enabled: canConfirm,
      onPressed: canConfirm ? onConfirm : null,
      fullWidth: narrow,
      order: 11,
    );
    final upgradeLink = _UpgradeLink(onPressed: onUpgrade, order: 12);

    if (narrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          confirmBtn,
          const SizedBox(height: 8),
          cancelBtn,
          const SizedBox(height: 10),
          Center(child: upgradeLink),
        ],
      );
    }

    return Row(
      children: [
        upgradeLink,
        const Spacer(),
        cancelBtn,
        const SizedBox(width: 10),
        confirmBtn,
      ],
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.fullWidth,
    required this.order,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final int order;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  final FocusNode _node = FocusNode(debugLabel: 'deviceLimit:confirm');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btn = TvFocusable(
      focusNode: _node,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      parallaxSlide: 0,
      showFocusElevation: false,
      focusedBorderWidth: 1.4,
      canRequestFocus: widget.enabled,
      onActivate: widget.enabled ? widget.onPressed : null,
      child: _PrimaryButtonSurface(
        label: widget.label,
        enabled: widget.enabled,
        onPressed: widget.onPressed,
      ),
    );
    final sized = widget.fullWidth
        ? SizedBox(width: double.infinity, child: btn)
        : btn;
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order.toDouble()),
      child: sized,
    );
  }
}

class _PrimaryButtonSurface extends StatelessWidget {
  const _PrimaryButtonSurface({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: NsEase.ease,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6BE3F0), NsColors.accent],
                  )
                : null,
            color: enabled ? null : NsColors.surface3,
            borderRadius: BorderRadius.circular(10),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: NsColors.accentGlow,
                      offset: Offset(0, 7),
                      blurRadius: 18,
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF001317)
                    : NsColors.text3,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.05,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  const _GhostButton({
    required this.label,
    required this.onPressed,
    required this.fullWidth,
    required this.order,
  });

  final String label;
  final VoidCallback onPressed;
  final bool fullWidth;
  final int order;

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  final FocusNode _node = FocusNode(debugLabel: 'deviceLimit:cancel');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btn = TvFocusable(
      focusNode: _node,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      parallaxSlide: 0,
      showFocusElevation: false,
      focusedBorderWidth: 1.4,
      onActivate: widget.onPressed,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: NsEase.ease,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: NsColors.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final sized = widget.fullWidth
        ? SizedBox(width: double.infinity, child: btn)
        : btn;
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order.toDouble()),
      child: sized,
    );
  }
}

class _UpgradeLink extends StatefulWidget {
  const _UpgradeLink({required this.onPressed, required this.order});
  final VoidCallback onPressed;
  final int order;

  @override
  State<_UpgradeLink> createState() => _UpgradeLinkState();
}

class _UpgradeLinkState extends State<_UpgradeLink> {
  final FocusNode _node = FocusNode(debugLabel: 'deviceLimit:upgrade');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    if (!mounted) return;
    final now = _node.hasFocus;
    if (_focused != now) setState(() => _focused = now);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order.toDouble()),
      child: TvFocusable(
        focusNode: _node,
        focusPadding: EdgeInsets.zero,
        focusScale: 1.0,
        parallaxSlide: 0,
        showFocusElevation: false,
        focusedBorderWidth: 1.4,
        onActivate: widget.onPressed,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Text(
                'Upgrade For Extra Devices',
                style: TextStyle(
                  color:
                      _focused ? NsColors.accent2 : NsColors.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  decoration: TextDecoration.underline,
                  decorationColor:
                      _focused ? NsColors.accent2 : NsColors.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
