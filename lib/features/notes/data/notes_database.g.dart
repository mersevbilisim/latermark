// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _imageNameMeta = const VerificationMeta(
    'imageName',
  );
  @override
  late final GeneratedColumn<String> imageName = GeneratedColumn<String>(
    'image_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Retention, int> retention =
      GeneratedColumn<int>(
        'retention',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<Retention>($NotesTable.$converterretention);
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    imageName,
    body,
    createdAt,
    retention,
    expiresAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('image_name')) {
      context.handle(
        _imageNameMeta,
        imageName.isAcceptableOrUnknown(data['image_name']!, _imageNameMeta),
      );
    } else if (isInserting) {
      context.missing(_imageNameMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      imageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_name'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retention: $NotesTable.$converterretention.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}retention'],
        )!,
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Retention, int, int> $converterretention =
      const EnumIndexConverter<Retention>(Retention.values);
}

class Note extends DataClass implements Insertable<Note> {
  final int id;

  /// Yalnızca dosya adı saklanır (ör. `1754...-4821.jpg`).
  ///
  /// Mutlak yol saklamak iOS'ta hataya yol açar: uygulama konteyner yolu her
  /// kurulumda değişir ve kayıtlı yollar geçersizleşir. Klasör her açılışta
  /// fotoğraf deposu tarafından yeniden çözülür.
  final String imageName;
  final String body;
  final DateTime createdAt;
  final Retention retention;

  /// Süreli notlar için hesaplanmış silinme anı; süresizse `null`.
  final DateTime? expiresAt;

  /// Nota en son ne zaman bakıldığı.
  ///
  /// Hatırlatıcı bunun üzerine kurulur: "şu kadar gün bakmazsan hatırlat".
  /// Kayıt açıldığında tazelenir, böylece hatırlatma ileri atılır.
  final DateTime? lastSeenAt;
  const Note({
    required this.id,
    required this.imageName,
    required this.body,
    required this.createdAt,
    required this.retention,
    this.expiresAt,
    this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['image_name'] = Variable<String>(imageName);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['retention'] = Variable<int>(
        $NotesTable.$converterretention.toSql(retention),
      );
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      imageName: Value(imageName),
      body: Value(body),
      createdAt: Value(createdAt),
      retention: Value(retention),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      imageName: serializer.fromJson<String>(json['imageName']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retention: $NotesTable.$converterretention.fromJson(
        serializer.fromJson<int>(json['retention']),
      ),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'imageName': serializer.toJson<String>(imageName),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retention': serializer.toJson<int>(
        $NotesTable.$converterretention.toJson(retention),
      ),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
    };
  }

