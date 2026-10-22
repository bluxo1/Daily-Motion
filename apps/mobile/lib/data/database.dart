import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class TrainingDatabase extends _$TrainingDatabase {
  TrainingDatabase(super.executor);

  factory TrainingDatabase.open(File file) => TrainingDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (sqlite) {
        sqlite.execute('PRAGMA journal_mode=WAL;');
        sqlite.execute('PRAGMA synchronous=FULL;');
        sqlite.execute('PRAGMA foreign_keys=ON;');
      },
    ),
  );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await customStatement('INSERT INTO recovery_state(singleton) VALUES(1)');
      await customStatement('PRAGMA user_version=$schemaVersion');
    }),
    onUpgrade: (migrator, from, to) => transaction(() async {
      if (from > to) {
        throw StateError(
          'A newer training database requires a compatible application.',
        );
      }
      if (from < 2) {
        await customStatement(
          'ALTER TABLE sessions ADD COLUMN branch_base INTEGER',
        );
        await customStatement(
          'ALTER TABLE outbox ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement('ALTER TABLE outbox ADD COLUMN last_error TEXT');
        await customStatement(
          'ALTER TABLE outbox ADD COLUMN request_digest TEXT',
        );
        await migrator.createTable(syncMetadata);
        await migrator.createTable(bootstrapStage);
        await migrator.createTable(bootstrapPages);
        // Preserve the base of every pre-migration pending branch.
        await customStatement(
          "UPDATE sessions SET branch_base=(SELECT origin_base FROM outbox WHERE session_id=sessions.id AND state != 'acknowledged' ORDER BY local_seq LIMIT 1)",
        );
      }
      if (from < 3) {
        await customStatement(
          'ALTER TABLE rest_timers ADD COLUMN monotonic_us INTEGER',
        );
        await customStatement(
          'ALTER TABLE rest_timers ADD COLUMN continuity_id TEXT',
        );
        await customStatement(
          'ALTER TABLE rest_timers ADD COLUMN uncertain INTEGER NOT NULL DEFAULT 0 CHECK(uncertain IN (0,1))',
        );
      }
      if (from < 4) {
        await customStatement(
          'ALTER TABLE outbox ADD COLUMN wire_version INTEGER NOT NULL DEFAULT 1 CHECK(wire_version IN (1,2))',
        );
        await customStatement(
          'ALTER TABLE outbox ADD COLUMN origin_context TEXT',
        );
        await customStatement(
          'ALTER TABLE outbox ADD COLUMN accepted_context TEXT',
        );
        await customStatement(
          'ALTER TABLE shadows ADD COLUMN recovery_context TEXT',
        );
        await migrator.createTable(recoveryState);
        await migrator.createTable(historicalReceipts);
        await customStatement(
          'INSERT INTO recovery_state(singleton) VALUES(1)',
        );
      }
      // Drift updates its version after the callback. Persist it with the DDL
      // too, so process loss after commit cannot retry an already-applied ALTER.
      await customStatement('PRAGMA user_version=$to');
    }),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys=ON;');
    },
  );
}
