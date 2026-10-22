part of 'workout_repository.dart';

final _recoveryUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Internal persistence from a verified, certified V2 transport response.
/// This is not a wire DTO or an authority credential. No v1 response, header,
/// timestamp or revision can supply missing lineage.
class RecoveryContext {
  final String ownerId;
  final String environmentId;
  final String incarnation;
  final String generation;
  final int activationSerial;
  final int evidenceOrder;
  final String evidenceDigest;
  final int erasureEpoch;
  final int position;

  RecoveryContext({
    required this.ownerId,
    required this.environmentId,
    required this.incarnation,
    required this.generation,
    required this.activationSerial,
    required this.evidenceOrder,
    required this.evidenceDigest,
    required this.erasureEpoch,
    required this.position,
  }) {
    for (final value in [ownerId, environmentId, incarnation, generation]) {
      if (!_recoveryUuid.hasMatch(value)) {
        throw const ContractViolation('recovery_metadata_unverified');
      }
    }
    if (activationSerial <= 0 ||
        [
          activationSerial,
          evidenceOrder,
          erasureEpoch,
          position,
        ].any((value) => value < 0 || value > 9223372036854775807) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(evidenceDigest) ||
        (evidenceOrder == 0) != (evidenceDigest == '0' * 64)) {
      throw const ContractViolation('recovery_metadata_unverified');
    }
  }

  Json get origin => {
    'environment_id': environmentId,
    'origin_incarnation': incarnation,
    'origin_generation': generation,
  };
  Json get json => {
    'owner_id': ownerId,
    'environment_id': environmentId,
    'incarnation': incarnation,
    'generation': generation,
    'activation_serial': activationSerial,
    'evidence_order': evidenceOrder,
    'evidence_digest': evidenceDigest,
    'erasure_epoch': erasureEpoch,
    'position': position,
  };

  static RecoveryContext _decode(String encoded) {
    try {
      final value = jsonDecode(encoded) as Json;
      if (value.length != 9) throw const FormatException();
      return RecoveryContext(
        ownerId: value['owner_id'] as String,
        environmentId: value['environment_id'] as String,
        incarnation: value['incarnation'] as String,
        generation: value['generation'] as String,
        activationSerial: value['activation_serial'] as int,
        evidenceOrder: value['evidence_order'] as int,
        evidenceDigest: value['evidence_digest'] as String,
        erasureEpoch: value['erasure_epoch'] as int,
        position: value['position'] as int,
      );
    } on FormatException {
      throw const ContractViolation('recovery_metadata_unverified');
    } on TypeError {
      throw const ContractViolation('recovery_metadata_unverified');
    }
  }
}

Json _withoutRecoveryFields(Json operation) =>
    Map<String, dynamic>.from(operation)
      ..remove('schema_version')
      ..remove('environment_id')
      ..remove('origin_incarnation')
      ..remove('origin_generation');

Json _decodeRecoveryOrigin(String encoded) {
  try {
    final value = jsonDecode(encoded) as Json;
    const fields = [
      'environment_id',
      'origin_incarnation',
      'origin_generation',
    ];
    if (value.length != fields.length) throw const FormatException();
    for (final field in fields) {
      final item = value[field] as String;
      if (!_recoveryUuid.hasMatch(item)) {
        throw const FormatException();
      }
    }
    return value;
  } on FormatException {
    throw const ContractViolation('recovery_metadata_unverified');
  } on TypeError {
    throw const ContractViolation('recovery_metadata_unverified');
  }
}

