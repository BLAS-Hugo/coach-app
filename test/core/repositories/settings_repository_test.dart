import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/settings_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftSettingsRepository(
      SettingsDao(db, now: clockAt(DateTime(2026, 9, 7))),
    );
  });

  tearDown(() => db.close());

  test('a fresh install starts on the documented defaults', () async {
    final settings = await repository.load();

    expect(settings.unitWeight, WeightUnit.kg);
    expect(settings.unitDistance, DistanceUnit.km);
    expect(settings.intensityScale, IntensityScale.rpe);
    expect(settings.defaultRestSeconds, 120);
    expect(settings.audioCues, isTrue);
    expect(settings.vibration, isTrue);
    // The design's default (PRD §5.7).
    expect(settings.themeMode, AppThemeMode.dark);
  });

  test('keeps a single row across loads', () async {
    final first = await repository.load();
    final second = await repository.load();

    expect(second.id, first.id);
    expect(await db.select(db.appSettingsRows).get(), hasLength(1));
  });

  test('persists a change', () async {
    final settings = await repository.load();

    await repository.save(
      settings.copyWith(
        unitWeight: WeightUnit.lb,
        intensityScale: IntensityScale.rir,
        defaultRestSeconds: 90,
      ),
    );

    final reloaded = await repository.load();
    expect(reloaded.unitWeight, WeightUnit.lb);
    expect(reloaded.intensityScale, IntensityScale.rir);
    expect(reloaded.defaultRestSeconds, 90);
    expect(await db.select(db.appSettingsRows).get(), hasLength(1));
  });

  test('watch emits the current settings and every later change', () async {
    final emissions = repository.watch();
    final settings = await repository.load();

    await repository.save(settings.copyWith(audioCues: false));

    await expectLater(
      emissions,
      emitsThrough(
        predicate<AppSettings>((s) => !s.audioCues, 'audio cues turned off'),
      ),
    );
  });

  test('watch works on a database nothing has written yet', () async {
    // The settings cubit is hydrated at startup, before any screen has had
    // a chance to write a preference.
    expect((await repository.watch().first).defaultRestSeconds, 120);
  });
}
