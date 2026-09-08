import 'package:coach_app/core/database/app_database.dart';
import 'package:coach_app/core/models/models.dart';
import 'package:coach_app/core/utils/date_only.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('AppDatabase', () {
    test('opens at schema v1 and matches its own definition', () async {
      // validateDatabaseSchema compares the tables SQLite actually created
      // against the schema drift generated. It is the guard a future
      // migration must keep passing.
      await db.customStatement('SELECT 1');
      expect(db.schemaVersion, 1);
      await expectLater(db.validateDatabaseSchema(), completes);
    });

    test('enforces foreign keys', () async {
      // SQLite leaves foreign keys off per connection unless asked, so this
      // asserts beforeOpen actually ran.
      final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(result.data.values.first, 1);
    });

    test('rejects a row whose foreign key points nowhere', () async {
      await expectLater(
        db
            .into(db.trainingBlocks)
            .insert(
              TrainingBlocksCompanion.insert(
                id: 'block-1',
                createdAt: DateTime(2026, 8, 17),
                updatedAt: DateTime(2026, 8, 17),
                planId: 'does-not-exist',
                name: 'Accumulation',
                orderIndex: 0,
                startDate: DateOnly(2026, 8, 17),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('refuses to upgrade without an explicit migration step', () {
      // No deleteAndRecreate fallback: there is no backup to restore from,
      // so a missing migration must fail loudly rather than wipe history.
      expect(
        () => db.migration.onUpgrade(Migrator(db), 1, 2),
        throwsStateError,
      );
    });
  });

  group('date storage', () {
    test('round-trips a DateOnly as an epoch day', () async {
      await db
          .into(db.plans)
          .insert(
            PlansCompanion.insert(
              id: 'plan-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              name: 'Upper/Lower',
              type: PlanType.strength,
            ),
          );
      final start = DateOnly(2026, 8, 17);
      await db
          .into(db.trainingBlocks)
          .insert(
            TrainingBlocksCompanion.insert(
              id: 'block-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              planId: 'plan-1',
              name: 'Accumulation',
              orderIndex: 0,
              startDate: start,
            ),
          );

      final row = await db.select(db.trainingBlocks).getSingle();
      expect(row.startDate, start);
      expect(row.endDate, isNull);

      // Stored as a bare integer, not a timestamp: no zone to get wrong.
      final raw = await db
          .customSelect('SELECT start_date FROM training_blocks')
          .getSingle();
      expect(raw.data['start_date'], start.epochDay);
    });

    test('round-trips a nullable DateOnly', () async {
      await db
          .into(db.plans)
          .insert(
            PlansCompanion.insert(
              id: 'plan-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              name: 'Upper/Lower',
              type: PlanType.strength,
            ),
          );
      final end = DateOnly(2026, 9, 13);
      await db
          .into(db.trainingBlocks)
          .insert(
            TrainingBlocksCompanion.insert(
              id: 'block-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              planId: 'plan-1',
              name: 'Accumulation',
              orderIndex: 0,
              startDate: DateOnly(2026, 8, 17),
              endDate: Value(end),
            ),
          );
      expect((await db.select(db.trainingBlocks).getSingle()).endDate, end);
    });
  });

  group('the weekly-slot uniqueness index', () {
    Future<void> seedPlan() async {
      await db
          .into(db.plans)
          .insert(
            PlansCompanion.insert(
              id: 'plan-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              name: 'Upper/Lower',
              type: PlanType.strength,
            ),
          );
      await db
          .into(db.trainingBlocks)
          .insert(
            TrainingBlocksCompanion.insert(
              id: 'block-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              planId: 'plan-1',
              name: 'Accumulation',
              orderIndex: 0,
              startDate: DateOnly(2026, 8, 17),
            ),
          );
      await db
          .into(db.sessionTemplates)
          .insert(
            SessionTemplatesCompanion.insert(
              id: 'tpl-1',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              planId: 'plan-1',
              name: 'Upper A',
            ),
          );
    }

    Future<void> insertSlot(String id, {DateTime? deletedAt}) {
      return db
          .into(db.weeklySlots)
          .insert(
            WeeklySlotsCompanion.insert(
              id: id,
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              deletedAt: Value(deletedAt),
              blockId: 'block-1',
              weekday: DateTime.monday,
              sessionTemplateId: 'tpl-1',
            ),
          );
    }

    setUp(seedPlan);

    test('allows one live slot per weekday per block', () async {
      await insertSlot('slot-1');
      await expectLater(insertSlot('slot-2'), throwsA(isA<SqliteException>()));
    });

    test('lets a soft-deleted slot sit alongside its replacement', () async {
      // This is why the index is partial: replacing Monday's session must
      // not require hard-deleting the row it replaces.
      await insertSlot('slot-1', deletedAt: DateTime(2026, 8, 20));
      await expectLater(insertSlot('slot-2'), completes);
      expect(await db.select(db.weeklySlots).get(), hasLength(2));
    });

    test('allows the same weekday in a different block', () async {
      await db
          .into(db.trainingBlocks)
          .insert(
            TrainingBlocksCompanion.insert(
              id: 'block-2',
              createdAt: DateTime(2026, 8, 17),
              updatedAt: DateTime(2026, 8, 17),
              planId: 'plan-1',
              name: 'Intensification',
              orderIndex: 1,
              startDate: DateOnly(2026, 9, 14),
            ),
          );
      await insertSlot('slot-1');
      await expectLater(
        db
            .into(db.weeklySlots)
            .insert(
              WeeklySlotsCompanion.insert(
                id: 'slot-2',
                createdAt: DateTime(2026, 8, 17),
                updatedAt: DateTime(2026, 8, 17),
                blockId: 'block-2',
                weekday: DateTime.monday,
                sessionTemplateId: 'tpl-1',
              ),
            ),
        completes,
      );
    });
  });
}
