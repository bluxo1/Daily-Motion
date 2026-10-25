import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/workout.dart';
import '../domain/rest_timer.dart';
import 'workout_controller.dart';
import 'sync_provider.dart';
import 'workout_presentation.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const WorkoutScreen({super.key, required this.sessionId});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen>
    with WidgetsBindingObserver {
  RestDisplay? timerDisplay;
  Timer? ticker;
  var finishing = false;
  var correctionOpen = false;
  var readingTimer = false;
  var timerReadAgain = false;
  var timerRevision = 0;
  var suspended = false;

  Future<void> cancelTimer() async {
    try {
      await ref.read(repositoryProvider).cancelTimer(widget.sessionId);
      // Responses sampled before this successful cancellation cannot restore it.
      timerRevision++;
      if (mounted) setState(() => timerDisplay = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rest timer could not be cancelled. Retry.'),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(restoreTimer());
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !suspended && timerDisplay != null) {
        unawaited(restoreTimer());
      }
    });
  }

  Future<void> restoreTimer() async {
    if (readingTimer) {
      timerReadAgain = true;
      return;
    }
    readingTimer = true;
    try {
      do {
        timerReadAgain = false;
        final target = ref.read(repositoryProvider);
        final revision = timerRevision;
        try {
          final value = await target.restDisplay(widget.sessionId);
          if (mounted &&
              revision == timerRevision &&
              identical(ref.read(repositoryProvider), target)) {
            setState(() => timerDisplay = value);
          }
        } catch (_) {
          if (mounted && revision == timerRevision) {
            setState(() => timerDisplay = null);
          }
        }
      } while (mounted && timerReadAgain);
    } finally {
      readingTimer = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    suspended = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) unawaited(restoreTimer());
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> finish({bool abandon = false}) async {
    if (finishing || correctionOpen) return;
    setState(() => finishing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(abandon ? 'Abandon workout?' : 'Finish workout?'),
          content: Text(
            abandon ? 'Recorded sets stay in history as an abandoned workout.' : 'Only recorded work is included. Draft sets stay unperformed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue training'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(abandon ? 'Abandon' : 'Finish'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref
          .read(workoutsProvider.notifier)
          .finish(widget.sessionId, abandon: abandon);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is WorkoutValidation ? error.message : 'Workout could not be saved. Your recorded work is retained; retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  Future<void> correct(Json exercise, Json item) async {
    if (correctionOpen || finishing) return;
    correctionOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SetEditor(
              key: ValueKey('correct-${item['set_id']}'),
              sessionId: widget.sessionId,
              exercise: exercise,
              item: item,
              correction: true,
              onSaved: () {
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ),
      );
    } finally {
      correctionOpen = false;
    }
  }

  Widget exerciseSection(Json workout, Json exercise) {
    final sets = (exercise['sets'] as List).cast<Json>();
    final pending = sets.where((s) => s['observation'] == null).toList();
    return Padding(
      key: ValueKey('exercise-${exercise['session_exercise_id']}'),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              exercise['name'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(exerciseConvention(exercise)),
          const SizedBox(height: 16),
          for (final (index, item) in sets.indexed)
            ListTile(
              key: ValueKey('set-${item['set_id']}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (item['observation']?['execution_status']) {
                'completed' => Icons.check_circle_outline,
                'partial' => Icons.timelapse,
                'failed' => Icons.cancel_outlined,
                'skipped' => Icons.skip_next_outlined,
                _ => Icons.radio_button_unchecked,
              }),
              title: Text(
                'Set ${index + 1} · ${item['set_class']} · ${item['set_purpose']}',
              ),
              subtitle: Text(setSummary(item)),
              trailing: item['observation'] == null
                  ? null
                  : Semantics(
                      label: exercise['name'] as String,
                      child: IconButton(
                        tooltip: 'Correct set ${index + 1}',
                        onPressed: () => correct(exercise, item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
            ),
          if (workout['status'] == 'active' && pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            SetEditor(
              key: ValueKey(pending.first['set_id']),
              enabled: !finishing,
              sessionId: widget.sessionId,
              exercise: exercise,
              item: pending.first,
              onSaved: () => unawaited(restoreTimer()),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutsProvider);
    ref.listen(workoutsProvider, (_, next) {
      if (next.hasValue) unawaited(restoreTimer());
    });
    return state.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Workout could not be loaded.'),
              OutlinedButton(
                onPressed: () => ref.invalidate(workoutsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        final matches = items.where(
          (w) => w['aggregate_id'] == widget.sessionId,
        );
        if (matches.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Workout unavailable.')),
          );
        }
        final workout = matches.single;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Workout'),
            actions: [
              if (workout['status'] == 'active')
                PopupMenuButton<String>(
                  tooltip: 'Workout options',
                  onSelected: (_) => finish(abandon: true),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'abandon',
                      child: Text('Abandon workout'),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  workout['name'] as String,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('${workout['status']} · ${workoutDate(workout)}'),
                Text('Workout timezone: ${workout['timezone']}'),
                Text(recordedCounts(workout)),
                Text(
                  workout['conflict'] == true
                      ? 'Saved on this device · sync needs review'
                      : ref.watch(syncStatusProvider).value?.label ??
                            'Saved on this device',
                ),
                if (timerDisplay != null && workout['status'] == 'active') ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              timerDisplay!.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: cancelTimer,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                for (final exercise
                    in (workout['exercises'] as List).cast<Json>())
                  exerciseSection(workout, exercise),
                if (workout['status'] == 'active') ...[
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: finishing ? null : finish,
                    child: const Text('Finish workout'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SetEditor extends ConsumerStatefulWidget {
  final String sessionId;
  final Json exercise;
  final Json item;
  final bool correction;
  final bool enabled;
  final VoidCallback onSaved;
  const SetEditor({
    super.key,
    required this.sessionId,
    required this.exercise,
    required this.item,
    required this.onSaved,
    this.correction = false,
    this.enabled = true,
  });
  @override
  ConsumerState<SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends ConsumerState<SetEditor>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => !widget.correction;
  final load = TextEditingController();
  final reps = TextEditingController();
  final effort = TextEditingController();
  final reason = TextEditingController();
  var scale = 'rir';
  var outcome = 'completed';
  var unit = 'kg';
  var ready = false;
  var saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(restore());
  }

  Future<void> restore() async {
    try {
      final actual = widget.item['observation']?['actual'] as Json?;
      final plan = widget.item['planned'] as Json;
      final draft = widget.correction
          ? null
          : await ref
                .read(repositoryProvider)
                .draft(widget.item['set_id'] as String);
      if (!mounted) return;
      load.text =
          draft?['load'] as String? ??
          actual?['load']?['value'] as String? ??
          plan['load']?['value'] as String? ??
          '';
      reps.text =
          draft?['reps'] as String? ??
          (actual?['reps'] ?? plan['reps'])?.toString() ??
          '';
      effort.text =
          draft?['effort'] as String? ??
          actual?['effort']?['value'] as String? ??
          '';
      scale =
          draft?['effort_scale'] as String? ??
          actual?['effort']?['scale'] as String? ??
          'rir';
      unit =
          draft?['unit'] as String? ??
          actual?['load']?['unit'] as String? ??
          plan['load']?['unit'] as String? ??
          'kg';
      outcome =
          draft?['execution_status'] as String? ??
          widget.item['observation']?['execution_status'] as String? ??
          'completed';
      setState(() => ready = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Draft could not be restored. Close and reopen this workout to retry.',
        );
      }
    }
  }

  Json entry() => {
    'load': load.text,
    'reps': reps.text,
    'effort': effort.text,
    'effort_scale': scale,
    'execution_status': outcome,
    'unit': unit,
  };

  Future<void> preserve() async {
    if (widget.correction) return;
    try {
      await ref
          .read(repositoryProvider)
          .saveDraft(widget.item['set_id'] as String, entry());
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Draft could not be saved. Keep this screen open and retry.',
        );
      }
    }
  }

  Future<void> save() async {
    if (saving || !ready || !widget.enabled) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(workoutsProvider.notifier)
          .record(
            widget.sessionId,
            widget.exercise,
            widget.item,
            entry(),
            reason: widget.correction ? reason.text : null,
          );
      if (mounted && saved) widget.onSaved();
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is WorkoutValidation
              ? exception.message
              : 'Local save failed. Your entry is still here; retry.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    load.dispose();
    reps.dispose();
    effort.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.correction ? 'Correct recorded set' : 'Record next set',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (!widget.correction)
          const Text('Template suggestion · edit to match your actual work'),
        const SizedBox(height: 16),
        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!ready)
          const LinearProgressIndicator()
        else ...[
          if (widget.exercise['loading_basis'] != 'bodyweight_only') ...[
            TextField(
              controller: load,
              enabled: !saving && widget.enabled,
              decoration: InputDecoration(
                labelText: 'Load ($unit, ${loadConvention(widget.exercise)})',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => unawaited(preserve()),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: reps,
            enabled: !saving && widget.enabled,
            decoration: const InputDecoration(labelText: 'Actual reps'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => unawaited(preserve()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: outcome,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Outcome'),
            items: const [
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'partial', child: Text('Partial')),
              DropdownMenuItem(value: 'failed', child: Text('Failed attempt')),
              DropdownMenuItem(value: 'skipped', child: Text('Skipped')),
            ],
            onChanged: saving || !widget.enabled
                ? null
                : (value) {
                    setState(() => outcome = value!);
                    unawaited(preserve());
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: scale,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Effort scale'),
            items: const [
              DropdownMenuItem(
                value: 'rir',
                child: Text('RIR · whole values 0–10'),
              ),
              DropdownMenuItem(
                value: 'rpe',
                child: Text('RPE · half steps 1–10'),
              ),
            ],
            onChanged: saving || !widget.enabled
                ? null
                : (value) {
                    setState(() => scale = value!);
                    unawaited(preserve());
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: effort,
            enabled: !saving && widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Actual effort (optional)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: widget.correction
                ? TextInputAction.next
                : TextInputAction.done,
            onChanged: (_) => unawaited(preserve()),
            onSubmitted: widget.correction ? null : (_) => save(),
          ),
          if (widget.correction) ...[
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              enabled: !saving && widget.enabled,
              maxLength: 240,
              decoration: const InputDecoration(labelText: 'Correction reason'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => save(),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving || !widget.enabled ? null : save,
            icon: const Icon(Icons.check),
            label: Text(
              saving
                  ? 'Saving on device…'
                  : widget.correction
                  ? 'Save correction'
                  : 'Record set',
            ),
          ),
        ],
      ],
    );
  }
}