  Note copyWith({
    int? id,
    String? imageName,
    String? body,
    DateTime? createdAt,
    Retention? retention,
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<DateTime?> lastSeenAt = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    imageName: imageName ?? this.imageName,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    retention: retention ?? this.retention,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      imageName: data.imageName.present ? data.imageName.value : this.imageName,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retention: data.retention.present ? data.retention.value : this.retention,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('imageName: $imageName, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('retention: $retention, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    imageName,
    body,
    createdAt,
    retention,
    expiresAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.imageName == this.imageName &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.retention == this.retention &&
          other.expiresAt == this.expiresAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String> imageName;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<Retention> retention;
  final Value<DateTime?> expiresAt;
  final Value<DateTime?> lastSeenAt;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.imageName = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retention = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String imageName,
    this.body = const Value.absent(),
    required DateTime createdAt,
    this.retention = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
  }) : imageName = Value(imageName),
       createdAt = Value(createdAt);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? imageName,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? retention,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? lastSeenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imageName != null) 'image_name': imageName,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (retention != null) 'retention': retention,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String>? imageName,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<Retention>? retention,
    Value<DateTime?>? expiresAt,
    Value<DateTime?>? lastSeenAt,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      imageName: imageName ?? this.imageName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      retention: retention ?? this.retention,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (imageName.present) {
      map['image_name'] = Variable<String>(imageName.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retention.present) {
      map['retention'] = Variable<int>(
        $NotesTable.$converterretention.toSql(retention.value),
      );
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('imageName: $imageName, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('retention: $retention, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTableTable extends SettingsTable
    with TableInfo<$SettingsTableTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AppThemeMode, int> themeMode =
      GeneratedColumn<int>(
        'theme_mode',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<AppThemeMode>($SettingsTableTable.$converterthemeMode);
  @override
  late final GeneratedColumnWithTypeConverter<FeedDensity, int> density =
      GeneratedColumn<int>(
        'density',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<FeedDensity>($SettingsTableTable.$converterdensity);
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderDelay, int>
  reminderDelay = GeneratedColumn<int>(
    'reminder_delay',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  ).withConverter<ReminderDelay>($SettingsTableTable.$converterreminderDelay);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    density,
    reminderEnabled,
    reminderDelay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeMode: $SettingsTableTable.$converterthemeMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}theme_mode'],
        )!,
      ),
      density: $SettingsTableTable.$converterdensity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}density'],
        )!,
      ),
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderDelay: $SettingsTableTable.$converterreminderDelay.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}reminder_delay'],
        )!,
      ),
    );
  }

  @override
  $SettingsTableTable createAlias(String alias) {
    return $SettingsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AppThemeMode, int, int> $converterthemeMode =
      const EnumIndexConverter<AppThemeMode>(AppThemeMode.values);
  static JsonTypeConverter2<FeedDensity, int, int> $converterdensity =
      const EnumIndexConverter<FeedDensity>(FeedDensity.values);
  static JsonTypeConverter2<ReminderDelay, int, int> $converterreminderDelay =
      const EnumIndexConverter<ReminderDelay>(ReminderDelay.values);
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  /// Her zaman 1. Tabloda tek satır bulunur.
  final int id;
  final AppThemeMode themeMode;
  final FeedDensity density;
  final bool reminderEnabled;
  final ReminderDelay reminderDelay;
  const SettingsRow({
    required this.id,
    required this.themeMode,
    required this.density,
    required this.reminderEnabled,
    required this.reminderDelay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['theme_mode'] = Variable<int>(
        $SettingsTableTable.$converterthemeMode.toSql(themeMode),
      );
    }
    {
      map['density'] = Variable<int>(
        $SettingsTableTable.$converterdensity.toSql(density),
      );
    }
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    {
      map['reminder_delay'] = Variable<int>(
        $SettingsTableTable.$converterreminderDelay.toSql(reminderDelay),
      );
    }
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      density: Value(density),
      reminderEnabled: Value(reminderEnabled),
      reminderDelay: Value(reminderDelay),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      themeMode: $SettingsTableTable.$converterthemeMode.fromJson(
        serializer.fromJson<int>(json['themeMode']),
      ),
      density: $SettingsTableTable.$converterdensity.fromJson(
        serializer.fromJson<int>(json['density']),
      ),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderDelay: $SettingsTableTable.$converterreminderDelay.fromJson(
        serializer.fromJson<int>(json['reminderDelay']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<int>(
        $SettingsTableTable.$converterthemeMode.toJson(themeMode),
      ),
      'density': serializer.toJson<int>(
        $SettingsTableTable.$converterdensity.toJson(density),
      ),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderDelay': serializer.toJson<int>(
        $SettingsTableTable.$converterreminderDelay.toJson(reminderDelay),
      ),
    };
  }

  SettingsRow copyWith({
    int? id,
    AppThemeMode? themeMode,
    FeedDensity? density,
    bool? reminderEnabled,
    ReminderDelay? reminderDelay,
  }) => SettingsRow(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    density: density ?? this.density,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderDelay: reminderDelay ?? this.reminderDelay,
  );
  SettingsRow copyWithCompanion(SettingsTableCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      density: data.density.present ? data.density.value : this.density,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderDelay: data.reminderDelay.present
          ? data.reminderDelay.value
          : this.reminderDelay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('density: $density, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderDelay: $reminderDelay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, themeMode, density, reminderEnabled, reminderDelay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.density == this.density &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderDelay == this.reminderDelay);
}

class SettingsTableCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<AppThemeMode> themeMode;
  final Value<FeedDensity> density;
  final Value<bool> reminderEnabled;
  final Value<ReminderDelay> reminderDelay;
  const SettingsTableCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.density = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderDelay = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.density = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderDelay = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<int>? themeMode,
    Expression<int>? density,
    Expression<bool>? reminderEnabled,
    Expression<int>? reminderDelay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (density != null) 'density': density,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderDelay != null) 'reminder_delay': reminderDelay,
    });
  }

  SettingsTableCompanion copyWith({
    Value<int>? id,
    Value<AppThemeMode>? themeMode,
    Value<FeedDensity>? density,
    Value<bool>? reminderEnabled,
    Value<ReminderDelay>? reminderDelay,
  }) {
    return SettingsTableCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDelay: reminderDelay ?? this.reminderDelay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<int>(
        $SettingsTableTable.$converterthemeMode.toSql(themeMode.value),
      );
    }
    if (density.present) {
      map['density'] = Variable<int>(
        $SettingsTableTable.$converterdensity.toSql(density.value),
      );
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderDelay.present) {
      map['reminder_delay'] = Variable<int>(
        $SettingsTableTable.$converterreminderDelay.toSql(reminderDelay.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('density: $density, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderDelay: $reminderDelay')
          ..write(')'))
        .toString();
  }
}

