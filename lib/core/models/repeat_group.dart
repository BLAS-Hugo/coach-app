import 'package:freezed_annotation/freezed_annotation.dart';

part 'repeat_group.freezed.dart';

/// An ordered subset of endurance blocks repeated [repeatCount] times, so
/// "6 × (400 m / 90 s)" is one group of two blocks rather than twelve rows
/// (PRD §4.3).
@freezed
abstract class RepeatGroup with _$RepeatGroup {
  const factory RepeatGroup({
    required String id,
    required String sessionTemplateId,
    required int orderIndex,
    required int repeatCount,
  }) = _RepeatGroup;
}
