import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'data/database.dart';
import 'data/workout_repository.dart';
import 'domain/workout.dart';
import 'design/theme.dart';
import 'features/home_screen.dart';
import 'features/workout_controller.dart';
import 'features/sync_provider.dart';
import 'sync/coordinator.dart';
import 'sync/transport.dart';
import 'auth/account_controller.dart';
import 'auth/auth_app.dart';
import 'auth/configuration.dart';
import 'auth/secure_storage.dart';
import 'auth/supabase_provider.dart';
import 'auth/local_owners.dart';
import 'platform/device_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const fixture = bool.fromEnvironment('DM_FOUNDATION_FIXTURE');
  if (!fixture || kReleaseMode) {
    const supabaseUrl = String.fromEnvironment('DM_SUPABASE_URL');
    const publishableKey = String.fromEnvironment(
      'DM_SUPABASE_PUBLISHABLE_KEY',
    );
    const apiUrl = String.fromEnvironment('DM_API_URL');
    const syntheticToken = String.fromEnvironment('DM_ACCESS_TOKEN');
    var configured = false;
    try {
      final configuration = AuthConfiguration(
        supabaseUrl: supabaseUrl,
        apiUrl: apiUrl,
        publishableKey: publishableKey,
        environment: const String.fromEnvironment(
          'DM_ENVIRONMENT',
          defaultValue: 'production',
        ),
        release: kReleaseMode,
        syntheticFixture: fixture,
        syntheticToken: syntheticToken,
      );
      configured = true;
      final support = await getApplicationSupportDirectory();
      await DeviceServices.prepareStorage(support);
      final storage = SecureSessionStorage(
        PlatformProtectedStorage(),
        configuration.namespace,
      );
      final controller = AccountController(
        provider: SupabaseOtpProvider(configuration, storage),
        gateway: HttpAccountGateway(configuration),
        storage: storage,
        stores: LocalOwnerStores(
          Directory(
            path.join(support.path, 'accounts', configuration.namespace),
          ),
          restClock: const DeviceServices(),
        ),
        syncTransport: (owner, token) => HttpSyncTransport(
          configuration.api,
          token,
          allowLoopbackHttp: configuration.development,
        ),
      );
      runApp(AccountApplication(controller: controller));
      unawaited(
        controller.restore(),
      ); // Cached training renders before refresh/network.
      AppLifecycleListener(
        onResume: () => controller.foreground(true),
        onPause: () => controller.foreground(false),
      );
    } catch (_) {
      runApp(DailyMotionApp(startupFailed: configured));
    }
    return;
  }
  try {
    final directory = await getApplicationSupportDirectory();
    await DeviceServices.prepareStorage(directory);
    const owner = String.fromEnvironment(
      'DM_TEST_OWNER',
      defaultValue: '20000000-0000-4000-8000-000000000001',
    );
    final database = TrainingDatabase.open(
      File(path.join(directory.path, 'foundation-$owner.sqlite')),
    );
    final repository = WorkoutRepository(
      database,
      owner,
      restClock: const DeviceServices(),
    );
    try {
      await repository.initialize();
    } on WorkoutValidation {
      if (await repository.remoteDisabled()) {
        await database.close();
        runApp(const DailyMotionApp(accountDisabled: true));
        return;
      }
      rethrow;
    }
    const apiUrl = String.fromEnvironment('DM_API_URL');
    const token = String.fromEnvironment('DM_ACCESS_TOKEN');
    late final ProviderContainer container;
    final coordinator = apiUrl.isEmpty
        ? null
        : SyncCoordinator(
            repository,
            HttpSyncTransport(
              Uri.parse(apiUrl),
              () async => token.isEmpty ? null : token,
              allowLoopbackHttp: !kReleaseMode,
            ),
            onInstalled: () async {
              await container.read(workoutsProvider.notifier).refresh();
            },
          );
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        syncCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    // Restore local data before initiating foreground network work.
    await container.read(workoutsProvider.future);
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const DailyMotionApp(fixtureEnabled: true),
      ),
    );
    coordinator?.start();
    if (coordinator != null) {
      AppLifecycleListener(
        onResume: () => coordinator.foreground(true),
        onPause: () => coordinator.foreground(false),
      );
    }
  } catch (_) {
    runApp(const DailyMotionApp(startupFailed: true));
  }
}

class DailyMotionApp extends StatelessWidget {
  final bool fixtureEnabled;
  final bool startupFailed;
  final bool accountDisabled;
  const DailyMotionApp({
    super.key,
    this.fixtureEnabled = false,
    this.startupFailed = false,
    this.accountDisabled = false,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Daily Motion',
    debugShowCheckedModeBanner: false,
    theme: motionTheme(Brightness.light),
    darkTheme: motionTheme(Brightness.dark),
    home: fixtureEnabled && !kReleaseMode
        ? const HomeScreen()
        : Builder(
            builder: (context) => Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Daily Motion',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            accountDisabled
                                ? 'This account was disabled remotely. Local training data has been removed.'
                                : startupFailed
                                ? 'Local storage could not be opened. Close and reopen the app to retry. Your saved data is retained.'
                                : 'Your training, recorded reliably.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            accountDisabled
                                ? 'Sign in with an active account to continue.'
                                : startupFailed
                                ? 'No workout changes were acknowledged.'
                                : 'Authentication is not configured for this build.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}
