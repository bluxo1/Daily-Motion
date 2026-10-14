import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/workout.dart';
import '../domain/rest_timer.dart';
import 'workout_controller.dart';
import 'sync_provider.dart';

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
  var readingTimer = false;
  var suspended = false;

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
    if (readingTimer) return;
    readingTimer = true;
    try {
      final value = await ref
          .read(repositoryProvider)
          .restDisplay(widget.sessionId);
      if (mounted) setState(() => timerDisplay = value);
    } catch (_) {
      // Owner closure/disable or unavailable storage cannot crash timer restoration.
      if (mounted) setState(() => timerDisplay = null);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(abandon ? 'Abandon workout?' : 'Finish workout?'),
        content: Text(
          abandon
              ? 'Recorded sets stay in history as an abandoned workout.'
              : 'Only recorded work is included. Draft sets stay unperformed.',
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
    setState(() => finishing = true);
    try {
      await ref
          .read(workoutsProvider.notifier)
          .finish(widget.sessionId, abandon: abandon);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(workoutsProvider).value ?? [];
    final matches = items.where((w) => w['aggregate_id'] == widget.sessionId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Workout unavailable.')));
    }
    final workout = matches.first;
    final exercise = (workout['exercises'] as List).first as Json;
    final sets = (exercise['sets'] as List).cast<Json>();
    final pending = sets.where((s) => s['observation'] == null).toList();
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
            Text(
              workout['conflict'] == true
                  ? 'Saved on this device · sync needs review'
                  : ref.watch(syncStatusProvider).value?.label ??
                        'Saved on this device',
            ),
            const SizedBox(height: 24),
            Text(
              exercise['name'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Total external load · bilateral reps'),
            const SizedBox(height: 16),
            for (var index = 0; index < sets.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  sets[index]['observation'] == null
                      ? Icons.radio_button_unchecked
                      : Icons.check_circle_outline,
                ),
                title: Text(
                  'Set ${index + 1} · ${sets[index]['set_class']} · ${sets[index]['set_purpose']}',
                ),
                subtitle: Text(
                  sets[index]['observation'] == null
                      ? 'Planned ${sets[index]['planned']['load']['value']} kg × ${sets[index]['planned']['reps']} · unperformed'
                      : '${sets[index]['observation']['execution_status']} · ${sets[index]['observation']['actual'] == null ? 'No performance recorded' : '${sets[index]['observation']['actual']['load']['value']} ${sets[index]['observation']['actual']['load']['unit']} × ${sets[index]['observation']['actual']['reps']}'}',
                ),
                trailing: sets[index]['observation'] == null
                    ? null
                    : IconButton(
                        tooltip: 'Correct set ${index + 1}',
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: SetEditor(
                                sessionId: widget.sessionId,
                                exercise: exercise,
                                item: sets[index],
                                correction: true,
                                onSaved: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
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
                        onPressed: () async {
                          await ref
                              .read(repositoryProvider)
                              .cancelTimer(widget.sessionId);
                          if (mounted) setState(() => timerDisplay = null);
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (workout['status'] == 'active' && pending.isNotEmpty) ...[
              const SizedBox(height: 24),
              SetEditor(
                key: ValueKey(pending.first['set_id']),
                sessionId: widget.sessionId,
                exercise: exercise,
                item: pending.first,
                onSaved: () => unawaited(restoreTimer()),
              ),
            ],
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
  }
}

class SetEditor extends ConsumerStatefulWidget {
  final String sessionId;
  final Json exercise;
  final Json item;
  final bool correction;
  final VoidCallback onSaved;
  const SetEditor({
    super.key,
    required this.sessionId,
    required this.exercise,
    required this.item,
    required this.onSaved,
    this.correction = false,
  });
  @override
  ConsumerState<SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends ConsumerState<SetEditor> {
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
    if (saving || !ready) return;
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
  Widget build(BuildContext context) => Column(
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
        TextField(
          controller: load,
          enabled: !saving,
          decoration: InputDecoration(
            labelText: 'Load ($unit, total external)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => unawaited(preserve()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reps,
          enabled: !saving,
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
          onChanged: saving
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
          onChanged: saving
              ? null
              : (value) {
                  setState(() => scale = value!);
                  unawaited(preserve());
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: effort,
          enabled: !saving,
          decoration: const InputDecoration(
            labelText: 'Actual effort (optional)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: (_) => unawaited(preserve()),
          onSubmitted: (_) => save(),
        ),
        if (widget.correction) ...[
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            enabled: !saving,
            maxLength: 240,
            decoration: const InputDecoration(labelText: 'Correction reason'),
            textInputAction: TextInputAction.done,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: saving ? null : save,
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
