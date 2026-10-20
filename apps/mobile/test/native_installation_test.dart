import 'package:daily_motion/qualification/native_installation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'synthetic harness rejects ordinary and missing native app identities',
    () {
      for (final device in <Map<String, dynamic>>[
        {},
        {
          'platform': 'android',
          'application_id': 'com.dailymotion.training.daily_motion',
        },
        {
          'platform': 'ios',
          'application_id': 'com.dailymotion.training.dailyMotion',
        },
        {'platform': 'android', 'application_id': 'app.qualification.personal'},
        {'platform': 'unknown', 'application_id': 'app.qualification'},
        {'platform': 'android', 'application_id': 42},
      ]) {
        expect(
          () => requireQualificationInstallation(device),
          throwsStateError,
        );
      }
    },
  );

  test('Android and iOS dedicated native installations are accepted', () {
    for (final platform in ['android', 'ios']) {
      expect(
        () => requireQualificationInstallation({
          'platform': platform,
          'application_id': 'com.dailymotion.training.qualification',
        }),
        returnsNormally,
      );
    }
  });
}
