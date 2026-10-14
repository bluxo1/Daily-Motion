import 'dart:math';

/// No identifiers, credentials or workout payloads enter performance evidence.
/// Collects the complete caller acknowledgement, not just an inner SQL interval.
class DurableBenchmark {
  final Map<String, dynamic> device;
  final String mode;
  final List<int> _samples = [];
  int failures = 0;
  DurableBenchmark(this.device, this.mode);
  void record(Duration elapsed, {required bool acknowledged}) {
    if (!acknowledged || elapsed.isNegative) {
      failures++;
      return;
    }
    _samples.add(elapsed.inMicroseconds);
  }

  Map<String, dynamic> report({
    required int warmups,
    required int historyRoots,
    required String scenario,
    String buildRevision = 'unrecorded',
  }) {
    final ordered = [..._samples]..sort();
    int percentile(double fraction) => ordered.isEmpty
        ? 0
        : ordered[max(0, (fraction * ordered.length).ceil() - 1)];
    final qualified =
        device['physical'] == true &&
        ['android-native', 'ios-native'].contains(device['source']) &&
        ['profile', 'release'].contains(mode) &&
        device['model'] is String &&
        (device['model'] as String).isNotEmpty &&
        device['os'] is String &&
        (device['os'] as String).isNotEmpty &&
        buildRevision != 'unrecorded' &&
        buildRevision.length >= 7 &&
        ordered.length >= 200 &&
        failures == 0;
    return {
      'schema_version': 1,
      'device': device,
      'build_mode': mode,
      'build_revision': buildRevision,
      'measurement': 'WorkoutController.record invocation through successful Future completion; includes durable SQLite commit and projection refresh',
      'clock': 'Dart Stopwatch monotonic',
      'percentile_method': 'nearest-rank ceil(p * n), all samples retained',
      'warmup_count': warmups,
      'history_roots': historyRoots,
      'scenario': scenario,
      'sample_count': ordered.length,
      'failure_count': failures,
      'samples_us': List<int>.unmodifiable(_samples),
      'p50_us': percentile(.5),
      'p95_us': percentile(.95),
      'p99_us': percentile(.99),
      'max_us': ordered.isEmpty ? 0 : ordered.last,
      'physical_performance_evidence': qualified,
      'target_p95_us': 100000,
      'target_met': qualified && percentile(.95) <= 100000,
    };
  }
}
