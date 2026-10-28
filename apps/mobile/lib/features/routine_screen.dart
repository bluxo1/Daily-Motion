import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/routine.dart';
import '../domain/exercise_catalog.dart';
import '../domain/workout.dart';
import '../data/workout_repository.dart';
import 'workout_controller.dart';
import 'workout_screen.dart';
import 'exercise_catalog_screen.dart';
import 'sync_provider.dart';
import '../sync/coordinator.dart';

final routinesProvider = FutureProvider.autoDispose<List<SavedRoutine>>(
  (ref) => ref.watch(repositoryProvider).routines(),
);

String _routineError(Object error, String fallback) =>
    error is WorkoutValidation ? error.message : fallback;

class RoutineScreen extends StatelessWidget {
  final Future<void> Function(String)? onStarted;
  final ValueChanged<bool>? onStartingChanged;
  const RoutineScreen({super.key, this.onStarted, this.onStartingChanged});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Routines')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RoutineLibrary(
          onStarted: onStarted,
          onStartingChanged: onStartingChanged,
        ),
      ),
    ),
  );
}

/// The existing routine editor/start flow, shared with the internal Train view.
/// The caller decides where an acknowledged workout opens; writes stay here in
/// the existing repository transaction and its stable start-attempt binding.
class RoutineLibrary extends ConsumerStatefulWidget {
  final bool inline;
  final bool firstWorkout;
  final bool enabled;
  final Future<void> Function(String)? onStarted;
  final ValueChanged<bool>? onStartingChanged;
  const RoutineLibrary({
    super.key,
    this.inline = false,
    this.firstWorkout = false,
    this.enabled = true,
    this.onStarted,
    this.onStartingChanged,
  });
  @override
  ConsumerState<RoutineLibrary> createState() => _RoutineLibraryState();
}

class _RoutineLibraryState extends ConsumerState<RoutineLibrary> {
  bool starting = false;
  bool editing = false;
  String? timezone;
  final attempts = <String, String>{};

