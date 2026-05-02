import 'package:flutter/material.dart';

import 'live_tv_appearance_editor_stack.dart';

/// **Live TV** appearance route (legacy settings): same stack as new settings
/// [LiveTvAppearanceEditorStack], wrapped in two-step system Back + scaffold.
class LiveTvEditScreen extends StatefulWidget {
  const LiveTvEditScreen({super.key});

  @override
  State<LiveTvEditScreen> createState() => _LiveTvEditScreenState();
}

class _LiveTvEditScreenState extends State<LiveTvEditScreen> {
  /// System **Back** is two-step ([PopScope]) so it does not leave on first press.
  var _exitArmed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_exitArmed) {
          setState(() => _exitArmed = true);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LiveTvAppearanceEditorStack(
          showRouteBackdrop: true,
          showTopHeaderBar: true,
          onExit: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
