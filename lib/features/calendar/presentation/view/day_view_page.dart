import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Placeholder for the day view (PRD §5.1, design screens 1a–1c), the app's
/// home screen.
///
/// Becomes the ±7-day date strip and the occurrence cards in M3.
class DayViewPage extends StatelessWidget {
  const DayViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.todayTitle)),
      body: Center(
        child: Text(
          context.l10n.todayTitle,
          style: context.typography.body,
        ),
      ),
    );
  }
}
