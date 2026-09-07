import 'package:coach_app/core/database/dao/settings_dao.dart';
import 'package:coach_app/core/database/id_generator.dart';
import 'package:coach_app/core/database/mappers.dart';
import 'package:coach_app/core/models/models.dart';

/// User preferences (PRD §5.7).
///
/// Exactly one row exists, created the first time anything asks for it, so
/// no caller has to deal with "settings do not exist yet". Units are a
/// display concern only — nothing here changes what is stored.
abstract interface class SettingsRepository {
  /// The current preferences, creating them on their defaults if this is a
  /// fresh install.
  Future<AppSettings> load();

  /// The preferences, re-emitted on every change.
  Stream<AppSettings> watch();

  Future<void> save(AppSettings settings);
}

/// Drift-backed [SettingsRepository].
class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<AppSettings> load() async {
    final existing = await _dao.find();
    if (existing != null) return existing.toDomain();

    // First run. The row is written rather than only returned, so the id
    // stays stable and later saves update it instead of racing to create a
    // second one.
    final created = AppSettings(id: newId());
    await save(created);
    return created;
  }

  @override
  Stream<AppSettings> watch() async* {
    // Hydrating the cubit at startup must not depend on a screen having
    // written a preference first.
    final current = await load();
    yield* _dao.watch().map((row) => row?.toDomain() ?? current);
  }

  @override
  Future<void> save(AppSettings settings) =>
      _dao.save(settings.toRow(_dao.now()));
}
