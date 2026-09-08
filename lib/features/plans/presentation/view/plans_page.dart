import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Placeholder for the plan list (PRD §5.4, design screen 4a).
///
/// Becomes the real plan cards, the week-template editor and the settings
/// rows in M2.
class PlansPage extends StatelessWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.programTitle)),
      body: Center(
        child: Text(context.l10n.programTitle, style: context.typography.body),
      ),
    );
  }
}
