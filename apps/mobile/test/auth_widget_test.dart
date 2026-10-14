import 'dart:async';
import 'dart:io';

import 'package:daily_motion/auth/account_controller.dart';
import 'package:daily_motion/auth/auth_app.dart';
import 'package:daily_motion/auth/configuration.dart';
import 'package:daily_motion/auth/local_owners.dart';
import 'package:daily_motion/auth/secure_storage.dart';
import 'package:daily_motion/data/database.dart';
import 'package:daily_motion/data/workout_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/sync_server.dart';

// Real SQLite for widget semantics; file persistence is tested by the account suite.
class WidgetOwnerStores extends LocalOwnerStores {
  WidgetOwnerStores() : super(Directory('unused-widget-path'));
  @override
  Future<LocalOwner> open(String verifiedOwner, {bool existing = false}) async {
    final database = TrainingDatabase(NativeDatabase.memory());
    return LocalOwner(database, WorkoutRepository(database, verifiedOwner));
  }
}

void main() {
  testWidgets(
    'an in-flight OTP request disables repeat submission and shows progress',
    (tester) async {
      final release = Completer<void>();
      final provider = FakeOtpProvider(
        testSession(testOwner, DateTime.now().toUtc()),
      )..requestOperation = () => release.future;
      final server = SyncServer();
      final controller = AccountController(
        provider: provider,
        gateway: FakeAccountGateway({testOwner: server}),
        storage: SecureSessionStorage(MemoryProtectedStorage(), 'widget'),
        stores: WidgetOwnerStores(),
        syncTransport: (_, _) => server,
      );
      controller.foreground(false);
      await controller.restore();
      await tester.pumpWidget(AccountApplication(controller: controller));
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'synthetic@example.test',
      );
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send code'),
            )
            .onPressed,
        null,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(provider.requests, 1);
      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Verify code'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(controller.close);
    },
  );
  testWidgets(
    'email-code UI verifies an owner without creating a personal sample workout',
    (tester) async {
      final now = DateTime.now().toUtc();
      final provider = FakeOtpProvider(testSession(testOwner, now));
      final server = SyncServer();
      final storage = SecureSessionStorage(MemoryProtectedStorage(), 'widget');
      final controller = AccountController(
        provider: provider,
        gateway: FakeAccountGateway({testOwner: server}),
        storage: storage,
        stores: WidgetOwnerStores(),
        syncTransport: (_, _) => server,
      );
      controller.foreground(false);
      await controller.restore();
      await tester.pumpWidget(AccountApplication(controller: controller));
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'synthetic@example.test',
      );
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(find.text('Verify code'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Email code'),
        '123456',
      );
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();
      expect(controller.owner, testOwner);
      expect(find.text('Start workout'), findsNothing);
      expect(await controller.local!.repository.workouts(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(controller.close);
    },
  );
  testWidgets(
    'OTP request failure shows a request error without false account-setup retry',
    (tester) async {
      final provider = FakeOtpProvider(
        testSession(testOwner, DateTime.now().toUtc()),
      )..requestFailure = const AuthFailure('otp_request_failed');
      final server = SyncServer();
      final controller = AccountController(
        provider: provider,
        gateway: FakeAccountGateway({testOwner: server}),
        storage: SecureSessionStorage(MemoryProtectedStorage(), 'widget'),
        stores: WidgetOwnerStores(),
        syncTransport: (_, _) => server,
      );
      controller.foreground(false);
      await controller.restore();
      await tester.pumpWidget(AccountApplication(controller: controller));
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'synthetic@example.test',
      );
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(
        find.text('This request could not be completed. Please retry.'),
        findsOneWidget,
      );
      expect(find.text('Retry account setup'), findsNothing);
      expect(find.text('Verify code'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(controller.close);
    },
  );
}
