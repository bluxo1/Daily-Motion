import 'package:uuid/uuid.dart';

import 'workout.dart';

enum CatalogEquipment { barbell, dumbbell, cable, machine, bodyweight, other }

enum MovementCategory { squat, hinge, push, pull, arms, calves, other }

enum CatalogSource { firstParty, privateCustom }

enum CatalogLoading {
  totalExternal('total_external', 'Total external load'),
  perImplement('per_implement', 'Load per implement'),
  machineStack('machine_stack', 'Machine stack load'),
  addedBodyweight('added_bodyweight', 'Added bodyweight load'),
  assistance('assistance', 'Positive assistance'),
  bodyweightOnly('bodyweight_only', 'Bodyweight only; no external load');

  final String wire;
  final String label;
  const CatalogLoading(this.wire, this.label);
}

enum CatalogRepetitions {
  bilateral('bilateral', 'Bilateral reps'),
  perSide('per_side', 'Reps per side'),
  alternatingTotal('alternating_total', 'Alternating total reps');

  final String wire;
  final String label;
  const CatalogRepetitions(this.wire, this.label);
}

enum CatalogSide { left, right, both, unspecified }

bool _catalogUuid(String value) =>
    value == value.toLowerCase() && Uuid.isValidUUID(fromString: value);

/// Local definition metadata. Only the existing workout snapshot fields cross
/// into RoutinePlan; selecting a definition never records an observation.
class CatalogDefinition {
  final String movementId;
  final String variantId;
  final int revision;
  final String name;
  final CatalogEquipment equipment;
  final String setup;
  final MovementCategory category;
  final CatalogLoading loading;
  final CatalogRepetitions repetitions;
  final CatalogSide? side;
  final CatalogSource source;
  final bool archived;

  CatalogDefinition({
    required this.movementId,
    required this.variantId,
    required this.revision,
    required String name,
    required this.equipment,
    required String setup,
    required this.category,
    required this.loading,
    required this.repetitions,
    this.side,
    required this.source,
    this.archived = false,
  }) : name = name.trim(),
       setup = setup.trim() {
    require(
      _catalogUuid(movementId) && _catalogUuid(variantId),
      'Use stable lowercase exercise identities.',
    );
    require(revision > 0, 'Invalid exercise definition revision.');
    require(
      this.name.isNotEmpty &&
          this.name.runes.length <= 120 &&
          !RegExp(r'[\x00-\x1f\x7f]').hasMatch(this.name),
      'Name the exercise using 1–120 characters.',
    );
    require(
      this.setup.runes.length <= 240 &&
          !RegExp(r'[\x00-\x1f\x7f]').hasMatch(this.setup),
      'Use a setup note of at most 240 characters.',
    );
  }

  String get provenance => source == CatalogSource.firstParty
      ? 'Daily Motion first-party catalog · 2026-10-27; no third-party text or media'
      : 'Private owner-authored definition · saved only on this device';

  String get conventions =>
      '${loading.label} · ${repetitions.label} · side: ${side?.name ?? 'unspecified'}';

  /// A display revision cannot silently alter a comparison identity's meaning.
  bool sameSemantics(CatalogDefinition other) =>
      movementId == other.movementId &&
      equipment == other.equipment &&
      setup == other.setup &&
      category == other.category &&
      loading == other.loading &&
      repetitions == other.repetitions &&
      side == other.side;

  CatalogDefinition displayRevision({required String name, bool? archived}) =>
      CatalogDefinition(
        movementId: movementId,
        variantId: variantId,
        revision: revision + 1,
        name: name,
        equipment: equipment,
        setup: setup,
        category: category,
        loading: loading,
        repetitions: repetitions,
        side: side,
        source: source,
        archived: archived ?? this.archived,
      );

  Json get json => {
    'movement_id': movementId,
    'variant_id': variantId,
    'definition_revision': revision,
    'name': name,
    'equipment': equipment.name,
    'setup': setup,
    'category': category.name,
    'loading_basis': loading.wire,
    'rep_convention': repetitions.wire,
    'side': side?.name,
    'source': source.name,
    'archived': archived,
  };

  factory CatalogDefinition.fromJson(Json json) => CatalogDefinition(
    movementId: json['movement_id'] as String,
    variantId: json['variant_id'] as String,
    revision: json['definition_revision'] as int,
    name: json['name'] as String,
    equipment: CatalogEquipment.values.byName(json['equipment'] as String),
    setup: json['setup'] as String,
    category: MovementCategory.values.byName(json['category'] as String),
    loading: CatalogLoading.values.singleWhere(
      (v) => v.wire == json['loading_basis'],
    ),
    repetitions: CatalogRepetitions.values.singleWhere(
      (v) => v.wire == json['rep_convention'],
    ),
    side: json['side'] == null
        ? null
        : CatalogSide.values.byName(json['side'] as String),
    source: CatalogSource.values.byName(json['source'] as String),
    archived: json['archived'] as bool,
  );

