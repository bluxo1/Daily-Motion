import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_repository.dart';
import '../domain/exercise_catalog.dart';
import '../domain/workout.dart';
import '../sync/coordinator.dart';
import 'sync_provider.dart';
import 'workout_controller.dart';

final exerciseCatalogProvider =
    FutureProvider.autoDispose<List<CatalogDefinition>>((ref) {
      final repo = ref.watch(repositoryProvider);
      if (ref.watch(
        syncStatusProvider.select(
          (s) => s.value?.phase == SyncPhase.accountDisabled,
        ),
      )) {
        throw const WorkoutValidation('This account is unavailable.');
      }
      return repo.exerciseCatalog();
    });

String _label(Enum value) {
  final name = value.name;
  return name[0].toUpperCase() + name.substring(1);
}

bool _disabled(WidgetRef ref, WorkoutRepository original) =>
    !identical(ref.watch(repositoryProvider), original) ||
    ref.watch(
      syncStatusProvider.select(
        (s) => s.value?.phase == SyncPhase.accountDisabled,
      ),
    );

Widget _unavailable() => const Scaffold(
  body: SafeArea(
    child: Center(
      child: Text('This account is unavailable. Return to sign in.'),
    ),
  ),
);

String _error(Object error, String fallback) =>
    error is WorkoutValidation ? error.message : fallback;

