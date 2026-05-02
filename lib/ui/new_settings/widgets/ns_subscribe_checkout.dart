/// Subscribe → Pay checkout modal.
///
/// 1:1 port of the HTML's `.modal.modal-checkout` (settings.html lines
/// 1568–1799) and its body template in `accSubscribe()` (lines 8932–9041).
///
/// Presents a full-width ported checkout sheet with:
///
///   * crown-icon header, eyebrow, plan name + badge, subtitle,
///   * summary rows (plan, billing period, subtotal, optional discount,
///     bold `TOTAL TODAY` row with per-month secondary label),
///   * `CHOOSE HOW TO PAY` section title,
///   * two pay cards side-by-side (stack on narrow):
///       1. Scan-with-phone card with a seeded fake QR + centered `TV` logo
///          and a caption,
///       2. Pay-on-this-device card (`FASTEST` pill) with a 6-cell payment
///          methods grid (VISA / MC / AMEX / Apple Pay / G Pay / PayPal)
///          and a primary `Pay $X.XX securely` CTA,
///   * a trust-bar footer (`256-bit encrypted · Cancel anytime · 14-day
///     money-back guarantee`) and a `Maybe later` cancel button,
///   * close (×) button at top-right.
///
/// Returns `true` when the user hits `Pay` (mock flow), `false` for
/// cancel/close/outside-tap/Back.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../account/account_api.dart';
import '../new_settings_data.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

Future<bool> showNsSubscribeCheckout(
  BuildContext context, {
  required NsAccPlan plan,
  required NsAccDuration duration,
  required String deviceIdSeed,
}) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Subscribe',
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a, b) => _CheckoutPage(
      plan: plan,
      duration: duration,
      seed: '${plan.id}|${duration.id}|$deviceIdSeed',
    ),
    transitionBuilder: (ctx, a, b, child) {
      // Match HTML `.modal.open` ease + a subtle scale.
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
  return r == true;
}

class _CheckoutPage extends StatefulWidget {
  const _CheckoutPage({
    required this.plan,
    required this.duration,
    required this.seed,
  });

  final NsAccPlan plan;
  final NsAccDuration duration;
  final String seed;