  Json prescription(String Function() newId, {int plannedSets = 3}) {
    require(!archived, 'Choose an active exercise definition.');
    require(plannedSets >= 1 && plannedSets <= 100, 'Use 1–100 planned sets.');
    return {
      'session_exercise_id': newId(),
      'variant_id': variantId,
      'name': name,
      'loading_basis': loading.wire,
      'rep_convention': repetitions.wire,
      // The wire's omitted-side default is both. A new catalog definition with
      // no recorded side must remain unspecified on every device instead.
      'side': side?.name ?? 'unspecified',
      'sets': [
        for (var i = 0; i < plannedSets; i++)
          {
            'set_id': newId(),
            'set_class': 'working',
            'set_purpose': 'regular',
            'planned': {'reps': 5, 'rest_seconds': 120},
          },
      ],
    };
  }
}

// Explicit identities are permanent assignments, not IDs generated at selection.
// These first-party labels contain no imported instructions, images or claims.
// Different equipment/setup or execution semantics require another variant ID.
final List<CatalogDefinition> curatedExercises = List.unmodifiable([
  _curated(
    '001',
    '001',
    'Barbell bench press',
    CatalogEquipment.barbell,
    MovementCategory.push,
    CatalogLoading.totalExternal,
  ),
  _curated(
    '001',
    '002',
    'Dumbbell bench press',
    CatalogEquipment.dumbbell,
    MovementCategory.push,
    CatalogLoading.perImplement,
  ),
  _curated(
    '002',
    '003',
    'Barbell back squat',
    CatalogEquipment.barbell,
    MovementCategory.squat,
    CatalogLoading.totalExternal,
  ),
  _curated(
    '002',
    '004',
    'Goblet squat',
    CatalogEquipment.dumbbell,
    MovementCategory.squat,
    CatalogLoading.perImplement,
  ),
  _curated(
    '003',
    '005',
    'Barbell deadlift',
    CatalogEquipment.barbell,
    MovementCategory.hinge,
    CatalogLoading.totalExternal,
  ),
  _curated(
    '004',
    '006',
    'Barbell Romanian deadlift',
    CatalogEquipment.barbell,
    MovementCategory.hinge,
    CatalogLoading.totalExternal,
  ),
  _curated(
    '004',
    '007',
    'Dumbbell Romanian deadlift',
    CatalogEquipment.dumbbell,
    MovementCategory.hinge,
    CatalogLoading.perImplement,
  ),
  _curated(
    '005',
    '008',
    'Barbell overhead press',
    CatalogEquipment.barbell,
    MovementCategory.push,
    CatalogLoading.totalExternal,
  ),
  _curated(
    '005',
    '009',
    'Dumbbell overhead press',
    CatalogEquipment.dumbbell,
    MovementCategory.push,
    CatalogLoading.perImplement,
  ),
  _curated(
    '006',
    '010',
    'Barbell bent-over row',
    CatalogEquipment.barbell,
    MovementCategory.pull,
    CatalogLoading.totalExternal,
  ),
  _curated(
    '006',
    '011',
    'Single-arm dumbbell row (each side)',
    CatalogEquipment.dumbbell,
    MovementCategory.pull,
    CatalogLoading.perImplement,
    reps: CatalogRepetitions.perSide,
  ),
  _curated(
    '007',
    '012',
    'Pull-up',
    CatalogEquipment.bodyweight,
    MovementCategory.pull,
    CatalogLoading.bodyweightOnly,
  ),
  _curated(
    '007',
    '013',
    'Weighted pull-up',
    CatalogEquipment.bodyweight,
    MovementCategory.pull,
    CatalogLoading.addedBodyweight,
  ),
  _curated(
    '008',
    '014',
    'Push-up',
    CatalogEquipment.bodyweight,
    MovementCategory.push,
    CatalogLoading.bodyweightOnly,
  ),
  _curated(
    '009',
    '015',
    'Dumbbell curl (alternating total)',
    CatalogEquipment.dumbbell,
    MovementCategory.arms,
    CatalogLoading.perImplement,
    reps: CatalogRepetitions.alternatingTotal,
  ),
  _curated(
    '010',
    '016',
    'Standing dumbbell calf raise',
    CatalogEquipment.dumbbell,
    MovementCategory.calves,
    CatalogLoading.perImplement,
  ),
]);

CatalogDefinition _curated(
  String movement,
  String variant,
  String name,
  CatalogEquipment equipment,
  MovementCategory category,
  CatalogLoading loading, {
  CatalogRepetitions reps = CatalogRepetitions.bilateral,
}) => CatalogDefinition(
  movementId: 'd0201000-0000-4000-8000-000000000$movement',
  variantId: 'd0202000-0000-4000-8000-000000000$variant',
  revision: 1,
  name: name,
  equipment: equipment,
  setup: '',
  category: category,
  loading: loading,
  repetitions: reps,
  side: CatalogSide.both,
  source: CatalogSource.firstParty,
);

List<CatalogDefinition> filterCatalog(
  Iterable<CatalogDefinition> definitions, {
  String search = '',
  CatalogEquipment? equipment,
  MovementCategory? category,
  CatalogSource? source,
  bool archived = false,
}) {
  final query = search.trim().toLowerCase();
  return definitions
      .where(
        (d) =>
            d.archived == archived &&
            (equipment == null || d.equipment == equipment) &&
            (category == null || d.category == category) &&
            (source == null || d.source == source) &&
            (query.isEmpty ||
                '${d.name} ${d.setup}'.toLowerCase().contains(query)),
      )
      .toList()
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.variantId.compareTo(b.variantId);
    });
}
