import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workout_controller.dart';
import 'workout_screen.dart';
import 'sync_provider.dart';
import '../sync/coordinator.dart';
import '../auth/auth_app.dart';
import 'routine_screen.dart';
import 'workout_history.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final bool syntheticFixture;
  final bool localRoutinesEnabled;
  const HomeScreen({
    super.key,
    this.syntheticFixture = true,
    this.localRoutinesEnabled =
        !kReleaseMode && const bool.fromEnvironment('DM_LOCAL_ROUTINES'),
  });
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var destination = 0;
  var starting = false;

  void open(String id) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => WorkoutScreen(sessionId: id)));

  Future<void> start() async {
    if (starting) return;
    setState(() => starting = true);
    try {
      final id = await ref.read(workoutsProvider.notifier).start();
      if (mounted) open(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(['Train', 'History', 'Progress'][destination]),
        actions: [
          if (ref.watch(accountControllerProvider) case final account?) ...[
            IconButton(
              tooltip: 'Sign in to synchronize',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => showAccountDialog(context, account),
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'Your saved and pending training will stay locked to this account. Sign in to the same account to recover it.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Stay signed in'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await account.signOut();
              },
            ),
          ],
          if (ref.watch(syncCoordinatorProvider) != null)
            IconButton(
              tooltip: 'Retry synchronization',
              onPressed: () =>
                  ref.read(syncCoordinatorProvider)?.synchronize(force: true),
              icon: const Icon(Icons.sync),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: destination,
        onDestinationSelected: (index) => setState(() => destination = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Train',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
        ],
      ),
      body: SafeArea(
        child: workouts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ref.watch(syncStatusProvider).value?.phase ==
                            SyncPhase.accountDisabled
                        ? 'This account was disabled remotely. Local training data has been removed.'
                        : 'Local history could not be loaded. Saved work is retained.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(workoutsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.syntheticFixture)
                const Text('Development fixture · synthetic account'),
              const SizedBox(height: 8),
              Text(
                ref.watch(syncStatusProvider).value?.label ??
                    'Saved on this device',
              ),
              const SizedBox(height: 24),
              if (items.any((w) => w['status'] == 'active')) ...[
                FilledButton.icon(
                  onPressed: () => open(
                    items.firstWhere(
                          (w) => w['status'] == 'active',
                        )['aggregate_id']
                        as String,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume workout'),
                ),
                const SizedBox(height: 24),
              ],
              if (destination == 0) ...[
                if (widget.localRoutinesEnabled) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const RoutineScreen()),
                    ),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('My routines'),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Make every set count.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your session is saved on this device, even offline.',
                ),
                const SizedBox(height: 24),
                if (widget.syntheticFixture)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upper body',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text('Barbell bench press · 3 working sets'),
                          const SizedBox(height: 8),
                          const Text(
                            'Template suggestion: 60 kg × 5 · 2 min rest',
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  starting ||
                                      items.any((w) => w['status'] == 'active')
                                  ? null
                                  : start,
                              child: Text(
                                starting ? 'Saving…' : 'Start workout',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else if (destination == 1) ...[
                WorkoutHistory(workouts: items, onOpen: open),
              ] else ...[
                ObservedPerformance(workouts: items),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
