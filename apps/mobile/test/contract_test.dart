import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_motion/domain/workout.dart';
import 'package:daily_motion/sync/contract_validation.dart';
import 'package:daily_motion/sync/transport_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show fixture;

void main() {
  test(
    'generated contract hash matches the checked authority and shared fixture',
    () {
      expect(
        sha256
            .convert(File('../../contracts/openapi.json').readAsBytesSync())
            .toString(),
        transportContractHash,
      );
      expect(OperationDto.fromJson(fixture()).aggregateType, 'workout_session');
      final unicode = jsonDecode(
        File('../../contracts/fixtures/unicode_workout.json')
            .readAsStringSync(),
      ) as Json;
      final root = applyOperation(null, OperationDto.fromJson(unicode).json)!;
      expect((root['name'] as String).runes.length, 80);
    },
  );
  test('command-specific payload and timestamp parsing fail explicitly', () {
    final op = fixture();
    op['payload']['unexpected'] = true;
    expect(() => OperationDto.fromJson(op), throwsA(isA<ContractViolation>()));
    final invalidDate = fixture()..['occurred_at'] = '2026-13-01T00:00:00Z';
    expect(
      () => OperationDto.fromJson(invalidDate),
      throwsA(isA<ContractViolation>()),
    );
    expect(isUtcInstant('2024-02-29T23:59:59.123456Z'), true);
    expect(isUtcInstant('2025-02-29T23:59:59Z'), false);
    for (final reason in ['   ', '\ufeff', '\u001c', '\u0085']) {
      expect(
        () => RecordSetDto.fromJson({
          'session_exercise_id':
              fixture()['payload']['exercises'][0]['session_exercise_id'],
          'set_id': fixture()['payload']['exercises'][0]['sets'][0]['set_id'],
          'execution_status': 'skipped',
          'actual': null,
          'completion_seq': 1,
          'correction_reason': reason,
        }),
        throwsA(isA<ContractViolation>()),
      );
    }
  });
  test('optional defaults normalize a separate domain copy without changing retry identity', () {
    final op = fixture();
    final item = op['payload']['exercises'][0]['sets'][0] as Json;
    item.remove('set_class');
    item.remove('set_purpose');
    item['planned'].remove('rest_seconds');
    final raw = jsonEncode(op);
    final normalized = domainTransportOperation(
      OperationDto.fromJson(op).json,
      transportSchemas,
    );
    final root = applyOperation(null, normalized)!;
    expect(allSets(root).first['planned']['rest_seconds'], 120);
    expect(jsonEncode(op), raw);
  });
}
