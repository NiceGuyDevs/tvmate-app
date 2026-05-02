import 'package:flutter/material.dart';

import '../data/team_visual_store.dart';
import 'ember_field_backdrop.dart';
import 'nocturne_field_backdrop.dart';
import 'settings_style_backdrop.dart';

/// Full-screen shell backdrop for the active [AppVisualTeam].
class TeamShellBackdrop extends StatelessWidget {
  const TeamShellBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: teamVisualStore,
      builder: (context, _) {
        final team = teamVisualStore.team;
        if (team == AppVisualTeam.settingsStyle) {
          return const SettingsStyleBackdrop();
        }
        if (team == AppVisualTeam.ember) {
          return const EmberFieldBackdrop();
        }
        if (team == AppVisualTeam.nocturne) {
          return const NocturneFieldBackdrop();
        }
        return const SettingsStyleBackdrop();
      },
    );
  }
}
