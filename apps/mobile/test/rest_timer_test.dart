import 'dart:io';
import 'dart:async';

import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:daily_motion/domain/rest_timer.dart';
import 'package:daily_motion/platform/device_services.dart';
import 'package:daily_motion/qualification/durable_benchmark.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show recordPayload;
import 'support/sync_server.dart' show testOwner;
import 'support/legacy_schema.dart';

class ControlledRestClock implements RestClock {
  ClockSample value;
  ControlledRestClock(this.value);
  @override
  Future<ClockSample> sample() async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime.utc(2026, 10, 13);
  RestAnchor anchor() => RestAnchor(
    start,
    start.add(const Duration(seconds: 120)),
    elapsedUs: 1000000,
    continuityId: 'boot:1',
  );
  test('SQLite FULL during a local write never acknowledges it or removes the durable draft', () async {
    final directory = await Directory.systemTemp.createTemp('sqlite-full-');
    final file = File('${directory.path}/db.sqlite');
    var db = TrainingDatabase.open(file);
    var repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final setId =
        allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
    await repo.saveDraft(setId, {'reps': '7'});
    await db.customStatement('CREATE TABLE qualification_pressure(value BLOB)');
    // Force actual pager capacity failure within the real save transaction.
    await db.customStatement(
      'CREATE TRIGGER qualification_full AFTER INSERT ON local_observations BEGIN INSERT INTO qualification_pressure VALUES(zeroblob(1048576)); END',
    );
    final pages =
        (await db.customSelect('PRAGMA page_count').getSingle())
                .data
                .values
                .single
            as int;
    await db.customStatement('PRAGMA max_page_count=$pages');
    var acknowledgements = 0;
    repo.onLocalCommit = (_) => acknowledgements++;
    await expectLater(
      repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!, index: 1),
      ),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('SqliteException(13)'),
          'remote SQLite SQLITE_FULL (13)',
        ),
      ),
    );
    expect(acknowledgements, 0);
    expect(await repo.pendingCount(), 2);
    expect(await repo.draft(setId), {'reps': '7'});
    await db.customStatement('DROP TRIGGER qualification_full');
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner);
    await repo.initialize();
    expect(
      allSets((await repo.workout(id))!)
          .where((set) => set['observation'] != null)
          .length,
      1,
    );
    expect(await repo.draft(setId), {'reps': '7'});
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    await db.close();
    await directory.delete(recursive: true);
  });
  test(
    'schema two upgrade preserves frozen requests, timers and pending drafts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'schema-two-timer-',
      );
      final file = File('${directory.path}/db.sqlite');
      var db = TrainingDatabase.open(file);
      var repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      final id = await repo.startFoundationWorkout();
      await repo.commit(
        id,
        'record_set',
        recordPayload((await repo.workout(id))!),
      );
      final frozen = await repo.prepareHead(id);
      final deadline = await repo.timerDeadline(id);
      final set =
          allSets((await repo.workout(id))!).elementAt(1)['set_id'] as String;
      await repo.saveDraft(set, {'reps': '7'});
      await reconstructSchemaThree(db);
      for (final column in ['monotonic_us', 'continuity_id', 'uncertain']) {
        await db.customStatement('ALTER TABLE rest_timers DROP COLUMN $column');
      }
      await db.customStatement('PRAGMA user_version=2');
      await db.close();
      db = TrainingDatabase.open(file);
      repo = WorkoutRepository(db, testOwner);
      await repo.initialize();
      expect(await repo.prepareHead(id), frozen);
      expect(await repo.timerDeadline(id), deadline);
      expect(await repo.draft(set), {'reps': '7'});
      expect((await repo.restDisplay(id))!.uncertain, true);
      await db.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    'same-boot suspension and process loss use elapsed time without ticks',
    () {
      final display = anchor().project(
        ClockSample(
          start.add(const Duration(seconds: 45)),
          elapsedUs: 46000000,
          continuityId: 'boot:1',
        ),
      );
      expect(display.remainingSeconds, 75);
      expect(display.uncertain, false);
    },
  );
  for (final seconds in [-3600, 3600]) {
    test('wall clock change $seconds never moves the same-boot countdown', () {
      final display = anchor().project(
        ClockSample(
          start.add(Duration(seconds: seconds)),
          elapsedUs: 31000000,
          continuityId: 'boot:1',
        ),
      );
      expect(display.remainingSeconds, 90);
      expect(display.uncertain, true);
    });
  }
  test('timezone changes do not change UTC anchors', () {
    final localRepresentation = DateTime.parse('2026-10-13T05:30:45+05:30');
    final display = anchor().project(
      ClockSample(
        localRepresentation,
        elapsedUs: 46000000,
        continuityId: 'boot:1',
      ),
    );
    expect(display.remainingSeconds, 75);
    expect(display.uncertain, false);
  });
  test('reboot or unknown continuity falls back conservatively and marks uncertainty', () {
    final display = anchor().project(
      ClockSample(
        start.add(const Duration(seconds: 45)),
        elapsedUs: 10,
        continuityId: 'boot:2',
      ),
    );
    expect(display.remainingSeconds, 75);
    expect(display.uncertain, true);
    expect(
      anchor()
          .project(ClockSample(start.subtract(const Duration(hours: 2))))
          .remainingSeconds,
      120,
    );
  });
  test('expired and negative-elapsed timers never become negative or grow unbounded', () {
    expect(
      anchor()
          .project(ClockSample(start.add(const Duration(hours: 2))))
          .remainingSeconds,
      0,
    );
    expect(
      anchor()
          .project(ClockSample(start, elapsedUs: 1, continuityId: 'boot:1'))
          .uncertain,
      true,
    );
  });
  test('legacy wall anchors remain approximate, not measured rest', () {
    final display = RestAnchor(
      start,
      start.add(const Duration(seconds: 120)),
    ).project(ClockSample(start.add(const Duration(seconds: 60))));
    expect(display.remainingSeconds, 60);
    expect(display.label, contains('approximate'));
  });
  test('native clock response validates and falls back safely', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      DeviceServices.channel,
      (_) async => {
        'wall_ms': start.millisecondsSinceEpoch,
        'elapsed_us': 10,
        'continuity_id': 'boot:1',
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(DeviceServices.channel, null),
    );
    final sample = await const DeviceServices().sample();
    expect(sample.continuityId, 'boot:1');
    messenger.setMockMethodCallHandler(
      DeviceServices.channel,
      (_) async => {'wall_ms': 'bad'},
    );
    expect((await const DeviceServices().sample()).elapsedUs, null);
  });
  test(
    'stalled or malformed native clock falls back without waiting indefinitely',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(DeviceServices.channel, null),
      );
      for (final invalid in [
        42,
        {
          'wall_ms': start.millisecondsSinceEpoch,
          'elapsed_us': 1,
          'continuity_id': '',
        },
      ]) {
        messenger.setMockMethodCallHandler(
          DeviceServices.channel,
          (_) async => invalid,
        );
        expect((await const DeviceServices().sample()).elapsedUs, null);
      }
      messenger.setMockMethodCallHandler(
        DeviceServices.channel,
        (_) => Completer<Object?>().future,
      );
      final sample = await const DeviceServices().sample().timeout(
        const Duration(seconds: 1),
      );
      expect(sample.elapsedUs, null);
    },
  );
  test('real file reopening preserves monotonic anchor, frozen outbox and sticky clock uncertainty', () async {
    final directory = await Directory.systemTemp.createTemp('timer-file-');
    final file = File('${directory.path}/db.sqlite');
    var db = TrainingDatabase.open(file);
    final clock = ControlledRestClock(
      ClockSample(start, elapsedUs: 1000000, continuityId: 'boot:1'),
    );
    var repo = WorkoutRepository(db, testOwner, restClock: clock);
    await repo.initialize();
    final id = await repo.startFoundationWorkout();
    await repo.commit(
      id,
      'record_set',
      recordPayload((await repo.workout(id))!),
    );
    final frozen = await repo.prepareHead(id);
    await db.close();
    db = TrainingDatabase.open(file);
    repo = WorkoutRepository(db, testOwner, restClock: clock);
    await repo.initialize();
    clock.value = ClockSample(
      start.add(const Duration(hours: 2)),
      elapsedUs: 31000000,
      continuityId: 'boot:1',
    );
    expect((await repo.restDisplay(id))!.remainingSeconds, 90);
    expect((await repo.restDisplay(id))!.uncertain, true);
    clock.value = ClockSample(
      start.add(const Duration(seconds: 30)),
      elapsedUs: 31000000,
      continuityId: 'boot:1',
    );
    expect((await repo.restDisplay(id))!.uncertain, true);
    expect(await repo.prepareHead(id), frozen);
    await db.close();
    await directory.delete(recursive: true);
  });
  test('benchmark excludes emulator/debug and insufficient or failed runs from the physical target', () {
    for (final device in [
      {
        'physical': false,
        'source': 'android-native',
        'model': 'fixture',
        'os': 'test',
      },
      {'physical': true, 'source': 'desktop', 'model': 'fixture', 'os': 'test'},
    ]) {
      final benchmark = DurableBenchmark(device, 'profile');
      for (var i = 0; i < 200; i++) {
        benchmark.record(const Duration(microseconds: 1), acknowledged: true);
      }
      expect(
        benchmark.report(
          warmups: 0,
          historyRoots: 0,
          scenario: 'test',
          buildRevision: 'fixture123',
        )['target_met'],
        false,
      );
    }
    final debug = DurableBenchmark({
      'physical': true,
      'source': 'android-native',
    }, 'debug');
    expect(
      debug.report(
        warmups: 0,
        historyRoots: 0,
        scenario: 'test',
      )['physical_performance_evidence'],
      false,
    );
  });
  test('benchmark requires device and revision metadata and rejects negative samples', () {
    final benchmark = DurableBenchmark({
      'physical': true,
      'source': 'android-native',
      'model': 'synthetic guard fixture',
      'os': 'test',
    }, 'profile');
    for (var i = 0; i < 200; i++) {
      benchmark.record(const Duration(microseconds: 1), acknowledged: true);
    }
    Map<String, dynamic> report(String revision) => benchmark.report(
      warmups: 32,
      historyRoots: 100,
      scenario: 'unit_guard_fixture_not_device_evidence',
      buildRevision: revision,
      completed: true,
    );
    expect(report('unrecorded')['physical_performance_evidence'], false);
    expect(report('fixture123')['physical_performance_evidence'], true);
    benchmark.device.remove('model');
    expect(report('fixture123')['physical_performance_evidence'], false);
    benchmark.device['model'] = 'synthetic guard fixture';
    benchmark.record(const Duration(microseconds: -1), acknowledged: true);
    expect(report('fixture123')['physical_performance_evidence'], false);
    expect(benchmark.failures, 1);
  });
  test('nearest-rank keeps outliers and refuses qualification after any failed write', () {
    final benchmark = DurableBenchmark({
      'physical': true,
      'source': 'android-native',
    }, 'profile');
    for (var i = 1; i <= 200; i++) {
      benchmark.record(Duration(microseconds: i * 1000), acknowledged: true);
    }
    var report = benchmark.report(
      warmups: 32,
      historyRoots: 100,
      scenario: 'offline',
    );
    expect(report['p95_us'], 190000);
    expect(report['max_us'], 200000);
    expect(report['target_met'], false);
    benchmark.record(Duration.zero, acknowledged: false);
    report = benchmark.report(
      warmups: 32,
      historyRoots: 100,
      scenario: 'offline',
    );
    expect(report['physical_performance_evidence'], false);
  });
}
