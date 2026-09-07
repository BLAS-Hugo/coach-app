import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent frame around the three top-level destinations.
///
/// Three destinations, deliberately: settings live inside `Programme`
/// rather than earning a fourth tab.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _AppTabBar(
        currentIndex: navigationShell.currentIndex,
        // `initialLocation: true` on the branch already in view pops that
        // branch back to its root, which is the expected re-tap behaviour.
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        labels: [l10n.tabToday, l10n.tabProgram, l10n.tabHistory],
      ),
    );
  }
}

/// The tab bar from the design: a `surfaceSunken` band with a hairline top
/// border, and an active tab marked by a 16 × 2 rule above its label.
/// No icons — the design uses none.
class _AppTabBar extends StatelessWidget {
  const _AppTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.labels,
  });

  static const double _height = 60;
  static const double _markerWidth = 16;
  static const double _markerHeight = 2;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: Row(
            children: [
              for (final (index, label) in labels.indexed)
                Expanded(
                  child: _Tab(
                    label: label,
                    selected: index == currentIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    // The active tab renders uppercase for the design; the semantic label
    // keeps the natural casing so screen readers announce it normally.
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _AppTabBar._markerWidth,
              height: _AppTabBar._markerHeight,
              color: selected ? colors.textPrimary : const Color(0x00000000),
            ),
            const SizedBox(height: AppSpacing.xs),
            ExcludeSemantics(
              child: Text(
                selected ? label.toUpperCase() : label,
                style: selected
                    ? typography.label.copyWith(color: colors.textPrimary)
                    : typography.body.copyWith(
                        fontSize: 11,
                        height: 14 / 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
