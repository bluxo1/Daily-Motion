import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/workout.dart';
import 'workout_controller.dart';
import 'workout_screen.dart';
import 'sync_provider.dart';
import '../sync/coordinator.dart';
import '../auth/auth_app.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final bool syntheticFixture;
  const HomeScreen({super.key, this.syntheticFixture = true});
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
                if (items.every((w) => w['status'] == 'active'))
                  const Text('Your recorded workouts will appear here.'),
                for (final workout in items.where(
                  (w) => w['status'] != 'active',
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text(workout['name'] as String),
                        subtitle: Text(
                          '${workout['status']} · ${allSets(workout).where((s) => s['observation'] != null && s['observation']['execution_status'] != 'skipped').length} recorded sets',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => open(workout['aggregate_id'] as String),
                      ),
                    ),
                  ),
              ] else ...[
                Text(
                  'Observed performance',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bench press · total external load · bilateral reps',
                ),
                const SizedBox(height: 16),
                if (!items.any(
                  (w) => allSets(w).any(
                    (s) => s['observation']?['execution_status'] == 'completed',
                  ),
                ))
                  const Text('Record working sets to see comparable results.'),
                for (final workout in items)
                  for (final item in allSets(workout).where(
                    (s) =>
                        s['set_class'] == 'working' &&
                        s['observation']?['execution_status'] == 'completed',
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item['observation']['actual']['load']['value']} ${item['observation']['actual']['load']['unit']} × ${item['observation']['actual']['reps']} reps',
                      ),
                      subtitle: Text(
                        '${workout['started_at']} · saved on this device',
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
