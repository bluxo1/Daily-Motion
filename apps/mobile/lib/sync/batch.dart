import 'dart:convert';

import '../domain/workout.dart';
import 'transport_limits.dart';

class PackedBatch {
  final List<String> operations;
  final List<String> mutations;
  final List<String> oversized;
  const PackedBatch(this.operations, this.mutations, this.oversized);
  String get body =>
      '{"schema_version":1,"operations":[${operations.join(',')}]}';
}

/// Envelopes remain byte-identical. Skip heads that cannot fit this request,
/// allowing smaller independent roots to proceed, without truncating any head.
PackedBatch packFrozenHeads(Iterable<String> heads) {
  final bodies = <String>[];
  final mutations = <String>[];
  final oversized = <String>[];
  final roots = <String>{};
  var length = utf8.encode('{"schema_version":1,"operations":[]}').length;
  for (final body in heads) {
    final operation = jsonDecode(body) as Json;
    final mutation = operation['mutation_id'] as String;
    final size = utf8.encode(body).length;
    if (size > transportCommandLimit) {
      oversized.add(mutation);
      continue;
    }
    final root = operation['aggregate_id'] as String;
    if (roots.contains(root) ||
        bodies.length == transportOperationCountLimit ||
        length + size + (bodies.isEmpty ? 0 : 1) > transportBatchLimit) {
      continue;
    }
    roots.add(root);
    bodies.add(body);
    mutations.add(mutation);
    length += size + (bodies.length == 1 ? 0 : 1);
  }
  return PackedBatch(bodies, mutations, oversized);
}
