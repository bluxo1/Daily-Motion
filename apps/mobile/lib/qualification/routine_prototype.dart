import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/theme.dart';

/// A disposable interaction study, not a routine repository or auth bypass.
/// It owns no account, database, outbox or network client.
void main() => runApp(const RoutinePrototypeApp());

@immutable
class RoutinePreview {
  final String name;
  final int sets;
  final int minimumReps;
  final int maximumReps;
  final int restSeconds;
  final int version;
  const RoutinePreview({
    required this.name,
    required this.sets,
    required this.minimumReps,
    required this.maximumReps,
    required this.restSeconds,
    required this.version,
  });

  String get prescription =>
      '$sets working sets · $minimumReps–$maximumReps planned reps · $restSeconds s planned rest';
}

class RoutinePrototypeController extends ChangeNotifier {
  String name = 'Upper body';
  String sets = '3';
  String minimumReps = '5';
  String maximumReps = '8';
  String restSeconds = '120';
  String? error;
  int _version = 0;
  final List<RoutinePreview> _previews = [];
  List<RoutinePreview> get previews => List.unmodifiable(_previews);

  void edit(String field, String value) {
    switch (field) {
      case 'name':
        name = value;
      case 'sets':
        sets = value;
      case 'minimumReps':
        minimumReps = value;
      case 'maximumReps':
        maximumReps = value;
      case 'restSeconds':
        restSeconds = value;
      default:
        throw ArgumentError('Unknown prototype field');
    }
    error = null;
    notifyListeners();
  }

  bool preview() {
    int? whole(String text) =>
        RegExp(r'^\d{1,4}$').hasMatch(text) ? int.tryParse(text) : null;
    final count = whole(sets);
    final low = whole(minimumReps);
    final high = whole(maximumReps);
    final rest = whole(restSeconds);
    if (name.trim().isEmpty || name.trim().length > 120) {
      error = 'Enter a routine name of 1–120 characters.';
    } else if (count == null || count < 1 || count > 20) {
      error = 'Use 1–20 planned sets in this prototype.';
    } else if (low == null ||
        high == null ||
        low < 1 ||
        high > 100 ||
        low > high) {
      error = 'Use a planned rep range from 1 to 100, minimum first.';
    } else if (rest == null || rest > 3600) {
      error = 'Use 0–3600 seconds of planned rest in this prototype.';
    } else {
      _previews.add(
        RoutinePreview(
          name: name.trim(),
          sets: count,
          minimumReps: low,
          maximumReps: high,
          restSeconds: rest,
          version: ++_version,
        ),
      );
      error = null;
    }
    notifyListeners();
    return error == null;
  }
}

class RoutinePrototypeApp extends StatelessWidget {
  const RoutinePrototypeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Daily Motion interaction study',
    theme: motionTheme(Brightness.light),
    darkTheme: motionTheme(Brightness.dark),
    home: kReleaseMode
        ? const Scaffold(
            body: SafeArea(
              child: Center(
                child: Text(
                  'Interaction prototypes are unavailable in release builds.',
                ),
              ),
            ),
          )
        : const RoutinePrototypeScreen(),
  );
}

class RoutinePrototypeScreen extends StatefulWidget {
  const RoutinePrototypeScreen({super.key});
  @override
  State<RoutinePrototypeScreen> createState() => _RoutinePrototypeScreenState();
}

class _RoutinePrototypeScreenState extends State<RoutinePrototypeScreen> {
  final controller = RoutinePrototypeController();
  late final fields = <String, TextEditingController>{
    'name': TextEditingController(text: controller.name),
    'sets': TextEditingController(text: controller.sets),
    'minimumReps': TextEditingController(text: controller.minimumReps),
    'maximumReps': TextEditingController(text: controller.maximumReps),
    'restSeconds': TextEditingController(text: controller.restSeconds),
  };
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    controller.dispose();
    super.dispose();
  }

  Future<void> preview() async {
    if (!controller.preview()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final snapshot = controller.previews.last;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Workout preview')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  snapshot.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Template preview ${snapshot.version} · synthetic, not a saved workout',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Barbell bench press · total external load · bilateral reps',
                ),
                Text(snapshot.prescription),
                const SizedBox(height: 16),
                const Text(
                  'These are planned values. No actual load, effort or completed sets have been recorded.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to routine'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Routine interaction study')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Phase 0 · synthetic interaction prototype'),
            const SizedBox(height: 12),
            const Text(
              'Edits last for this study only. No personal routines or workouts are saved.',
            ),
            const SizedBox(height: 24),
            for (final field in const {
              'name': 'Routine name',
              'sets': 'Planned working sets',
              'minimumReps': 'Minimum planned reps',
              'maximumReps': 'Maximum planned reps',
              'restSeconds': 'Planned rest (seconds)',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  key: ValueKey(field.key),
                  controller: fields[field.key],
                  keyboardType: field.key == 'name'
                      ? TextInputType.text
                      : TextInputType.number,
                  textInputAction: field.key == 'restSeconds'
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: InputDecoration(labelText: field.value),
                  onChanged: (text) => controller.edit(field.key, text),
                  onSubmitted: (_) {
                    if (field.key == 'restSeconds') {
                      FocusManager.instance.primaryFocus?.unfocus();
                    } else {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
              ),
            if (controller.error case final error?)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(error),
                ),
              ),
            FilledButton(
              onPressed: preview,
              child: const Text('Preview next workout'),
            ),
            const SizedBox(height: 24),
            if (controller.previews.isNotEmpty) ...[
              Text(
                'Previously started previews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Later routine edits leave these prescriptions unchanged.',
              ),
              for (final snapshot in controller.previews)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${snapshot.name} · preview ${snapshot.version}\n${snapshot.prescription}',
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
