import 'dart:convert';

import '../sync/contract_validation.dart';
import '../sync/transport_contract.dart';
import 'workout.dart';

/// Immutable planned content using the existing workout creation contract.
/// Getters return detached copies; no performed observations belong here.
class RoutinePlan {
  final String _encoded;
  RoutinePlan._(this._encoded);

  factory RoutinePlan({required String name, required List<Json> exercises}) =>
      RoutinePlan.fromJson({
        'name': name.trim(),
        'timezone': 'Asia/Kolkata',
        'exercises': exercises,
      });

  factory RoutinePlan.fromJson(Json value) {
    final content = copyJson(value);
    try {
      validateTransport('CreateSession', content);
    } on ContractViolation {
      throw const WorkoutValidation(
        'Check the routine name, exercise definitions and planned sets.',
      );
    }
    require((content['name'] as String).trim().isNotEmpty, 'Name the routine.');
    for (final exercise in (content['exercises'] as List).cast<Json>()) {
      require(
        (exercise['name'] as String).trim().isNotEmpty,
        'Name each exercise.',
      );
      for (final item in (exercise['sets'] as List).cast<Json>()) {
        require(
          item['set_purpose'] != 'backoff' || item['set_class'] == 'working',
          'Back-off sets must be working sets.',
        );
      }
    }
    // A non-UUID sentinel cannot collide with contract-validated child UUIDs.
    // This reducer call validates prescriptions; it does not create a session.
    applyOperation(null, {
      'command': 'create_session',
      'aggregate_id': 'routine-prescription-validation',
      'occurred_at': '2000-01-01T00:00:00Z',
      'payload': content,
    });
    const uuid = '00000000-0000-4000-8000-000000000000';
    const instant = '9999-12-31T23:59:59.999999Z';
    // Reserve the full existing v2 envelope and largest supported revision,
    // just as commit() does. A saved plan must fit a future workout command.
    final bounded = {
      'schema_version': 2,
      'mutation_id': uuid,
      'installation_id': uuid,
      'aggregate_type': 'workout_session',
      'aggregate_id': uuid,
      'expected_revision': 9223372036854775807,
      'command': 'create_session',
      'occurred_at': instant,
      'recorded_at': instant,
      'environment_id': uuid,
      'origin_incarnation': uuid,
      'origin_generation': uuid,
      'payload': {...content, 'timezone': 'Asia/Calcutta'},
    };
    require(
      utf8.encode(canonicalJson(bounded)).length <= commandByteLimit,
      'This routine is too large to start safely. Reduce its planned content.',
    );
    return RoutinePlan._(canonicalJson(content));
  }

  Json get json => jsonDecode(_encoded) as Json;
  String get name => json['name'] as String;
  List<Json> get exercises => (json['exercises'] as List).cast<Json>();
}

class SavedRoutine {
  final String id;
  final String templateId;

  /// Device-local editor revision, never a server acknowledgement.
  final int localRevision;
  final RoutinePlan plan;
  const SavedRoutine({
    required this.id,
    required this.templateId,
    required this.localRevision,
    required this.plan,
  });
}
