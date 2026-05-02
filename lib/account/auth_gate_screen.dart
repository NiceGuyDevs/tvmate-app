import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Shown when the user isn't logged in.
/// After successful login/register, always proceeds to the main shell
/// regardless of subscription status.
class AuthGateScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final bool startOnRegister;
  const AuthGateScreen({super.key, required this.onAuthenticated, this.startOnRegister = false});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  late bool _showRegister;

  @override
  void initState() {
    super.initState();
    _showRegister = widget.startOnRegister;
  }

  void _onAuthSuccess() {
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(
        onSuccess: _onAuthSuccess,
        onLogin: () => setState(() { _showRegister = false; }),
      );
    }
    return LoginScreen(
      onSuccess: _onAuthSuccess,
      onRegister: () => setState(() { _showRegister = true; }),
    );
  }
}
