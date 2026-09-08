import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Placeholder for the history screen (PRD §5.6, design screens 5a–5c).
///
/// Becomes the week list, per-exercise progression and block summary in M9.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.historyTitle)),
      body: Center(
        child: Text(context.l10n.historyTitle, style: context.typography.body),
      ),
    );
  }
}
