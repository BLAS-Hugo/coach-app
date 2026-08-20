import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Placeholder for the day view (PRD §5.1), the app's home screen.
///
/// Replaced by the real ±7-day date strip and occurrence cards in M3.
class DayViewPage extends StatelessWidget {
  const DayViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(child: Text(l10n.appTitle)),
    );
  }
}
