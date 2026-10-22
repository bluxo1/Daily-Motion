// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class LocalIdentity extends Table
    with TableInfo<LocalIdentity, LocalIdentityData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LocalIdentity(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (singleton = 1)',
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _installationIdMeta = const VerificationMeta(
    'installationId',
  );
  late final GeneratedColumn<String> installationId = GeneratedColumn<String>(
    'installation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  late final GeneratedColumn<int> locked = GeneratedColumn<int>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (locked IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    singleton,
    ownerId,
    installationId,
    locked,
    cursor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_identity';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalIdentityData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton')) {
      context.handle(
        _singletonMeta,
        singleton.isAcceptableOrUnknown(data['singleton']!, _singletonMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('installation_id')) {
      context.handle(
        _installationIdMeta,
        installationId.isAcceptableOrUnknown(
          data['installation_id']!,
          _installationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installationIdMeta);
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  LocalIdentityData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalIdentityData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      installationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}installation_id'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}locked'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
    );
  }

  @override
  LocalIdentity createAlias(String alias) {
    return LocalIdentity(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalIdentityData extends DataClass
    implements Insertable<LocalIdentityData> {
  final int singleton;
  final String ownerId;
  final String installationId;
  final int locked;
  final String? cursor;
  const LocalIdentityData({
    required this.singleton,
    required this.ownerId,
    required this.installationId,
    required this.locked,
    this.cursor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['owner_id'] = Variable<String>(ownerId);
    map['installation_id'] = Variable<String>(installationId);
    map['locked'] = Variable<int>(locked);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    return map;
  }

  LocalIdentityCompanion toCompanion(bool nullToAbsent) {
    return LocalIdentityCompanion(
      singleton: Value(singleton),
      ownerId: Value(ownerId),
      installationId: Value(installationId),
      locked: Value(locked),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
    );
  }

  factory LocalIdentityData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalIdentityData(
      singleton: serializer.fromJson<int>(json['singleton']),
      ownerId: serializer.fromJson<String>(json['owner_id']),
      installationId: serializer.fromJson<String>(json['installation_id']),
      locked: serializer.fromJson<int>(json['locked']),
      cursor: serializer.fromJson<String?>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'owner_id': serializer.toJson<String>(ownerId),
      'installation_id': serializer.toJson<String>(installationId),
      'locked': serializer.toJson<int>(locked),
      'cursor': serializer.toJson<String?>(cursor),
    };
  }

  LocalIdentityData copyWith({
    int? singleton,
    String? ownerId,
    String? installationId,
    int? locked,
    Value<String?> cursor = const Value.absent(),
  }) => LocalIdentityData(
    singleton: singleton ?? this.singleton,
    ownerId: ownerId ?? this.ownerId,
    installationId: installationId ?? this.installationId,
    locked: locked ?? this.locked,
    cursor: cursor.present ? cursor.value : this.cursor,
  );
  LocalIdentityData copyWithCompanion(LocalIdentityCompanion data) {
    return LocalIdentityData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      installationId: data.installationId.present
          ? data.installationId.value
          : this.installationId,
      locked: data.locked.present ? data.locked.value : this.locked,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalIdentityData(')
          ..write('singleton: $singleton, ')
          ..write('ownerId: $ownerId, ')
          ..write('installationId: $installationId, ')
          ..write('locked: $locked, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(singleton, ownerId, installationId, locked, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalIdentityData &&
          other.singleton == this.singleton &&
          other.ownerId == this.ownerId &&
          other.installationId == this.installationId &&
          other.locked == this.locked &&
          other.cursor == this.cursor);
}

class LocalIdentityCompanion extends UpdateCompanion<LocalIdentityData> {
  final Value<int> singleton;
  final Value<String> ownerId;
  final Value<String> installationId;
  final Value<int> locked;
  final Value<String?> cursor;
  const LocalIdentityCompanion({
    this.singleton = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.installationId = const Value.absent(),
    this.locked = const Value.absent(),
    this.cursor = const Value.absent(),
  });
  LocalIdentityCompanion.insert({
    this.singleton = const Value.absent(),
    required String ownerId,
    required String installationId,
    this.locked = const Value.absent(),
    this.cursor = const Value.absent(),
  }) : ownerId = Value(ownerId),
       installationId = Value(installationId);
  static Insertable<LocalIdentityData> custom({
    Expression<int>? singleton,
    Expression<String>? ownerId,
    Expression<String>? installationId,
    Expression<int>? locked,
    Expression<String>? cursor,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (ownerId != null) 'owner_id': ownerId,
      if (installationId != null) 'installation_id': installationId,
      if (locked != null) 'locked': locked,
      if (cursor != null) 'cursor': cursor,
    });
  }

  LocalIdentityCompanion copyWith({
    Value<int>? singleton,
    Value<String>? ownerId,
    Value<String>? installationId,
    Value<int>? locked,
    Value<String?>? cursor,
  }) {
    return LocalIdentityCompanion(
      singleton: singleton ?? this.singleton,
      ownerId: ownerId ?? this.ownerId,
      installationId: installationId ?? this.installationId,
      locked: locked ?? this.locked,
      cursor: cursor ?? this.cursor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (installationId.present) {
      map['installation_id'] = Variable<String>(installationId.value);
    }
    if (locked.present) {
      map['locked'] = Variable<int>(locked.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalIdentityCompanion(')
          ..write('singleton: $singleton, ')
          ..write('ownerId: $ownerId, ')
          ..write('installationId: $installationId, ')
          ..write('locked: $locked, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }
}

class Sessions extends Table with TableInfo<Sessions, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Sessions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _hasConflictMeta = const VerificationMeta(
    'hasConflict',
  );
  late final GeneratedColumn<int> hasConflict = GeneratedColumn<int>(
    'has_conflict',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _branchBaseMeta = const VerificationMeta(
    'branchBase',
  );
  late final GeneratedColumn<int> branchBase = GeneratedColumn<int>(
    'branch_base',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    metadata,
    localSeq,
    hasConflict,
    branchBase,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_localSeqMeta);
    }
    if (data.containsKey('has_conflict')) {
      context.handle(
        _hasConflictMeta,
        hasConflict.isAcceptableOrUnknown(
          data['has_conflict']!,
          _hasConflictMeta,
        ),
      );
    }
    if (data.containsKey('branch_base')) {
      context.handle(
        _branchBaseMeta,
        branchBase.isAcceptableOrUnknown(data['branch_base']!, _branchBaseMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      hasConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_conflict'],
      )!,
      branchBase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_base'],
      ),
    );
  }

  @override
  Sessions createAlias(String alias) {
    return Sessions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String metadata;
  final int localSeq;
  final int hasConflict;
  final int? branchBase;
  const Session({
    required this.id,
    required this.metadata,
    required this.localSeq,
    required this.hasConflict,
    this.branchBase,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['metadata'] = Variable<String>(metadata);
    map['local_seq'] = Variable<int>(localSeq);
    map['has_conflict'] = Variable<int>(hasConflict);
    if (!nullToAbsent || branchBase != null) {
      map['branch_base'] = Variable<int>(branchBase);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      metadata: Value(metadata),
      localSeq: Value(localSeq),
      hasConflict: Value(hasConflict),
      branchBase: branchBase == null && nullToAbsent
          ? const Value.absent()
          : Value(branchBase),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      metadata: serializer.fromJson<String>(json['metadata']),
      localSeq: serializer.fromJson<int>(json['local_seq']),
      hasConflict: serializer.fromJson<int>(json['has_conflict']),
      branchBase: serializer.fromJson<int?>(json['branch_base']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'metadata': serializer.toJson<String>(metadata),
      'local_seq': serializer.toJson<int>(localSeq),
      'has_conflict': serializer.toJson<int>(hasConflict),
      'branch_base': serializer.toJson<int?>(branchBase),
    };
  }

  Session copyWith({
    String? id,
    String? metadata,
    int? localSeq,
    int? hasConflict,
    Value<int?> branchBase = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    metadata: metadata ?? this.metadata,
    localSeq: localSeq ?? this.localSeq,
    hasConflict: hasConflict ?? this.hasConflict,
    branchBase: branchBase.present ? branchBase.value : this.branchBase,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      hasConflict: data.hasConflict.present
          ? data.hasConflict.value
          : this.hasConflict,
      branchBase: data.branchBase.present
          ? data.branchBase.value
          : this.branchBase,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('metadata: $metadata, ')
          ..write('localSeq: $localSeq, ')
          ..write('hasConflict: $hasConflict, ')
          ..write('branchBase: $branchBase')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, metadata, localSeq, hasConflict, branchBase);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.metadata == this.metadata &&
          other.localSeq == this.localSeq &&
          other.hasConflict == this.hasConflict &&
          other.branchBase == this.branchBase);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> metadata;
  final Value<int> localSeq;
  final Value<int> hasConflict;
  final Value<int?> branchBase;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.metadata = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.branchBase = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String metadata,
    required int localSeq,
    this.hasConflict = const Value.absent(),
    this.branchBase = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       metadata = Value(metadata),
       localSeq = Value(localSeq);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? metadata,
    Expression<int>? localSeq,
    Expression<int>? hasConflict,
    Expression<int>? branchBase,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (metadata != null) 'metadata': metadata,
      if (localSeq != null) 'local_seq': localSeq,
      if (hasConflict != null) 'has_conflict': hasConflict,
      if (branchBase != null) 'branch_base': branchBase,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? metadata,
    Value<int>? localSeq,
    Value<int>? hasConflict,
    Value<int?>? branchBase,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      localSeq: localSeq ?? this.localSeq,
      hasConflict: hasConflict ?? this.hasConflict,
      branchBase: branchBase ?? this.branchBase,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (hasConflict.present) {
      map['has_conflict'] = Variable<int>(hasConflict.value);
    }
    if (branchBase.present) {
      map['branch_base'] = Variable<int>(branchBase.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('metadata: $metadata, ')
          ..write('localSeq: $localSeq, ')
          ..write('hasConflict: $hasConflict, ')
          ..write('branchBase: $branchBase, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Exercises extends Table with TableInfo<Exercises, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Exercises(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES sessions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _definitionMeta = const VerificationMeta(
    'definition',
  );
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
    'definition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, ordinal, definition];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('definition')) {
      context.handle(
        _definitionMeta,
        definition.isAcceptableOrUnknown(data['definition']!, _definitionMeta),
      );
    } else if (isInserting) {
      context.missing(_definitionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      definition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition'],
      )!,
    );
  }

  @override
  Exercises createAlias(String alias) {
    return Exercises(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final String id;
  final String sessionId;
  final int ordinal;
  final String definition;
  const Exercise({
    required this.id,
    required this.sessionId,
    required this.ordinal,
    required this.definition,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['ordinal'] = Variable<int>(ordinal);
    map['definition'] = Variable<String>(definition);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      ordinal: Value(ordinal),
      definition: Value(definition),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['session_id']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      definition: serializer.fromJson<String>(json['definition']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'session_id': serializer.toJson<String>(sessionId),
      'ordinal': serializer.toJson<int>(ordinal),
      'definition': serializer.toJson<String>(definition),
    };
  }

  Exercise copyWith({
    String? id,
    String? sessionId,
    int? ordinal,
    String? definition,
  }) => Exercise(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    ordinal: ordinal ?? this.ordinal,
    definition: definition ?? this.definition,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('definition: $definition')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, ordinal, definition);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ordinal == this.ordinal &&
          other.definition == this.definition);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> ordinal;
  final Value<String> definition;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.definition = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String id,
    required String sessionId,
    required int ordinal,
    required String definition,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       ordinal = Value(ordinal),
       definition = Value(definition);
  static Insertable<Exercise> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? ordinal,
    Expression<String>? definition,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ordinal != null) 'ordinal': ordinal,
      if (definition != null) 'definition': definition,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? ordinal,
    Value<String>? definition,
    Value<int>? rowid,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ordinal: ordinal ?? this.ordinal,
      definition: definition ?? this.definition,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('definition: $definition, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class WorkoutSets extends Table with TableInfo<WorkoutSets, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WorkoutSets(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES exercises(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _prescriptionMeta = const VerificationMeta(
    'prescription',
  );
  late final GeneratedColumn<String> prescription = GeneratedColumn<String>(
    'prescription',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _observationMeta = const VerificationMeta(
    'observation',
  );
  late final GeneratedColumn<String> observation = GeneratedColumn<String>(
    'observation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseId,
    ordinal,
    prescription,
    observation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('prescription')) {
      context.handle(
        _prescriptionMeta,
        prescription.isAcceptableOrUnknown(
          data['prescription']!,
          _prescriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prescriptionMeta);
    }
    if (data.containsKey('observation')) {
      context.handle(
        _observationMeta,
        observation.isAcceptableOrUnknown(
          data['observation']!,
          _observationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      prescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription'],
      )!,
      observation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observation'],
      ),
    );
  }

  @override
  WorkoutSets createAlias(String alias) {
    return WorkoutSets(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final String id;
  final String exerciseId;
  final int ordinal;
  final String prescription;
  final String? observation;
  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.ordinal,
    required this.prescription,
    this.observation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['ordinal'] = Variable<int>(ordinal);
    map['prescription'] = Variable<String>(prescription);
    if (!nullToAbsent || observation != null) {
      map['observation'] = Variable<String>(observation);
    }
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      ordinal: Value(ordinal),
      prescription: Value(prescription),
      observation: observation == null && nullToAbsent
          ? const Value.absent()
          : Value(observation),
    );
  }

  factory WorkoutSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<String>(json['id']),
      exerciseId: serializer.fromJson<String>(json['exercise_id']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      prescription: serializer.fromJson<String>(json['prescription']),
      observation: serializer.fromJson<String?>(json['observation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exercise_id': serializer.toJson<String>(exerciseId),
      'ordinal': serializer.toJson<int>(ordinal),
      'prescription': serializer.toJson<String>(prescription),
      'observation': serializer.toJson<String?>(observation),
    };
  }

  WorkoutSet copyWith({
    String? id,
    String? exerciseId,
    int? ordinal,
    String? prescription,
    Value<String?> observation = const Value.absent(),
  }) => WorkoutSet(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    ordinal: ordinal ?? this.ordinal,
    prescription: prescription ?? this.prescription,
    observation: observation.present ? observation.value : this.observation,
  );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      prescription: data.prescription.present
          ? data.prescription.value
          : this.prescription,
      observation: data.observation.present
          ? data.observation.value
          : this.observation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('ordinal: $ordinal, ')
          ..write('prescription: $prescription, ')
          ..write('observation: $observation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, exerciseId, ordinal, prescription, observation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.ordinal == this.ordinal &&
          other.prescription == this.prescription &&
          other.observation == this.observation);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<String> id;
  final Value<String> exerciseId;
  final Value<int> ordinal;
  final Value<String> prescription;
  final Value<String?> observation;
  final Value<int> rowid;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.prescription = const Value.absent(),
    this.observation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    required String id,
    required String exerciseId,
    required int ordinal,
    required String prescription,
    this.observation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       exerciseId = Value(exerciseId),
       ordinal = Value(ordinal),
       prescription = Value(prescription);
  static Insertable<WorkoutSet> custom({
    Expression<String>? id,
    Expression<String>? exerciseId,
    Expression<int>? ordinal,
    Expression<String>? prescription,
    Expression<String>? observation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (ordinal != null) 'ordinal': ordinal,
      if (prescription != null) 'prescription': prescription,
      if (observation != null) 'observation': observation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? exerciseId,
    Value<int>? ordinal,
    Value<String>? prescription,
    Value<String?>? observation,
    Value<int>? rowid,
  }) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      ordinal: ordinal ?? this.ordinal,
      prescription: prescription ?? this.prescription,
      observation: observation ?? this.observation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (prescription.present) {
      map['prescription'] = Variable<String>(prescription.value);
    }
    if (observation.present) {
      map['observation'] = Variable<String>(observation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('ordinal: $ordinal, ')
          ..write('prescription: $prescription, ')
          ..write('observation: $observation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LocalObservations extends Table
    with TableInfo<LocalObservations, LocalObservation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LocalObservations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES sessions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, localSeq, setId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_observations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalObservation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_localSeqMeta);
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, localSeq};
  @override
  LocalObservation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalObservation(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  LocalObservations createAlias(String alias) {
    return LocalObservations(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(session_id, local_seq)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class LocalObservation extends DataClass
    implements Insertable<LocalObservation> {
  final String sessionId;
  final int localSeq;
  final String setId;
  final String payload;
  const LocalObservation({
    required this.sessionId,
    required this.localSeq,
    required this.setId,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['local_seq'] = Variable<int>(localSeq);
    map['set_id'] = Variable<String>(setId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalObservationsCompanion toCompanion(bool nullToAbsent) {
    return LocalObservationsCompanion(
      sessionId: Value(sessionId),
      localSeq: Value(localSeq),
      setId: Value(setId),
      payload: Value(payload),
    );
  }

  factory LocalObservation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalObservation(
      sessionId: serializer.fromJson<String>(json['session_id']),
      localSeq: serializer.fromJson<int>(json['local_seq']),
      setId: serializer.fromJson<String>(json['set_id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'session_id': serializer.toJson<String>(sessionId),
      'local_seq': serializer.toJson<int>(localSeq),
      'set_id': serializer.toJson<String>(setId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalObservation copyWith({
    String? sessionId,
    int? localSeq,
    String? setId,
    String? payload,
  }) => LocalObservation(
    sessionId: sessionId ?? this.sessionId,
    localSeq: localSeq ?? this.localSeq,
    setId: setId ?? this.setId,
    payload: payload ?? this.payload,
  );
  LocalObservation copyWithCompanion(LocalObservationsCompanion data) {
    return LocalObservation(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      setId: data.setId.present ? data.setId.value : this.setId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalObservation(')
          ..write('sessionId: $sessionId, ')
          ..write('localSeq: $localSeq, ')
          ..write('setId: $setId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, localSeq, setId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalObservation &&
          other.sessionId == this.sessionId &&
          other.localSeq == this.localSeq &&
          other.setId == this.setId &&
          other.payload == this.payload);
}

class LocalObservationsCompanion extends UpdateCompanion<LocalObservation> {
  final Value<String> sessionId;
  final Value<int> localSeq;
  final Value<String> setId;
  final Value<String> payload;
  final Value<int> rowid;
  const LocalObservationsCompanion({
    this.sessionId = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.setId = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalObservationsCompanion.insert({
    required String sessionId,
    required int localSeq,
    required String setId,
    required String payload,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       localSeq = Value(localSeq),
       setId = Value(setId),
       payload = Value(payload);
  static Insertable<LocalObservation> custom({
    Expression<String>? sessionId,
    Expression<int>? localSeq,
    Expression<String>? setId,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (localSeq != null) 'local_seq': localSeq,
      if (setId != null) 'set_id': setId,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalObservationsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? localSeq,
    Value<String>? setId,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return LocalObservationsCompanion(
      sessionId: sessionId ?? this.sessionId,
      localSeq: localSeq ?? this.localSeq,
      setId: setId ?? this.setId,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalObservationsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('localSeq: $localSeq, ')
          ..write('setId: $setId, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Outbox extends Table with TableInfo<Outbox, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Outbox(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _predecessorIdMeta = const VerificationMeta(
    'predecessorId',
  );
  late final GeneratedColumn<String> predecessorId = GeneratedColumn<String>(
    'predecessor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _originBaseMeta = const VerificationMeta(
    'originBase',
  );
  late final GeneratedColumn<int> originBase = GeneratedColumn<int>(
    'origin_base',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _frozenBodyMeta = const VerificationMeta(
    'frozenBody',
  );
  late final GeneratedColumn<String> frozenBody = GeneratedColumn<String>(
    'frozen_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _acceptedRevisionMeta = const VerificationMeta(
    'acceptedRevision',
  );
  late final GeneratedColumn<int> acceptedRevision = GeneratedColumn<int>(
    'accepted_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (state IN (\'pending\', \'acknowledged\', \'conflict\', \'rejected\'))',
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _requestDigestMeta = const VerificationMeta(
    'requestDigest',
  );
  late final GeneratedColumn<String> requestDigest = GeneratedColumn<String>(
    'request_digest',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _wireVersionMeta = const VerificationMeta(
    'wireVersion',
  );
  late final GeneratedColumn<int> wireVersion = GeneratedColumn<int>(
    'wire_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1 CHECK (wire_version IN (1, 2))',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _originContextMeta = const VerificationMeta(
    'originContext',
  );
  late final GeneratedColumn<String> originContext = GeneratedColumn<String>(
    'origin_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _acceptedContextMeta = const VerificationMeta(
    'acceptedContext',
  );
  late final GeneratedColumn<String> acceptedContext = GeneratedColumn<String>(
    'accepted_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    sessionId,
    localSeq,
    predecessorId,
    originBase,
    operation,
    frozenBody,
    acceptedRevision,
    state,
    attemptCount,
    lastError,
    requestDigest,
    wireVersion,
    originContext,
    acceptedContext,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_localSeqMeta);
    }
    if (data.containsKey('predecessor_id')) {
      context.handle(
        _predecessorIdMeta,
        predecessorId.isAcceptableOrUnknown(
          data['predecessor_id']!,
          _predecessorIdMeta,
        ),
      );
    }
    if (data.containsKey('origin_base')) {
      context.handle(
        _originBaseMeta,
        originBase.isAcceptableOrUnknown(data['origin_base']!, _originBaseMeta),
      );
    } else if (isInserting) {
      context.missing(_originBaseMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('frozen_body')) {
      context.handle(
        _frozenBodyMeta,
        frozenBody.isAcceptableOrUnknown(data['frozen_body']!, _frozenBodyMeta),
      );
    }
    if (data.containsKey('accepted_revision')) {
      context.handle(
        _acceptedRevisionMeta,
        acceptedRevision.isAcceptableOrUnknown(
          data['accepted_revision']!,
          _acceptedRevisionMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('request_digest')) {
      context.handle(
        _requestDigestMeta,
        requestDigest.isAcceptableOrUnknown(
          data['request_digest']!,
          _requestDigestMeta,
        ),
      );
    }
    if (data.containsKey('wire_version')) {
      context.handle(
        _wireVersionMeta,
        wireVersion.isAcceptableOrUnknown(
          data['wire_version']!,
          _wireVersionMeta,
        ),
      );
    }
    if (data.containsKey('origin_context')) {
      context.handle(
        _originContextMeta,
        originContext.isAcceptableOrUnknown(
          data['origin_context']!,
          _originContextMeta,
        ),
      );
    }
    if (data.containsKey('accepted_context')) {
      context.handle(
        _acceptedContextMeta,
        acceptedContext.isAcceptableOrUnknown(
          data['accepted_context']!,
          _acceptedContextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, localSeq},
  ];
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      predecessorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}predecessor_id'],
      ),
      originBase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin_base'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      frozenBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frozen_body'],
      ),
      acceptedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted_revision'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      requestDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_digest'],
      ),
      wireVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wire_version'],
      )!,
      originContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_context'],
      ),
      acceptedContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accepted_context'],
      ),
    );
  }

  @override
  Outbox createAlias(String alias) {
    return Outbox(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(session_id, local_seq)'];
  @override
  bool get dontWriteConstraints => true;
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String mutationId;
  final String sessionId;
  final int localSeq;
  final String? predecessorId;
  final int originBase;
  final String operation;
  final String? frozenBody;
  final int? acceptedRevision;
  final String state;
  final int attemptCount;
  final String? lastError;
  final String? requestDigest;
  final int wireVersion;
  final String? originContext;
  final String? acceptedContext;
  const OutboxData({
    required this.mutationId,
    required this.sessionId,
    required this.localSeq,
    this.predecessorId,
    required this.originBase,
    required this.operation,
    this.frozenBody,
    this.acceptedRevision,
    required this.state,
    required this.attemptCount,
    this.lastError,
    this.requestDigest,
    required this.wireVersion,
    this.originContext,
    this.acceptedContext,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['session_id'] = Variable<String>(sessionId);
    map['local_seq'] = Variable<int>(localSeq);
    if (!nullToAbsent || predecessorId != null) {
      map['predecessor_id'] = Variable<String>(predecessorId);
    }
    map['origin_base'] = Variable<int>(originBase);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || frozenBody != null) {
      map['frozen_body'] = Variable<String>(frozenBody);
    }
    if (!nullToAbsent || acceptedRevision != null) {
      map['accepted_revision'] = Variable<int>(acceptedRevision);
    }
    map['state'] = Variable<String>(state);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || requestDigest != null) {
      map['request_digest'] = Variable<String>(requestDigest);
    }
    map['wire_version'] = Variable<int>(wireVersion);
    if (!nullToAbsent || originContext != null) {
      map['origin_context'] = Variable<String>(originContext);
    }
    if (!nullToAbsent || acceptedContext != null) {
      map['accepted_context'] = Variable<String>(acceptedContext);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      mutationId: Value(mutationId),
      sessionId: Value(sessionId),
      localSeq: Value(localSeq),
      predecessorId: predecessorId == null && nullToAbsent
          ? const Value.absent()
          : Value(predecessorId),
      originBase: Value(originBase),
      operation: Value(operation),
      frozenBody: frozenBody == null && nullToAbsent
          ? const Value.absent()
          : Value(frozenBody),
      acceptedRevision: acceptedRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedRevision),
      state: Value(state),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      requestDigest: requestDigest == null && nullToAbsent
          ? const Value.absent()
          : Value(requestDigest),
      wireVersion: Value(wireVersion),
      originContext: originContext == null && nullToAbsent
          ? const Value.absent()
          : Value(originContext),
      acceptedContext: acceptedContext == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedContext),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      mutationId: serializer.fromJson<String>(json['mutation_id']),
      sessionId: serializer.fromJson<String>(json['session_id']),
      localSeq: serializer.fromJson<int>(json['local_seq']),
      predecessorId: serializer.fromJson<String?>(json['predecessor_id']),
      originBase: serializer.fromJson<int>(json['origin_base']),
      operation: serializer.fromJson<String>(json['operation']),
      frozenBody: serializer.fromJson<String?>(json['frozen_body']),
      acceptedRevision: serializer.fromJson<int?>(json['accepted_revision']),
      state: serializer.fromJson<String>(json['state']),
      attemptCount: serializer.fromJson<int>(json['attempt_count']),
      lastError: serializer.fromJson<String?>(json['last_error']),
      requestDigest: serializer.fromJson<String?>(json['request_digest']),
      wireVersion: serializer.fromJson<int>(json['wire_version']),
      originContext: serializer.fromJson<String?>(json['origin_context']),
      acceptedContext: serializer.fromJson<String?>(json['accepted_context']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutation_id': serializer.toJson<String>(mutationId),
      'session_id': serializer.toJson<String>(sessionId),
      'local_seq': serializer.toJson<int>(localSeq),
      'predecessor_id': serializer.toJson<String?>(predecessorId),
      'origin_base': serializer.toJson<int>(originBase),
      'operation': serializer.toJson<String>(operation),
      'frozen_body': serializer.toJson<String?>(frozenBody),
      'accepted_revision': serializer.toJson<int?>(acceptedRevision),
      'state': serializer.toJson<String>(state),
      'attempt_count': serializer.toJson<int>(attemptCount),
      'last_error': serializer.toJson<String?>(lastError),
      'request_digest': serializer.toJson<String?>(requestDigest),
      'wire_version': serializer.toJson<int>(wireVersion),
      'origin_context': serializer.toJson<String?>(originContext),
      'accepted_context': serializer.toJson<String?>(acceptedContext),
    };
  }

  OutboxData copyWith({
    String? mutationId,
    String? sessionId,
    int? localSeq,
    Value<String?> predecessorId = const Value.absent(),
    int? originBase,
    String? operation,
    Value<String?> frozenBody = const Value.absent(),
    Value<int?> acceptedRevision = const Value.absent(),
    String? state,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    Value<String?> requestDigest = const Value.absent(),
    int? wireVersion,
    Value<String?> originContext = const Value.absent(),
    Value<String?> acceptedContext = const Value.absent(),
  }) => OutboxData(
    mutationId: mutationId ?? this.mutationId,
    sessionId: sessionId ?? this.sessionId,
    localSeq: localSeq ?? this.localSeq,
    predecessorId: predecessorId.present
        ? predecessorId.value
        : this.predecessorId,
    originBase: originBase ?? this.originBase,
    operation: operation ?? this.operation,
    frozenBody: frozenBody.present ? frozenBody.value : this.frozenBody,
    acceptedRevision: acceptedRevision.present
        ? acceptedRevision.value
        : this.acceptedRevision,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    requestDigest: requestDigest.present
        ? requestDigest.value
        : this.requestDigest,
    wireVersion: wireVersion ?? this.wireVersion,
    originContext: originContext.present
        ? originContext.value
        : this.originContext,
    acceptedContext: acceptedContext.present
        ? acceptedContext.value
        : this.acceptedContext,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      predecessorId: data.predecessorId.present
          ? data.predecessorId.value
          : this.predecessorId,
      originBase: data.originBase.present
          ? data.originBase.value
          : this.originBase,
      operation: data.operation.present ? data.operation.value : this.operation,
      frozenBody: data.frozenBody.present
          ? data.frozenBody.value
          : this.frozenBody,
      acceptedRevision: data.acceptedRevision.present
          ? data.acceptedRevision.value
          : this.acceptedRevision,
      state: data.state.present ? data.state.value : this.state,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      requestDigest: data.requestDigest.present
          ? data.requestDigest.value
          : this.requestDigest,
      wireVersion: data.wireVersion.present
          ? data.wireVersion.value
          : this.wireVersion,
      originContext: data.originContext.present
          ? data.originContext.value
          : this.originContext,
      acceptedContext: data.acceptedContext.present
          ? data.acceptedContext.value
          : this.acceptedContext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('mutationId: $mutationId, ')
          ..write('sessionId: $sessionId, ')
          ..write('localSeq: $localSeq, ')
          ..write('predecessorId: $predecessorId, ')
          ..write('originBase: $originBase, ')
          ..write('operation: $operation, ')
          ..write('frozenBody: $frozenBody, ')
          ..write('acceptedRevision: $acceptedRevision, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('requestDigest: $requestDigest, ')
          ..write('wireVersion: $wireVersion, ')
          ..write('originContext: $originContext, ')
          ..write('acceptedContext: $acceptedContext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mutationId,
    sessionId,
    localSeq,
    predecessorId,
    originBase,
    operation,
    frozenBody,
    acceptedRevision,
    state,
    attemptCount,
    lastError,
    requestDigest,
    wireVersion,
    originContext,
    acceptedContext,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.mutationId == this.mutationId &&
          other.sessionId == this.sessionId &&
          other.localSeq == this.localSeq &&
          other.predecessorId == this.predecessorId &&
          other.originBase == this.originBase &&
          other.operation == this.operation &&
          other.frozenBody == this.frozenBody &&
          other.acceptedRevision == this.acceptedRevision &&
          other.state == this.state &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.requestDigest == this.requestDigest &&
          other.wireVersion == this.wireVersion &&
          other.originContext == this.originContext &&
          other.acceptedContext == this.acceptedContext);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> mutationId;
  final Value<String> sessionId;
  final Value<int> localSeq;
  final Value<String?> predecessorId;
  final Value<int> originBase;
  final Value<String> operation;
  final Value<String?> frozenBody;
  final Value<int?> acceptedRevision;
  final Value<String> state;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<String?> requestDigest;
  final Value<int> wireVersion;
  final Value<String?> originContext;
  final Value<String?> acceptedContext;
  final Value<int> rowid;
  const OutboxCompanion({
    this.mutationId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.predecessorId = const Value.absent(),
    this.originBase = const Value.absent(),
    this.operation = const Value.absent(),
    this.frozenBody = const Value.absent(),
    this.acceptedRevision = const Value.absent(),
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.requestDigest = const Value.absent(),
    this.wireVersion = const Value.absent(),
    this.originContext = const Value.absent(),
    this.acceptedContext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String mutationId,
    required String sessionId,
    required int localSeq,
    this.predecessorId = const Value.absent(),
    required int originBase,
    required String operation,
    this.frozenBody = const Value.absent(),
    this.acceptedRevision = const Value.absent(),
    required String state,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.requestDigest = const Value.absent(),
    this.wireVersion = const Value.absent(),
    this.originContext = const Value.absent(),
    this.acceptedContext = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       sessionId = Value(sessionId),
       localSeq = Value(localSeq),
       originBase = Value(originBase),
       operation = Value(operation),
       state = Value(state);
  static Insertable<OutboxData> custom({
    Expression<String>? mutationId,
    Expression<String>? sessionId,
    Expression<int>? localSeq,
    Expression<String>? predecessorId,
    Expression<int>? originBase,
    Expression<String>? operation,
    Expression<String>? frozenBody,
    Expression<int>? acceptedRevision,
    Expression<String>? state,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<String>? requestDigest,
    Expression<int>? wireVersion,
    Expression<String>? originContext,
    Expression<String>? acceptedContext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (sessionId != null) 'session_id': sessionId,
      if (localSeq != null) 'local_seq': localSeq,
      if (predecessorId != null) 'predecessor_id': predecessorId,
      if (originBase != null) 'origin_base': originBase,
      if (operation != null) 'operation': operation,
      if (frozenBody != null) 'frozen_body': frozenBody,
      if (acceptedRevision != null) 'accepted_revision': acceptedRevision,
      if (state != null) 'state': state,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (requestDigest != null) 'request_digest': requestDigest,
      if (wireVersion != null) 'wire_version': wireVersion,
      if (originContext != null) 'origin_context': originContext,
      if (acceptedContext != null) 'accepted_context': acceptedContext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? sessionId,
    Value<int>? localSeq,
    Value<String?>? predecessorId,
    Value<int>? originBase,
    Value<String>? operation,
    Value<String?>? frozenBody,
    Value<int?>? acceptedRevision,
    Value<String>? state,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<String?>? requestDigest,
    Value<int>? wireVersion,
    Value<String?>? originContext,
    Value<String?>? acceptedContext,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      mutationId: mutationId ?? this.mutationId,
      sessionId: sessionId ?? this.sessionId,
      localSeq: localSeq ?? this.localSeq,
      predecessorId: predecessorId ?? this.predecessorId,
      originBase: originBase ?? this.originBase,
      operation: operation ?? this.operation,
      frozenBody: frozenBody ?? this.frozenBody,
      acceptedRevision: acceptedRevision ?? this.acceptedRevision,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      requestDigest: requestDigest ?? this.requestDigest,
      wireVersion: wireVersion ?? this.wireVersion,
      originContext: originContext ?? this.originContext,
      acceptedContext: acceptedContext ?? this.acceptedContext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (predecessorId.present) {
      map['predecessor_id'] = Variable<String>(predecessorId.value);
    }
    if (originBase.present) {
      map['origin_base'] = Variable<int>(originBase.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (frozenBody.present) {
      map['frozen_body'] = Variable<String>(frozenBody.value);
    }
    if (acceptedRevision.present) {
      map['accepted_revision'] = Variable<int>(acceptedRevision.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (requestDigest.present) {
      map['request_digest'] = Variable<String>(requestDigest.value);
    }
    if (wireVersion.present) {
      map['wire_version'] = Variable<int>(wireVersion.value);
    }
    if (originContext.present) {
      map['origin_context'] = Variable<String>(originContext.value);
    }
    if (acceptedContext.present) {
      map['accepted_context'] = Variable<String>(acceptedContext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('sessionId: $sessionId, ')
          ..write('localSeq: $localSeq, ')
          ..write('predecessorId: $predecessorId, ')
          ..write('originBase: $originBase, ')
          ..write('operation: $operation, ')
          ..write('frozenBody: $frozenBody, ')
          ..write('acceptedRevision: $acceptedRevision, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('requestDigest: $requestDigest, ')
          ..write('wireVersion: $wireVersion, ')
          ..write('originContext: $originContext, ')
          ..write('acceptedContext: $acceptedContext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Shadows extends Table with TableInfo<Shadows, Shadow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Shadows(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _projectionMeta = const VerificationMeta(
    'projection',
  );
  late final GeneratedColumn<String> projection = GeneratedColumn<String>(
    'projection',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _recoveryContextMeta = const VerificationMeta(
    'recoveryContext',
  );
  late final GeneratedColumn<String> recoveryContext = GeneratedColumn<String>(
    'recovery_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    revision,
    projection,
    recoveryContext,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shadows';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shadow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('projection')) {
      context.handle(
        _projectionMeta,
        projection.isAcceptableOrUnknown(data['projection']!, _projectionMeta),
      );
    }
    if (data.containsKey('recovery_context')) {
      context.handle(
        _recoveryContextMeta,
        recoveryContext.isAcceptableOrUnknown(
          data['recovery_context']!,
          _recoveryContextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  Shadow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shadow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      projection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}projection'],
      ),
      recoveryContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recovery_context'],
      ),
    );
  }

  @override
  Shadows createAlias(String alias) {
    return Shadows(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Shadow extends DataClass implements Insertable<Shadow> {
  final String sessionId;
  final int revision;
  final String? projection;
  final String? recoveryContext;
  const Shadow({
    required this.sessionId,
    required this.revision,
    this.projection,
    this.recoveryContext,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || projection != null) {
      map['projection'] = Variable<String>(projection);
    }
    if (!nullToAbsent || recoveryContext != null) {
      map['recovery_context'] = Variable<String>(recoveryContext);
    }
    return map;
  }

  ShadowsCompanion toCompanion(bool nullToAbsent) {
    return ShadowsCompanion(
      sessionId: Value(sessionId),
      revision: Value(revision),
      projection: projection == null && nullToAbsent
          ? const Value.absent()
          : Value(projection),
      recoveryContext: recoveryContext == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryContext),
    );
  }

  factory Shadow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shadow(
      sessionId: serializer.fromJson<String>(json['session_id']),
      revision: serializer.fromJson<int>(json['revision']),
      projection: serializer.fromJson<String?>(json['projection']),
      recoveryContext: serializer.fromJson<String?>(json['recovery_context']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'session_id': serializer.toJson<String>(sessionId),
      'revision': serializer.toJson<int>(revision),
      'projection': serializer.toJson<String?>(projection),
      'recovery_context': serializer.toJson<String?>(recoveryContext),
    };
  }

  Shadow copyWith({
    String? sessionId,
    int? revision,
    Value<String?> projection = const Value.absent(),
    Value<String?> recoveryContext = const Value.absent(),
  }) => Shadow(
    sessionId: sessionId ?? this.sessionId,
    revision: revision ?? this.revision,
    projection: projection.present ? projection.value : this.projection,
    recoveryContext: recoveryContext.present
        ? recoveryContext.value
        : this.recoveryContext,
  );
  Shadow copyWithCompanion(ShadowsCompanion data) {
    return Shadow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      revision: data.revision.present ? data.revision.value : this.revision,
      projection: data.projection.present
          ? data.projection.value
          : this.projection,
      recoveryContext: data.recoveryContext.present
          ? data.recoveryContext.value
          : this.recoveryContext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shadow(')
          ..write('sessionId: $sessionId, ')
          ..write('revision: $revision, ')
          ..write('projection: $projection, ')
          ..write('recoveryContext: $recoveryContext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, revision, projection, recoveryContext);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shadow &&
          other.sessionId == this.sessionId &&
          other.revision == this.revision &&
          other.projection == this.projection &&
          other.recoveryContext == this.recoveryContext);
}

class ShadowsCompanion extends UpdateCompanion<Shadow> {
  final Value<String> sessionId;
  final Value<int> revision;
  final Value<String?> projection;
  final Value<String?> recoveryContext;
  final Value<int> rowid;
  const ShadowsCompanion({
    this.sessionId = const Value.absent(),
    this.revision = const Value.absent(),
    this.projection = const Value.absent(),
    this.recoveryContext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShadowsCompanion.insert({
    required String sessionId,
    required int revision,
    this.projection = const Value.absent(),
    this.recoveryContext = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       revision = Value(revision);
  static Insertable<Shadow> custom({
    Expression<String>? sessionId,
    Expression<int>? revision,
    Expression<String>? projection,
    Expression<String>? recoveryContext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (revision != null) 'revision': revision,
      if (projection != null) 'projection': projection,
      if (recoveryContext != null) 'recovery_context': recoveryContext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShadowsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? revision,
    Value<String?>? projection,
    Value<String?>? recoveryContext,
    Value<int>? rowid,
  }) {
    return ShadowsCompanion(
      sessionId: sessionId ?? this.sessionId,
      revision: revision ?? this.revision,
      projection: projection ?? this.projection,
      recoveryContext: recoveryContext ?? this.recoveryContext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (projection.present) {
      map['projection'] = Variable<String>(projection.value);
    }
    if (recoveryContext.present) {
      map['recovery_context'] = Variable<String>(recoveryContext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShadowsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('revision: $revision, ')
          ..write('projection: $projection, ')
          ..write('recoveryContext: $recoveryContext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Drafts extends Table with TableInfo<Drafts, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Drafts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY REFERENCES workout_sets(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _valuesJsonMeta = const VerificationMeta(
    'valuesJson',
  );
  late final GeneratedColumn<String> valuesJson = GeneratedColumn<String>(
    'values_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [setId, valuesJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('values_json')) {
      context.handle(
        _valuesJsonMeta,
        valuesJson.isAcceptableOrUnknown(data['values_json']!, _valuesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valuesJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setId};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      valuesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}values_json'],
      )!,
    );
  }

  @override
  Drafts createAlias(String alias) {
    return Drafts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Draft extends DataClass implements Insertable<Draft> {
  final String setId;
  final String valuesJson;
  const Draft({required this.setId, required this.valuesJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['set_id'] = Variable<String>(setId);
    map['values_json'] = Variable<String>(valuesJson);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(setId: Value(setId), valuesJson: Value(valuesJson));
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      setId: serializer.fromJson<String>(json['set_id']),
      valuesJson: serializer.fromJson<String>(json['values_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'set_id': serializer.toJson<String>(setId),
      'values_json': serializer.toJson<String>(valuesJson),
    };
  }

  Draft copyWith({String? setId, String? valuesJson}) => Draft(
    setId: setId ?? this.setId,
    valuesJson: valuesJson ?? this.valuesJson,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      setId: data.setId.present ? data.setId.value : this.setId,
      valuesJson: data.valuesJson.present
          ? data.valuesJson.value
          : this.valuesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('setId: $setId, ')
          ..write('valuesJson: $valuesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(setId, valuesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.setId == this.setId &&
          other.valuesJson == this.valuesJson);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<String> setId;
  final Value<String> valuesJson;
  final Value<int> rowid;
  const DraftsCompanion({
    this.setId = const Value.absent(),
    this.valuesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String setId,
    required String valuesJson,
    this.rowid = const Value.absent(),
  }) : setId = Value(setId),
       valuesJson = Value(valuesJson);
  static Insertable<Draft> custom({
    Expression<String>? setId,
    Expression<String>? valuesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (setId != null) 'set_id': setId,
      if (valuesJson != null) 'values_json': valuesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? setId,
    Value<String>? valuesJson,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      setId: setId ?? this.setId,
      valuesJson: valuesJson ?? this.valuesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (valuesJson.present) {
      map['values_json'] = Variable<String>(valuesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('setId: $setId, ')
          ..write('valuesJson: $valuesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RestTimers extends Table with TableInfo<RestTimers, RestTimer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RestTimers(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY REFERENCES sessions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _anchorMeta = const VerificationMeta('anchor');
  late final GeneratedColumn<String> anchor = GeneratedColumn<String>(
    'anchor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  late final GeneratedColumn<String> deadline = GeneratedColumn<String>(
    'deadline',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _monotonicUsMeta = const VerificationMeta(
    'monotonicUs',
  );
  late final GeneratedColumn<int> monotonicUs = GeneratedColumn<int>(
    'monotonic_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _continuityIdMeta = const VerificationMeta(
    'continuityId',
  );
  late final GeneratedColumn<String> continuityId = GeneratedColumn<String>(
    'continuity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _uncertainMeta = const VerificationMeta(
    'uncertain',
  );
  late final GeneratedColumn<int> uncertain = GeneratedColumn<int>(
    'uncertain',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (uncertain IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    anchor,
    deadline,
    monotonicUs,
    continuityId,
    uncertain,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rest_timers';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestTimer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('anchor')) {
      context.handle(
        _anchorMeta,
        anchor.isAcceptableOrUnknown(data['anchor']!, _anchorMeta),
      );
    } else if (isInserting) {
      context.missing(_anchorMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    } else if (isInserting) {
      context.missing(_deadlineMeta);
    }
    if (data.containsKey('monotonic_us')) {
      context.handle(
        _monotonicUsMeta,
        monotonicUs.isAcceptableOrUnknown(
          data['monotonic_us']!,
          _monotonicUsMeta,
        ),
      );
    }
    if (data.containsKey('continuity_id')) {
      context.handle(
        _continuityIdMeta,
        continuityId.isAcceptableOrUnknown(
          data['continuity_id']!,
          _continuityIdMeta,
        ),
      );
    }
    if (data.containsKey('uncertain')) {
      context.handle(
        _uncertainMeta,
        uncertain.isAcceptableOrUnknown(data['uncertain']!, _uncertainMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  RestTimer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestTimer(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      anchor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deadline'],
      )!,
      monotonicUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monotonic_us'],
      ),
      continuityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}continuity_id'],
      ),
      uncertain: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uncertain'],
      )!,
    );
  }

  @override
  RestTimers createAlias(String alias) {
    return RestTimers(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class RestTimer extends DataClass implements Insertable<RestTimer> {
  final String sessionId;
  final String anchor;
  final String deadline;
  final int? monotonicUs;
  final String? continuityId;
  final int uncertain;
  const RestTimer({
    required this.sessionId,
    required this.anchor,
    required this.deadline,
    this.monotonicUs,
    this.continuityId,
    required this.uncertain,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['anchor'] = Variable<String>(anchor);
    map['deadline'] = Variable<String>(deadline);
    if (!nullToAbsent || monotonicUs != null) {
      map['monotonic_us'] = Variable<int>(monotonicUs);
    }
    if (!nullToAbsent || continuityId != null) {
      map['continuity_id'] = Variable<String>(continuityId);
    }
    map['uncertain'] = Variable<int>(uncertain);
    return map;
  }

  RestTimersCompanion toCompanion(bool nullToAbsent) {
    return RestTimersCompanion(
      sessionId: Value(sessionId),
      anchor: Value(anchor),
      deadline: Value(deadline),
      monotonicUs: monotonicUs == null && nullToAbsent
          ? const Value.absent()
          : Value(monotonicUs),
      continuityId: continuityId == null && nullToAbsent
          ? const Value.absent()
          : Value(continuityId),
      uncertain: Value(uncertain),
    );
  }

  factory RestTimer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestTimer(
      sessionId: serializer.fromJson<String>(json['session_id']),
      anchor: serializer.fromJson<String>(json['anchor']),
      deadline: serializer.fromJson<String>(json['deadline']),
      monotonicUs: serializer.fromJson<int?>(json['monotonic_us']),
      continuityId: serializer.fromJson<String?>(json['continuity_id']),
      uncertain: serializer.fromJson<int>(json['uncertain']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'session_id': serializer.toJson<String>(sessionId),
      'anchor': serializer.toJson<String>(anchor),
      'deadline': serializer.toJson<String>(deadline),
      'monotonic_us': serializer.toJson<int?>(monotonicUs),
      'continuity_id': serializer.toJson<String?>(continuityId),
      'uncertain': serializer.toJson<int>(uncertain),
    };
  }

  RestTimer copyWith({
    String? sessionId,
    String? anchor,
    String? deadline,
    Value<int?> monotonicUs = const Value.absent(),
    Value<String?> continuityId = const Value.absent(),
    int? uncertain,
  }) => RestTimer(
    sessionId: sessionId ?? this.sessionId,
    anchor: anchor ?? this.anchor,
    deadline: deadline ?? this.deadline,
    monotonicUs: monotonicUs.present ? monotonicUs.value : this.monotonicUs,
    continuityId: continuityId.present ? continuityId.value : this.continuityId,
    uncertain: uncertain ?? this.uncertain,
  );
  RestTimer copyWithCompanion(RestTimersCompanion data) {
    return RestTimer(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      anchor: data.anchor.present ? data.anchor.value : this.anchor,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      monotonicUs: data.monotonicUs.present
          ? data.monotonicUs.value
          : this.monotonicUs,
      continuityId: data.continuityId.present
          ? data.continuityId.value
          : this.continuityId,
      uncertain: data.uncertain.present ? data.uncertain.value : this.uncertain,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestTimer(')
          ..write('sessionId: $sessionId, ')
          ..write('anchor: $anchor, ')
          ..write('deadline: $deadline, ')
          ..write('monotonicUs: $monotonicUs, ')
          ..write('continuityId: $continuityId, ')
          ..write('uncertain: $uncertain')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    anchor,
    deadline,
    monotonicUs,
    continuityId,
    uncertain,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestTimer &&
          other.sessionId == this.sessionId &&
          other.anchor == this.anchor &&
          other.deadline == this.deadline &&
          other.monotonicUs == this.monotonicUs &&
          other.continuityId == this.continuityId &&
          other.uncertain == this.uncertain);
}

class RestTimersCompanion extends UpdateCompanion<RestTimer> {
  final Value<String> sessionId;
  final Value<String> anchor;
  final Value<String> deadline;
  final Value<int?> monotonicUs;
  final Value<String?> continuityId;
  final Value<int> uncertain;
  final Value<int> rowid;
  const RestTimersCompanion({
    this.sessionId = const Value.absent(),
    this.anchor = const Value.absent(),
    this.deadline = const Value.absent(),
    this.monotonicUs = const Value.absent(),
    this.continuityId = const Value.absent(),
    this.uncertain = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestTimersCompanion.insert({
    required String sessionId,
    required String anchor,
    required String deadline,
    this.monotonicUs = const Value.absent(),
    this.continuityId = const Value.absent(),
    this.uncertain = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       anchor = Value(anchor),
       deadline = Value(deadline);
  static Insertable<RestTimer> custom({
    Expression<String>? sessionId,
    Expression<String>? anchor,
    Expression<String>? deadline,
    Expression<int>? monotonicUs,
    Expression<String>? continuityId,
    Expression<int>? uncertain,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (anchor != null) 'anchor': anchor,
      if (deadline != null) 'deadline': deadline,
      if (monotonicUs != null) 'monotonic_us': monotonicUs,
      if (continuityId != null) 'continuity_id': continuityId,
      if (uncertain != null) 'uncertain': uncertain,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestTimersCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? anchor,
    Value<String>? deadline,
    Value<int?>? monotonicUs,
    Value<String?>? continuityId,
    Value<int>? uncertain,
    Value<int>? rowid,
  }) {
    return RestTimersCompanion(
      sessionId: sessionId ?? this.sessionId,
      anchor: anchor ?? this.anchor,
      deadline: deadline ?? this.deadline,
      monotonicUs: monotonicUs ?? this.monotonicUs,
      continuityId: continuityId ?? this.continuityId,
      uncertain: uncertain ?? this.uncertain,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (anchor.present) {
      map['anchor'] = Variable<String>(anchor.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<String>(deadline.value);
    }
    if (monotonicUs.present) {
      map['monotonic_us'] = Variable<int>(monotonicUs.value);
    }
    if (continuityId.present) {
      map['continuity_id'] = Variable<String>(continuityId.value);
    }
    if (uncertain.present) {
      map['uncertain'] = Variable<int>(uncertain.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestTimersCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('anchor: $anchor, ')
          ..write('deadline: $deadline, ')
          ..write('monotonicUs: $monotonicUs, ')
          ..write('continuityId: $continuityId, ')
          ..write('uncertain: $uncertain, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RetiredIds extends Table with TableInfo<RetiredIds, RetiredId> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RetiredIds(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'retired_ids';
  @override
  VerificationContext validateIntegrity(
    Insertable<RetiredId> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RetiredId map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RetiredId(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  RetiredIds createAlias(String alias) {
    return RetiredIds(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class RetiredId extends DataClass implements Insertable<RetiredId> {
  final String id;
  const RetiredId({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    return map;
  }

  RetiredIdsCompanion toCompanion(bool nullToAbsent) {
    return RetiredIdsCompanion(id: Value(id));
  }

  factory RetiredId.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RetiredId(id: serializer.fromJson<String>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<String>(id)};
  }

  RetiredId copyWith({String? id}) => RetiredId(id: id ?? this.id);
  RetiredId copyWithCompanion(RetiredIdsCompanion data) {
    return RetiredId(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('RetiredId(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RetiredId && other.id == this.id);
}

class RetiredIdsCompanion extends UpdateCompanion<RetiredId> {
  final Value<String> id;
  final Value<int> rowid;
  const RetiredIdsCompanion({
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RetiredIdsCompanion.insert({
    required String id,
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<RetiredId> custom({
    Expression<String>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RetiredIdsCompanion copyWith({Value<String>? id, Value<int>? rowid}) {
    return RetiredIdsCompanion(id: id ?? this.id, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RetiredIdsCompanion(')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncMetadata extends Table
    with TableInfo<SyncMetadata, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncMetadata(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (singleton = 1)',
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
    'generation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _erasureEpochMeta = const VerificationMeta(
    'erasureEpoch',
  );
  late final GeneratedColumn<int> erasureEpoch = GeneratedColumn<int>(
    'erasure_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _remoteDisabledMeta = const VerificationMeta(
    'remoteDisabled',
  );
  late final GeneratedColumn<int> remoteDisabled = GeneratedColumn<int>(
    'remote_disabled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _retryAttemptMeta = const VerificationMeta(
    'retryAttempt',
  );
  late final GeneratedColumn<int> retryAttempt = GeneratedColumn<int>(
    'retry_attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _nextAttemptMeta = const VerificationMeta(
    'nextAttempt',
  );
  late final GeneratedColumn<String> nextAttempt = GeneratedColumn<String>(
    'next_attempt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    singleton,
    generation,
    position,
    erasureEpoch,
    remoteDisabled,
    retryAttempt,
    nextAttempt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton')) {
      context.handle(
        _singletonMeta,
        singleton.isAcceptableOrUnknown(data['singleton']!, _singletonMeta),
      );
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('erasure_epoch')) {
      context.handle(
        _erasureEpochMeta,
        erasureEpoch.isAcceptableOrUnknown(
          data['erasure_epoch']!,
          _erasureEpochMeta,
        ),
      );
    }
    if (data.containsKey('remote_disabled')) {
      context.handle(
        _remoteDisabledMeta,
        remoteDisabled.isAcceptableOrUnknown(
          data['remote_disabled']!,
          _remoteDisabledMeta,
        ),
      );
    }
    if (data.containsKey('retry_attempt')) {
      context.handle(
        _retryAttemptMeta,
        retryAttempt.isAcceptableOrUnknown(
          data['retry_attempt']!,
          _retryAttemptMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt')) {
      context.handle(
        _nextAttemptMeta,
        nextAttempt.isAcceptableOrUnknown(
          data['next_attempt']!,
          _nextAttemptMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      erasureEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}erasure_epoch'],
      )!,
      remoteDisabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_disabled'],
      )!,
      retryAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_attempt'],
      )!,
      nextAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_attempt'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  SyncMetadata createAlias(String alias) {
    return SyncMetadata(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final int singleton;
  final String? generation;
  final int position;
  final int erasureEpoch;
  final int remoteDisabled;
  final int retryAttempt;
  final String? nextAttempt;
  final String? lastError;
  const SyncMetadataData({
    required this.singleton,
    this.generation,
    required this.position,
    required this.erasureEpoch,
    required this.remoteDisabled,
    required this.retryAttempt,
    this.nextAttempt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    if (!nullToAbsent || generation != null) {
      map['generation'] = Variable<String>(generation);
    }
    map['position'] = Variable<int>(position);
    map['erasure_epoch'] = Variable<int>(erasureEpoch);
    map['remote_disabled'] = Variable<int>(remoteDisabled);
    map['retry_attempt'] = Variable<int>(retryAttempt);
    if (!nullToAbsent || nextAttempt != null) {
      map['next_attempt'] = Variable<String>(nextAttempt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      singleton: Value(singleton),
      generation: generation == null && nullToAbsent
          ? const Value.absent()
          : Value(generation),
      position: Value(position),
      erasureEpoch: Value(erasureEpoch),
      remoteDisabled: Value(remoteDisabled),
      retryAttempt: Value(retryAttempt),
      nextAttempt: nextAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttempt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      singleton: serializer.fromJson<int>(json['singleton']),
      generation: serializer.fromJson<String?>(json['generation']),
      position: serializer.fromJson<int>(json['position']),
      erasureEpoch: serializer.fromJson<int>(json['erasure_epoch']),
      remoteDisabled: serializer.fromJson<int>(json['remote_disabled']),
      retryAttempt: serializer.fromJson<int>(json['retry_attempt']),
      nextAttempt: serializer.fromJson<String?>(json['next_attempt']),
      lastError: serializer.fromJson<String?>(json['last_error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'generation': serializer.toJson<String?>(generation),
      'position': serializer.toJson<int>(position),
      'erasure_epoch': serializer.toJson<int>(erasureEpoch),
      'remote_disabled': serializer.toJson<int>(remoteDisabled),
      'retry_attempt': serializer.toJson<int>(retryAttempt),
      'next_attempt': serializer.toJson<String?>(nextAttempt),
      'last_error': serializer.toJson<String?>(lastError),
    };
  }

  SyncMetadataData copyWith({
    int? singleton,
    Value<String?> generation = const Value.absent(),
    int? position,
    int? erasureEpoch,
    int? remoteDisabled,
    int? retryAttempt,
    Value<String?> nextAttempt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncMetadataData(
    singleton: singleton ?? this.singleton,
    generation: generation.present ? generation.value : this.generation,
    position: position ?? this.position,
    erasureEpoch: erasureEpoch ?? this.erasureEpoch,
    remoteDisabled: remoteDisabled ?? this.remoteDisabled,
    retryAttempt: retryAttempt ?? this.retryAttempt,
    nextAttempt: nextAttempt.present ? nextAttempt.value : this.nextAttempt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      position: data.position.present ? data.position.value : this.position,
      erasureEpoch: data.erasureEpoch.present
          ? data.erasureEpoch.value
          : this.erasureEpoch,
      remoteDisabled: data.remoteDisabled.present
          ? data.remoteDisabled.value
          : this.remoteDisabled,
      retryAttempt: data.retryAttempt.present
          ? data.retryAttempt.value
          : this.retryAttempt,
      nextAttempt: data.nextAttempt.present
          ? data.nextAttempt.value
          : this.nextAttempt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('singleton: $singleton, ')
          ..write('generation: $generation, ')
          ..write('position: $position, ')
          ..write('erasureEpoch: $erasureEpoch, ')
          ..write('remoteDisabled: $remoteDisabled, ')
          ..write('retryAttempt: $retryAttempt, ')
          ..write('nextAttempt: $nextAttempt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    singleton,
    generation,
    position,
    erasureEpoch,
    remoteDisabled,
    retryAttempt,
    nextAttempt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.singleton == this.singleton &&
          other.generation == this.generation &&
          other.position == this.position &&
          other.erasureEpoch == this.erasureEpoch &&
          other.remoteDisabled == this.remoteDisabled &&
          other.retryAttempt == this.retryAttempt &&
          other.nextAttempt == this.nextAttempt &&
          other.lastError == this.lastError);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<int> singleton;
  final Value<String?> generation;
  final Value<int> position;
  final Value<int> erasureEpoch;
  final Value<int> remoteDisabled;
  final Value<int> retryAttempt;
  final Value<String?> nextAttempt;
  final Value<String?> lastError;
  const SyncMetadataCompanion({
    this.singleton = const Value.absent(),
    this.generation = const Value.absent(),
    this.position = const Value.absent(),
    this.erasureEpoch = const Value.absent(),
    this.remoteDisabled = const Value.absent(),
    this.retryAttempt = const Value.absent(),
    this.nextAttempt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    this.singleton = const Value.absent(),
    this.generation = const Value.absent(),
    this.position = const Value.absent(),
    this.erasureEpoch = const Value.absent(),
    this.remoteDisabled = const Value.absent(),
    this.retryAttempt = const Value.absent(),
    this.nextAttempt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  static Insertable<SyncMetadataData> custom({
    Expression<int>? singleton,
    Expression<String>? generation,
    Expression<int>? position,
    Expression<int>? erasureEpoch,
    Expression<int>? remoteDisabled,
    Expression<int>? retryAttempt,
    Expression<String>? nextAttempt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (generation != null) 'generation': generation,
      if (position != null) 'position': position,
      if (erasureEpoch != null) 'erasure_epoch': erasureEpoch,
      if (remoteDisabled != null) 'remote_disabled': remoteDisabled,
      if (retryAttempt != null) 'retry_attempt': retryAttempt,
      if (nextAttempt != null) 'next_attempt': nextAttempt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<int>? singleton,
    Value<String?>? generation,
    Value<int>? position,
    Value<int>? erasureEpoch,
    Value<int>? remoteDisabled,
    Value<int>? retryAttempt,
    Value<String?>? nextAttempt,
    Value<String?>? lastError,
  }) {
    return SyncMetadataCompanion(
      singleton: singleton ?? this.singleton,
      generation: generation ?? this.generation,
      position: position ?? this.position,
      erasureEpoch: erasureEpoch ?? this.erasureEpoch,
      remoteDisabled: remoteDisabled ?? this.remoteDisabled,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      nextAttempt: nextAttempt ?? this.nextAttempt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (erasureEpoch.present) {
      map['erasure_epoch'] = Variable<int>(erasureEpoch.value);
    }
    if (remoteDisabled.present) {
      map['remote_disabled'] = Variable<int>(remoteDisabled.value);
    }
    if (retryAttempt.present) {
      map['retry_attempt'] = Variable<int>(retryAttempt.value);
    }
    if (nextAttempt.present) {
      map['next_attempt'] = Variable<String>(nextAttempt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('singleton: $singleton, ')
          ..write('generation: $generation, ')
          ..write('position: $position, ')
          ..write('erasureEpoch: $erasureEpoch, ')
          ..write('remoteDisabled: $remoteDisabled, ')
          ..write('retryAttempt: $retryAttempt, ')
          ..write('nextAttempt: $nextAttempt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class BootstrapStage extends Table
    with TableInfo<BootstrapStage, BootstrapStageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BootstrapStage(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (singleton = 1)',
  );
  static const VerificationMeta _manifestMeta = const VerificationMeta(
    'manifest',
  );
  late final GeneratedColumn<String> manifest = GeneratedColumn<String>(
    'manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [singleton, manifest];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bootstrap_stage';
  @override
  VerificationContext validateIntegrity(
    Insertable<BootstrapStageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton')) {
      context.handle(
        _singletonMeta,
        singleton.isAcceptableOrUnknown(data['singleton']!, _singletonMeta),
      );
    }
    if (data.containsKey('manifest')) {
      context.handle(
        _manifestMeta,
        manifest.isAcceptableOrUnknown(data['manifest']!, _manifestMeta),
      );
    } else if (isInserting) {
      context.missing(_manifestMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  BootstrapStageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BootstrapStageData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      manifest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest'],
      )!,
    );
  }

  @override
  BootstrapStage createAlias(String alias) {
    return BootstrapStage(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class BootstrapStageData extends DataClass
    implements Insertable<BootstrapStageData> {
  final int singleton;
  final String manifest;
  const BootstrapStageData({required this.singleton, required this.manifest});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['manifest'] = Variable<String>(manifest);
    return map;
  }

  BootstrapStageCompanion toCompanion(bool nullToAbsent) {
    return BootstrapStageCompanion(
      singleton: Value(singleton),
      manifest: Value(manifest),
    );
  }

  factory BootstrapStageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BootstrapStageData(
      singleton: serializer.fromJson<int>(json['singleton']),
      manifest: serializer.fromJson<String>(json['manifest']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'manifest': serializer.toJson<String>(manifest),
    };
  }

  BootstrapStageData copyWith({int? singleton, String? manifest}) =>
      BootstrapStageData(
        singleton: singleton ?? this.singleton,
        manifest: manifest ?? this.manifest,
      );
  BootstrapStageData copyWithCompanion(BootstrapStageCompanion data) {
    return BootstrapStageData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      manifest: data.manifest.present ? data.manifest.value : this.manifest,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapStageData(')
          ..write('singleton: $singleton, ')
          ..write('manifest: $manifest')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singleton, manifest);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BootstrapStageData &&
          other.singleton == this.singleton &&
          other.manifest == this.manifest);
}

class BootstrapStageCompanion extends UpdateCompanion<BootstrapStageData> {
  final Value<int> singleton;
  final Value<String> manifest;
  const BootstrapStageCompanion({
    this.singleton = const Value.absent(),
    this.manifest = const Value.absent(),
  });
  BootstrapStageCompanion.insert({
    this.singleton = const Value.absent(),
    required String manifest,
  }) : manifest = Value(manifest);
  static Insertable<BootstrapStageData> custom({
    Expression<int>? singleton,
    Expression<String>? manifest,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (manifest != null) 'manifest': manifest,
    });
  }

  BootstrapStageCompanion copyWith({
    Value<int>? singleton,
    Value<String>? manifest,
  }) {
    return BootstrapStageCompanion(
      singleton: singleton ?? this.singleton,
      manifest: manifest ?? this.manifest,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (manifest.present) {
      map['manifest'] = Variable<String>(manifest.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapStageCompanion(')
          ..write('singleton: $singleton, ')
          ..write('manifest: $manifest')
          ..write(')'))
        .toString();
  }
}

class BootstrapPages extends Table
    with TableInfo<BootstrapPages, BootstrapPage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BootstrapPages(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [pageIndex, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bootstrap_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<BootstrapPage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pageIndex};
  @override
  BootstrapPage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BootstrapPage(
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  BootstrapPages createAlias(String alias) {
    return BootstrapPages(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class BootstrapPage extends DataClass implements Insertable<BootstrapPage> {
  final int pageIndex;
  final String body;
  const BootstrapPage({required this.pageIndex, required this.body});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['page_index'] = Variable<int>(pageIndex);
    map['body'] = Variable<String>(body);
    return map;
  }

  BootstrapPagesCompanion toCompanion(bool nullToAbsent) {
    return BootstrapPagesCompanion(
      pageIndex: Value(pageIndex),
      body: Value(body),
    );
  }

  factory BootstrapPage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BootstrapPage(
      pageIndex: serializer.fromJson<int>(json['page_index']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'page_index': serializer.toJson<int>(pageIndex),
      'body': serializer.toJson<String>(body),
    };
  }

  BootstrapPage copyWith({int? pageIndex, String? body}) => BootstrapPage(
    pageIndex: pageIndex ?? this.pageIndex,
    body: body ?? this.body,
  );
  BootstrapPage copyWithCompanion(BootstrapPagesCompanion data) {
    return BootstrapPage(
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapPage(')
          ..write('pageIndex: $pageIndex, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pageIndex, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BootstrapPage &&
          other.pageIndex == this.pageIndex &&
          other.body == this.body);
}

class BootstrapPagesCompanion extends UpdateCompanion<BootstrapPage> {
  final Value<int> pageIndex;
  final Value<String> body;
  const BootstrapPagesCompanion({
    this.pageIndex = const Value.absent(),
    this.body = const Value.absent(),
  });
  BootstrapPagesCompanion.insert({
    this.pageIndex = const Value.absent(),
    required String body,
  }) : body = Value(body);
  static Insertable<BootstrapPage> custom({
    Expression<int>? pageIndex,
    Expression<String>? body,
  }) {
    return RawValuesInsertable({
      if (pageIndex != null) 'page_index': pageIndex,
      if (body != null) 'body': body,
    });
  }

  BootstrapPagesCompanion copyWith({
    Value<int>? pageIndex,
    Value<String>? body,
  }) {
    return BootstrapPagesCompanion(
      pageIndex: pageIndex ?? this.pageIndex,
      body: body ?? this.body,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapPagesCompanion(')
          ..write('pageIndex: $pageIndex, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }
}

class RecoveryState extends Table
    with TableInfo<RecoveryState, RecoveryStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RecoveryState(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (singleton = 1)',
  );
  static const VerificationMeta _requiredMeta = const VerificationMeta(
    'required',
  );
  late final GeneratedColumn<int> required = GeneratedColumn<int>(
    'required',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (required IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _currentContextMeta = const VerificationMeta(
    'currentContext',
  );
  late final GeneratedColumn<String> currentContext = GeneratedColumn<String>(
    'current_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _highWaterMeta = const VerificationMeta(
    'highWater',
  );
  late final GeneratedColumn<int> highWater = GeneratedColumn<int>(
    'high_water',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (high_water >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    singleton,
    required,
    currentContext,
    highWater,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recovery_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecoveryStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton')) {
      context.handle(
        _singletonMeta,
        singleton.isAcceptableOrUnknown(data['singleton']!, _singletonMeta),
      );
    }
    if (data.containsKey('required')) {
      context.handle(
        _requiredMeta,
        required.isAcceptableOrUnknown(data['required']!, _requiredMeta),
      );
    }
    if (data.containsKey('current_context')) {
      context.handle(
        _currentContextMeta,
        currentContext.isAcceptableOrUnknown(
          data['current_context']!,
          _currentContextMeta,
        ),
      );
    }
    if (data.containsKey('high_water')) {
      context.handle(
        _highWaterMeta,
        highWater.isAcceptableOrUnknown(data['high_water']!, _highWaterMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  RecoveryStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecoveryStateData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      required: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required'],
      )!,
      currentContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_context'],
      ),
      highWater: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}high_water'],
      )!,
    );
  }

  @override
  RecoveryState createAlias(String alias) {
    return RecoveryState(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class RecoveryStateData extends DataClass
    implements Insertable<RecoveryStateData> {
  final int singleton;
  final int required;
  final String? currentContext;
  final int highWater;
  const RecoveryStateData({
    required this.singleton,
    required this.required,
    this.currentContext,
    required this.highWater,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['required'] = Variable<int>(required);
    if (!nullToAbsent || currentContext != null) {
      map['current_context'] = Variable<String>(currentContext);
    }
    map['high_water'] = Variable<int>(highWater);
    return map;
  }

  RecoveryStateCompanion toCompanion(bool nullToAbsent) {
    return RecoveryStateCompanion(
      singleton: Value(singleton),
      required: Value(required),
      currentContext: currentContext == null && nullToAbsent
          ? const Value.absent()
          : Value(currentContext),
      highWater: Value(highWater),
    );
  }

  factory RecoveryStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecoveryStateData(
      singleton: serializer.fromJson<int>(json['singleton']),
      required: serializer.fromJson<int>(json['required']),
      currentContext: serializer.fromJson<String?>(json['current_context']),
      highWater: serializer.fromJson<int>(json['high_water']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'required': serializer.toJson<int>(required),
      'current_context': serializer.toJson<String?>(currentContext),
      'high_water': serializer.toJson<int>(highWater),
    };
  }

  RecoveryStateData copyWith({
    int? singleton,
    int? required,
    Value<String?> currentContext = const Value.absent(),
    int? highWater,
  }) => RecoveryStateData(
    singleton: singleton ?? this.singleton,
    required: required ?? this.required,
    currentContext: currentContext.present
        ? currentContext.value
        : this.currentContext,
    highWater: highWater ?? this.highWater,
  );
  RecoveryStateData copyWithCompanion(RecoveryStateCompanion data) {
    return RecoveryStateData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      required: data.required.present ? data.required.value : this.required,
      currentContext: data.currentContext.present
          ? data.currentContext.value
          : this.currentContext,
      highWater: data.highWater.present ? data.highWater.value : this.highWater,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecoveryStateData(')
          ..write('singleton: $singleton, ')
          ..write('required: $required, ')
          ..write('currentContext: $currentContext, ')
          ..write('highWater: $highWater')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(singleton, required, currentContext, highWater);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecoveryStateData &&
          other.singleton == this.singleton &&
          other.required == this.required &&
          other.currentContext == this.currentContext &&
          other.highWater == this.highWater);
}

class RecoveryStateCompanion extends UpdateCompanion<RecoveryStateData> {
  final Value<int> singleton;
  final Value<int> required;
  final Value<String?> currentContext;
  final Value<int> highWater;
  const RecoveryStateCompanion({
    this.singleton = const Value.absent(),
    this.required = const Value.absent(),
    this.currentContext = const Value.absent(),
    this.highWater = const Value.absent(),
  });
  RecoveryStateCompanion.insert({
    this.singleton = const Value.absent(),
    this.required = const Value.absent(),
    this.currentContext = const Value.absent(),
    this.highWater = const Value.absent(),
  });
  static Insertable<RecoveryStateData> custom({
    Expression<int>? singleton,
    Expression<int>? required,
    Expression<String>? currentContext,
    Expression<int>? highWater,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (required != null) 'required': required,
      if (currentContext != null) 'current_context': currentContext,
      if (highWater != null) 'high_water': highWater,
    });
  }

  RecoveryStateCompanion copyWith({
    Value<int>? singleton,
    Value<int>? required,
    Value<String?>? currentContext,
    Value<int>? highWater,
  }) {
    return RecoveryStateCompanion(
      singleton: singleton ?? this.singleton,
      required: required ?? this.required,
      currentContext: currentContext ?? this.currentContext,
      highWater: highWater ?? this.highWater,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (required.present) {
      map['required'] = Variable<int>(required.value);
    }
    if (currentContext.present) {
      map['current_context'] = Variable<String>(currentContext.value);
    }
    if (highWater.present) {
      map['high_water'] = Variable<int>(highWater.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecoveryStateCompanion(')
          ..write('singleton: $singleton, ')
          ..write('required: $required, ')
          ..write('currentContext: $currentContext, ')
          ..write('highWater: $highWater')
          ..write(')'))
        .toString();
  }
}

class HistoricalReceipts extends Table
    with TableInfo<HistoricalReceipts, HistoricalReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HistoricalReceipts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _evidenceMeta = const VerificationMeta(
    'evidence',
  );
  late final GeneratedColumn<String> evidence = GeneratedColumn<String>(
    'evidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [mutationId, evidence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historical_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoricalReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('evidence')) {
      context.handle(
        _evidenceMeta,
        evidence.isAcceptableOrUnknown(data['evidence']!, _evidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_evidenceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  HistoricalReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoricalReceipt(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      evidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence'],
      )!,
    );
  }

  @override
  HistoricalReceipts createAlias(String alias) {
    return HistoricalReceipts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class HistoricalReceipt extends DataClass
    implements Insertable<HistoricalReceipt> {
  final String mutationId;
  final String evidence;
  const HistoricalReceipt({required this.mutationId, required this.evidence});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['evidence'] = Variable<String>(evidence);
    return map;
  }

  HistoricalReceiptsCompanion toCompanion(bool nullToAbsent) {
    return HistoricalReceiptsCompanion(
      mutationId: Value(mutationId),
      evidence: Value(evidence),
    );
  }

  factory HistoricalReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoricalReceipt(
      mutationId: serializer.fromJson<String>(json['mutation_id']),
      evidence: serializer.fromJson<String>(json['evidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutation_id': serializer.toJson<String>(mutationId),
      'evidence': serializer.toJson<String>(evidence),
    };
  }

  HistoricalReceipt copyWith({String? mutationId, String? evidence}) =>
      HistoricalReceipt(
        mutationId: mutationId ?? this.mutationId,
        evidence: evidence ?? this.evidence,
      );
  HistoricalReceipt copyWithCompanion(HistoricalReceiptsCompanion data) {
    return HistoricalReceipt(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      evidence: data.evidence.present ? data.evidence.value : this.evidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoricalReceipt(')
          ..write('mutationId: $mutationId, ')
          ..write('evidence: $evidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mutationId, evidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoricalReceipt &&
          other.mutationId == this.mutationId &&
          other.evidence == this.evidence);
}

class HistoricalReceiptsCompanion extends UpdateCompanion<HistoricalReceipt> {
  final Value<String> mutationId;
  final Value<String> evidence;
  final Value<int> rowid;
  const HistoricalReceiptsCompanion({
    this.mutationId = const Value.absent(),
    this.evidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoricalReceiptsCompanion.insert({
    required String mutationId,
    required String evidence,
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       evidence = Value(evidence);
  static Insertable<HistoricalReceipt> custom({
    Expression<String>? mutationId,
    Expression<String>? evidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (evidence != null) 'evidence': evidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoricalReceiptsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? evidence,
    Value<int>? rowid,
  }) {
    return HistoricalReceiptsCompanion(
      mutationId: mutationId ?? this.mutationId,
      evidence: evidence ?? this.evidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (evidence.present) {
      map['evidence'] = Variable<String>(evidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoricalReceiptsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('evidence: $evidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TrainingDatabase extends GeneratedDatabase {
  _$TrainingDatabase(QueryExecutor e) : super(e);
  $TrainingDatabaseManager get managers => $TrainingDatabaseManager(this);
  late final LocalIdentity localIdentity = LocalIdentity(this);
  late final Sessions sessions = Sessions(this);
  late final Exercises exercises = Exercises(this);
  late final Index exercisesBySession = Index(
    'exercises_by_session',
    'CREATE INDEX exercises_by_session ON exercises (session_id, ordinal)',
  );
  late final WorkoutSets workoutSets = WorkoutSets(this);
  late final Index setsByExercise = Index(
    'sets_by_exercise',
    'CREATE INDEX sets_by_exercise ON workout_sets (exercise_id, ordinal)',
  );
  late final LocalObservations localObservations = LocalObservations(this);
  late final Outbox outbox = Outbox(this);
  late final Shadows shadows = Shadows(this);
  late final Drafts drafts = Drafts(this);
  late final RestTimers restTimers = RestTimers(this);
  late final RetiredIds retiredIds = RetiredIds(this);
  late final SyncMetadata syncMetadata = SyncMetadata(this);
  late final BootstrapStage bootstrapStage = BootstrapStage(this);
  late final BootstrapPages bootstrapPages = BootstrapPages(this);
  late final RecoveryState recoveryState = RecoveryState(this);
  late final HistoricalReceipts historicalReceipts = HistoricalReceipts(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localIdentity,
    sessions,
    exercises,
    exercisesBySession,
    workoutSets,
    setsByExercise,
    localObservations,
    outbox,
    shadows,
    drafts,
    restTimers,
    retiredIds,
    syncMetadata,
    bootstrapStage,
    bootstrapPages,
    recoveryState,
    historicalReceipts,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('exercises', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'exercises',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_observations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('drafts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rest_timers', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $LocalIdentityCreateCompanionBuilder = LocalIdentityCompanion Function({
  Value<int> singleton,
  required String ownerId,
  required String installationId,
  Value<int> locked,
  Value<String?> cursor,
});
typedef $LocalIdentityUpdateCompanionBuilder = LocalIdentityCompanion Function({
  Value<int> singleton,
  Value<String> ownerId,
  Value<String> installationId,
  Value<int> locked,
  Value<String?> cursor,
});

class $LocalIdentityFilterComposer
    extends Composer<_$TrainingDatabase, LocalIdentity> {
  $LocalIdentityFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installationId => $composableBuilder(
    column: $table.installationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $LocalIdentityOrderingComposer
    extends Composer<_$TrainingDatabase, LocalIdentity> {
  $LocalIdentityOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installationId => $composableBuilder(
    column: $table.installationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $LocalIdentityAnnotationComposer
    extends Composer<_$TrainingDatabase, LocalIdentity> {
  $LocalIdentityAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get installationId => $composableBuilder(
    column: $table.installationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $LocalIdentityTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          LocalIdentity,
          LocalIdentityData,
          $LocalIdentityFilterComposer,
          $LocalIdentityOrderingComposer,
          $LocalIdentityAnnotationComposer,
          $LocalIdentityCreateCompanionBuilder,
          $LocalIdentityUpdateCompanionBuilder,
          (
            LocalIdentityData,
            BaseReferences<
              _$TrainingDatabase,
              LocalIdentity,
              LocalIdentityData
            >,
          ),
          LocalIdentityData,
          PrefetchHooks Function()
        > {
  $LocalIdentityTableManager(_$TrainingDatabase db, LocalIdentity table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LocalIdentityFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LocalIdentityOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LocalIdentityAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> installationId = const Value.absent(),
                Value<int> locked = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
              }) => LocalIdentityCompanion(
                singleton: singleton,
                ownerId: ownerId,
                installationId: installationId,
                locked: locked,
                cursor: cursor,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                required String ownerId,
                required String installationId,
                Value<int> locked = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
              }) => LocalIdentityCompanion.insert(
                singleton: singleton,
                ownerId: ownerId,
                installationId: installationId,
                locked: locked,
                cursor: cursor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<LocalIdentity, LocalIdentityData>(table),
                  BaseReferences<
                    _$TrainingDatabase,
                    LocalIdentity,
                    LocalIdentityData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $LocalIdentityProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      LocalIdentity,
      LocalIdentityData,
      $LocalIdentityFilterComposer,
      $LocalIdentityOrderingComposer,
      $LocalIdentityAnnotationComposer,
      $LocalIdentityCreateCompanionBuilder,
      $LocalIdentityUpdateCompanionBuilder,
      (
        LocalIdentityData,
        BaseReferences<_$TrainingDatabase, LocalIdentity, LocalIdentityData>,
      ),
      LocalIdentityData,
      PrefetchHooks Function()
    >;
typedef $SessionsCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String metadata,
  required int localSeq,
  Value<int> hasConflict,
  Value<int?> branchBase,
  Value<int> rowid,
});
typedef $SessionsUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> metadata,
  Value<int> localSeq,
  Value<int> hasConflict,
  Value<int?> branchBase,
  Value<int> rowid,
});

final class $SessionsReferences
    extends BaseReferences<_$TrainingDatabase, Sessions, Session> {
  $SessionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Exercises, List<Exercise>> _exercisesRefsTable(
    _$TrainingDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.exercises,
    aliasName: 'sessions__id__exercises__session_id',
  );

  $ExercisesProcessedTableManager get exercisesRefs {
    final manager = $ExercisesTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exercisesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<LocalObservations, List<LocalObservation>>
  _localObservationsRefsTable(_$TrainingDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localObservations,
        aliasName: 'sessions__id__local_observations__session_id',
      );

  $LocalObservationsProcessedTableManager get localObservationsRefs {
    final manager = $LocalObservationsTableManager(
      $_db,
      $_db.localObservations,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localObservationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<RestTimers, List<RestTimer>> _restTimersRefsTable(
    _$TrainingDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.restTimers,
    aliasName: 'sessions__id__rest_timers__session_id',
  );

  $RestTimersProcessedTableManager get restTimersRefs {
    final manager = $RestTimersTableManager(
      $_db,
      $_db.restTimers,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_restTimersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $SessionsFilterComposer extends Composer<_$TrainingDatabase, Sessions> {
  $SessionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchBase => $composableBuilder(
    column: $table.branchBase,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> exercisesRefs(
    Expression<bool> Function($ExercisesFilterComposer f) f,
  ) {
    final $ExercisesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ExercisesFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localObservationsRefs(
    Expression<bool> Function($LocalObservationsFilterComposer f) f,
  ) {
    final $LocalObservationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localObservations,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $LocalObservationsFilterComposer(
            $db: $db,
            $table: $db.localObservations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> restTimersRefs(
    Expression<bool> Function($RestTimersFilterComposer f) f,
  ) {
    final $RestTimersFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.restTimers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $RestTimersFilterComposer(
            $db: $db,
            $table: $db.restTimers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SessionsOrderingComposer extends Composer<_$TrainingDatabase, Sessions> {
  $SessionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchBase => $composableBuilder(
    column: $table.branchBase,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SessionsAnnotationComposer
    extends Composer<_$TrainingDatabase, Sessions> {
  $SessionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<int> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => column,
  );

  GeneratedColumn<int> get branchBase => $composableBuilder(
    column: $table.branchBase,
    builder: (column) => column,
  );

  Expression<T> exercisesRefs<T extends Object>(
    Expression<T> Function($ExercisesAnnotationComposer a) f,
  ) {
    final $ExercisesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ExercisesAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localObservationsRefs<T extends Object>(
    Expression<T> Function($LocalObservationsAnnotationComposer a) f,
  ) {
    final $LocalObservationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localObservations,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $LocalObservationsAnnotationComposer(
            $db: $db,
            $table: $db.localObservations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> restTimersRefs<T extends Object>(
    Expression<T> Function($RestTimersAnnotationComposer a) f,
  ) {
    final $RestTimersAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.restTimers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $RestTimersAnnotationComposer(
            $db: $db,
            $table: $db.restTimers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SessionsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          Sessions,
          Session,
          $SessionsFilterComposer,
          $SessionsOrderingComposer,
          $SessionsAnnotationComposer,
          $SessionsCreateCompanionBuilder,
          $SessionsUpdateCompanionBuilder,
          (Session, $SessionsReferences),
          Session,
          PrefetchHooks Function({
            bool exercisesRefs,
            bool localObservationsRefs,
            bool restTimersRefs,
          })
        > {
  $SessionsTableManager(_$TrainingDatabase db, Sessions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SessionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SessionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SessionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<int> localSeq = const Value.absent(),
                Value<int> hasConflict = const Value.absent(),
                Value<int?> branchBase = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                metadata: metadata,
                localSeq: localSeq,
                hasConflict: hasConflict,
                branchBase: branchBase,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String metadata,
                required int localSeq,
                Value<int> hasConflict = const Value.absent(),
                Value<int?> branchBase = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                metadata: metadata,
                localSeq: localSeq,
                hasConflict: hasConflict,
                branchBase: branchBase,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Sessions, Session>(table),
                  $SessionsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                exercisesRefs = false,
                localObservationsRefs = false,
                restTimersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (exercisesRefs) db.exercises,
                    if (localObservationsRefs) db.localObservations,
                    if (restTimersRefs) db.restTimers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (exercisesRefs)
                        await $_getPrefetchedData<Session, Sessions, Exercise>(
                          currentTable: table,
                          referencedTable: $SessionsReferences
                              ._exercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $SessionsReferences(db, table, p0).exercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localObservationsRefs)
                        await $_getPrefetchedData<
                          Session,
                          Sessions,
                          LocalObservation
                        >(
                          currentTable: table,
                          referencedTable: $SessionsReferences
                              ._localObservationsRefsTable(db),
                          managerFromTypedResult: (p0) => $SessionsReferences(
                            db,
                            table,
                            p0,
                          ).localObservationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (restTimersRefs)
                        await $_getPrefetchedData<Session, Sessions, RestTimer>(
                          currentTable: table,
                          referencedTable: $SessionsReferences
                              ._restTimersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $SessionsReferences(db, table, p0).restTimersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $SessionsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      Sessions,
      Session,
      $SessionsFilterComposer,
      $SessionsOrderingComposer,
      $SessionsAnnotationComposer,
      $SessionsCreateCompanionBuilder,
      $SessionsUpdateCompanionBuilder,
      (Session, $SessionsReferences),
      Session,
      PrefetchHooks Function({
        bool exercisesRefs,
        bool localObservationsRefs,
        bool restTimersRefs,
      })
    >;
typedef $ExercisesCreateCompanionBuilder = ExercisesCompanion Function({
  required String id,
  required String sessionId,
  required int ordinal,
  required String definition,
  Value<int> rowid,
});
typedef $ExercisesUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<int> ordinal,
  Value<String> definition,
  Value<int> rowid,
});

final class $ExercisesReferences
    extends BaseReferences<_$TrainingDatabase, Exercises, Exercise> {
  $ExercisesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Sessions _sessionIdTable(_$TrainingDatabase db) =>
      db.sessions.createAlias('exercises__session_id__sessions__id');

  $SessionsProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $SessionsTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<WorkoutSets, List<WorkoutSet>>
  _workoutSetsRefsTable(_$TrainingDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: 'exercises__id__workout_sets__exercise_id',
  );

  $WorkoutSetsProcessedTableManager get workoutSetsRefs {
    final manager = $WorkoutSetsTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ExercisesFilterComposer extends Composer<_$TrainingDatabase, Exercises> {
  $ExercisesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnFilters(column),
  );

  $SessionsFilterComposer get sessionId {
    final $SessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($WorkoutSetsFilterComposer f) f,
  ) {
    final $WorkoutSetsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $WorkoutSetsFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ExercisesOrderingComposer
    extends Composer<_$TrainingDatabase, Exercises> {
  $ExercisesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  $SessionsOrderingComposer get sessionId {
    final $SessionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ExercisesAnnotationComposer
    extends Composer<_$TrainingDatabase, Exercises> {
  $ExercisesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => column,
  );

  $SessionsAnnotationComposer get sessionId {
    final $SessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($WorkoutSetsAnnotationComposer a) f,
  ) {
    final $WorkoutSetsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $WorkoutSetsAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ExercisesTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          Exercises,
          Exercise,
          $ExercisesFilterComposer,
          $ExercisesOrderingComposer,
          $ExercisesAnnotationComposer,
          $ExercisesCreateCompanionBuilder,
          $ExercisesUpdateCompanionBuilder,
          (Exercise, $ExercisesReferences),
          Exercise,
          PrefetchHooks Function({bool sessionId, bool workoutSetsRefs})
        > {
  $ExercisesTableManager(_$TrainingDatabase db, Exercises table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ExercisesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ExercisesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ExercisesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> definition = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                sessionId: sessionId,
                ordinal: ordinal,
                definition: definition,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int ordinal,
                required String definition,
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                sessionId: sessionId,
                ordinal: ordinal,
                definition: definition,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Exercises, Exercise>(table),
                  $ExercisesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionId = false, workoutSetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSetsRefs) db.workoutSets,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sessionId,
                            referencedTable: $ExercisesReferences
                                ._sessionIdTable(db),
                            referencedColumn: $ExercisesReferences
                                ._sessionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSetsRefs)
                        await $_getPrefetchedData<
                          Exercise,
                          Exercises,
                          WorkoutSet
                        >(
                          currentTable: table,
                          referencedTable: $ExercisesReferences
                              ._workoutSetsRefsTable(db),
                          managerFromTypedResult: (p0) => $ExercisesReferences(
                            db,
                            table,
                            p0,
                          ).workoutSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $ExercisesProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      Exercises,
      Exercise,
      $ExercisesFilterComposer,
      $ExercisesOrderingComposer,
      $ExercisesAnnotationComposer,
      $ExercisesCreateCompanionBuilder,
      $ExercisesUpdateCompanionBuilder,
      (Exercise, $ExercisesReferences),
      Exercise,
      PrefetchHooks Function({bool sessionId, bool workoutSetsRefs})
    >;
typedef $WorkoutSetsCreateCompanionBuilder = WorkoutSetsCompanion Function({
  required String id,
  required String exerciseId,
  required int ordinal,
  required String prescription,
  Value<String?> observation,
  Value<int> rowid,
});
typedef $WorkoutSetsUpdateCompanionBuilder = WorkoutSetsCompanion Function({
  Value<String> id,
  Value<String> exerciseId,
  Value<int> ordinal,
  Value<String> prescription,
  Value<String?> observation,
  Value<int> rowid,
});

final class $WorkoutSetsReferences
    extends BaseReferences<_$TrainingDatabase, WorkoutSets, WorkoutSet> {
  $WorkoutSetsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Exercises _exerciseIdTable(_$TrainingDatabase db) =>
      db.exercises.createAlias('workout_sets__exercise_id__exercises__id');

  $ExercisesProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $ExercisesTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<Drafts, List<Draft>> _draftsRefsTable(
    _$TrainingDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.drafts,
    aliasName: 'workout_sets__id__drafts__set_id',
  );

  $DraftsProcessedTableManager get draftsRefs {
    final manager = $DraftsTableManager(
      $_db,
      $_db.drafts,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_draftsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $WorkoutSetsFilterComposer
    extends Composer<_$TrainingDatabase, WorkoutSets> {
  $WorkoutSetsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescription => $composableBuilder(
    column: $table.prescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => ColumnFilters(column),
  );

  $ExercisesFilterComposer get exerciseId {
    final $ExercisesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ExercisesFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> draftsRefs(
    Expression<bool> Function($DraftsFilterComposer f) f,
  ) {
    final $DraftsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DraftsFilterComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $WorkoutSetsOrderingComposer
    extends Composer<_$TrainingDatabase, WorkoutSets> {
  $WorkoutSetsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescription => $composableBuilder(
    column: $table.prescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => ColumnOrderings(column),
  );

  $ExercisesOrderingComposer get exerciseId {
    final $ExercisesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ExercisesOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $WorkoutSetsAnnotationComposer
    extends Composer<_$TrainingDatabase, WorkoutSets> {
  $WorkoutSetsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get prescription => $composableBuilder(
    column: $table.prescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => column,
  );

  $ExercisesAnnotationComposer get exerciseId {
    final $ExercisesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ExercisesAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> draftsRefs<T extends Object>(
    Expression<T> Function($DraftsAnnotationComposer a) f,
  ) {
    final $DraftsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DraftsAnnotationComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $WorkoutSetsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          WorkoutSets,
          WorkoutSet,
          $WorkoutSetsFilterComposer,
          $WorkoutSetsOrderingComposer,
          $WorkoutSetsAnnotationComposer,
          $WorkoutSetsCreateCompanionBuilder,
          $WorkoutSetsUpdateCompanionBuilder,
          (WorkoutSet, $WorkoutSetsReferences),
          WorkoutSet,
          PrefetchHooks Function({bool exerciseId, bool draftsRefs})
        > {
  $WorkoutSetsTableManager(_$TrainingDatabase db, WorkoutSets table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $WorkoutSetsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $WorkoutSetsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $WorkoutSetsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> prescription = const Value.absent(),
                Value<String?> observation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsCompanion(
                id: id,
                exerciseId: exerciseId,
                ordinal: ordinal,
                prescription: prescription,
                observation: observation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String exerciseId,
                required int ordinal,
                required String prescription,
                Value<String?> observation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                ordinal: ordinal,
                prescription: prescription,
                observation: observation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<WorkoutSets, WorkoutSet>(table),
                  $WorkoutSetsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({exerciseId = false, draftsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (draftsRefs) db.drafts],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $WorkoutSetsReferences
                            ._exerciseIdTable(db),
                        referencedColumn: $WorkoutSetsReferences
                            ._exerciseIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (draftsRefs)
                    await $_getPrefetchedData<WorkoutSet, WorkoutSets, Draft>(
                      currentTable: table,
                      referencedTable: $WorkoutSetsReferences._draftsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $WorkoutSetsReferences(db, table, p0).draftsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $WorkoutSetsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      WorkoutSets,
      WorkoutSet,
      $WorkoutSetsFilterComposer,
      $WorkoutSetsOrderingComposer,
      $WorkoutSetsAnnotationComposer,
      $WorkoutSetsCreateCompanionBuilder,
      $WorkoutSetsUpdateCompanionBuilder,
      (WorkoutSet, $WorkoutSetsReferences),
      WorkoutSet,
      PrefetchHooks Function({bool exerciseId, bool draftsRefs})
    >;
typedef $LocalObservationsCreateCompanionBuilder =
    LocalObservationsCompanion Function({
      required String sessionId,
      required int localSeq,
      required String setId,
      required String payload,
      Value<int> rowid,
    });
typedef $LocalObservationsUpdateCompanionBuilder =
    LocalObservationsCompanion Function({
      Value<String> sessionId,
      Value<int> localSeq,
      Value<String> setId,
      Value<String> payload,
      Value<int> rowid,
    });

final class $LocalObservationsReferences
    extends
        BaseReferences<
          _$TrainingDatabase,
          LocalObservations,
          LocalObservation
        > {
  $LocalObservationsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Sessions _sessionIdTable(_$TrainingDatabase db) =>
      db.sessions.createAlias('local_observations__session_id__sessions__id');

  $SessionsProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $SessionsTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $LocalObservationsFilterComposer
    extends Composer<_$TrainingDatabase, LocalObservations> {
  $LocalObservationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setId => $composableBuilder(
    column: $table.setId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $SessionsFilterComposer get sessionId {
    final $SessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $LocalObservationsOrderingComposer
    extends Composer<_$TrainingDatabase, LocalObservations> {
  $LocalObservationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setId => $composableBuilder(
    column: $table.setId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $SessionsOrderingComposer get sessionId {
    final $SessionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $LocalObservationsAnnotationComposer
    extends Composer<_$TrainingDatabase, LocalObservations> {
  $LocalObservationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get setId =>
      $composableBuilder(column: $table.setId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $SessionsAnnotationComposer get sessionId {
    final $SessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $LocalObservationsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          LocalObservations,
          LocalObservation,
          $LocalObservationsFilterComposer,
          $LocalObservationsOrderingComposer,
          $LocalObservationsAnnotationComposer,
          $LocalObservationsCreateCompanionBuilder,
          $LocalObservationsUpdateCompanionBuilder,
          (LocalObservation, $LocalObservationsReferences),
          LocalObservation,
          PrefetchHooks Function({bool sessionId})
        > {
  $LocalObservationsTableManager(_$TrainingDatabase db, LocalObservations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LocalObservationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LocalObservationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LocalObservationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> localSeq = const Value.absent(),
                Value<String> setId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalObservationsCompanion(
                sessionId: sessionId,
                localSeq: localSeq,
                setId: setId,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int localSeq,
                required String setId,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => LocalObservationsCompanion.insert(
                sessionId: sessionId,
                localSeq: localSeq,
                setId: setId,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<LocalObservations, LocalObservation>(table),
                  $LocalObservationsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $LocalObservationsReferences
                            ._sessionIdTable(db),
                        referencedColumn: $LocalObservationsReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $LocalObservationsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      LocalObservations,
      LocalObservation,
      $LocalObservationsFilterComposer,
      $LocalObservationsOrderingComposer,
      $LocalObservationsAnnotationComposer,
      $LocalObservationsCreateCompanionBuilder,
      $LocalObservationsUpdateCompanionBuilder,
      (LocalObservation, $LocalObservationsReferences),
      LocalObservation,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $OutboxCreateCompanionBuilder = OutboxCompanion Function({
  required String mutationId,
  required String sessionId,
  required int localSeq,
  Value<String?> predecessorId,
  required int originBase,
  required String operation,
  Value<String?> frozenBody,
  Value<int?> acceptedRevision,
  required String state,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<String?> requestDigest,
  Value<int> wireVersion,
  Value<String?> originContext,
  Value<String?> acceptedContext,
  Value<int> rowid,
});
typedef $OutboxUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> mutationId,
  Value<String> sessionId,
  Value<int> localSeq,
  Value<String?> predecessorId,
  Value<int> originBase,
  Value<String> operation,
  Value<String?> frozenBody,
  Value<int?> acceptedRevision,
  Value<String> state,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<String?> requestDigest,
  Value<int> wireVersion,
  Value<String?> originContext,
  Value<String?> acceptedContext,
  Value<int> rowid,
});

class $OutboxFilterComposer extends Composer<_$TrainingDatabase, Outbox> {
  $OutboxFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predecessorId => $composableBuilder(
    column: $table.predecessorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originBase => $composableBuilder(
    column: $table.originBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frozenBody => $composableBuilder(
    column: $table.frozenBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acceptedRevision => $composableBuilder(
    column: $table.acceptedRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestDigest => $composableBuilder(
    column: $table.requestDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wireVersion => $composableBuilder(
    column: $table.wireVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originContext => $composableBuilder(
    column: $table.originContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptedContext => $composableBuilder(
    column: $table.acceptedContext,
    builder: (column) => ColumnFilters(column),
  );
}

class $OutboxOrderingComposer extends Composer<_$TrainingDatabase, Outbox> {
  $OutboxOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predecessorId => $composableBuilder(
    column: $table.predecessorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originBase => $composableBuilder(
    column: $table.originBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frozenBody => $composableBuilder(
    column: $table.frozenBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acceptedRevision => $composableBuilder(
    column: $table.acceptedRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestDigest => $composableBuilder(
    column: $table.requestDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wireVersion => $composableBuilder(
    column: $table.wireVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originContext => $composableBuilder(
    column: $table.originContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptedContext => $composableBuilder(
    column: $table.acceptedContext,
    builder: (column) => ColumnOrderings(column),
  );
}

class $OutboxAnnotationComposer extends Composer<_$TrainingDatabase, Outbox> {
  $OutboxAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get predecessorId => $composableBuilder(
    column: $table.predecessorId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originBase => $composableBuilder(
    column: $table.originBase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get frozenBody => $composableBuilder(
    column: $table.frozenBody,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acceptedRevision => $composableBuilder(
    column: $table.acceptedRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get requestDigest => $composableBuilder(
    column: $table.requestDigest,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wireVersion => $composableBuilder(
    column: $table.wireVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originContext => $composableBuilder(
    column: $table.originContext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acceptedContext => $composableBuilder(
    column: $table.acceptedContext,
    builder: (column) => column,
  );
}

class $OutboxTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          Outbox,
          OutboxData,
          $OutboxFilterComposer,
          $OutboxOrderingComposer,
          $OutboxAnnotationComposer,
          $OutboxCreateCompanionBuilder,
          $OutboxUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$TrainingDatabase, Outbox, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $OutboxTableManager(_$TrainingDatabase db, Outbox table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $OutboxFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $OutboxOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $OutboxAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> localSeq = const Value.absent(),
                Value<String?> predecessorId = const Value.absent(),
                Value<int> originBase = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> frozenBody = const Value.absent(),
                Value<int?> acceptedRevision = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> requestDigest = const Value.absent(),
                Value<int> wireVersion = const Value.absent(),
                Value<String?> originContext = const Value.absent(),
                Value<String?> acceptedContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                mutationId: mutationId,
                sessionId: sessionId,
                localSeq: localSeq,
                predecessorId: predecessorId,
                originBase: originBase,
                operation: operation,
                frozenBody: frozenBody,
                acceptedRevision: acceptedRevision,
                state: state,
                attemptCount: attemptCount,
                lastError: lastError,
                requestDigest: requestDigest,
                wireVersion: wireVersion,
                originContext: originContext,
                acceptedContext: acceptedContext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String sessionId,
                required int localSeq,
                Value<String?> predecessorId = const Value.absent(),
                required int originBase,
                required String operation,
                Value<String?> frozenBody = const Value.absent(),
                Value<int?> acceptedRevision = const Value.absent(),
                required String state,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> requestDigest = const Value.absent(),
                Value<int> wireVersion = const Value.absent(),
                Value<String?> originContext = const Value.absent(),
                Value<String?> acceptedContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                mutationId: mutationId,
                sessionId: sessionId,
                localSeq: localSeq,
                predecessorId: predecessorId,
                originBase: originBase,
                operation: operation,
                frozenBody: frozenBody,
                acceptedRevision: acceptedRevision,
                state: state,
                attemptCount: attemptCount,
                lastError: lastError,
                requestDigest: requestDigest,
                wireVersion: wireVersion,
                originContext: originContext,
                acceptedContext: acceptedContext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Outbox, OutboxData>(table),
                  BaseReferences<_$TrainingDatabase, Outbox, OutboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $OutboxProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      Outbox,
      OutboxData,
      $OutboxFilterComposer,
      $OutboxOrderingComposer,
      $OutboxAnnotationComposer,
      $OutboxCreateCompanionBuilder,
      $OutboxUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$TrainingDatabase, Outbox, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $ShadowsCreateCompanionBuilder = ShadowsCompanion Function({
  required String sessionId,
  required int revision,
  Value<String?> projection,
  Value<String?> recoveryContext,
  Value<int> rowid,
});
typedef $ShadowsUpdateCompanionBuilder = ShadowsCompanion Function({
  Value<String> sessionId,
  Value<int> revision,
  Value<String?> projection,
  Value<String?> recoveryContext,
  Value<int> rowid,
});

class $ShadowsFilterComposer extends Composer<_$TrainingDatabase, Shadows> {
  $ShadowsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projection => $composableBuilder(
    column: $table.projection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recoveryContext => $composableBuilder(
    column: $table.recoveryContext,
    builder: (column) => ColumnFilters(column),
  );
}

class $ShadowsOrderingComposer extends Composer<_$TrainingDatabase, Shadows> {
  $ShadowsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projection => $composableBuilder(
    column: $table.projection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recoveryContext => $composableBuilder(
    column: $table.recoveryContext,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ShadowsAnnotationComposer extends Composer<_$TrainingDatabase, Shadows> {
  $ShadowsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get projection => $composableBuilder(
    column: $table.projection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recoveryContext => $composableBuilder(
    column: $table.recoveryContext,
    builder: (column) => column,
  );
}

class $ShadowsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          Shadows,
          Shadow,
          $ShadowsFilterComposer,
          $ShadowsOrderingComposer,
          $ShadowsAnnotationComposer,
          $ShadowsCreateCompanionBuilder,
          $ShadowsUpdateCompanionBuilder,
          (Shadow, BaseReferences<_$TrainingDatabase, Shadows, Shadow>),
          Shadow,
          PrefetchHooks Function()
        > {
  $ShadowsTableManager(_$TrainingDatabase db, Shadows table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ShadowsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ShadowsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ShadowsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> projection = const Value.absent(),
                Value<String?> recoveryContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShadowsCompanion(
                sessionId: sessionId,
                revision: revision,
                projection: projection,
                recoveryContext: recoveryContext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int revision,
                Value<String?> projection = const Value.absent(),
                Value<String?> recoveryContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShadowsCompanion.insert(
                sessionId: sessionId,
                revision: revision,
                projection: projection,
                recoveryContext: recoveryContext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Shadows, Shadow>(table),
                  BaseReferences<_$TrainingDatabase, Shadows, Shadow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ShadowsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      Shadows,
      Shadow,
      $ShadowsFilterComposer,
      $ShadowsOrderingComposer,
      $ShadowsAnnotationComposer,
      $ShadowsCreateCompanionBuilder,
      $ShadowsUpdateCompanionBuilder,
      (Shadow, BaseReferences<_$TrainingDatabase, Shadows, Shadow>),
      Shadow,
      PrefetchHooks Function()
    >;
typedef $DraftsCreateCompanionBuilder = DraftsCompanion Function({
  required String setId,
  required String valuesJson,
  Value<int> rowid,
});
typedef $DraftsUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> setId,
  Value<String> valuesJson,
  Value<int> rowid,
});

final class $DraftsReferences
    extends BaseReferences<_$TrainingDatabase, Drafts, Draft> {
  $DraftsReferences(super.$_db, super.$_table, super.$_typedResult);

  static WorkoutSets _setIdTable(_$TrainingDatabase db) =>
      db.workoutSets.createAlias('drafts__set_id__workout_sets__id');

  $WorkoutSetsProcessedTableManager get setId {
    final $_column = $_itemColumn<String>('set_id')!;

    final manager = $WorkoutSetsTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $DraftsFilterComposer extends Composer<_$TrainingDatabase, Drafts> {
  $DraftsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => ColumnFilters(column),
  );

  $WorkoutSetsFilterComposer get setId {
    final $WorkoutSetsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $WorkoutSetsFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DraftsOrderingComposer extends Composer<_$TrainingDatabase, Drafts> {
  $DraftsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => ColumnOrderings(column),
  );

  $WorkoutSetsOrderingComposer get setId {
    final $WorkoutSetsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $WorkoutSetsOrderingComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DraftsAnnotationComposer extends Composer<_$TrainingDatabase, Drafts> {
  $DraftsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => column,
  );

  $WorkoutSetsAnnotationComposer get setId {
    final $WorkoutSetsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $WorkoutSetsAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DraftsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          Drafts,
          Draft,
          $DraftsFilterComposer,
          $DraftsOrderingComposer,
          $DraftsAnnotationComposer,
          $DraftsCreateCompanionBuilder,
          $DraftsUpdateCompanionBuilder,
          (Draft, $DraftsReferences),
          Draft,
          PrefetchHooks Function({bool setId})
        > {
  $DraftsTableManager(_$TrainingDatabase db, Drafts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DraftsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DraftsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DraftsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> setId = const Value.absent(),
                Value<String> valuesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                setId: setId,
                valuesJson: valuesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String setId,
                required String valuesJson,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                setId: setId,
                valuesJson: valuesJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Drafts, Draft>(table),
                  $DraftsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.setId,
                        referencedTable: $DraftsReferences._setIdTable(db),
                        referencedColumn: $DraftsReferences._setIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DraftsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      Drafts,
      Draft,
      $DraftsFilterComposer,
      $DraftsOrderingComposer,
      $DraftsAnnotationComposer,
      $DraftsCreateCompanionBuilder,
      $DraftsUpdateCompanionBuilder,
      (Draft, $DraftsReferences),
      Draft,
      PrefetchHooks Function({bool setId})
    >;
typedef $RestTimersCreateCompanionBuilder = RestTimersCompanion Function({
  required String sessionId,
  required String anchor,
  required String deadline,
  Value<int?> monotonicUs,
  Value<String?> continuityId,
  Value<int> uncertain,
  Value<int> rowid,
});
typedef $RestTimersUpdateCompanionBuilder = RestTimersCompanion Function({
  Value<String> sessionId,
  Value<String> anchor,
  Value<String> deadline,
  Value<int?> monotonicUs,
  Value<String?> continuityId,
  Value<int> uncertain,
  Value<int> rowid,
});

final class $RestTimersReferences
    extends BaseReferences<_$TrainingDatabase, RestTimers, RestTimer> {
  $RestTimersReferences(super.$_db, super.$_table, super.$_typedResult);

  static Sessions _sessionIdTable(_$TrainingDatabase db) =>
      db.sessions.createAlias('rest_timers__session_id__sessions__id');

  $SessionsProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $SessionsTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $RestTimersFilterComposer
    extends Composer<_$TrainingDatabase, RestTimers> {
  $RestTimersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monotonicUs => $composableBuilder(
    column: $table.monotonicUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get continuityId => $composableBuilder(
    column: $table.continuityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uncertain => $composableBuilder(
    column: $table.uncertain,
    builder: (column) => ColumnFilters(column),
  );

  $SessionsFilterComposer get sessionId {
    final $SessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RestTimersOrderingComposer
    extends Composer<_$TrainingDatabase, RestTimers> {
  $RestTimersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monotonicUs => $composableBuilder(
    column: $table.monotonicUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get continuityId => $composableBuilder(
    column: $table.continuityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uncertain => $composableBuilder(
    column: $table.uncertain,
    builder: (column) => ColumnOrderings(column),
  );

  $SessionsOrderingComposer get sessionId {
    final $SessionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RestTimersAnnotationComposer
    extends Composer<_$TrainingDatabase, RestTimers> {
  $RestTimersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get anchor =>
      $composableBuilder(column: $table.anchor, builder: (column) => column);

  GeneratedColumn<String> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<int> get monotonicUs => $composableBuilder(
    column: $table.monotonicUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get continuityId => $composableBuilder(
    column: $table.continuityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uncertain =>
      $composableBuilder(column: $table.uncertain, builder: (column) => column);

  $SessionsAnnotationComposer get sessionId {
    final $SessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SessionsAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RestTimersTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          RestTimers,
          RestTimer,
          $RestTimersFilterComposer,
          $RestTimersOrderingComposer,
          $RestTimersAnnotationComposer,
          $RestTimersCreateCompanionBuilder,
          $RestTimersUpdateCompanionBuilder,
          (RestTimer, $RestTimersReferences),
          RestTimer,
          PrefetchHooks Function({bool sessionId})
        > {
  $RestTimersTableManager(_$TrainingDatabase db, RestTimers table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RestTimersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RestTimersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RestTimersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> anchor = const Value.absent(),
                Value<String> deadline = const Value.absent(),
                Value<int?> monotonicUs = const Value.absent(),
                Value<String?> continuityId = const Value.absent(),
                Value<int> uncertain = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestTimersCompanion(
                sessionId: sessionId,
                anchor: anchor,
                deadline: deadline,
                monotonicUs: monotonicUs,
                continuityId: continuityId,
                uncertain: uncertain,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String anchor,
                required String deadline,
                Value<int?> monotonicUs = const Value.absent(),
                Value<String?> continuityId = const Value.absent(),
                Value<int> uncertain = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestTimersCompanion.insert(
                sessionId: sessionId,
                anchor: anchor,
                deadline: deadline,
                monotonicUs: monotonicUs,
                continuityId: continuityId,
                uncertain: uncertain,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<RestTimers, RestTimer>(table),
                  $RestTimersReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $RestTimersReferences._sessionIdTable(
                          db,
                        ),
                        referencedColumn: $RestTimersReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $RestTimersProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      RestTimers,
      RestTimer,
      $RestTimersFilterComposer,
      $RestTimersOrderingComposer,
      $RestTimersAnnotationComposer,
      $RestTimersCreateCompanionBuilder,
      $RestTimersUpdateCompanionBuilder,
      (RestTimer, $RestTimersReferences),
      RestTimer,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $RetiredIdsCreateCompanionBuilder = RetiredIdsCompanion Function({
  required String id,
  Value<int> rowid,
});
typedef $RetiredIdsUpdateCompanionBuilder = RetiredIdsCompanion Function({
  Value<String> id,
  Value<int> rowid,
});

class $RetiredIdsFilterComposer
    extends Composer<_$TrainingDatabase, RetiredIds> {
  $RetiredIdsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $RetiredIdsOrderingComposer
    extends Composer<_$TrainingDatabase, RetiredIds> {
  $RetiredIdsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $RetiredIdsAnnotationComposer
    extends Composer<_$TrainingDatabase, RetiredIds> {
  $RetiredIdsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $RetiredIdsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          RetiredIds,
          RetiredId,
          $RetiredIdsFilterComposer,
          $RetiredIdsOrderingComposer,
          $RetiredIdsAnnotationComposer,
          $RetiredIdsCreateCompanionBuilder,
          $RetiredIdsUpdateCompanionBuilder,
          (
            RetiredId,
            BaseReferences<_$TrainingDatabase, RetiredIds, RetiredId>,
          ),
          RetiredId,
          PrefetchHooks Function()
        > {
  $RetiredIdsTableManager(_$TrainingDatabase db, RetiredIds table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RetiredIdsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RetiredIdsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RetiredIdsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => RetiredIdsCompanion(id: id, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            Value<int> rowid = const Value.absent(),
          }) => RetiredIdsCompanion.insert(id: id, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<RetiredIds, RetiredId>(table),
                  BaseReferences<_$TrainingDatabase, RetiredIds, RetiredId>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $RetiredIdsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      RetiredIds,
      RetiredId,
      $RetiredIdsFilterComposer,
      $RetiredIdsOrderingComposer,
      $RetiredIdsAnnotationComposer,
      $RetiredIdsCreateCompanionBuilder,
      $RetiredIdsUpdateCompanionBuilder,
      (RetiredId, BaseReferences<_$TrainingDatabase, RetiredIds, RetiredId>),
      RetiredId,
      PrefetchHooks Function()
    >;
typedef $SyncMetadataCreateCompanionBuilder = SyncMetadataCompanion Function({
  Value<int> singleton,
  Value<String?> generation,
  Value<int> position,
  Value<int> erasureEpoch,
  Value<int> remoteDisabled,
  Value<int> retryAttempt,
  Value<String?> nextAttempt,
  Value<String?> lastError,
});
typedef $SyncMetadataUpdateCompanionBuilder = SyncMetadataCompanion Function({
  Value<int> singleton,
  Value<String?> generation,
  Value<int> position,
  Value<int> erasureEpoch,
  Value<int> remoteDisabled,
  Value<int> retryAttempt,
  Value<String?> nextAttempt,
  Value<String?> lastError,
});

class $SyncMetadataFilterComposer
    extends Composer<_$TrainingDatabase, SyncMetadata> {
  $SyncMetadataFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get erasureEpoch => $composableBuilder(
    column: $table.erasureEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteDisabled => $composableBuilder(
    column: $table.remoteDisabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryAttempt => $composableBuilder(
    column: $table.retryAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextAttempt => $composableBuilder(
    column: $table.nextAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $SyncMetadataOrderingComposer
    extends Composer<_$TrainingDatabase, SyncMetadata> {
  $SyncMetadataOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get erasureEpoch => $composableBuilder(
    column: $table.erasureEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteDisabled => $composableBuilder(
    column: $table.remoteDisabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryAttempt => $composableBuilder(
    column: $table.retryAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextAttempt => $composableBuilder(
    column: $table.nextAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SyncMetadataAnnotationComposer
    extends Composer<_$TrainingDatabase, SyncMetadata> {
  $SyncMetadataAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get erasureEpoch => $composableBuilder(
    column: $table.erasureEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteDisabled => $composableBuilder(
    column: $table.remoteDisabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryAttempt => $composableBuilder(
    column: $table.retryAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextAttempt => $composableBuilder(
    column: $table.nextAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $SyncMetadataTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          SyncMetadata,
          SyncMetadataData,
          $SyncMetadataFilterComposer,
          $SyncMetadataOrderingComposer,
          $SyncMetadataAnnotationComposer,
          $SyncMetadataCreateCompanionBuilder,
          $SyncMetadataUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$TrainingDatabase, SyncMetadata, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $SyncMetadataTableManager(_$TrainingDatabase db, SyncMetadata table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SyncMetadataFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SyncMetadataOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SyncMetadataAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<String?> generation = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> erasureEpoch = const Value.absent(),
                Value<int> remoteDisabled = const Value.absent(),
                Value<int> retryAttempt = const Value.absent(),
                Value<String?> nextAttempt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncMetadataCompanion(
                singleton: singleton,
                generation: generation,
                position: position,
                erasureEpoch: erasureEpoch,
                remoteDisabled: remoteDisabled,
                retryAttempt: retryAttempt,
                nextAttempt: nextAttempt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<String?> generation = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> erasureEpoch = const Value.absent(),
                Value<int> remoteDisabled = const Value.absent(),
                Value<int> retryAttempt = const Value.absent(),
                Value<String?> nextAttempt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                singleton: singleton,
                generation: generation,
                position: position,
                erasureEpoch: erasureEpoch,
                remoteDisabled: remoteDisabled,
                retryAttempt: retryAttempt,
                nextAttempt: nextAttempt,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncMetadata, SyncMetadataData>(table),
                  BaseReferences<
                    _$TrainingDatabase,
                    SyncMetadata,
                    SyncMetadataData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SyncMetadataProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      SyncMetadata,
      SyncMetadataData,
      $SyncMetadataFilterComposer,
      $SyncMetadataOrderingComposer,
      $SyncMetadataAnnotationComposer,
      $SyncMetadataCreateCompanionBuilder,
      $SyncMetadataUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$TrainingDatabase, SyncMetadata, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;
typedef $BootstrapStageCreateCompanionBuilder =
    BootstrapStageCompanion Function({
      Value<int> singleton,
      required String manifest,
    });
typedef $BootstrapStageUpdateCompanionBuilder =
    BootstrapStageCompanion Function({
      Value<int> singleton,
      Value<String> manifest,
    });

class $BootstrapStageFilterComposer
    extends Composer<_$TrainingDatabase, BootstrapStage> {
  $BootstrapStageFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnFilters(column),
  );
}

class $BootstrapStageOrderingComposer
    extends Composer<_$TrainingDatabase, BootstrapStage> {
  $BootstrapStageOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnOrderings(column),
  );
}

class $BootstrapStageAnnotationComposer
    extends Composer<_$TrainingDatabase, BootstrapStage> {
  $BootstrapStageAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<String> get manifest =>
      $composableBuilder(column: $table.manifest, builder: (column) => column);
}

class $BootstrapStageTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          BootstrapStage,
          BootstrapStageData,
          $BootstrapStageFilterComposer,
          $BootstrapStageOrderingComposer,
          $BootstrapStageAnnotationComposer,
          $BootstrapStageCreateCompanionBuilder,
          $BootstrapStageUpdateCompanionBuilder,
          (
            BootstrapStageData,
            BaseReferences<
              _$TrainingDatabase,
              BootstrapStage,
              BootstrapStageData
            >,
          ),
          BootstrapStageData,
          PrefetchHooks Function()
        > {
  $BootstrapStageTableManager(_$TrainingDatabase db, BootstrapStage table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BootstrapStageFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BootstrapStageOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BootstrapStageAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<String> manifest = const Value.absent(),
              }) => BootstrapStageCompanion(
                singleton: singleton,
                manifest: manifest,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                required String manifest,
              }) => BootstrapStageCompanion.insert(
                singleton: singleton,
                manifest: manifest,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<BootstrapStage, BootstrapStageData>(table),
                  BaseReferences<
                    _$TrainingDatabase,
                    BootstrapStage,
                    BootstrapStageData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $BootstrapStageProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      BootstrapStage,
      BootstrapStageData,
      $BootstrapStageFilterComposer,
      $BootstrapStageOrderingComposer,
      $BootstrapStageAnnotationComposer,
      $BootstrapStageCreateCompanionBuilder,
      $BootstrapStageUpdateCompanionBuilder,
      (
        BootstrapStageData,
        BaseReferences<_$TrainingDatabase, BootstrapStage, BootstrapStageData>,
      ),
      BootstrapStageData,
      PrefetchHooks Function()
    >;
typedef $BootstrapPagesCreateCompanionBuilder =
    BootstrapPagesCompanion Function({
      Value<int> pageIndex,
      required String body,
    });
typedef $BootstrapPagesUpdateCompanionBuilder =
    BootstrapPagesCompanion Function({
      Value<int> pageIndex,
      Value<String> body,
    });

class $BootstrapPagesFilterComposer
    extends Composer<_$TrainingDatabase, BootstrapPages> {
  $BootstrapPagesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $BootstrapPagesOrderingComposer
    extends Composer<_$TrainingDatabase, BootstrapPages> {
  $BootstrapPagesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $BootstrapPagesAnnotationComposer
    extends Composer<_$TrainingDatabase, BootstrapPages> {
  $BootstrapPagesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $BootstrapPagesTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          BootstrapPages,
          BootstrapPage,
          $BootstrapPagesFilterComposer,
          $BootstrapPagesOrderingComposer,
          $BootstrapPagesAnnotationComposer,
          $BootstrapPagesCreateCompanionBuilder,
          $BootstrapPagesUpdateCompanionBuilder,
          (
            BootstrapPage,
            BaseReferences<_$TrainingDatabase, BootstrapPages, BootstrapPage>,
          ),
          BootstrapPage,
          PrefetchHooks Function()
        > {
  $BootstrapPagesTableManager(_$TrainingDatabase db, BootstrapPages table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BootstrapPagesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BootstrapPagesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BootstrapPagesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> pageIndex = const Value.absent(),
            Value<String> body = const Value.absent(),
          }) => BootstrapPagesCompanion(pageIndex: pageIndex, body: body),
          createCompanionCallback:
              ({
                Value<int> pageIndex = const Value.absent(),
                required String body,
              }) => BootstrapPagesCompanion.insert(
                pageIndex: pageIndex,
                body: body,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<BootstrapPages, BootstrapPage>(table),
                  BaseReferences<
                    _$TrainingDatabase,
                    BootstrapPages,
                    BootstrapPage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $BootstrapPagesProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      BootstrapPages,
      BootstrapPage,
      $BootstrapPagesFilterComposer,
      $BootstrapPagesOrderingComposer,
      $BootstrapPagesAnnotationComposer,
      $BootstrapPagesCreateCompanionBuilder,
      $BootstrapPagesUpdateCompanionBuilder,
      (
        BootstrapPage,
        BaseReferences<_$TrainingDatabase, BootstrapPages, BootstrapPage>,
      ),
      BootstrapPage,
      PrefetchHooks Function()
    >;
typedef $RecoveryStateCreateCompanionBuilder = RecoveryStateCompanion Function({
  Value<int> singleton,
  Value<int> required,
  Value<String?> currentContext,
  Value<int> highWater,
});
typedef $RecoveryStateUpdateCompanionBuilder = RecoveryStateCompanion Function({
  Value<int> singleton,
  Value<int> required,
  Value<String?> currentContext,
  Value<int> highWater,
});

class $RecoveryStateFilterComposer
    extends Composer<_$TrainingDatabase, RecoveryState> {
  $RecoveryStateFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get required => $composableBuilder(
    column: $table.required,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentContext => $composableBuilder(
    column: $table.currentContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highWater => $composableBuilder(
    column: $table.highWater,
    builder: (column) => ColumnFilters(column),
  );
}

class $RecoveryStateOrderingComposer
    extends Composer<_$TrainingDatabase, RecoveryState> {
  $RecoveryStateOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get required => $composableBuilder(
    column: $table.required,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentContext => $composableBuilder(
    column: $table.currentContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highWater => $composableBuilder(
    column: $table.highWater,
    builder: (column) => ColumnOrderings(column),
  );
}

class $RecoveryStateAnnotationComposer
    extends Composer<_$TrainingDatabase, RecoveryState> {
  $RecoveryStateAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<int> get required =>
      $composableBuilder(column: $table.required, builder: (column) => column);

  GeneratedColumn<String> get currentContext => $composableBuilder(
    column: $table.currentContext,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highWater =>
      $composableBuilder(column: $table.highWater, builder: (column) => column);
}

class $RecoveryStateTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          RecoveryState,
          RecoveryStateData,
          $RecoveryStateFilterComposer,
          $RecoveryStateOrderingComposer,
          $RecoveryStateAnnotationComposer,
          $RecoveryStateCreateCompanionBuilder,
          $RecoveryStateUpdateCompanionBuilder,
          (
            RecoveryStateData,
            BaseReferences<
              _$TrainingDatabase,
              RecoveryState,
              RecoveryStateData
            >,
          ),
          RecoveryStateData,
          PrefetchHooks Function()
        > {
  $RecoveryStateTableManager(_$TrainingDatabase db, RecoveryState table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RecoveryStateFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RecoveryStateOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RecoveryStateAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<int> required = const Value.absent(),
                Value<String?> currentContext = const Value.absent(),
                Value<int> highWater = const Value.absent(),
              }) => RecoveryStateCompanion(
                singleton: singleton,
                required: required,
                currentContext: currentContext,
                highWater: highWater,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<int> required = const Value.absent(),
                Value<String?> currentContext = const Value.absent(),
                Value<int> highWater = const Value.absent(),
              }) => RecoveryStateCompanion.insert(
                singleton: singleton,
                required: required,
                currentContext: currentContext,
                highWater: highWater,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<RecoveryState, RecoveryStateData>(table),
                  BaseReferences<
                    _$TrainingDatabase,
                    RecoveryState,
                    RecoveryStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $RecoveryStateProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      RecoveryState,
      RecoveryStateData,
      $RecoveryStateFilterComposer,
      $RecoveryStateOrderingComposer,
      $RecoveryStateAnnotationComposer,
      $RecoveryStateCreateCompanionBuilder,
      $RecoveryStateUpdateCompanionBuilder,
      (
        RecoveryStateData,
        BaseReferences<_$TrainingDatabase, RecoveryState, RecoveryStateData>,
      ),
      RecoveryStateData,
      PrefetchHooks Function()
    >;
typedef $HistoricalReceiptsCreateCompanionBuilder =
    HistoricalReceiptsCompanion Function({
      required String mutationId,
      required String evidence,
      Value<int> rowid,
    });
typedef $HistoricalReceiptsUpdateCompanionBuilder =
    HistoricalReceiptsCompanion Function({
      Value<String> mutationId,
      Value<String> evidence,
      Value<int> rowid,
    });

class $HistoricalReceiptsFilterComposer
    extends Composer<_$TrainingDatabase, HistoricalReceipts> {
  $HistoricalReceiptsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnFilters(column),
  );
}

class $HistoricalReceiptsOrderingComposer
    extends Composer<_$TrainingDatabase, HistoricalReceipts> {
  $HistoricalReceiptsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $HistoricalReceiptsAnnotationComposer
    extends Composer<_$TrainingDatabase, HistoricalReceipts> {
  $HistoricalReceiptsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidence =>
      $composableBuilder(column: $table.evidence, builder: (column) => column);
}

class $HistoricalReceiptsTableManager
    extends
        RootTableManager<
          _$TrainingDatabase,
          HistoricalReceipts,
          HistoricalReceipt,
          $HistoricalReceiptsFilterComposer,
          $HistoricalReceiptsOrderingComposer,
          $HistoricalReceiptsAnnotationComposer,
          $HistoricalReceiptsCreateCompanionBuilder,
          $HistoricalReceiptsUpdateCompanionBuilder,
          (
            HistoricalReceipt,
            BaseReferences<
              _$TrainingDatabase,
              HistoricalReceipts,
              HistoricalReceipt
            >,
          ),
          HistoricalReceipt,
          PrefetchHooks Function()
        > {
  $HistoricalReceiptsTableManager(
    _$TrainingDatabase db,
    HistoricalReceipts table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $HistoricalReceiptsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $HistoricalReceiptsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $HistoricalReceiptsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> evidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoricalReceiptsCompanion(
                mutationId: mutationId,
                evidence: evidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String evidence,
                Value<int> rowid = const Value.absent(),
              }) => HistoricalReceiptsCompanion.insert(
                mutationId: mutationId,
                evidence: evidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<HistoricalReceipts, HistoricalReceipt>(table),
                  BaseReferences<
                    _$TrainingDatabase,
                    HistoricalReceipts,
                    HistoricalReceipt
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $HistoricalReceiptsProcessedTableManager =
    ProcessedTableManager<
      _$TrainingDatabase,
      HistoricalReceipts,
      HistoricalReceipt,
      $HistoricalReceiptsFilterComposer,
      $HistoricalReceiptsOrderingComposer,
      $HistoricalReceiptsAnnotationComposer,
      $HistoricalReceiptsCreateCompanionBuilder,
      $HistoricalReceiptsUpdateCompanionBuilder,
      (
        HistoricalReceipt,
        BaseReferences<
          _$TrainingDatabase,
          HistoricalReceipts,
          HistoricalReceipt
        >,
      ),
      HistoricalReceipt,
      PrefetchHooks Function()
    >;

class $TrainingDatabaseManager {
  final _$TrainingDatabase _db;
  $TrainingDatabaseManager(this._db);
  $LocalIdentityTableManager get localIdentity =>
      $LocalIdentityTableManager(_db, _db.localIdentity);
  $SessionsTableManager get sessions =>
      $SessionsTableManager(_db, _db.sessions);
  $ExercisesTableManager get exercises =>
      $ExercisesTableManager(_db, _db.exercises);
  $WorkoutSetsTableManager get workoutSets =>
      $WorkoutSetsTableManager(_db, _db.workoutSets);
  $LocalObservationsTableManager get localObservations =>
      $LocalObservationsTableManager(_db, _db.localObservations);
  $OutboxTableManager get outbox => $OutboxTableManager(_db, _db.outbox);
  $ShadowsTableManager get shadows => $ShadowsTableManager(_db, _db.shadows);
  $DraftsTableManager get drafts => $DraftsTableManager(_db, _db.drafts);
  $RestTimersTableManager get restTimers =>
      $RestTimersTableManager(_db, _db.restTimers);
  $RetiredIdsTableManager get retiredIds =>
      $RetiredIdsTableManager(_db, _db.retiredIds);
  $SyncMetadataTableManager get syncMetadata =>
      $SyncMetadataTableManager(_db, _db.syncMetadata);
  $BootstrapStageTableManager get bootstrapStage =>
      $BootstrapStageTableManager(_db, _db.bootstrapStage);
  $BootstrapPagesTableManager get bootstrapPages =>
      $BootstrapPagesTableManager(_db, _db.bootstrapPages);
  $RecoveryStateTableManager get recoveryState =>
      $RecoveryStateTableManager(_db, _db.recoveryState);
  $HistoricalReceiptsTableManager get historicalReceipts =>
      $HistoricalReceiptsTableManager(_db, _db.historicalReceipts);
}
