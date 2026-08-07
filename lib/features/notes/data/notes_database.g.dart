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
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customMinutesMeta = const VerificationMeta(
    'customMinutes',
  );
  @override
  late final GeneratedColumn<int> customMinutes = GeneratedColumn<int>(
    'custom_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
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
  static const VerificationMeta _remindAfterDaysMeta = const VerificationMeta(
    'remindAfterDays',
  );
  @override
  late final GeneratedColumn<int> remindAfterDays = GeneratedColumn<int>(
    'remind_after_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    imageName,
    body,
    createdAt,
    retention,
    ocrText,
    customMinutes,
    expiresAt,
    lastSeenAt,
    remindAfterDays,
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
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    }
    if (data.containsKey('custom_minutes')) {
      context.handle(
        _customMinutesMeta,
        customMinutes.isAcceptableOrUnknown(
          data['custom_minutes']!,
          _customMinutesMeta,
        ),
      );
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
    if (data.containsKey('remind_after_days')) {
      context.handle(
        _remindAfterDaysMeta,
        remindAfterDays.isAcceptableOrUnknown(
          data['remind_after_days']!,
          _remindAfterDaysMeta,
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
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      ),
      customMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_minutes'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
      remindAfterDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_after_days'],
      )!,
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

  /// Karedeki yazının makine okuması. **Arayüzde hiç gösterilmez.**
  ///
  /// Tek işi aramayı beslemek: kullanıcı "4521" ya da "kombi" yazınca fişin
  /// kendisi bulunsun. Görünmediği için OCR hataları da görünmez — %80
  /// isabetle bile arama işe yarar, oysa aynı metni nota yazsaydık her hata
  /// kullanıcının düzeltmesi gereken bir kir olurdu.
  ///
  /// `null` = henüz taranmadı. Boş metin = tarandı, yazı bulunamadı.
  final String? ocrText;

  /// Özel saklama süresi (dakika). Yalnızca [Retention.custom] için anlamlı.
  ///
  /// Ayrı sütun gerekiyor: enum indeksi sabit bir değer taşır, kullanıcının
  /// seçtiği süre ise her kayıtta farklı olabilir.
  final int customMinutes;

  /// Süreli notlar için hesaplanmış silinme anı; süresizse `null`.
  final DateTime? expiresAt;

  /// Nota en son ne zaman bakıldığı. Detay ekranında tazelenir.
  final DateTime? lastSeenAt;

  /// "Beni bu kadar gün sonra hatırlat." `0` ise hatırlatma yok.
  ///
  /// Hatırlatma isteğe bağlıdır ve **not başına** verilir. Eskiden her kayda
  /// otomatik kurulurdu; yüzlerce notu olan biri bakmadığı her kare için
  /// bildirim alıyordu. Üstelik iOS aynı anda yalnızca 64 bekleyen bildirim
  /// tutar — otomatik kurulum o sınırı sessizce aşıyordu.
  final int remindAfterDays;
  const Note({
    required this.id,
    required this.imageName,
    required this.body,
    required this.createdAt,
    required this.retention,
    this.ocrText,
    required this.customMinutes,
    this.expiresAt,
    this.lastSeenAt,
    required this.remindAfterDays,
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
    if (!nullToAbsent || ocrText != null) {
      map['ocr_text'] = Variable<String>(ocrText);
    }
    map['custom_minutes'] = Variable<int>(customMinutes);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    map['remind_after_days'] = Variable<int>(remindAfterDays);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      imageName: Value(imageName),
      body: Value(body),
      createdAt: Value(createdAt),
      retention: Value(retention),
      ocrText: ocrText == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrText),
      customMinutes: Value(customMinutes),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      remindAfterDays: Value(remindAfterDays),
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
      ocrText: serializer.fromJson<String?>(json['ocrText']),
      customMinutes: serializer.fromJson<int>(json['customMinutes']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
      remindAfterDays: serializer.fromJson<int>(json['remindAfterDays']),
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
      'ocrText': serializer.toJson<String?>(ocrText),
      'customMinutes': serializer.toJson<int>(customMinutes),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
      'remindAfterDays': serializer.toJson<int>(remindAfterDays),
    };
  }

  Note copyWith({
    int? id,
    String? imageName,
    String? body,
    DateTime? createdAt,
    Retention? retention,
    Value<String?> ocrText = const Value.absent(),
    int? customMinutes,
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<DateTime?> lastSeenAt = const Value.absent(),
    int? remindAfterDays,
  }) => Note(
    id: id ?? this.id,
    imageName: imageName ?? this.imageName,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    retention: retention ?? this.retention,
    ocrText: ocrText.present ? ocrText.value : this.ocrText,
    customMinutes: customMinutes ?? this.customMinutes,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    remindAfterDays: remindAfterDays ?? this.remindAfterDays,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      imageName: data.imageName.present ? data.imageName.value : this.imageName,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retention: data.retention.present ? data.retention.value : this.retention,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
      customMinutes: data.customMinutes.present
          ? data.customMinutes.value
          : this.customMinutes,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      remindAfterDays: data.remindAfterDays.present
          ? data.remindAfterDays.value
          : this.remindAfterDays,
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
          ..write('ocrText: $ocrText, ')
          ..write('customMinutes: $customMinutes, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('remindAfterDays: $remindAfterDays')
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
    ocrText,
    customMinutes,
    expiresAt,
    lastSeenAt,
    remindAfterDays,
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
          other.ocrText == this.ocrText &&
          other.customMinutes == this.customMinutes &&
          other.expiresAt == this.expiresAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.remindAfterDays == this.remindAfterDays);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String> imageName;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<Retention> retention;
  final Value<String?> ocrText;
  final Value<int> customMinutes;
  final Value<DateTime?> expiresAt;
  final Value<DateTime?> lastSeenAt;
  final Value<int> remindAfterDays;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.imageName = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retention = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.customMinutes = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.remindAfterDays = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String imageName,
    this.body = const Value.absent(),
    required DateTime createdAt,
    this.retention = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.customMinutes = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.remindAfterDays = const Value.absent(),
  }) : imageName = Value(imageName),
       createdAt = Value(createdAt);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? imageName,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? retention,
    Expression<String>? ocrText,
    Expression<int>? customMinutes,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? remindAfterDays,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imageName != null) 'image_name': imageName,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (retention != null) 'retention': retention,
      if (ocrText != null) 'ocr_text': ocrText,
      if (customMinutes != null) 'custom_minutes': customMinutes,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (remindAfterDays != null) 'remind_after_days': remindAfterDays,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String>? imageName,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<Retention>? retention,
    Value<String?>? ocrText,
    Value<int>? customMinutes,
    Value<DateTime?>? expiresAt,
    Value<DateTime?>? lastSeenAt,
    Value<int>? remindAfterDays,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      imageName: imageName ?? this.imageName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      retention: retention ?? this.retention,
      ocrText: ocrText ?? this.ocrText,
      customMinutes: customMinutes ?? this.customMinutes,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      remindAfterDays: remindAfterDays ?? this.remindAfterDays,
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
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (customMinutes.present) {
      map['custom_minutes'] = Variable<int>(customMinutes.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (remindAfterDays.present) {
      map['remind_after_days'] = Variable<int>(remindAfterDays.value);
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
          ..write('ocrText: $ocrText, ')
          ..write('customMinutes: $customMinutes, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('remindAfterDays: $remindAfterDays')
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
        defaultValue: const Constant(2),
      ).withConverter<AppThemeMode>($SettingsTableTable.$converterthemeMode);
  @override
  late final GeneratedColumnWithTypeConverter<FeedDensity, int> density =
      GeneratedColumn<int>(
        'density',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(1),
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
  late final GeneratedColumnWithTypeConverter<Retention, int> defaultRetention =
      GeneratedColumn<int>(
        'default_retention',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<Retention>(
        $SettingsTableTable.$converterdefaultRetention,
      );
  @override
  late final GeneratedColumnWithTypeConverter<AppLocale, int> locale =
      GeneratedColumn<int>(
        'locale',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<AppLocale>($SettingsTableTable.$converterlocale);
  static const VerificationMeta _defaultCustomMinutesMeta =
      const VerificationMeta('defaultCustomMinutes');
  @override
  late final GeneratedColumn<int> defaultCustomMinutes = GeneratedColumn<int>(
    'default_custom_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _proUnlockedMeta = const VerificationMeta(
    'proUnlocked',
  );
  @override
  late final GeneratedColumn<bool> proUnlocked = GeneratedColumn<bool>(
    'pro_unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pro_unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    density,
    reminderEnabled,
    defaultRetention,
    locale,
    defaultCustomMinutes,
    proUnlocked,
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
    if (data.containsKey('default_custom_minutes')) {
      context.handle(
        _defaultCustomMinutesMeta,
        defaultCustomMinutes.isAcceptableOrUnknown(
          data['default_custom_minutes']!,
          _defaultCustomMinutesMeta,
        ),
      );
    }
    if (data.containsKey('pro_unlocked')) {
      context.handle(
        _proUnlockedMeta,
        proUnlocked.isAcceptableOrUnknown(
          data['pro_unlocked']!,
          _proUnlockedMeta,
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
      defaultRetention: $SettingsTableTable.$converterdefaultRetention.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}default_retention'],
        )!,
      ),
      locale: $SettingsTableTable.$converterlocale.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}locale'],
        )!,
      ),
      defaultCustomMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_custom_minutes'],
      )!,
      proUnlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pro_unlocked'],
      )!,
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
  static JsonTypeConverter2<Retention, int, int> $converterdefaultRetention =
      const EnumIndexConverter<Retention>(Retention.values);
  static JsonTypeConverter2<AppLocale, int, int> $converterlocale =
      const EnumIndexConverter<AppLocale>(AppLocale.values);
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  /// Her zaman 1. Tabloda tek satır bulunur.
  final int id;

  /// Varsayılan koyu (index 2): uygulama fotoğrafın önde durduğu bir arayüz
  /// ve karanlık zemin kareyi öne çıkarıyor.
  final AppThemeMode themeMode;

  /// Varsayılan ızgara (index 1): uygulama ilk açıldığında daha çok kayıt
  /// tek bakışta görünsün.
  final FeedDensity density;
  final bool reminderEnabled;

  /// Yeni kayıtların varsayılan saklama süresi.
  ///
  /// Otomatik silme artık her çekimde sorulmaz; buradan bir kez seçilir ve
  /// kayıtlar onunla açılır. Böylece çekim akışında tek bir karar kalır.
  final Retention defaultRetention;

  /// Dil tercihi. Varsayılan sistem dili.
  final AppLocale locale;

  /// Yeni kayıtların varsayılan özel süresi (dakika).
  final int defaultCustomMinutes;

  /// Pro hakkının son bilinen durumu.
  ///
  /// Doğruluk kaynağı **mağaza**; bu yalnızca önbellek. Soğuk açılışta mağaza
  /// cevabı gelene kadar ödemiş bir kullanıcıya paywall göstermemek için var.
  final bool proUnlocked;
  const SettingsRow({
    required this.id,
    required this.themeMode,
    required this.density,
    required this.reminderEnabled,
    required this.defaultRetention,
    required this.locale,
    required this.defaultCustomMinutes,
    required this.proUnlocked,
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
      map['default_retention'] = Variable<int>(
        $SettingsTableTable.$converterdefaultRetention.toSql(defaultRetention),
      );
    }
    {
      map['locale'] = Variable<int>(
        $SettingsTableTable.$converterlocale.toSql(locale),
      );
    }
    map['default_custom_minutes'] = Variable<int>(defaultCustomMinutes);
    map['pro_unlocked'] = Variable<bool>(proUnlocked);
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      density: Value(density),
      reminderEnabled: Value(reminderEnabled),
      defaultRetention: Value(defaultRetention),
      locale: Value(locale),
      defaultCustomMinutes: Value(defaultCustomMinutes),
      proUnlocked: Value(proUnlocked),
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
      defaultRetention: $SettingsTableTable.$converterdefaultRetention.fromJson(
        serializer.fromJson<int>(json['defaultRetention']),
      ),
      locale: $SettingsTableTable.$converterlocale.fromJson(
        serializer.fromJson<int>(json['locale']),
      ),
      defaultCustomMinutes: serializer.fromJson<int>(
        json['defaultCustomMinutes'],
      ),
      proUnlocked: serializer.fromJson<bool>(json['proUnlocked']),
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
      'defaultRetention': serializer.toJson<int>(
        $SettingsTableTable.$converterdefaultRetention.toJson(defaultRetention),
      ),
      'locale': serializer.toJson<int>(
        $SettingsTableTable.$converterlocale.toJson(locale),
      ),
      'defaultCustomMinutes': serializer.toJson<int>(defaultCustomMinutes),
      'proUnlocked': serializer.toJson<bool>(proUnlocked),
    };
  }

  SettingsRow copyWith({
    int? id,
    AppThemeMode? themeMode,
    FeedDensity? density,
    bool? reminderEnabled,
    Retention? defaultRetention,
    AppLocale? locale,
    int? defaultCustomMinutes,
    bool? proUnlocked,
  }) => SettingsRow(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    density: density ?? this.density,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    defaultRetention: defaultRetention ?? this.defaultRetention,
    locale: locale ?? this.locale,
    defaultCustomMinutes: defaultCustomMinutes ?? this.defaultCustomMinutes,
    proUnlocked: proUnlocked ?? this.proUnlocked,
  );
  SettingsRow copyWithCompanion(SettingsTableCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      density: data.density.present ? data.density.value : this.density,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      defaultRetention: data.defaultRetention.present
          ? data.defaultRetention.value
          : this.defaultRetention,
      locale: data.locale.present ? data.locale.value : this.locale,
      defaultCustomMinutes: data.defaultCustomMinutes.present
          ? data.defaultCustomMinutes.value
          : this.defaultCustomMinutes,
      proUnlocked: data.proUnlocked.present
          ? data.proUnlocked.value
          : this.proUnlocked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('density: $density, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('defaultRetention: $defaultRetention, ')
          ..write('locale: $locale, ')
          ..write('defaultCustomMinutes: $defaultCustomMinutes, ')
          ..write('proUnlocked: $proUnlocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    density,
    reminderEnabled,
    defaultRetention,
    locale,
    defaultCustomMinutes,
    proUnlocked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.density == this.density &&
          other.reminderEnabled == this.reminderEnabled &&
          other.defaultRetention == this.defaultRetention &&
          other.locale == this.locale &&
          other.defaultCustomMinutes == this.defaultCustomMinutes &&
          other.proUnlocked == this.proUnlocked);
}

class SettingsTableCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<AppThemeMode> themeMode;
  final Value<FeedDensity> density;
  final Value<bool> reminderEnabled;
  final Value<Retention> defaultRetention;
  final Value<AppLocale> locale;
  final Value<int> defaultCustomMinutes;
  final Value<bool> proUnlocked;
  const SettingsTableCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.density = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.defaultRetention = const Value.absent(),
    this.locale = const Value.absent(),
    this.defaultCustomMinutes = const Value.absent(),
    this.proUnlocked = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.density = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.defaultRetention = const Value.absent(),
    this.locale = const Value.absent(),
    this.defaultCustomMinutes = const Value.absent(),
    this.proUnlocked = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<int>? themeMode,
    Expression<int>? density,
    Expression<bool>? reminderEnabled,
    Expression<int>? defaultRetention,
    Expression<int>? locale,
    Expression<int>? defaultCustomMinutes,
    Expression<bool>? proUnlocked,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (density != null) 'density': density,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (defaultRetention != null) 'default_retention': defaultRetention,
      if (locale != null) 'locale': locale,
      if (defaultCustomMinutes != null)
        'default_custom_minutes': defaultCustomMinutes,
      if (proUnlocked != null) 'pro_unlocked': proUnlocked,
    });
  }

  SettingsTableCompanion copyWith({
    Value<int>? id,
    Value<AppThemeMode>? themeMode,
    Value<FeedDensity>? density,
    Value<bool>? reminderEnabled,
    Value<Retention>? defaultRetention,
    Value<AppLocale>? locale,
    Value<int>? defaultCustomMinutes,
    Value<bool>? proUnlocked,
  }) {
    return SettingsTableCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      defaultRetention: defaultRetention ?? this.defaultRetention,
      locale: locale ?? this.locale,
      defaultCustomMinutes: defaultCustomMinutes ?? this.defaultCustomMinutes,
      proUnlocked: proUnlocked ?? this.proUnlocked,
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
    if (defaultRetention.present) {
      map['default_retention'] = Variable<int>(
        $SettingsTableTable.$converterdefaultRetention.toSql(
          defaultRetention.value,
        ),
      );
    }
    if (locale.present) {
      map['locale'] = Variable<int>(
        $SettingsTableTable.$converterlocale.toSql(locale.value),
      );
    }
    if (defaultCustomMinutes.present) {
      map['default_custom_minutes'] = Variable<int>(defaultCustomMinutes.value);
    }
    if (proUnlocked.present) {
      map['pro_unlocked'] = Variable<bool>(proUnlocked.value);
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
          ..write('defaultRetention: $defaultRetention, ')
          ..write('locale: $locale, ')
          ..write('defaultCustomMinutes: $defaultCustomMinutes, ')
          ..write('proUnlocked: $proUnlocked')
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
      Value<String?> ocrText,
      Value<int> customMinutes,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSeenAt,
      Value<int> remindAfterDays,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<String> imageName,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<Retention> retention,
      Value<String?> ocrText,
      Value<int> customMinutes,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSeenAt,
      Value<int> remindAfterDays,
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

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customMinutes => $composableBuilder(
    column: $table.customMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindAfterDays => $composableBuilder(
    column: $table.remindAfterDays,
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

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customMinutes => $composableBuilder(
    column: $table.customMinutes,
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

  ColumnOrderings<int> get remindAfterDays => $composableBuilder(
    column: $table.remindAfterDays,
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

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  GeneratedColumn<int> get customMinutes => $composableBuilder(
    column: $table.customMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remindAfterDays => $composableBuilder(
    column: $table.remindAfterDays,
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
                Value<String?> ocrText = const Value.absent(),
                Value<int> customMinutes = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<int> remindAfterDays = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                imageName: imageName,
                body: body,
                createdAt: createdAt,
                retention: retention,
                ocrText: ocrText,
                customMinutes: customMinutes,
                expiresAt: expiresAt,
                lastSeenAt: lastSeenAt,
                remindAfterDays: remindAfterDays,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String imageName,
                Value<String> body = const Value.absent(),
                required DateTime createdAt,
                Value<Retention> retention = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                Value<int> customMinutes = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<int> remindAfterDays = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                imageName: imageName,
                body: body,
                createdAt: createdAt,
                retention: retention,
                ocrText: ocrText,
                customMinutes: customMinutes,
                expiresAt: expiresAt,
                lastSeenAt: lastSeenAt,
                remindAfterDays: remindAfterDays,
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
      Value<Retention> defaultRetention,
      Value<AppLocale> locale,
      Value<int> defaultCustomMinutes,
      Value<bool> proUnlocked,
    });
typedef $$SettingsTableTableUpdateCompanionBuilder =
    SettingsTableCompanion Function({
      Value<int> id,
      Value<AppThemeMode> themeMode,
      Value<FeedDensity> density,
      Value<bool> reminderEnabled,
      Value<Retention> defaultRetention,
      Value<AppLocale> locale,
      Value<int> defaultCustomMinutes,
      Value<bool> proUnlocked,
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

  ColumnWithTypeConverterFilters<Retention, Retention, int>
  get defaultRetention => $composableBuilder(
    column: $table.defaultRetention,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<AppLocale, AppLocale, int> get locale =>
      $composableBuilder(
        column: $table.locale,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get defaultCustomMinutes => $composableBuilder(
    column: $table.defaultCustomMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get proUnlocked => $composableBuilder(
    column: $table.proUnlocked,
    builder: (column) => ColumnFilters(column),
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

  ColumnOrderings<int> get defaultRetention => $composableBuilder(
    column: $table.defaultRetention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultCustomMinutes => $composableBuilder(
    column: $table.defaultCustomMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get proUnlocked => $composableBuilder(
    column: $table.proUnlocked,
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

  GeneratedColumnWithTypeConverter<Retention, int> get defaultRetention =>
      $composableBuilder(
        column: $table.defaultRetention,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<AppLocale, int> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<int> get defaultCustomMinutes => $composableBuilder(
    column: $table.defaultCustomMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get proUnlocked => $composableBuilder(
    column: $table.proUnlocked,
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
                Value<Retention> defaultRetention = const Value.absent(),
                Value<AppLocale> locale = const Value.absent(),
                Value<int> defaultCustomMinutes = const Value.absent(),
                Value<bool> proUnlocked = const Value.absent(),
              }) => SettingsTableCompanion(
                id: id,
                themeMode: themeMode,
                density: density,
                reminderEnabled: reminderEnabled,
                defaultRetention: defaultRetention,
                locale: locale,
                defaultCustomMinutes: defaultCustomMinutes,
                proUnlocked: proUnlocked,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AppThemeMode> themeMode = const Value.absent(),
                Value<FeedDensity> density = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<Retention> defaultRetention = const Value.absent(),
                Value<AppLocale> locale = const Value.absent(),
                Value<int> defaultCustomMinutes = const Value.absent(),
                Value<bool> proUnlocked = const Value.absent(),
              }) => SettingsTableCompanion.insert(
                id: id,
                themeMode: themeMode,
                density: density,
                reminderEnabled: reminderEnabled,
                defaultRetention: defaultRetention,
                locale: locale,
                defaultCustomMinutes: defaultCustomMinutes,
                proUnlocked: proUnlocked,
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
