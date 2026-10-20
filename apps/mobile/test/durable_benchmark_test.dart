import 'package:daily_motion/qualification/durable_benchmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DurableBenchmark run() {
    final benchmark = DurableBenchmark({
      'physical': true,
      'source': 'android-native',
      'model': 'synthetic metadata fixture',
      'os': 'test',
    }, 'profile');
    for (var i = 0; i < 200; i++) {
      benchmark.record(const Duration(microseconds: 1000), acknowledged: true);
    }
    return benchmark;
  }

  test('physical benchmark rejects missing workload declaration', () {
    for (final declaration in [
      (0, 100, 'offline'),
      (32, 0, 'offline'),
      (32, 100, ''),
    ]) {
      final report = run().report(
        warmups: declaration.$1,
        historyRoots: declaration.$2,
        scenario: declaration.$3,
        buildRevision: 'fixture123',
        completed: true,
      );
      expect(report['physical_performance_evidence'], false);
      expect(report['target_met'], false);
    }
  });

  test(
    'partial benchmark retains samples but never meets the physical target',
    () {
      final report = run().report(
        warmups: 32,
        historyRoots: 100,
        scenario: 'synthetic guard fixture',
        buildRevision: 'fixture123',
        completed: false,
      );
      expect(report['sample_count'], 200);
      expect(report['samples_us'], hasLength(200));
      expect(report['run_completed'], false);
      expect(report['physical_performance_evidence'], false);
      expect(report['target_met'], false);
    },
  );
  test('failed attempts retain their raw duration without becoming successful samples', () {
    final benchmark = run();
    benchmark.record(const Duration(microseconds: 123456), acknowledged: false);
    final report = benchmark.report(
      warmups: 32,
      historyRoots: 100,
      scenario: 'synthetic guard fixture',
      buildRevision: 'fixture123',
      completed: true,
    );
    expect(report['sample_count'], 200);
    expect(report['failure_count'], 1);
    expect(report['failed_measurements'], [
      {'attempt': 201, 'elapsed_us': 123456, 'acknowledged': false},
    ]);
    expect(report['target_met'], false);
  });
}
