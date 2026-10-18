import 'package:daily_motion/auth/configuration.dart';

/// Unlike a throwsA matcher, this never formats an unexpected session result.
Future<void> requireAuthRejection(
  Future<Object?> Function() operation,
  String expectedCode,
) async {
  try {
    await operation();
  } on AuthFailure catch (failure) {
    if (failure.code == expectedCode) return;
    throw StateError('Unexpected authentication error category');
  } catch (_) {
    throw StateError('Unexpected authentication failure type');
  }
  throw StateError('Expected authentication rejection');
}
