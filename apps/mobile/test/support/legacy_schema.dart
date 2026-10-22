import 'package:daily_motion/data/database.dart';

/// Only for newly created synthetic test databases. Reconstructs the exact v3
/// layout by removing additive v4 metadata; original row blobs stay intact.
Future<void> reconstructSchemaThree(TrainingDatabase db) async {
  await db.customStatement('DROP TABLE historical_receipts');
  await db.customStatement('DROP TABLE recovery_state');
  for (final column in ['wire_version', 'origin_context', 'accepted_context']) {
    await db.customStatement('ALTER TABLE outbox DROP COLUMN $column');
  }
  await db.customStatement('ALTER TABLE shadows DROP COLUMN recovery_context');
  await db.customStatement('PRAGMA user_version=3');
}

/// Reconstruct supported pre-recovery shapes only in newly owned test files.
Future<void> reconstructLegacySchema(TrainingDatabase db, int version) async {
  if (![1, 2, 3].contains(version)) {
    throw ArgumentError('Unsupported synthetic legacy schema');
  }
  await reconstructSchemaThree(db);
  if (version < 3) {
    for (final column in ['monotonic_us', 'continuity_id', 'uncertain']) {
      await db.customStatement('ALTER TABLE rest_timers DROP COLUMN $column');
    }
  }
  if (version == 1) {
    await db.customStatement('ALTER TABLE sessions DROP COLUMN branch_base');
    for (final column in ['attempt_count', 'last_error', 'request_digest']) {
      await db.customStatement('ALTER TABLE outbox DROP COLUMN $column');
    }
    for (final table in [
      'sync_metadata',
      'bootstrap_stage',
      'bootstrap_pages',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
  }
  await db.customStatement('PRAGMA user_version=$version');
}