class ExerciseCatalogScreen extends ConsumerStatefulWidget {
  const ExerciseCatalogScreen({super.key});
  @override
  ConsumerState<ExerciseCatalogScreen> createState() =>
      _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends ConsumerState<ExerciseCatalogScreen> {
  late final repo = ref.read(repositoryProvider);
  final search = TextEditingController();
  final searchFocus = FocusNode();
  CatalogEquipment? equipment;
  MovementCategory? category;
  CatalogSource? source;
  bool archived = false;
  bool busy = false;
  bool restoreSearchFocus = false;
  String? error;

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Future<void> choose(CatalogDefinition definition) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final current = (await repo.exerciseCatalog())
          .where((d) => d.variantId == definition.variantId)
          .single;
      require(
        !current.archived && current.revision == definition.revision,
        'This exercise changed. Review the refreshed definition before choosing it.',
      );
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        Navigator.pop(context, current);
      }
    } catch (failure) {
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        ref.invalidate(exerciseCatalogProvider);
        setState(
          () => error = _error(
            failure,
            'Exercise access could not be confirmed. Retry after checking account access.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit({
    CatalogDefinition? initial,
    CatalogDefinition? fork,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    final saved = await Navigator.of(context).push<CatalogDefinition>(
      MaterialPageRoute(
        builder: (_) => CustomExerciseEditor(initial: initial, fork: fork),
      ),
    );
    if (!mounted || !identical(ref.read(repositoryProvider), repo)) return;
    ref.invalidate(exerciseCatalogProvider);
    setState(() {
      busy = false;
      restoreSearchFocus = true;
      error = null;
      if (saved != null) {
        search.clear();
        equipment = null;
        category = null;
        source = CatalogSource.privateCustom;
        archived = saved.archived;
      }
    });
  }

  Future<void> archive(CatalogDefinition definition) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.saveCustomExercise(
        definition: definition.displayRevision(
          name: definition.name,
          archived: !definition.archived,
        ),
        expectedRevision: definition.revision,
      );
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        ref.invalidate(exerciseCatalogProvider);
      }
    } catch (failure) {
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        setState(
          () => error = _error(
            failure,
            'Could not update this private exercise. Retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget filter<T>(
    String label,
    T? value,
    List<T> options,
    String Function(T) text,
    void Function(T?) update,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<T>(
      key: ValueKey('catalog-$label-${value.toString()}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('All')),
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(
              text(option),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: busy ? null : (v) => setState(() => update(v)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_disabled(ref, repo)) return _unavailable();
    final catalog = ref.watch(exerciseCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise catalog')),
      body: SafeArea(
        child: catalog.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Exercises could not be loaded. Local data is retained.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(exerciseCatalogProvider),
                    child: const Text('Retry catalog'),
                  ),
                ],
              ),
            ),
          ),
          data: (all) {
            // Reloading temporarily detaches the search field. Request focus
            // only after the refreshed data actually renders it again.
            if (restoreSearchFocus) {
              restoreSearchFocus = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    identical(ref.read(repositoryProvider), repo) &&
                    searchFocus.context != null) {
                  searchFocus.requestFocus();
                }
              });
            }
            final items = filterCatalog(
              all,
              search: search.text,
              equipment: equipment,
              category: category,
              source: source,
              archived: archived,
            );
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Choose a definition, then configure planned sets. This does not record performed work.',
                        ),
                        const Text(
                          'Reusable private definitions stay on this device without catalog sync or backup. Started workout snapshots use normal workout sync.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('catalog-search'),
                          controller: search,
                          focusNode: searchFocus,
                          decoration: const InputDecoration(
                            labelText: 'Search exercises',
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => searchFocus.unfocus(),
                        ),
                        filter(
                          'Equipment',
                          equipment,
                          CatalogEquipment.values,
                          _label,
                          (v) => equipment = v,
                        ),
                        filter(
                          'Movement category',
                          category,
                          MovementCategory.values,
                          _label,
                          (v) => category = v,
                        ),
                        filter(
                          'Source',
                          source,
                          CatalogSource.values,
                          (v) => v == CatalogSource.firstParty
                              ? 'Curated'
                              : 'Private custom',
                          (v) => source = v,
                        ),
                        const SizedBox(height: 12),
                        FilterChip(
                          label: const Text('Archived private exercises'),
                          selected: archived,
                          onSelected: busy
                              ? null
                              : (v) => setState(() {
                                  archived = v;
                                  if (v) source = CatalogSource.privateCustom;
                                }),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: busy ? null : () => edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create custom exercise'),
                        ),
                        if (error != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              key: const ValueKey('catalog-error'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text('${items.length} matching definitions'),
                        if (items.isEmpty)
                          const Text(
                            'No exercise definitions match. Try another search or filter, or create a private exercise.',
                          ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final d = items[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Card(
                        key: ValueKey('catalog-${d.variantId}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  d.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              Text(
                                '${d.source == CatalogSource.firstParty ? 'Curated' : 'Private custom'} · ${_label(d.equipment)} · ${_label(d.category)}',
                              ),
                              Text(d.conventions),
                              if (d.setup.isNotEmpty) Text('Setup: ${d.setup}'),
                              Text(
                                'Variant ${d.variantId.substring(24)} · definition ${d.revision}${d.archived ? ' · archived' : ''}',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!d.archived)
                                    Semantics(
                                      label:
                                          'Choose ${d.name}, variant ${d.variantId.substring(24)}',
                                      child: FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => choose(d),
                                        child: const Text('Choose exercise'),
                                      ),
                                    ),
                                  if (d.source ==
                                      CatalogSource.privateCustom) ...[
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => edit(initial: d),
                                      child: const Text('Rename'),
                                    ),
                                    TextButton(
                                      onPressed: busy ? null : () => archive(d),
                                      child: Text(
                                        d.archived ? 'Restore' : 'Archive',
                                      ),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => edit(fork: d),
                                    child: const Text(
                                      'Create separate variant',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CustomExerciseEditor extends ConsumerStatefulWidget {
  final CatalogDefinition? initial;
  final CatalogDefinition? fork;
  const CustomExerciseEditor({super.key, this.initial, this.fork});
  @override
  ConsumerState<CustomExerciseEditor> createState() =>
      _CustomExerciseEditorState();
}

class _CustomExerciseEditorState extends ConsumerState<CustomExerciseEditor> {
  late final repo = ref.read(repositoryProvider);
  late final original = widget.initial ?? widget.fork;
  late final variant = widget.initial?.variantId ?? repo.newId();
  late final movement = original?.movementId ?? repo.newId();
  late final name = TextEditingController(text: original?.name ?? '');
  late final setup = TextEditingController(text: original?.setup ?? '');
  late CatalogEquipment equipment =
      original?.equipment ?? CatalogEquipment.other;
  late MovementCategory category = original?.category ?? MovementCategory.other;
  late CatalogLoading loading =
      original?.loading ?? CatalogLoading.totalExternal;
  late CatalogRepetitions repetitions =
      original?.repetitions ?? CatalogRepetitions.bilateral;
  late CatalogSide? side = widget.initial != null
      ? widget.initial!.side
      : original?.side ?? CatalogSide.unspecified;
  bool dirty = false;
  bool saving = false;
  bool leaving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    setup.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (saving || leaving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved custom exercise?'),
          content: const Text('Your last saved definition will be kept.'),
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
    if (saving || leaving || !identical(ref.read(repositoryProvider), repo)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final definition = CatalogDefinition(
        movementId: movement,
        variantId: variant,
        revision: (widget.initial?.revision ?? 0) + 1,
        name: name.text,
        equipment: equipment,
        setup: setup.text,
        category: category,
        loading: loading,
        repetitions: repetitions,
        side: side,
        source: CatalogSource.privateCustom,
        archived: widget.initial?.archived ?? false,
      );
      final saved = await repo.saveCustomExercise(
        definition: definition,
        expectedRevision: widget.initial?.revision ?? 0,
      );
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        setState(() {
          dirty = false;
          leaving = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(ref.read(repositoryProvider), repo)) {
            Navigator.pop(context, saved);
          }
        });
      }
    } catch (failure) {
      if (mounted && identical(ref.read(repositoryProvider), repo)) {
        setState(
          () => error = _error(
            failure,
            'Could not confirm the local save. Your input is retained. Retry with the same values.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget choice<T>(
    String label,
    T value,
    List<T> values,
    String Function(T) text,
    void Function(T) update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      key: ValueKey('custom-$label'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(text(v), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: saving
          ? null
          : (v) {
              if (v != null) {
                setState(() {
                  update(v);
                  dirty = true;
                });
              }
            },
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_disabled(ref, repo)) return _unavailable();
    return PopScope(
      canPop: leaving || (!dirty && !saving),
      onPopInvokedWithResult: (popped, _) {
        if (!popped) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initial == null
                ? 'Create custom exercise'
                : 'Rename private exercise',
          ),
          leading: BackButton(onPressed: leave),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Saving a reusable definition stays local and records no performed sets. Starting a workout copies its definition into the normal workout snapshot.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('custom-name'),
                controller: name,
                enabled: !saving,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Custom exercise name',
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
              const SizedBox(height: 16),
              if (widget.initial == null) ...[
                choice(
                  'Equipment',
                  equipment,
                  CatalogEquipment.values,
                  _label,
                  (v) => equipment = v,
                ),
                choice(
                  'Movement category',
                  category,
                  MovementCategory.values,
                  _label,
                  (v) => category = v,
                ),
                TextField(
                  key: const ValueKey('custom-setup'),
                  controller: setup,
                  enabled: !saving,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Equipment/setup note',
                    helperText: 'For another machine, setup or execution style, create a separate variant.',
                    helperMaxLines: 4,
                  ),
                  onChanged: (_) => setState(() => dirty = true),
                ),
                const SizedBox(height: 16),
                choice(
                  'Load convention',
                  loading,
                  CatalogLoading.values,
                  (v) => v.label,
                  (v) => loading = v,
                ),
                choice(
                  'Rep convention',
                  repetitions,
                  CatalogRepetitions.values,
                  (v) => v.label,
                  (v) => repetitions = v,
                ),
                choice(
                  'Recorded side',
                  side ?? CatalogSide.unspecified,
                  CatalogSide.values,
                  _label,
                  (v) => side = v,
                ),
              ] else ...[
                Text(widget.initial!.conventions),
                Text('Equipment: ${_label(equipment)}. Setup: ${setup.text}'),
                const Text(
                  'A display rename preserves comparison identity. To change equipment, setup or conventions, create a separate variant from the picker.',
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error!, key: const ValueKey('custom-error')),
                  ),
                ),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save custom exercise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
