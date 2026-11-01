import 'dart:convert';

import '../domain/workout.dart';
import 'transport_limits.dart';
import 'contract_validation.dart';

class PackedBatch {
  final List<String> operations;
  final List<String> mutations;
  final List<String> oversized;
  final int schemaVersion;
  const PackedBatch(
    this.operations,
    this.mutations,
    this.oversized, {
    this.schemaVersion = 1,
  });
  String get body =>
      '{"schema_version":$schemaVersion,"operations":[${operations.join(',')}]}';
}

/// Envelopes remain byte-identical. Skip heads that cannot fit this request,
/// allowing smaller independent roots to proceed, without truncating any head.
PackedBatch packFrozenHeads(Iterable<String> heads, {int schemaVersion = 1}) {
  if (![1, 3].contains(schemaVersion)) {
    throw const ContractViolation('upgrade_required');
  }
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
    final root = schemaVersion == 3
        ? '${operation['aggregate_type']}:${operation['aggregate_id']}'
        : operation['aggregate_id'] as String;
    if (roots.contains(root) ||
        bodies.length == transportOperationCountLimit ||
        length + size + (bodies.isEmpty ? 0 : 1) > transportBatchLimit) {
      continue;
    }
    roots.add(root);
    if (schemaVersion == 3 && mutations.contains(mutation)) {
      throw const ContractViolation('identity_collision');
    }
    bodies.add(body);
    mutations.add(mutation);
    length += size + (bodies.length == 1 ? 0 : 1);
  }
  return PackedBatch(
    bodies,
    mutations,
    oversized,
    schemaVersion: schemaVersion,
  );
}
