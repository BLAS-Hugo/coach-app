import 'package:freezed_annotation/freezed_annotation.dart';

part 'intensity_label.freezed.dart';

/// A user-editable intensity label, e.g. `Z4`, `seuil`, `4:30/km`.
///
/// A label and nothing more: the app measures no intensity and owns no
/// sensors (PRD §4.3). Logged endurance blocks copy the text rather than
/// referencing this row, so deleting a label never rewrites history.
@freezed
abstract class IntensityLabel with _$IntensityLabel {
  const factory IntensityLabel({
    required String id,
    required String label,
    required int orderIndex,
  }) = _IntensityLabel;
}
