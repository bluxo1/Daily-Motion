import 'package:flutter_test/flutter_test.dart';

import 'support/hosted_otp_schedule.dart';

void main() {
  late DateTime clock;
  late List<Duration> waits;
  late HostedOtpSchedule schedule;

  setUp(() {
    clock = DateTime.utc(2026, 10, 19);
    waits = [];
    schedule = HostedOtpSchedule(
      now: () => clock,
      delay: (duration) async {
        waits.add(duration);
        clock = clock.add(duration);
      },
    );
  });

  test(
    'slow acknowledgement still leaves a full cooldown for return to A',
    () async {
      await schedule.request('A', () async {
        clock = clock.add(const Duration(seconds: 15));
      });
      await schedule.request('A', () async {});

      expect(waits, [const Duration(seconds: 61)]);
      expect(schedule.accountCount, 1);
    },
  );

  test(
    'B has an independent clock and does not erase the A cooldown',
    () async {
      await schedule.request('A', () async {
        clock = clock.add(const Duration(seconds: 15));
      });
      await schedule.request('B', () async {
        clock = clock.add(const Duration(seconds: 10));
      });
      expect(waits, isEmpty);
      await schedule.request('A', () async {});

      expect(waits, [const Duration(seconds: 51)]);
      expect(schedule.accountCount, 2);
    },
  );

  test('elapsed cooldown needs no additional delay', () async {
    await schedule.request('A', () async {});
    clock = clock.add(const Duration(seconds: 62));
    await schedule.request('A', () async {});

    expect(waits, isEmpty);
  });

  test('failed request is not retried or recorded as successful', () async {
    var calls = 0;
    await expectLater(
      schedule.request('A', () async {
        calls++;
        throw StateError('synthetic request failure');
      }),
      throwsStateError,
    );

    expect(calls, 1);
    expect(schedule.accountCount, 0);
    expect(waits, isEmpty);
  });
}