abstract class _$NotesDatabase extends GeneratedDatabase {
  _$NotesDatabase(QueryExecutor e) : super(e);
  $NotesDatabaseManager get managers => $NotesDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [notes, settingsTable];
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      required String imageName,
      Value<String> body,
      required DateTime createdAt,
      Value<Retention> retention,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSeenAt,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<String> imageName,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<Retention> retention,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSeenAt,
    });

class $$NotesTableFilterComposer
    extends Composer<_$NotesDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageName => $composableBuilder(
    column: $table.imageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Retention, Retention, int> get retention =>
      $composableBuilder(
        column: $table.retention,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$NotesDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageName => $composableBuilder(
    column: $table.imageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retention => $composableBuilder(
    column: $table.retention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$NotesDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imageName =>
      $composableBuilder(column: $table.imageName, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Retention, int> get retention =>
      $composableBuilder(column: $table.retention, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$NotesDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$NotesDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> imageName = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<Retention> retention = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                imageName: imageName,
                body: body,
                createdAt: createdAt,
                retention: retention,
                expiresAt: expiresAt,
                lastSeenAt: lastSeenAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String imageName,
                Value<String> body = const Value.absent(),
                required DateTime createdAt,
                Value<Retention> retention = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                imageName: imageName,
                body: body,
                createdAt: createdAt,
                retention: retention,
                expiresAt: expiresAt,
                lastSeenAt: lastSeenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$NotesDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableTableCreateCompanionBuilder =
    SettingsTableCompanion Function({
      Value<int> id,
      Value<AppThemeMode> themeMode,
      Value<FeedDensity> density,
      Value<bool> reminderEnabled,
      Value<ReminderDelay> reminderDelay,
    });
typedef $$SettingsTableTableUpdateCompanionBuilder =
    SettingsTableCompanion Function({
      Value<int> id,
      Value<AppThemeMode> themeMode,
      Value<FeedDensity> density,
      Value<bool> reminderEnabled,
      Value<ReminderDelay> reminderDelay,
    });

class $$SettingsTableTableFilterComposer
    extends Composer<_$NotesDatabase, $SettingsTableTable> {
  $$SettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AppThemeMode, AppThemeMode, int>
  get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<FeedDensity, FeedDensity, int> get density =>
      $composableBuilder(
        column: $table.density,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderDelay, ReminderDelay, int>
  get reminderDelay => $composableBuilder(
    column: $table.reminderDelay,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$SettingsTableTableOrderingComposer
    extends Composer<_$NotesDatabase, $SettingsTableTable> {
  $$SettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get density => $composableBuilder(
    column: $table.density,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderDelay => $composableBuilder(
    column: $table.reminderDelay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableTableAnnotationComposer
    extends Composer<_$NotesDatabase, $SettingsTableTable> {
  $$SettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AppThemeMode, int> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FeedDensity, int> get density =>
      $composableBuilder(column: $table.density, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ReminderDelay, int> get reminderDelay =>
      $composableBuilder(
        column: $table.reminderDelay,
        builder: (column) => column,
      );
}

class $$SettingsTableTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $SettingsTableTable,
          SettingsRow,
          $$SettingsTableTableFilterComposer,
          $$SettingsTableTableOrderingComposer,
          $$SettingsTableTableAnnotationComposer,
          $$SettingsTableTableCreateCompanionBuilder,
          $$SettingsTableTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$NotesDatabase, $SettingsTableTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableTableManager(
    _$NotesDatabase db,
    $SettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AppThemeMode> themeMode = const Value.absent(),
                Value<FeedDensity> density = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<ReminderDelay> reminderDelay = const Value.absent(),
              }) => SettingsTableCompanion(
                id: id,
                themeMode: themeMode,
                density: density,
                reminderEnabled: reminderEnabled,
                reminderDelay: reminderDelay,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AppThemeMode> themeMode = const Value.absent(),
                Value<FeedDensity> density = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<ReminderDelay> reminderDelay = const Value.absent(),
              }) => SettingsTableCompanion.insert(
                id: id,
                themeMode: themeMode,
                density: density,
                reminderEnabled: reminderEnabled,
                reminderDelay: reminderDelay,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $SettingsTableTable,
      SettingsRow,
      $$SettingsTableTableFilterComposer,
      $$SettingsTableTableOrderingComposer,
      $$SettingsTableTableAnnotationComposer,
      $$SettingsTableTableCreateCompanionBuilder,
      $$SettingsTableTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$NotesDatabase, $SettingsTableTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;

class $NotesDatabaseManager {
  final _$NotesDatabase _db;
  $NotesDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$SettingsTableTableTableManager get settingsTable =>
      $$SettingsTableTableTableManager(_db, _db.settingsTable);
}
