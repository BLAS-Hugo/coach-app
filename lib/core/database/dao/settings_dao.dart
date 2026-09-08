import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/syncable_dao.dart';
import 'package:coach_app/core/database/tables/logging_tables.dart';
import 'package:drift/drift.dart';

part 'settings_dao.g.dart';

/// The single row of user preferences.
@DriftAccessor(tables: [AppSettingsRows])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin, SyncableDao {
  SettingsDao(super.attachedDatabase, {this.now = DateTime.now});

  @override
  final DateTime Function() now;

  /// The preferences row, or null before anything has been written.
  Future<AppSettingsRow?> find() =>
      (selectLive(appSettingsRows)..limit(1)).getSingleOrNull();

  Stream<AppSettingsRow?> watch() =>
      (selectLive(appSettingsRows)..limit(1)).watchSingleOrNull();

  Future<void> save(AppSettingsRow row) => upsertRow(appSettingsRows, row);
}
