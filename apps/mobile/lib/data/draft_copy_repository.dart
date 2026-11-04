part of 'workout_repository.dart';

/// A confirmation binds one exact local branch and draft, never an observation.
class SetDraftCopyPreview {
  final String _owner, _installation, _session, _target, _root, _draft, _entry;
  final String _values;
  final int sourceOrdinal;
  final int targetOrdinal;
  const SetDraftCopyPreview._(
    this._owner,
    this._installation,
    this._session,
    this._target,
    this._root,
    this._draft,
    this._entry,
    this._values,
    this.sourceOrdinal,
    this.targetOrdinal,
  );
  Json get values => jsonDecode(_values) as Json;
  bool matchesEntry(Json entry) => canonicalJson(entry) == _entry;
}

extension SetDraftCopyRepository on WorkoutRepository {
  Future<SetDraftCopyPreview> previewSetDraftCopy(
    String sessionId,
    String targetId,
    Json entry,
  ) => db.transaction(() async {
    await _guard();
    final root = await _read(sessionId);
    require(
      root != null && root['status'] == 'active',
      'Open an active workout to copy values.',
    );
    final state = root!;
    Json? source;
    var sourceOrdinal = 0;
    var targetOrdinal = 0;
    var found = false;
    for (final exercise in state['exercises'] as List) {
      Json? candidate;
      var ordinal = 0;
      for (final item in exercise['sets'] as List) {
        ordinal++;
        if (item['set_id'] == targetId) {
          require(
            item['observation'] == null,
            'This set has already been recorded.',
          );
          found = true;
          source = candidate;
          targetOrdinal = ordinal;
          break;
        }
        if (item['set_class'] == 'working' &&
            item['observation']?['execution_status'] == 'completed') {
          candidate = item as Json;
          sourceOrdinal = ordinal;
        }
      }
      if (found) break;
    }
    require(
      found && source != null,
      'No preceding completed working set in this exercise.',
    );
    final stored = await draft(targetId);
    const keys = {
      'load',
      'reps',
      'effort',
      'effort_scale',
      'execution_status',
      'unit',
    };
    for (final values in [stored, entry]) {
      require(
        values == null || values.keys.every(keys.contains),
        'This draft needs a newer app.',
      );
      require(
        values == null || values.values.every((value) => value is String),
        'The draft cannot be copied safely.',
      );
    }
    final actual = source!['observation']['actual'] as Json;
    final values = {
      ...entry,
      'load': actual['load']?['value'] as String? ?? '',
      'unit': actual['load']?['unit'] as String? ?? entry['unit'] ?? 'kg',
      'reps': actual['reps'].toString(),
      'effort': '',
    };
    final identity = await db
        .customSelect('SELECT installation_id FROM local_identity')
        .getSingle();
    return SetDraftCopyPreview._(
      ownerId,
      identity.read<String>('installation_id'),
      sessionId,
      targetId,
      canonicalJson(state),
      canonicalJson(stored),
      canonicalJson(entry),
      canonicalJson(values),
      sourceOrdinal,
      targetOrdinal,
    );
  });

  Future<Json> applySetDraftCopy(SetDraftCopyPreview preview) =>
      db.transaction(() async {
        await _guard();
        final identity = await db
            .customSelect('SELECT installation_id FROM local_identity')
            .getSingle();
        require(
          preview._owner == ownerId &&
              preview._installation == identity.read<String>('installation_id'),
          'This preview belongs to a different installation.',
        );
        require(
          canonicalJson(await _read(preview._session)) == preview._root &&
              canonicalJson(await draft(preview._target)) == preview._draft,
          'The workout or draft changed. Review a fresh preview.',
        );
        await db.customStatement(
          'INSERT INTO drafts(set_id,values_json) VALUES(?,?) ON CONFLICT(set_id) DO UPDATE SET values_json=excluded.values_json',
          [preview._target, preview._values],
        );
        return preview.values;
      });
}
