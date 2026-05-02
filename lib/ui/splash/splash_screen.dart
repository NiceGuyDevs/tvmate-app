import 'dart:async';

import 'package:flutter/material.dart';

import '../../account/access_gate.dart';
import '../../data/performance_tier_store.dart';
import '../../shell/main_shell_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';

/// Wide splash art (full logo). Falls back to main brand PNG if missing.
const String _kSplashAsset = 'assets/images/splash_logo.png';
const String _kFallbackBrandAsset = 'assets/images/tvmate_logo.png';

/// Launch experience: black screen, large logo (same as first paint), spinner on top.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final Duration _handoffDelay;
  late final AnimationController _anim;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  Timer? _handoffTimer;

  @override
  void initState() {
    super.initState();
    final opt = performanceTierStore.isOptimizedEffective;
    _handoffDelay = Duration(milliseconds: opt ? 1600 : 2200);
    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: opt ? 900 : 1400),
    );
    _opacity = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _anim.forward();
    _handoffTimer = Timer(_handoffDelay, _runAccessGate);
  }

  Future<void> _runAccessGate() async {
    if (!mounted) return;
    await accessGate.check();
    if (!mounted) return;
    _goToShell();
  }

  void _goToShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MainShellScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _handoffTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.teamPalette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: 720,
                  height: 240,
                  child: Image.asset(
                    _kSplashAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        _kFallbackBrandAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, _, __) => _LogoFallback(),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: chrome.brandCyan.withOpacity(0.9),
                  backgroundColor: chrome.brandCyan.withOpacity(0.12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chrome = context.teamPalette;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.focusBorderRadius),
        border: Border.all(
          color: chrome.brandCyan.withOpacity(0.6),
          width: 2,
        ),
        color: chrome.surfaceElevated,
      ),
      child: Text(
        'TVMate.Pro',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 28,
              color: chrome.brandCyan,
              letterSpacing: 4,
            ),
      ),
    );
  }
}
