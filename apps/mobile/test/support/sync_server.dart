import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/transport.dart';
import 'package:daily_motion/sync/transport_contract.dart';

const testOwner = '20000000-0000-4000-8000-000000000001';
const testGeneration = '40000000-0000-4000-8000-000000000001';

/// Deterministic transport timing harness. Database semantics are separately
/// exercised by the connected HTTP/PostgreSQL suite, never inferred from this fake.
class SyncServer implements SyncTransport {
  @override
  Future<SyncTransport> beginCycle() async => this;
  String owner = testOwner;
  String generation = testGeneration;
  int epoch = 0;
  int position = 0;
  final roots = <String, Json>{};
  final receipts = <String, Json>{};
  final digests = <String, String>{};
  final feed = <Json>[];
  final retired = <String>{};
  final pushed = <String>[];
  final snapshotPages = <String, List<Json>>{};
  final snapshotEpochs = <String, int>{};
  int limit = 100;
  bool disabled = false;
  String? failBefore;
  String? failAfter;
  Future<void> Function(String method)? before;
  Future<void> Function(String method)? after;

  Json get context => {
    'schema_version': 1,
    'owner_id': owner,
    'generation': generation,
    'erasure_epoch': epoch,
  };
  Json get identity => {
    ...context,
    'position': position,
    'minimum_position': 0,
    'account_status': 'active',
    'command_limit': 262144,
    'batch_limit': 1048576,
    'page_limit': 524288,
    'snapshot_limit': 67108864,
  };
  Future<void> boundary(String method, {bool isAfter = false}) async {
    if (disabled) throw SyncFailure('account_inactive', ownerId: owner);
    await (isAfter ? after : before)?.call(method);
    final failure = isAfter ? failAfter : failBefore;
    if (failure != null && method == 'push') {
      if (isAfter) {
        failAfter = null;
      } else {
        failBefore = null;
      }
      throw SyncFailure(failure, retryable: true);
    }
  }

  @override
  Future<MeResponseDto> me() async {
    await boundary('me');
    return MeResponseDto.fromJson(identity);
  }

  @override
  Future<PushResponseDto> push(String frozenBatch) async {
    pushed.add(frozenBatch);
    await boundary('push');
    final request = PushRequestDto.fromJson(jsonDecode(frozenBatch) as Json);
    final results = <Json>[];
    for (final op in request.operations.cast<Json>()) {
      final id = op['aggregate_id'] as String;
      final mutation = op['mutation_id'] as String;
      final digest = canonicalJson(op);
      final base = op['expected_revision'] as int;
      Json result;
      if (receipts.containsKey(mutation)) {
        result = digests[mutation] != digest
            ? {
                'mutation_id': mutation,
                'aggregate_id': id,
                'status': 'rejected',
                'error': {
                  'code': 'mutation_digest_mismatch',
                  'retryable': false,
                },
              }
            : {
                ...receipts[mutation]!,
                if (receipts[mutation]!['status'] == 'accepted')
                  'status': 'duplicate',
              };
      } else if (retired.contains(id)) {
        result = {
          'mutation_id': mutation,
          'aggregate_id': id,
          'status': 'rejected',
          'error': {'code': 'retired_id', 'retryable': false},
        };
      } else if ((roots[id]?['revision'] ?? 0) != base) {
        result = {
          'mutation_id': mutation,
          'aggregate_id': id,
          'status': 'conflict',
          'expected_revision': base,
          'current_revision': roots[id]?['revision'] ?? 0,
          'error': {'code': 'revision_conflict', 'retryable': false},
        };
      } else {
        try {
          final root = applyOperation(roots[id], op, revision: base + 1);
          if (root == null) {
            erase(id);
          } else {
            roots[id] = root;
            feed.add({
              'position': ++position,
              'operation': copyJson(op),
              'revision': base + 1,
            });
          }
          result = {
            'mutation_id': mutation,
            'aggregate_id': id,
            'status': 'accepted',
            'accepted_revision': base + 1,
            'accepted_at': '2026-10-13T07:00:00Z',
          };
        } catch (_) {
          result = {
            'mutation_id': mutation,
            'aggregate_id': id,
            'status': 'rejected',
            'error': {'code': 'invalid_transition', 'retryable': false},
          };
        }
      }
      receipts.putIfAbsent(mutation, () => copyJson(result));
      digests.putIfAbsent(mutation, () => digest);
      results.add(result);
    }
    await boundary('push', isAfter: true);
    return PushResponseDto.fromJson({...context, 'results': results});
  }

  void erase(String id) {
    final root = roots.remove(id);
    retired.add(id);
    if (root != null) {
      for (final e in root['exercises'] as List) {
        retired.add(e['session_exercise_id'] as String);
      }
      retired.addAll(allSets(root).map((s) => s['set_id'] as String));
    }
    epoch++;
    for (var i = 0; i < feed.length; i++) {
      if (feed[i]['operation']?['aggregate_id'] == id) {
        feed[i] = {
          'position': feed[i]['position'],
          'aggregate_id': id,
          'redacted': true,
          'retired_ids': retired.toList(),
        };
      }
    }
    feed.add({
      'position': ++position,
      'aggregate_id': id,
      'redacted': true,
      'retired_ids': retired.toList(),
    });
  }

  @override
  Future<PullResponseDto> pull(String? cursor) async {
    await boundary('pull');
    final from = cursor == null ? 0 : int.parse(cursor.split(':').last);
    if (cursor != null && !cursor.startsWith('$generation:')) {
      throw const SyncFailure('bootstrap_required');
    }
    final changes = feed
        .where((c) => (c['position'] as int) > from)
        .take(limit)
        .toList();
    final end = changes.isEmpty ? from : changes.last['position'] as int;
    await boundary('pull', isAfter: true);
    return PullResponseDto.fromJson({
      ...context,
      'changes': changes,
      'next_cursor': '$generation:$end',
      'next_position': end,
      'has_more': end < position,
    });
  }

  @override
  Future<BootstrapManifestDto> bootstrap(String installation) async {
    await boundary('bootstrap');
    final token = 'snapshot-${snapshotPages.length}';
    final pages = <Json>[
      {
        'roots': roots.values.map(copyJson).toList(),
        'retired_ids': retired.toList(),
      },
    ];
    snapshotPages[token] = pages;
    snapshotEpochs[token] = epoch;
    return BootstrapManifestDto.fromJson({
      ...context,
      'installation_id': installation,
      'token': token,
      'page_count': pages.length,
      'checksums': pages
          .map((p) => sha256.convert(utf8.encode(canonicalJson(p))).toString())
          .toList(),
      'cursor': '$generation:$position',
      'position': position,
      'expires_at': '2099-01-01T00:00:00Z',
    });
  }

  @override
  Future<SnapshotPageDto> page(String token, int index) async {
    await boundary('page');
    if (snapshotEpochs[token] != epoch) {
      throw const SyncFailure('snapshot_expired');
    }
    final page = SnapshotPageDto.fromJson(snapshotPages[token]![index]);
    await boundary('page', isAfter: true);
    return page;
  }

  @override
  Future<MeResponseDto> validateSnapshot(String token) async {
    await boundary('validate');
    if (snapshotEpochs[token] != epoch) {
      throw const SyncFailure('snapshot_expired');
    }
    return MeResponseDto.fromJson(identity);
  }
}
