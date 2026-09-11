import 'dart:ui' as ui;

import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The dashed "+ Nouveau plan" affordance under the plan list.
///
/// Dashed rather than solid on purpose: the design uses the outline to say
/// "there could be a card here", so it reads as a slot rather than as a
/// third plan.
class NewPlanButton extends StatelessWidget {
  const NewPlanButton({required this.onPressed, super.key});

  /// Identifies the dashed outline: the Material and ink layers around it
  /// contribute [CustomPaint]s of their own.
  @visibleForTesting
  static const Key outlineKey = Key('newPlanButtonOutline');

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.plansNewPlanAction;

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: const Color(0x00000000),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: CustomPaint(
              key: outlineKey,
              painter: _DashedOutlinePainter(
                color: colors.borderStrong,
                radius: AppRadii.md,
              ),
              child: SizedBox(
                height: AppTouchTarget.min,
                child: Center(
                  child: Text(
                    '+ $label',
                    style: context.typography.body.copyWith(
                      fontSize: 13,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
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

/// Strokes a rounded rectangle as a dashed line.
///
/// Flutter has no dashed [BorderSide], so the outline is walked with
/// [ui.PathMetric.extractPath] and drawn one dash at a time.
class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter({required this.color, required this.radius});

  static const double _dash = 5;
  static const double _gap = 4;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Inset by half the stroke so the dashes sit inside the widget's box
    // rather than straddling its edge.
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );

    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        final end = start + _dash;
        canvas.drawPath(
          metric.extractPath(start, end < metric.length ? end : metric.length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