  Future<void> edit([SavedRoutine? routine]) async {
    if (editing || starting || !widget.enabled) return;
    setState(() => editing = true);
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RoutineEditorScreen(initial: routine),
        ),
      );
    } finally {
      if (mounted) {
        ref.invalidate(routinesProvider);
        setState(() => editing = false);
      }
    }
  }

  Future<void> start(SavedRoutine routine) async {
    if (starting || editing || !widget.enabled) return;
    if (timezone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose the workout timezone before starting.'),
        ),
      );
      return;
    }
    setState(() => starting = true);
    final repo = ref.read(repositoryProvider);
    final onStarted = widget.onStarted;
    final onStartingChanged = widget.onStartingChanged;
    onStartingChanged?.call(true);
    final attemptKey = '${routine.templateId}/$timezone';
    final attempt = attempts.putIfAbsent(attemptKey, repo.newId);
    String? acknowledged;
    try {
      final id = await repo.startRoutine(
        routineId: routine.id,
        templateId: routine.templateId,
        attemptId: attempt,
        timezone: timezone,
      );
      acknowledged = id;
      if (onStarted != null) {
        // A tab change may dispose these controls while SQLite is committing.
        // The owner-bound host still needs the acknowledgement for Resume.
        await onStarted(id);
      } else {
        if (!mounted || !identical(ref.read(repositoryProvider), repo)) return;
        await ref.read(workoutsProvider.notifier).refresh();
        if (mounted && identical(ref.read(repositoryProvider), repo)) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => WorkoutScreen(sessionId: id)),
          );
        }
      }
      attempts.remove(attemptKey);
    } catch (error) {
      if (!mounted || !identical(ref.read(repositoryProvider), repo)) return;
      // Read after an uncertain response: a committed session may already be
      // resumable. Retain the attempt until a successful response is known.
      await ref.read(workoutsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              acknowledged != null
                  ? 'Workout saved on this device. It could not be opened. Resume it from Train.'
                  : _routineError(
                      error,
                      'The workout start could not be confirmed. Check Resume workout on Train before retrying.',
                    ),
            ),
          ),
        );
      }
    } finally {
      onStartingChanged?.call(false);
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(routinesProvider);
    final workouts = ref.watch(workoutsProvider);
    final active = workouts.value?.any((w) => w['status'] == 'active') ?? false;
    final canStart =
        widget.enabled &&
        !starting &&
        !editing &&
        !active &&
        workouts.hasValue &&
        !workouts.isLoading &&
        !workouts.hasError;
    return routines.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Routines could not be loaded. Saved work is retained.'),
          OutlinedButton(
            onPressed: () => ref.invalidate(routinesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.inline) ...[
            Semantics(
              header: true,
              child: Text(
                items.isEmpty
                    ? (widget.firstWorkout
                          ? 'Start your first workout'
                          : 'Plan your next workout')
                    : 'Choose a routine',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text(
                'Create a routine, record your sets, then find your training in History and Progress.',
              ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Saved only on this device. Routines are not backed up or synced yet.',
          ),
          const SizedBox(height: 16),
          if (items.isNotEmpty || !widget.inline) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: timezone,
              decoration: const InputDecoration(labelText: 'Workout timezone'),
              items: const [
                DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                DropdownMenuItem(
                  value: 'Asia/Kolkata',
                  child: Text('Asia/Kolkata'),
                ),
                DropdownMenuItem(
                  value: 'Asia/Calcutta',
                  child: Text('Asia/Calcutta'),
                ),
              ],
              onChanged: starting || editing || !widget.enabled
                  ? null
                  : (value) => setState(() => timezone = value),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: starting || editing || !widget.enabled
                ? null
                : () => edit(),
            icon: const Icon(Icons.add),
            label: Text(widget.inline ? 'Create routine' : 'New routine'),
          ),
          if (active)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Resume or finish your active workout from Train before starting another.',
              ),
            ),
          if (items.isEmpty && !widget.inline)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Create a routine with planned exercises and sets.'),
            ),
          for (final routine in items)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                key: ValueKey('routine-${routine.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          routine.plan.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${routine.plan.exercises.length} exercises · ${routine.plan.exercises.fold<int>(0, (n, e) => n + (e['sets'] as List).length)} planned sets',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: starting || editing || !widget.enabled
                                ? null
                                : () => edit(routine),
                            child: const Text('Edit routine'),
                          ),
                          FilledButton(
                            onPressed: canStart ? () => start(routine) : null,
                            child: Text(
                              starting ? 'Opening…' : 'Start workout',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RoutineEditorScreen extends ConsumerStatefulWidget {
  final SavedRoutine? initial;
  const RoutineEditorScreen({super.key, this.initial});
  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  late final repository = ref.read(repositoryProvider);
  late final name = TextEditingController(
    text: widget.initial?.plan.name ?? '',
  );
  late final id = widget.initial?.id ?? repository.newId();
  late final exercises = [
    for (final e in widget.initial?.plan.exercises ?? <Json>[])
      _ExerciseFields(e),
  ];
  bool dirty = false;
  bool saving = false;
  bool picking = false;
  bool leaving = false;
  String? error;

  Future<void> addExercise() async {
    if (saving || picking || leaving || exercises.length >= 50) return;
    setState(() => picking = true);
    try {
      final selected = await Navigator.of(context).push<CatalogDefinition>(
        MaterialPageRoute(builder: (_) => const ExerciseCatalogScreen()),
      );
      if (!mounted ||
          !identical(ref.read(repositoryProvider), repository) ||
          selected == null) {
        return;
      }
      setState(() {
        exercises.add(
          _ExerciseFields(
            selected.prescription(repository.newId),
            catalogSelection: true,
          ),
        );
        dirty = true;
        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    for (final e in exercises) {
      e.dispose();
    }
    super.dispose();
  }

  void changed() {
    if (!dirty || error != null) {
      setState(() {
        dirty = true;
        error = null;
      });
    }
  }

  void moveExercise(_ExerciseFields exercise, int offset) {
    if (!mounted || saving || leaving) return;
    final current = exercises.indexOf(exercise);
    final destination = current + offset;
    if (current < 0 || destination < 0 || destination >= exercises.length) {
      return;
    }
    setState(() {
      exercises.removeAt(current);
      exercises.insert(destination, exercise);
      dirty = true;
      error = null;
    });
  }

  void removeExercise(_ExerciseFields exercise) {
    if (!mounted || saving || leaving || !exercises.contains(exercise)) return;
    setState(() {
      exercises.remove(exercise);
      dirty = true;
      error = null;
    });
    // EditableText must detach before its controllers are disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => exercise.dispose());
  }

  void removeSet(_ExerciseFields exercise, _SetFields item) {
    if (!mounted ||
        saving ||
        leaving ||
        !exercises.contains(exercise) ||
        exercise.sets.length <= 1 ||
        !exercise.sets.contains(item)) {
      return;
    }
    setState(() {
      exercise.sets.remove(item);
      dirty = true;
      error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  Future<void> leave() async {
    if (saving || leaving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text('Your last saved routine will be kept.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> save() async {
    if (saving ||
        leaving ||
        picking ||
        !identical(ref.read(repositoryProvider), repository)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final repo = repository;
      final plan = RoutinePlan(
        name: name.text,
        exercises: [for (final e in exercises) e.json(repo.newId)],
      );
      await repo.saveRoutine(
        id: id,
        expectedRevision: widget.initial?.localRevision ?? 0,
        plan: plan,
      );
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        setState(() {
          dirty = false;
          leaving = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = _routineError(
            failure,
            'Could not save on this device. Your edits are still here. Retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    Key? key,
    bool text = false,
    bool readOnly = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      enabled: !saving,
      readOnly: readOnly,
      keyboardType: text
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 3,
      ),
      onChanged: (_) => changed(),
    ),
  );
  Widget choice(
    String value,
    String label,
    List<String> options,
    void Function(String) update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(
              option.replaceAll('_', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: saving
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  update(value);
                  dirty = true;
                  error = null;
                });
              }
            },
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!identical(ref.watch(repositoryProvider), repository) ||
        ref.watch(syncStatusProvider).value?.phase ==
            SyncPhase.accountDisabled) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('This account is unavailable. Return to sign in.'),
          ),
        ),
      );
    }
    final catalog = ref.watch(exerciseCatalogProvider);
    final knownVariants = {
      for (final d in catalog.value ?? <CatalogDefinition>[]) d.variantId,
    };
    return PopScope(
      canPop: leaving || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initial == null ? 'Create routine' : 'Edit routine',
          ),
          leading: BackButton(onPressed: leave),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Plan future work. Nothing here records performed sets.',
              ),
              const SizedBox(height: 16),
              field(
                name,
                'Routine name',
                key: const ValueKey('routine-name'),
                text: true,
              ),
              if (catalog.hasError) ...[
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Exercise definitions could not be verified. Existing definition fields are temporarily read-only.',
                    key: ValueKey('routine-catalog-error'),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('routine-catalog-retry'),
                  onPressed: saving || picking || leaving
                      ? null
                      : () => ref.invalidate(exerciseCatalogProvider),
                  child: const Text('Retry exercise catalog'),
                ),
              ],
              for (var i = 0; i < exercises.length; i++)
                exerciseCard(
                  exercises[i],
                  i,
                  readOnlyDefinition:
                      exercises[i].catalogSelection ||
                      !catalog.hasValue ||
                      catalog.isLoading ||
                      catalog.hasError ||
                      knownVariants.contains(
                        exercises[i].original['variant_id'],
                      ),
                ),
              OutlinedButton.icon(
                onPressed: saving || picking || exercises.length >= 50
                    ? null
                    : addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      key: const ValueKey('routine-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save routine'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget exerciseCard(
    _ExerciseFields e,
    int index, {
    required bool readOnlyDefinition,
  }) => Card(
    key: ValueKey(e.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercise ${index + 1}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Move exercise ${index + 1} up',
                onPressed: saving || index == 0
                    ? null
                    : () => moveExercise(e, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move exercise ${index + 1} down',
                onPressed: saving || index == exercises.length - 1
                    ? null
                    : () => moveExercise(e, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Remove exercise ${index + 1}',
                onPressed: saving ? null : () => removeExercise(e),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          field(
            e.name,
            'Exercise name',
            key: ValueKey('exercise-name-${e.id}'),
            text: true,
            readOnly: readOnlyDefinition,
          ),
          if (readOnlyDefinition) ...[
            const Text(
              'Saved definition snapshot. Catalog renames do not rewrite this plan. Use the picker for another variant.',
            ),
            Text(
              '${e.basis.replaceAll('_', ' ')} · ${e.reps.replaceAll('_', ' ')} · side: ${e.side}',
            ),
          ] else ...[
            const Text(
              'Changing the name or conventions starts a separate exercise history.',
            ),
            const SizedBox(height: 12),
            choice(
              e.basis,
              'Load convention',
              [
                'total_external',
                'per_implement',
                'machine_stack',
                'added_bodyweight',
                'assistance',
                'bodyweight_only',
              ],
              (v) {
                e.basis = v;
                if (v == 'bodyweight_only') {
                  for (final s in e.sets) {
                    s.load.clear();
                  }
                }
              },
            ),
            choice(e.reps, 'Rep convention', [
              'bilateral',
              'per_side',
              'alternating_total',
            ], (v) => e.reps = v),
            choice(e.side, 'Side', [
              'left',
              'right',
              'both',
              'unspecified',
            ], (v) => e.side = v),
          ],
          for (var j = 0; j < e.sets.length; j++) setFields(e, e.sets[j], j),
          OutlinedButton(
            onPressed: saving || e.sets.length >= 100
                ? null
                : () => setState(() {
                    e.sets.add(
                      _SetFields.blank(ref.read(repositoryProvider).newId()),
                    );
                    dirty = true;
                  }),
            child: const Text('Add planned set'),
          ),
        ],
      ),
    ),
  );

  Widget setFields(_ExerciseFields exercise, _SetFields s, int index) =>
      Padding(
        key: ValueKey(s.id),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Planned set ${index + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            choice(s.setClass, 'Set class', [
              'warmup',
              'working',
            ], (v) => s.setClass = v),
            choice(s.purpose, 'Set purpose', [
              'regular',
              'top',
              'backoff',
            ], (v) => s.purpose = v),
            field(
              s.reps,
              'Planned reps',
              hint: 'Optional · whole reps, 1–999',
              key: ValueKey('planned-reps-${s.id}'),
            ),
            if (exercise.basis != 'bodyweight_only') ...[
              field(
                s.load,
                'Planned load',
                hint: 'Optional · non-negative decimal',
                key: ValueKey('planned-load-${s.id}'),
              ),
              choice(s.unit, 'Load unit', ['kg', 'lb'], (v) => s.unit = v),
            ],
            field(
              s.rest,
              'Planned rest (seconds)',
              hint: '0–3600 seconds',
              key: ValueKey('planned-rest-${s.id}'),
            ),
            TextButton.icon(
              onPressed: saving || exercise.sets.length == 1
                  ? null
                  : () => removeSet(exercise, s),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text('Remove planned set ${index + 1}'),
            ),
          ],
        ),
      );
}

class _ExerciseFields {
  final String id;
  final Json original;
  final bool catalogSelection;
  final TextEditingController name;
  String basis;
  String reps;
  String side;
  String? changedVariant;
  final List<_SetFields> sets;
  _ExerciseFields(Json e, {this.catalogSelection = false})
    : original = copyJson(e),
      id = e['session_exercise_id'] as String,
      name = TextEditingController(text: e['name'] as String),
      basis = e['loading_basis'] as String,
      reps = e['rep_convention'] as String,
      side = e['side'] as String? ?? 'unspecified',
      sets = [for (final s in (e['sets'] as List).cast<Json>()) _SetFields(s)];
  Json json(String Function() newId) {
    final definitionChanged =
        name.text.trim() != original['name'] ||
        basis != original['loading_basis'] ||
        reps != original['rep_convention'] ||
        side != (original['side'] ?? 'unspecified');
    return {
      'session_exercise_id': id,
      'variant_id': definitionChanged
          ? changedVariant ??= newId()
          : original['variant_id'],
      'name': name.text.trim(),
      'loading_basis': basis,
      'rep_convention': reps,
      if (original.containsKey('side') || side != 'unspecified') 'side': side,
      'sets': [for (final s in sets) s.json(basis)],
    };
  }

  void dispose() {
    name.dispose();
    for (final s in sets) {
      s.dispose();
    }
  }
}

class _SetFields {
  final String id;
  final TextEditingController reps;
  final TextEditingController load;
  final TextEditingController rest;
  String unit;
  String setClass;
  String purpose;
  _SetFields(Json s)
    : id = s['set_id'] as String,
      reps = TextEditingController(
        text: s['planned']['reps']?.toString() ?? '',
      ),
      load = TextEditingController(
        text: s['planned']['load']?['value'] as String? ?? '',
      ),
      rest = TextEditingController(
        text: s['planned']['rest_seconds'].toString(),
      ),
      unit = s['planned']['load']?['unit'] as String? ?? 'kg',
      setClass = s['set_class'] as String,
      purpose = s['set_purpose'] as String;
  static Json blankJson(String id) => {
    'set_id': id,
    'set_class': 'working',
    'set_purpose': 'regular',
    'planned': {'reps': 5, 'rest_seconds': 120},
  };
  factory _SetFields.blank(String id) => _SetFields(blankJson(id));
  Json json(String basis) {
    final repText = reps.text.trim();
    final restText = rest.text.trim();
    require(
      repText.isEmpty || RegExp(r'^\d{1,3}$').hasMatch(repText),
      'Enter whole planned reps, or leave the target blank.',
    );
    require(
      RegExp(r'^\d{1,4}$').hasMatch(restText),
      'Enter whole seconds of planned rest.',
    );
    return {
      'set_id': id,
      'set_class': setClass,
      'set_purpose': purpose,
      'planned': {
        'reps': repText.isEmpty ? null : int.parse(repText),
        'rest_seconds': int.parse(restText),
        'load': basis == 'bodyweight_only' || load.text.trim().isEmpty
            ? null
            : {
                'value': load.text.trim().replaceAll(',', '.'),
                'unit': unit,
                'basis': basis,
              },
      },
    };
  }

  void dispose() {
    reps.dispose();
    load.dispose();
    rest.dispose();
  }
}
