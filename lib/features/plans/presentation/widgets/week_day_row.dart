import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One weekday of the weekly template (design screen 4b).
///
/// A session day reads as the day, an accent rule, the session's name and
/// size, and a drag handle; a rest day as the day, `repos` and a `+`. The
/// handle drags the session onto another day — dropped on a session, the
/// two swap. Tapping the row opens the day's sheet either way.
///
/// With [editable] off — a finished block — the row is text only: no tap,
/// no handle, no drop.
class WeekDayRow extends StatelessWidget {
  const WeekDayRow({
    required this.weekday,
    required this.accent,
    required this.editable,
    this.sessionName,
    this.sessionMeta,
    this.onTap,
    this.onSessionDropped,
    this.isLast = false,
    super.key,
  });

  /// Identifies [weekday]'s drag handle.
  @visibleForTesting
  static Key handleKey(int weekday) => Key('weekDayHandle$weekday');

  /// Width of the day abbreviation column.
  static const double _dayWidth = 34;

  /// The accent rule: 2 wide, as tall as a two-line session.
  static const double _ruleWidth = 2;
  static const double _ruleHeight = 34;

  /// ISO weekday, 1 (Monday) to 7 (Sunday).
  final int weekday;
  final Color accent;
  final bool editable;

  /// Null for a rest day.
  final String? sessionName;
  final String? sessionMeta;
  final VoidCallback? onTap;

  /// Called with the weekday a session was dragged from.
  final ValueChanged<int>? onSessionDropped;

  /// Draws the closing rule under the last day.
  final bool isLast;

  bool get _isRest => sessionName == null;

  @override
  Widget build(BuildContext context) {
    if (!editable) return _content(context, highlighted: false);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != weekday,
      onAcceptWithDetails: (details) => onSessionDropped?.call(details.data),
      builder: (context, candidates, _) =>
          _content(context, highlighted: candidates.isNotEmpty),
    );
  }

  Widget _content(BuildContext context, {required bool highlighted}) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typography = context.typography;
    final border = BorderSide(color: colors.borderSubtle);
    final name = sessionName;
    final meta = sessionMeta;

    final row = Container(
      constraints: const BoxConstraints(minHeight: AppTouchTarget.primary),
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      decoration: BoxDecoration(
        // Raised, not filled: a drop target is a tappable surface lifting to
        // meet the drag, and a filled surface means "session in progress".
        color: highlighted ? colors.surfaceRaised : null,
        border: Border(top: border, bottom: isLast ? border : BorderSide.none),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _dayWidth,
            child: Text(
              l10n.weekdayShort('$weekday').toUpperCase(),
              style: typography.label.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: _ruleWidth,
            height: _ruleHeight,
            decoration: BoxDecoration(
              color: _isRest ? null : accent,
              borderRadius: BorderRadius.circular(_ruleWidth / 2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: name == null
                ? Text(
                    l10n.weekTemplateRest,
                    style: typography.body.copyWith(
                      fontSize: 14,
                      color: colors.textMuted,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: typography.body.copyWith(
                          height: 20 / 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta != null)
                        Text(
                          meta,
                          style: typography.dataSmall.copyWith(
                            fontSize: 11.5,
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
          ),
          if (editable)
            _trailing(context)
          else
            const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );

    if (!editable) return MergeSemantics(child: row);
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }

  /// The `+` of a rest day, or the session's drag handle — a full touch
  /// target either way, so the gutter the design gives it is inside it.
  Widget _trailing(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    Widget glyph(String text, {double size = 15}) => SizedBox(
      width: AppTouchTarget.min,
      height: AppTouchTarget.min,
      child: Center(
        child: Text(
          text,
          style: typography.body.copyWith(
            fontSize: size,
            height: 1,
            color: colors.textMuted,
          ),
        ),
      ),
    );

    if (_isRest) {
      return Semantics(
        label: context.l10n.weekTemplateAddSession(
          context.l10n.weekdayLong('$weekday').toLowerCase(),
        ),
        child: ExcludeSemantics(child: glyph('+', size: 17)),
      );
    }

    return Semantics(
      hint: context.l10n.weekTemplateMoveSession,
      child: Draggable<int>(
        key: handleKey(weekday),
        data: weekday,
        axis: Axis.vertical,
        feedback: _DragFeedback(name: sessionName!, accent: accent),
        childWhenDragging: Opacity(opacity: 0.3, child: glyph('⋮⋮')),
        child: ExcludeSemantics(child: glyph('⋮⋮')),
      ),
    );
  }
}

/// What follows the finger while a session is dragged: its name on a
/// raised chip, ruled in the accent like the row it came from.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.name, required this.accent});

  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: WeekDayRow._ruleWidth,
              height: AppSpacing.md,
              color: accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              name,
              style: context.typography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
