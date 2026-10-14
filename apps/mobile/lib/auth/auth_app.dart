import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import '../features/home_screen.dart';
import '../features/workout_controller.dart';
import '../features/sync_provider.dart';
import 'account_controller.dart';

final accountControllerProvider = Provider<AccountController?>((ref) => null);

class AccountApplication extends StatelessWidget {
  final AccountController controller;
  const AccountApplication({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) {
      final selected = controller.local;
      if (selected != null &&
          controller.state.phase != AccountPhase.signingOut) {
        return _TrainingApplication(
          key: ObjectKey(selected),
          controller: controller,
        );
      }
      return MaterialApp(
        title: 'Daily Motion',
        debugShowCheckedModeBanner: false,
        theme: motionTheme(Brightness.light),
        darkTheme: motionTheme(Brightness.dark),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AuthForm(controller: controller),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TrainingApplication extends StatefulWidget {
  final AccountController controller;
  const _TrainingApplication({super.key, required this.controller});
  @override
  State<_TrainingApplication> createState() => _TrainingApplicationState();
}

class _TrainingApplicationState extends State<_TrainingApplication> {
  late final ProviderContainer container;
  StreamSubscription<void>? updates;
  @override
  void initState() {
    super.initState();
    final controller = widget.controller;
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(controller.local!.repository),
        syncCoordinatorProvider.overrideWithValue(controller.coordinator),
        accountControllerProvider.overrideWithValue(controller),
      ],
    );
    updates = controller.installations.listen((_) {
      if (mounted) {
        unawaited(container.read(workoutsProvider.notifier).refresh());
      }
    });
  }

  @override
  void dispose() {
    unawaited(updates?.cancel());
    container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      title: 'Daily Motion',
      debugShowCheckedModeBanner: false,
      theme: motionTheme(Brightness.light),
      darkTheme: motionTheme(Brightness.dark),
      home: const HomeScreen(syntheticFixture: false),
    ),
  );
}

class AuthForm extends StatefulWidget {
  final AccountController controller;
  final VoidCallback? onVerified;
  const AuthForm({super.key, required this.controller, this.onVerified});
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final email = TextEditingController();
  final code = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (_, _) {
      final controller = widget.controller;
      final busy = controller.busy;
      final challenge = controller.challengeEmail;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daily Motion',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in with an email code. A connection is needed to sign in. After setup, saved training is available offline.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        code.clear();
                        await controller.requestOtp(email.text);
                      },
                child: const Text('Send code'),
              ),
              if (challenge != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: code,
                  enabled: !busy,
                  obscureText: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Email code'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final otp = code.text;
                          code.clear(); // Codes are transient; never emitted to logs/URLs/telemetry.
                          await controller.verifyOtp(otp);
                          if (mounted &&
                              controller.state.phase ==
                                  AccountPhase.authenticated) {
                            widget.onVerified?.call();
                          }
                        },
                  child: const Text('Verify code'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          code.clear();
                          await controller.requestOtp(challenge, resend: true);
                        },
                  child: const Text('Resend code'),
                ),
              ],
              if (controller.canRetryInitialization)
                TextButton(
                  onPressed: busy ? null : controller.retryInitialization,
                  child: const Text('Retry account setup'),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (controller.state.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(controller.state.message),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showAccountDialog(
  BuildContext context,
  AccountController controller,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AuthForm(
        controller: controller,
        onVerified: () => Navigator.of(context).pop(),
      ),
    ),
  ),
);