extension RecoveryRepository on WorkoutRepository {
  /// Persists an already-verified historical result in isolation from live state.
  /// The future certified transport must authenticate its original context and
  /// result binding before calling this. This method supplies no certificate
  /// verification and is not a wire decoder or automatic conflict resolution.
  Future<void> recordHistoricalResult({
    required Json result,
    required String requestDigest,
    required RecoveryContext originalContext,
  }) async {
    final captured = jsonDecode(canonicalJson(result)) as Json;
    await db.transaction(() async {
      await _guard();
      if (originalContext.ownerId != ownerId) {
        throw const ContractViolation('wrong_owner');
      }
      final current = await _currentRecoveryContext();
      if (current == null ||
          originalContext.environmentId != current.environmentId ||
          originalContext.activationSerial >= current.activationSerial ||
          originalContext.evidenceOrder > current.evidenceOrder ||
          originalContext.evidenceOrder == 0 ||
          originalContext.evidenceOrder == current.evidenceOrder &&
              originalContext.evidenceDigest != current.evidenceDigest ||
          originalContext.erasureEpoch > current.erasureEpoch ||
          canonicalJson(originalContext.origin) ==
              canonicalJson(current.origin)) {
        throw const ContractViolation('recovery_metadata_unverified');
      }
      final schema = switch (captured['status']) {
        'accepted' => 'AcceptedResult',
        'conflict' => 'ConflictResult',
        'rejected' => 'RejectedResult',
        _ => throw const ContractViolation('recovery_metadata_unverified'),
      };
      validateTransport(schema, captured);
      final row = await db
          .customSelect(
            'SELECT * FROM outbox WHERE mutation_id=?',
            variables: [Variable(captured['mutation_id'] as String)],
          )
          .getSingleOrNull();
      if (row == null ||
          row.read<String>('session_id') != captured['aggregate_id'] ||
          row.read<int>('wire_version') != 2 ||
          row.readNullable<String>('origin_context') !=
              canonicalJson(originalContext.origin)) {
        throw const ContractViolation('timeline_reconciliation_required');
      }
      final frozen = row.readNullable<String>('frozen_body');
      if (frozen == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(requestDigest) ||
          sha256.convert(utf8.encode(frozen)).toString() != requestDigest) {
        throw const ContractViolation('mutation_digest_mismatch');
      }
      final operation = jsonDecode(frozen) as Json;
      validateTransport('OperationV2', operation);
      if (operation['mutation_id'] != captured['mutation_id'] ||
          operation['aggregate_id'] != captured['aggregate_id'] ||
          canonicalJson({
                for (final key in originalContext.origin.keys)
                  key: operation[key],
              }) !=
              canonicalJson(originalContext.origin) ||
          captured['status'] == 'accepted' &&
              captured['accepted_revision'] !=
                  (operation['expected_revision'] as int) + 1 ||
          captured['status'] == 'conflict' &&
              captured['expected_revision'] != operation['expected_revision']) {
        throw const ContractViolation('recovery_metadata_unverified');
      }
      // Store the original result and context, never a later /me context. No
      // acknowledgement, shadow, cursor, successor, projection or draft changes.
      final evidence = canonicalJson({
        'schema_version': 2,
        'request_digest': requestDigest,
        'original_context': originalContext.json,
        'original_result': captured,
      });
      final mutation = row.read<String>('mutation_id');
      final previous = await db
          .customSelect(
            'SELECT evidence FROM historical_receipts WHERE mutation_id=?',
            variables: [Variable(mutation)],
          )
          .getSingleOrNull();
      if (previous != null) {
        if (previous.read<String>('evidence') != evidence) {
          throw const ContractViolation('recovery_metadata_unverified');
        }
        return;
      }
      await db.customStatement(
        'INSERT INTO historical_receipts(mutation_id,evidence) VALUES(?,?)',
        [mutation, evidence],
      );
    });
  }

  Future<bool> _recoveryRequired() async {
    final row = await db
        .customSelect(
          'SELECT required,current_context,high_water FROM recovery_state',
        )
        .getSingleOrNull();
    // A cleared/reset flag cannot undo other durable evidence of V2 use. Keep
    // inconsistent metadata intact for reconciliation; never guess a repair.
    if (row == null) return true;
    try {
      if (row.read<int>('required') != 0 ||
          row.readNullable<String>('current_context') != null ||
          row.read<int>('high_water') != 0) {
        return true;
      }
    } on FormatException {
      return true;
    } on TypeError {
      return true;
    }
    // Only an otherwise pre-activation row needs this retained-evidence lookup.
    // Normal V2 saves read the singleton and never scan old command history.
    return (await db.customSelect(
          '''SELECT
          EXISTS(SELECT 1 FROM outbox WHERE wire_version=2
                 UNION ALL SELECT 1 FROM shadows WHERE recovery_context IS NOT NULL
                 UNION ALL SELECT 1 FROM historical_receipts) AS retained_v2''',
        ).getSingle()).read<int>('retained_v2') !=
        0;
  }

  Future<RecoveryContext?> _currentRecoveryContext() async {
    try {
      final row = await db
          .customSelect(
            'SELECT required,current_context,high_water FROM recovery_state',
          )
          .getSingleOrNull();
      final value = row?.readNullable<String>('current_context');
      if (value == null) return null;
      final context = RecoveryContext._decode(value);
      if (context.ownerId != ownerId) {
        throw const ContractViolation('wrong_owner');
      }
      if (row!.read<int>('required') != 1 ||
          row.read<int>('high_water') < context.erasureEpoch) {
        throw const ContractViolation('recovery_metadata_unverified');
      }
      return context;
    } on FormatException {
      throw const ContractViolation('recovery_metadata_unverified');
    } on TypeError {
      // SQLite's dynamic types can still hold malformed metadata. Use the
      // existing typed cloud pause so valid local saves retain unknown origin.
      throw const ContractViolation('recovery_metadata_unverified');
    }
  }

