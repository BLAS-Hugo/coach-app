import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/database/dao/exercise_dao.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/repositories/exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository repository;

  ExerciseRepository buildRepository({DateTime Function()? clock}) =>
      DriftExerciseRepository(
        ExerciseDao(db, now: clock ?? clockAt(DateTime(2026, 9, 7))),
      );

  setUp(() {
    db = openTestDatabase();
    repository = buildRepository();
  });

  tearDown(() => db.close());

  group('save', () {
    test('inserts an exercise and reads it back as a domain model', () async {
      const squat = Exercise(id: 'e1', name: 'Squat', muscleGroup: 'Jambes');

      await repository.save(squat);

      expect(await repository.findById('e1'), squat);
    });

    test('updates an existing exercise in place', () async {
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));

      await repository.save(
        const Exercise(id: 'e1', name: 'Squat barre', notes: 'Barre haute'),
      );

      expect(
        await repository.findById('e1'),
        const Exercise(id: 'e1', name: 'Squat barre', notes: 'Barre haute'),
      );
    });

    test('keeps the original createdAt when updating', () async {
      final created = DateTime(2026, 9, 7, 8);
      final updated = DateTime(2026, 9, 8, 20);
      final repository = buildRepository(clock: clockOver([created, updated]));
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));

      await repository.save(const Exercise(id: 'e1', name: 'Squat barre'));

      final row = await db.select(db.exercises).getSingle();
      expect(row.createdAt, created);
      expect(row.updatedAt, updated);
    });
  });

  group('watchAll', () {
    test('emits live exercises ordered by name', () async {
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));
      await repository.save(const Exercise(id: 'e2', name: 'Développé'));

      expect(await repository.watchAll().first, [
        const Exercise(id: 'e2', name: 'Développé'),
        const Exercise(id: 'e1', name: 'Squat'),
      ]);
    });

    test('re-emits when an exercise is added', () async {
      final emissions = repository.watchAll();
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));

      await expectLater(
        emissions,
        emitsThrough([const Exercise(id: 'e1', name: 'Squat')]),
      );
    });
  });

  group('delete', () {
    test('hides the exercise without removing the row', () async {
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));

      await repository.delete('e1');

      expect(await repository.watchAll().first, isEmpty);
      expect(await repository.findById('e1'), isNull);
      // The row survives: a logged exercise still points at it, and that
      // history must stay readable (PRD §4.1).
      final row = await db.select(db.exercises).getSingle();
      expect(row.deletedAt, DateTime(2026, 9, 7));
    });
  });

  group('watchMatching', () {
    setUp(() async {
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));
      await repository.save(const Exercise(id: 'e2', name: 'Squat bulgare'));
      await repository.save(const Exercise(id: 'e3', name: 'Développé'));
    });

    test('matches a case-insensitive substring of the name', () async {
      final matches = await repository.watchMatching('squ').first;

      expect(matches.map((e) => e.id), ['e1', 'e2']);
    });

    test('emits every exercise for an empty query', () async {
      expect(await repository.watchMatching('  ').first, hasLength(3));
    });

    test('matches across accents', () async {
      await repository.save(const Exercise(id: 'e4', name: 'Élévations'));

      // Typing accents on a phone keyboard mid-workout is friction, and an
      // autocomplete that misses "elevations" is what fragments an
      // exercise's history into two spellings.
      expect((await repository.watchMatching('elev').first).map((e) => e.id), [
        'e4',
      ]);
    });

    test('excludes a deleted exercise', () async {
      await repository.delete('e2');

      final matches = await repository.watchMatching('squat').first;

      expect(matches.map((e) => e.id), ['e1']);
    });
  });

  group('findOrCreateByName', () {
    test('creates an exercise when nothing matches', () async {
      final created = await repository.findOrCreateByName('Soulevé de terre');

      expect(created.name, 'Soulevé de terre');
      expect(await repository.findById(created.id), created);
    });

    test(
      'reuses an existing exercise regardless of case and spacing',
      () async {
        await repository.save(const Exercise(id: 'e1', name: 'Squat'));

        final found = await repository.findOrCreateByName('  squat ');

        // Fragmenting "Squat" from "squat " would silently split that
        // exercise's history in two, which is the whole reason exercises have
        // an identity at all (PRD §4.5).
        expect(found.id, 'e1');
        expect(await db.select(db.exercises).get(), hasLength(1));
      },
    );

    test('refuses a blank name', () async {
      // The autocomplete can hand this over if the user taps "create" on an
      // empty field; a nameless exercise is a history bucket nobody can
      // ever find again.
      await expectLater(
        repository.findOrCreateByName('   '),
        throwsArgumentError,
      );
    });

    test('reuses an existing exercise across accents', () async {
      await repository.save(const Exercise(id: 'e1', name: 'Élévations'));

      final found = await repository.findOrCreateByName('elevations');

      expect(found.id, 'e1');
    });

    test('does not reuse a deleted exercise', () async {
      await repository.save(const Exercise(id: 'e1', name: 'Squat'));
      await repository.delete('e1');

      final created = await repository.findOrCreateByName('Squat');

      expect(created.id, isNot('e1'));
    });
  });
}