  @override
  State<_CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<_CheckoutPage> {
  /// Real Stripe checkout URL returned by `accountApi.createCheckout` —
  /// used as the QR payload and the launch target for the Pay CTA.
  /// Null while we're still fetching it / if the request failed.
  String? _checkoutUrl;

  /// Human-readable error message if `createCheckout` fails. Null when
  /// loading succeeded or is still in flight.
  String? _error;

  bool get _loading => _checkoutUrl == null && _error == null;

  @override
  void initState() {
    super.initState();
    // Fetch the real Stripe session URL up front so the QR area can show
    // a scannable code (not a decorative placeholder) and the Pay CTA
    // can launch it instantly — same command path as the old ACC
    // overlay's `_showStripeCheckout`.
    _fetchCheckoutUrl();
  }

  Future<void> _fetchCheckoutUrl() async {
    try {
      final result = await accountApi.createCheckout(
        widget.plan.id,
        durationId: widget.duration.id,
      );
      if (!mounted) return;
      final url = (result['url'] as String?) ?? '';
      if (url.isEmpty) {
        setState(() => _error = 'No checkout URL returned');
        return;
      }
      setState(() => _checkoutUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _pay() async {
    final url = _checkoutUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // Close on Esc / Back. [NsFocusAccentScope] — dialog route is outside the
    // main new-settings body; scope enables orange TV focus on CTAs and ×.
    return NsFocusAccentScope(
      enabled: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(false),
        },
        child: Focus(
          autofocus: true,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: _CheckoutCard(
                      plan: widget.plan,
                      duration: widget.duration,
                      seed: widget.seed,
                      checkoutUrl: _checkoutUrl,
                      loading: _loading,
                      error: _error,
                      onPay: _pay,
                      onRetry: () {
                        setState(() {
                          _checkoutUrl = null;
                          _error = null;
                        });
                        _fetchCheckoutUrl();
                      },
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

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.plan,
    required this.duration,
    required this.seed,
    required this.checkoutUrl,
    required this.loading,
    required this.error,
    required this.onPay,
    required this.onRetry,
  });

  final NsAccPlan plan;
  final NsAccDuration duration;
  final String seed;
  final String? checkoutUrl;
  final bool loading;
  final String? error;
  final VoidCallback onPay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final price = nsAccPriceCombo(plan.baseCents, duration);
    final subtotalCents = plan.baseCents * duration.months;
    final subtotalStr = '\$${(subtotalCents / 100).toStringAsFixed(2)}';
    final discountPct = duration.discount > 0
        ? '${(duration.discount * 100).round()}%'
        : null;
    // `total today` (post-discount) — same formula as the HTML
    // `price.monthly * duration.months` then formatted.
    final discounted = plan.baseCents * (1 - duration.discount);
    final totalTodayCents = discounted * duration.months;
    final totalTodayStr =
        '\$${(totalTodayCents / 100).toStringAsFixed(2)}';
    // Per-month label shown in the big total row — the HTML uses the
    // same monthly string as on the card.
    final perMonth = price.monthly;
    final payCtaLabel = 'Pay $totalTodayStr securely';

    // Base gradient background — ports the two radial-gradient overlays
    // from `.modal-checkout`.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NsColors.line2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            offset: Offset(0, 22),
            blurRadius: 48,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Top-right accent-cyan wash.
            Positioned(
              top: -80,
              right: -120,
              child: Container(
                width: 520,
                height: 220,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [NsColors.accentGlow, Color(0x00000000)],
                    radius: 0.9,
                  ),
                ),
              ),
            ),
            // Top-left indigo wash.
            Positioned(
              top: -50,
              left: -80,
              child: Container(
                width: 440,
                height: 180,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x1A7AA2F7), Color(0x007AA2F7)],
                    radius: 0.95,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Head(plan: plan, duration: duration),
                _Body(
                  plan: plan,
                  duration: duration,
                  seed: seed,
                  subtotalStr: subtotalStr,
                  discountPct: discountPct,
                  totalTodayStr: totalTodayStr,
                  perMonthStr: perMonth,
                  payCtaLabel: payCtaLabel,
                  checkoutUrl: checkoutUrl,
                  loading: loading,
                  error: error,
                  onPay: onPay,
                  onRetry: onRetry,
                ),
                _Foot(),
              ],
            ),
            // Close (×) button — absolute top-right.
            Positioned(
              top: 10,
              right: 10,
              child: _CloseButton(
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Head — crown icon, eyebrow, plan name + badge, subtitle.
// ═══════════════════════════════════════════════════════════════════════

class _Head extends StatelessWidget {
  const _Head({required this.plan, required this.duration});
  final NsAccPlan plan;
  final NsAccDuration duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 46, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crown icon tile — HTML `.co-ico` (42×42, accent soft fill,
          // accent line border, cyan crown, soft drop shadow).
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.accentSoft,
              border: Border.all(color: NsColors.accentLine),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: NsColors.accentGlow,
                  offset: Offset(0, 5),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: NsColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow: `● SUBSCRIBE`
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: NsColors.accent,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'SUBSCRIBE',
                      style: TextStyle(
                        color: NsColors.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        fontFamily: 'monospace',
                        height: 1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Plan name + badge.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        color: NsColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (plan.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _alpha(plan.accent, 0.13),
                          border: Border.all(
                            color: _alpha(plan.accent, 0.33),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          plan.badge!,
                          style: TextStyle(
                            color: plan.accent,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlock everything in ${plan.name} for '
                  '${duration.label.toLowerCase()}.',
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 11.5,
                    height: 1.35,
                    decoration: TextDecoration.none,
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

// ═══════════════════════════════════════════════════════════════════════
//  Body — summary rows + pay grid.
// ═══════════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  const _Body({
    required this.plan,
    required this.duration,
    required this.seed,
    required this.subtotalStr,
    required this.discountPct,
    required this.totalTodayStr,
    required this.perMonthStr,
    required this.payCtaLabel,
    required this.checkoutUrl,
    required this.loading,
    required this.error,
    required this.onPay,
    required this.onRetry,
  });

  final NsAccPlan plan;
  final NsAccDuration duration;
  final String seed;
  final String subtotalStr;
  final String? discountPct;
  final String totalTodayStr;
  final String perMonthStr;
  final String payCtaLabel;
  final String? checkoutUrl;
  final bool loading;
  final String? error;
  final VoidCallback onPay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryBlock(
            planName: plan.name,
            duration: duration,
            subtotalStr: subtotalStr,
            discountPct: discountPct,
            totalTodayStr: totalTodayStr,
            perMonthStr: perMonthStr,
          ),
          const SizedBox(height: 12),
          const _SectionTitle('CHOOSE HOW TO PAY'),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              // Stack pay cards below ~520 px (TV narrow / phone portrait)
              // matching HTML `@media (max-width:560px)`.
              final stacked = constraints.maxWidth < 520;
              final qrCard = _QrCard(
                seed: seed,
                checkoutUrl: checkoutUrl,
                loading: loading,
                error: error,
                onRetry: onRetry,
              );
              final payCard = _PayDeviceCard(
                ctaLabel: payCtaLabel,
                onPay: onPay,
                enabled: checkoutUrl != null,
                loading: loading,
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    qrCard,
                    const SizedBox(height: 8),
                    payCard,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 100, child: qrCard),
                    const SizedBox(width: 10),
                    Expanded(flex: 115, child: payCard),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: NsColors.text3,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ─── Summary rows ─────────────────────────────────────────────────────

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.planName,
    required this.duration,
    required this.subtotalStr,
    required this.discountPct,
    required this.totalTodayStr,
    required this.perMonthStr,
  });

  final String planName;
  final NsAccDuration duration;
  final String subtotalStr;
  final String? discountPct;
  final String totalTodayStr;
  final String perMonthStr;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _SumRow(label: 'Plan', value: planName),
      _SumRow(
        label: 'Billing period',
        value: '${duration.label} (${duration.months}× monthly)',
      ),
      _SumRow(label: 'Subtotal', value: subtotalStr),
      if (discountPct != null)
        _SumRow(
          label: 'Discount',
          value: '−$discountPct off',
          valueColor: NsColors.success,
          valueWeight: FontWeight.w700,
        ),
      _TotalRow(total: totalTodayStr, perMonth: perMonthStr),
    ];
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i != 0) {
        children.add(const Divider(
          height: 1,
          thickness: 1,
          color: NsColors.line,
        ));
      }
      children.add(rows[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? valueWeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? NsColors.text,
              fontSize: 11,
              fontWeight: valueWeight ?? FontWeight.w600,
              height: 1.3,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total, required this.perMonth});
  final String total;
  final String perMonth;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x05FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Expanded(
            child: Text(
              'TOTAL TODAY',
              style: TextStyle(
                color: NsColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Text(
            total,
            style: const TextStyle(
              color: NsColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            perMonth,
            style: const TextStyle(
              color: NsColors.text3,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pay cards ────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.seed,
    required this.checkoutUrl,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final String seed;
  final String? checkoutUrl;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final caption = error != null
        ? 'Could not generate QR. Tap retry or use "Pay on this device".'
        : (loading
            ? 'Generating secure payment link…'
            : 'Open your camera and point it at the code to pay on your phone.');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PayHead(step: '1', title: 'Scan with phone'),
          const SizedBox(height: 8),
          Center(
            child: _QrFrame(
              seed: seed,
              checkoutUrl: checkoutUrl,
              loading: loading,
              error: error,
              onRetry: onRetry,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: error != null ? NsColors.danger : NsColors.text3,
              fontSize: 10,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayDeviceCard extends StatelessWidget {
  const _PayDeviceCard({
    required this.ctaLabel,
    required this.onPay,
    required this.enabled,
    required this.loading,
  });
  final String ctaLabel;
  final VoidCallback onPay;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.accentLine),
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: NsColors.accentSoft,
            spreadRadius: 1,
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PayHead(step: '2', title: 'Pay on this device', recPill: 'FASTEST'),
          const SizedBox(height: 8),
          const _PayMethodGrid(),
          const SizedBox(height: 8),
          _PayCtaButton(
            label: ctaLabel,
            enabled: enabled,
            loading: loading,
            onPressed: onPay,
          ),
          const SizedBox(height: 6),
          const Text(
            "You'll be redirected to our payment processor.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 10,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayHead extends StatelessWidget {
  const _PayHead({required this.step, required this.title, this.recPill});
  final String step;
  final String title;
  final String? recPill;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NsColors.accentSoft,
            border: Border.all(color: NsColors.accentLine),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: NsColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: NsColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.05,
              height: 1,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (recPill != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: NsColors.accentSoft,
              border: Border.all(color: NsColors.accentLine),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              recPill!,
              style: const TextStyle(
                color: NsColors.accent,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
      ],
    );
  }
}

// Six payment methods in a 3-column grid with HTML-exact colors.
class _PayMethodGrid extends StatelessWidget {
  const _PayMethodGrid();
  @override
  Widget build(BuildContext context) {
    const items = [
      _PmSpec.visa,
      _PmSpec.mc,
      _PmSpec.amex,
      _PmSpec.apple,
      _PmSpec.gpay,
      _PmSpec.paypal,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 5.0;
        const cols = 3;
        final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in items)
              SizedBox(
                width: cellW,
                height: 26,
                child: _PmCell(spec: p),
              ),
          ],
        );
      },
    );
  }
}

enum _PmSpec { visa, mc, amex, apple, gpay, paypal }

class _PmCell extends StatelessWidget {
  const _PmCell({required this.spec});
  final _PmSpec spec;

  @override
  Widget build(BuildContext context) {
    // HTML definitions from settings.html lines 1756–1761.
    switch (spec) {
      case _PmSpec.visa:
        return _plainBg(
          color: Colors.white,
          child: const Text(
            'VISA',
            style: TextStyle(
              color: Color(0xFF1A1F71),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
        );
      case _PmSpec.mc:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.5, 0.5],
              colors: [Color(0xFFEB001B), Color(0xFFF79E1B)],
            ),
          ),
          child: const Center(
            child: Text(
              'MC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      case _PmSpec.amex:
        return _plainBg(
          color: const Color(0xFF006FCF),
          child: const Text(
            'AMEX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
        );
      case _PmSpec.apple:
        return _plainBg(
          color: Colors.black,
          border: const Color(0x26FFFFFF),
          child: const Text(
            'Apple Pay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              decoration: TextDecoration.none,
            ),
          ),
        );
      case _PmSpec.gpay:
        return _plainBg(
          color: Colors.white,
          child: const Text(
            'G Pay',
            style: TextStyle(
              color: Color(0xFF5F6368),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              decoration: TextDecoration.none,
            ),
          ),
        );
      case _PmSpec.paypal:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF003087), Color(0xFF009CDE)],
            ),
          ),
          child: const Center(
            child: Text(
              'PayPal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
    }
  }

  Widget _plainBg({
    required Color color,
    Color? border,
    required Widget child,
  }) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: border != null
            ? Border.all(color: border)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class _PayCtaButton extends StatelessWidget {
  const _PayCtaButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: enabled ? onPressed : () {},
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: NsEase.ease,
        height: 38,
        decoration: BoxDecoration(
          // Dim the gradient while we're still waiting on the Stripe URL
          // from the backend so the button reads as "not ready yet".
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? const [Color(0xFF6BE3F0), NsColors.accent]
                : const [NsColors.surface2, NsColors.surface2],
          ),
          border: Border.all(
            color: enabled ? Colors.transparent : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (enabled)
              const BoxShadow(
                color: NsColors.accentGlow,
                offset: Offset(0, 7),
                blurRadius: 18,
              ),
            if (focused && enabled)
              const BoxShadow(
                color: NsColors.accentSoft,
                spreadRadius: 3,
                blurRadius: 0,
              ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NsColors.accent,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: enabled
                          ? const Color(0xFF001317)
                          : NsColors.text3,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? const Color(0xFF001317)
                            : NsColors.text3,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.05,
                        height: 1,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Footer — trust bar + `Maybe later` cancel.
// ═══════════════════════════════════════════════════════════════════════

class _Foot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: const BoxDecoration(
        color: NsColors.bg2,
        border: Border(top: BorderSide(color: NsColors.line)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 12,
            color: NsColors.success,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: NsColors.text3,
                  fontSize: 10.5,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
                children: [
                  TextSpan(
                    text: '256-bit encrypted',
                    style: TextStyle(
                      color: NsColors.text2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' · Cancel anytime · 14-day money-back guarantee',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _CancelButton(
            label: 'Maybe later',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: focused ? NsColors.text : NsColors.text3,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: 'Close',
      focusAccentRadius: 7,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? NsColors.surface : NsColors.surface2,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 14,
          color: focused ? NsColors.text : NsColors.text3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Fake QR code — 1:1 port of `buildFakeQR(seedStr)` from settings.html
//  lines 8886–8929. Deterministic 25×25 grid seeded from the seed string.
// ═══════════════════════════════════════════════════════════════════════

class _QrFrame extends StatelessWidget {
  const _QrFrame({
    required this.seed,
    required this.checkoutUrl,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final String seed;
  final String? checkoutUrl;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Three visual states for the QR area:
    //   * URL ready  → real `QrImageView` of the Stripe URL (same as
    //     the old ACC overlay's `_showQrCheckoutDialog`).
    //   * loading    → white tile with a spinner and the fake-QR
    //     placeholder dimmed behind, so the layout doesn't jump.
    //   * error      → white tile with a warning icon + retry button.
    final hasUrl = checkoutUrl != null && checkoutUrl!.isNotEmpty;
    return Container(
      width: 140,
      height: 140,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        children: [
          if (hasUrl)
            Positioned.fill(
              child: QrImageView(
                data: checkoutUrl!,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  color: Colors.black,
                  eyeShape: QrEyeShape.square,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  color: Colors.black,
                  dataModuleShape: QrDataModuleShape.square,
                ),
              ),
            )
          else
            Positioned.fill(
              child: Opacity(
                opacity: error != null ? 0.0 : 0.35,
                child: CustomPaint(
                  painter: _FakeQrPainter(seed: seed),
                ),
              ),
            ),
          if (loading && !hasUrl)
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: NsColors.accent,
                ),
              ),
            ),
          if (error != null && !hasUrl)
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: NsColors.danger,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    NsFocusable(
                      onActivate: onRetry,
                      semanticLabel: 'Retry',
                      builder: (context, focused) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: focused
                              ? NsColors.accentSoft
                              : const Color(0xFFEFEFEF),
                          border: Border.all(
                            color: focused
                                ? NsColors.accentLine
                                : const Color(0xFFD4D4D8),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Center `TV` logo — overlays the QR like the HTML reference.
          // Only shown when we have a real QR (logo over a placeholder
          // is distracting) OR no error.
          if (hasUrl)
            Center(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [NsColors.accent, Color(0xFF7AA2F7)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      offset: Offset(0, 3),
                      blurRadius: 9,
                    ),
                  ],
                ),
                child: const Text(
                  'TV',
                  style: TextStyle(
                    color: Color(0xFF001317),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FakeQrPainter extends CustomPainter {
  _FakeQrPainter({required this.seed});
  final String seed;

  static const int _kSize = 25;

  @override
  void paint(Canvas canvas, Size size) {
    // HTML seeding: cumulative hash then LCG(1664525, 1013904223).
    int s = 0;
    for (var i = 0; i < seed.length; i++) {
      s = (s * 33 + seed.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    double rand() {
      s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
      return (s & 0xFFFF) / 0xFFFF;
    }

    bool inMarker(int r, int c, int rr, int cc) =>
        r >= rr && r < rr + 7 && c >= cc && c < cc + 7;
    List<int>? markerOf(int r, int c) {
      const corners = [
        [0, 0],
        [0, _kSize - 7],
        [_kSize - 7, 0],
      ];
      for (final m in corners) {
        if (inMarker(r, c, m[0], m[1])) return m;
      }
      return null;
    }

    bool inAlign(int r, int c) {
      const ar = _kSize - 9;
      const ac = _kSize - 9;
      return r >= ar && r < ar + 5 && c >= ac && c < ac + 5;
    }

    bool inCenterClear(int r, int c) {
      const cMin = (_kSize ~/ 2) - 2;
      const cMax = cMin + 4;
      return r >= cMin && r <= cMax && c >= cMin && c <= cMax;
    }

    final paint = Paint()..color = const Color(0xFF0D1119);
    final cell = size.width / _kSize;

    for (var r = 0; r < _kSize; r++) {
      for (var c = 0; c < _kSize; c++) {
        var on = false;
        final m = markerOf(r, c);
        if (m != null) {
          final lr = r - m[0], lc = c - m[1];
          final onMarker = (lr == 0 || lr == 6 || lc == 0 || lc == 6) ||
              (lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4);
          on = onMarker;
        } else if (inAlign(r, c)) {
          final ar = _kSize - 9, ac = _kSize - 9;
          final lr = r - ar, lc = c - ac;
          final onAlign = (lr == 0 || lr == 4 || lc == 0 || lc == 4) ||
              (lr == 2 && lc == 2);
          on = onAlign;
        } else if (inCenterClear(r, c)) {
          on = false;
        } else {
          on = rand() > 0.5;
        }
        if (on) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FakeQrPainter old) => old.seed != seed;
}

Color _alpha(Color c, double a) => c.withAlpha((a * 255).round());
