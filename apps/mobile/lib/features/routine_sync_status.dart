import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_repository.dart';
import '../domain/routine.dart';
import '../domain/workout.dart';
import '../sync/coordinator.dart';
import 'sync_provider.dart';
import 'workout_controller.dart';

/// UI invalidation only. Scheduling and delivery remain in SyncCoordinator.
final routineChangesProvider = StreamProvider.autoDispose<int>((ref) {
  final repository = ref.watch(repositoryProvider);
  final coordinator = ref.watch(syncCoordinatorProvider);
  final changes = StreamController<int>();
  var revision = 0;
  changes.add(revision);
  void changed(void _) {
    if (!changes.isClosed) changes.add(++revision);
  }

  final local = repository.commits.listen(changed);
  final remote = coordinator?.installations.listen(changed);
  ref.onDispose(() {
    unawaited(local.cancel());
    unawaited(remote?.cancel());
    unawaited(changes.close());
  });
  return changes.stream;
});

final routineDeliveryProvider = FutureProvider.autoDispose
    .family<Json?, String>((ref, id) {
      ref.watch(routineChangesProvider);
      return ref.watch(repositoryProvider).routineSyncDetails(id);
    });

class RoutineSyncStatus extends ConsumerStatefulWidget {
  final SavedRoutine routine;
  const RoutineSyncStatus({super.key, required this.routine});
  @override
  ConsumerState<RoutineSyncStatus> createState() => _RoutineSyncStatusState();
}

class _RoutineSyncStatusState extends ConsumerState<RoutineSyncStatus> {
  final retryFocus = FocusNode();
  bool retrying = false;
  @override
  void dispose() {
    retryFocus.dispose();
    super.dispose();
  }

  Future<void> retry(
    SyncCoordinator coordinator,
    WorkoutRepository repository,
  ) async {
    if (retrying ||
        !identical(ref.read(repositoryProvider), repository) ||
        !identical(ref.read(syncCoordinatorProvider), coordinator)) {
      return;
    }
    final restoreFocus = retryFocus.hasFocus;
    setState(() => retrying = true);
    try {
      await coordinator.synchronize(force: true);
    } finally {
      if (mounted && identical(ref.read(repositoryProvider), repository)) {
        setState(() => retrying = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && restoreFocus && retryFocus.canRequestFocus) {
            retryFocus.requestFocus();
          }
        });
      }
    }
  }

  Future<void> review(WorkoutRepository repository) async {
    try {
      final local = await repository.routine(widget.routine.id);
      final details = await repository.routineSyncDetails(widget.routine.id);
      if (!mounted ||
          !identical(ref.read(repositoryProvider), repository) ||
          local == null ||
          ref.read(syncCoordinatorProvider)?.status.phase ==
              SyncPhase.accountDisabled) {
        return;
      }
      final encoded = details?['server_shadow'] as String?;
      final cloud = encoded == null ? null : jsonDecode(encoded) as Json;
      final cloudPlan = cloud == null
          ? null
          : RoutinePlan.fromJson(
              ((cloud['templates'] as List).last as Json)['prescription']
                  as Json,
            );
      await showDialog<void>(
        context: context,
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final available =
                identical(ref.watch(repositoryProvider), repository) &&
                ref.watch(syncStatusProvider).value?.phase !=
                    SyncPhase.accountDisabled;
            return AlertDialog(
              title: const Text('Routine conflict'),
              content: SingleChildScrollView(
                child: available
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Both plans are retained. No changes are applied here.',
                          ),
                          const SizedBox(height: 16),
                          ..._planPreview('Your saved plan', local.plan),
                          const SizedBox(height: 16),
                          if (cloudPlan != null)
                            ..._planPreview('Cloud plan', cloudPlan)
                          else
                            const Text(
                              'The cloud plan is unavailable. Your saved plan is retained.',
                            ),
                        ],
                      )
                    : const Text(
                        'This account is unavailable. Return to sign in.',
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        ),
      );
    } catch (_) {
      if (mounted && identical(ref.read(repositoryProvider), repository)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sync details could not be loaded. Your saved work is retained.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    final coordinator = ref.watch(syncCoordinatorProvider);
    final status = ref.watch(syncStatusProvider).value ?? coordinator?.status;
    final read = ref.watch(routineDeliveryProvider(widget.routine.id));
    final details = read.hasValue && !read.isLoading && !read.hasError
        ? read.value
        : null;
    final capable = coordinator?.routineConnection != null;
    if (widget.routine.ownerId != repository.ownerId ||
        status?.phase == SyncPhase.accountDisabled) {
      return const SizedBox.shrink();
    }
    final conflict = details?['has_conflict'] == 1;
    final rejected = details?['mutation_state'] == 'rejected';
    final pending = (details?['pending_count'] as int? ?? 0) > 0;
    final accepted =
        details != null &&
        details['server_revision'] > 0 &&
        !pending &&
        !conflict &&
        details['working_template_id'] == widget.routine.templateId &&
        details['accepted_template_id'] == widget.routine.templateId;
    final interruption = status?.cloudInterruptionLabel;
    final deliveryLabel =
        status?.phase == SyncPhase.attention &&
            (pending || status?.code != null)
        ? 'Sync needs attention'
        : accepted
        ? 'Synchronized'
        : status?.phase == SyncPhase.syncing && pending
        ? 'Synchronizing routine'
        : pending
        ? 'Pending routine sync'
        : 'Saved on this device';
    final label = !capable
        ? 'Saved on this device'
        : conflict && !rejected
        ? 'Routine conflict'
        : rejected || read.hasError
        ? 'Sync needs attention'
        : status?.phase == SyncPhase.authenticationRequired
        ? 'Cloud sign-in required'
        : interruption ?? deliveryLabel;
    final busy = retrying || status?.phase == SyncPhase.syncing;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            label:
                'Routine synchronization: $label. ${widget.routine.plan.name}',
            child: ExcludeSemantics(child: Text(label)),
          ),
          if (conflict)
            const Text(
              'Your saved work is retained. Other workouts can still synchronize.',
            ),
          if (capable && status?.cloudInterruptionExplanation != null)
            Text(status!.cloudInterruptionExplanation!),
          if (capable && coordinator != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('routine-sync-retry-${widget.routine.id}'),
                  focusNode: retryFocus,
                  onPressed:
                      busy || status?.phase == SyncPhase.authenticationRequired
                      ? null
                      : () => retry(coordinator, repository),
                  icon: const Icon(Icons.sync),
                  label: Text(
                    conflict
                        ? 'Refresh cloud status'
                        : accepted
                        ? 'Sync routine'
                        : 'Retry routine sync',
                  ),
                ),
                if (conflict && !rejected)
                  TextButton(
                    key: ValueKey('routine-sync-review-${widget.routine.id}'),
                    onPressed: () => review(repository),
                    child: const Text('Review conflict'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

List<Widget> _planPreview(String label, RoutinePlan plan) => [
  Semantics(header: true, child: Text(label)),
  Text(plan.name),
  for (final exercise in plan.exercises) ...[
    Text(exercise['name'] as String),
    Text(
      (exercise['sets'] as List)
          .map((raw) {
            final set = raw as Json;
            final target = set['planned'] as Json;
            final load = target['load'] as Json?;
            return '${set['set_class'] ?? 'working'} · ${target['reps'] == null ? 'No rep target' : '${target['reps']} reps'}'
                '${load == null ? '' : ' · ${load['value']} ${load['unit']}'} · ${target['rest_seconds'] ?? 120}s rest';
          })
          .join('\n'),
    ),
  ],
];