  Future<RecoveryContext?> recoveryContext() => db.transaction(() async {
    await _guard();
    return _currentRecoveryContext();
  });

  /// Called only after explicit V2 negotiation. No automatic downgrade exists.
  Future<void> requireRecoveryProtocol() => db.transaction(() async {
    await _guard();
    await db.customStatement('UPDATE recovery_state SET required=1');
  });

  /// Installs already-verified context without changing branches, bodies or cursor.
  Future<void> installRecoveryContext(RecoveryContext context) =>
      db.transaction(() async {
        await _guard();
        if (context.ownerId != ownerId) {
          throw const ContractViolation('wrong_owner');
        }
        final previous = await _currentRecoveryContext();
        final highWater =
            (await db
                    .customSelect('SELECT high_water FROM recovery_state')
                    .getSingle())
                .read<int>('high_water');
        final metadata = await syncMetadata();
        if (context.erasureEpoch < highWater ||
            context.erasureEpoch < (metadata['erasure_epoch'] as int)) {
          throw const ContractViolation('recovery_metadata_unverified');
        }
        if (previous != null) {
          final sameTimeline =
              canonicalJson(previous.origin) == canonicalJson(context.origin);
          if (context.environmentId != previous.environmentId ||
              context.activationSerial < previous.activationSerial ||
              context.evidenceOrder < previous.evidenceOrder ||
              context.evidenceOrder == previous.evidenceOrder &&
                  context.evidenceDigest != previous.evidenceDigest ||
              context.activationSerial == previous.activationSerial &&
                  !sameTimeline ||
              sameTimeline && context.position < previous.position) {
            throw const ContractViolation('recovery_metadata_unverified');
          }
        }
        await db.customStatement(
          'UPDATE recovery_state SET required=1,current_context=?,high_water=?',
          [canonicalJson(context.json), context.erasureEpoch],
        );
      });

  Future<Json?> _captureOrigin(
    QueryRow? predecessor,
    QueryRow? shadow, {
    required bool newRoot,
  }) async {
    // Successors inherit their pending predecessor, including unknown origin.
    if (predecessor != null) {
      final encoded = predecessor.readNullable<String>('origin_context');
      return encoded == null ? null : _decodeRecoveryOrigin(encoded);
    }
    if (newRoot) return (await _currentRecoveryContext())?.origin;
    // Existing clean work requires its own certified shadow, not current /me.
    final encoded = shadow?.readNullable<String>('recovery_context');
    if (encoded == null) return null;
    final context = RecoveryContext._decode(encoded);
    if (context.ownerId != ownerId) {
      throw const ContractViolation('wrong_owner');
    }
    return context.origin;
  }

  Future<bool> _eligibleRecoveryHead(QueryRow row) async {
    final origin = row.readNullable<String>('origin_context');
    RecoveryContext? current;
    try {
      current = await _currentRecoveryContext();
    } on ContractViolation {
      // Unverifiable cloud metadata never locks local training or guesses origin.
    }
    String? code;
    if (row.read<int>('wire_version') != 2 || origin == null) {
      code = 'timeline_reconciliation_required';
    } else if (current == null) {
      code = 'recovery_metadata_unverified';
    } else {
      try {
        final stored = _decodeRecoveryOrigin(origin);
        final operation = jsonDecode(
          row.readNullable<String>('frozen_body') ??
              row.read<String>('operation'),
        ) as Json;
        validateTransport('OperationV2', operation);
        final embedded = {
          for (final key in [
            'environment_id',
            'origin_incarnation',
            'origin_generation',
          ])
            key: operation[key],
        };
        if (canonicalJson(stored) != canonicalJson(embedded)) {
          throw const ContractViolation('recovery_metadata_unverified');
        }
        if (canonicalJson(stored) != canonicalJson(current.origin)) {
          code = 'timeline_reconciliation_required';
        }
      } on ContractViolation {
        code = 'recovery_metadata_unverified';
      } on FormatException {
        code = 'recovery_metadata_unverified';
      } on TypeError {
        code = 'recovery_metadata_unverified';
      }
    }
    await db.customStatement(
      'UPDATE outbox SET last_error=? WHERE mutation_id=?',
      [code, row.read<String>('mutation_id')],
    );
    return code == null;
  }

  Future<void> _requireLegacySync() async {
    if (await _recoveryRequired()) {
      throw const ContractViolation('upgrade_required');
    }
  }
}
