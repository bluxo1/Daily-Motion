import 'dart:convert';

import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'repository_test.dart' show fixture;

void main() {
  String head({int bytes = 100, String? root}) {
    final op = fixture()
      ..['mutation_id'] = const Uuid().v4()
      ..['aggregate_id'] = root ?? const Uuid().v4();
    // Transport packing is independent of domain payload contents. ASCII padding
    // models large already-frozen heads; domain acceptance is tested separately.
    op['payload']['padding'] = 'x' * bytes;
    return canonicalJson(op);
  }

  test('mixed large heads pack adaptively without exceeding 1 MiB', () {
    final heads = [
      for (var i = 0; i < 6; i++) head(bytes: 240000),
      head(bytes: 100),
      head(bytes: 100),
    ];
    final batch = packFrozenHeads(heads);
    expect(utf8.encode(batch.body).length, lessThanOrEqualTo(1048576));
    expect(
      batch.operations.length,
      6,
    ); // Four large and both small independent roots.
    final remaining = heads
        .where((h) => !batch.operations.contains(h))
        .toList();
    expect(packFrozenHeads(remaining).operations.length, 2);
    expect(batch.oversized, isEmpty);
  });
  test(
    '50-operation and one-head-per-root bounds preserve all remaining commands',
    () {
      final root = const Uuid().v4();
      final heads = [
        head(root: root),
        head(root: root),
        for (var i = 0; i < 55; i++) head(),
      ];
      final batch = packFrozenHeads(heads);
      expect(batch.operations.length, 50);
      expect(
        batch.operations
            .where((h) => jsonDecode(h)['aggregate_id'] == root)
            .length,
        1,
      );
      final remaining = heads
          .where((h) => !batch.operations.contains(h))
          .toList();
      expect(packFrozenHeads(remaining).operations.length, 7);
    },
  );
  test(
    'oversized corrupt legacy head does not starve independent valid heads',
    () {
      final bad = head(bytes: 262144), good = head();
      final batch = packFrozenHeads([bad, good]);
      expect(batch.oversized, [jsonDecode(bad)['mutation_id']]);
      expect(batch.operations, [good]);
    },
  );
}
