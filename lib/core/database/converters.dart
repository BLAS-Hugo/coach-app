import 'package:coach_app/core/utils/date_only.dart';
import 'package:drift/drift.dart';

/// Stores a [DateOnly] as its epoch-day count.
///
/// `docs/PLANNING.md` §9 requires dates to be stored as UTC-midnight epoch
/// days, never as a local `DateTime` with a time component.
/// [DateOnly.epochDay] is exactly that, so this converter is a pass-through
/// rather than a lossy reinterpretation — which is the point: there is no
/// zone conversion here to get wrong.
class DateOnlyConverter extends TypeConverter<DateOnly, int>
    with JsonTypeConverter<DateOnly, int> {
  const DateOnlyConverter();

  @override
  DateOnly fromSql(int fromDb) => DateOnly.fromEpochDay(fromDb);

  @override
  int toSql(DateOnly value) => value.epochDay;
}
