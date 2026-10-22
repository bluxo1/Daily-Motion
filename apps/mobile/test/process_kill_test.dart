import 'package:flutter_test/flutter_test.dart';

import 'support/process_kill_harness.dart';

void main() {
  for (final protocol in ['v1', 'v2']) {
    for (final stage in ['before_commit', 'during_commit', 'after_commit']) {
      test(
        '$protocol hard OS process kill $stage restores atomic acknowledgement/outbox/draft',
        () => assertHardKillRecovery(protocol: protocol, stage: stage),
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  }
}
