import 'package:daily_motion/auth/configuration.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_rejection.dart';

class _SensitiveResult {
  bool formatted = false;

  @override
  String toString() {
    formatted = true;
    throw StateError('A credential-bearing result was formatted');
  }
}

void main() {
  test(
    'authentication rejection never formats an unexpected session',
    () async {
      final sensitive = _SensitiveResult();
      await expectLater(
        requireAuthRejection(() async => sensitive, 'authentication_required'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'safe message',
            'Expected authentication rejection',
          ),
        ),
      );
      expect(sensitive.formatted, false);
    },
  );

  test('authentication rejection requires the exact safe category', () async {
    await requireAuthRejection(
      () async => throw const AuthFailure('authentication_required'),
      'authentication_required',
    );
    await expectLater(
      requireAuthRejection(
        () async => throw const AuthFailure('provider_unavailable'),
        'authentication_required',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('unexpected provider errors are replaced without formatting', () async {
    final sensitive = _SensitiveResult();
    await expectLater(
      requireAuthRejection(
        () async => throw sensitive,
        'authentication_required',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'safe message',
          'Unexpected authentication failure type',
        ),
      ),
    );
    expect(sensitive.formatted, false);
  });
}
