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
          ..write('customMinutes: $customMinutes, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('remindAfterDays: $remindAfterDays')
          ..write(')'))
        .toString();
  }
}

class $NoteSearchTable extends NoteSearch
    with TableInfo<$NoteSearchTable, NoteSearchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteSearchTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bodyFoldedMeta = const VerificationMeta(
    'bodyFolded',
  );
  @override
  late final GeneratedColumn<String> bodyFolded = GeneratedColumn<String>(
    'body_folded',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _photoFoldedMeta = const VerificationMeta(
    'photoFolded',
  );
  @override
  late final GeneratedColumn<String> photoFolded = GeneratedColumn<String>(
    'photo_folded',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    noteId,
    bodyFolded,
    photoFolded,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteSearchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('body_folded')) {
      context.handle(
        _bodyFoldedMeta,
        bodyFolded.isAcceptableOrUnknown(data['body_folded']!, _bodyFoldedMeta),
      );
    }
    if (data.containsKey('photo_folded')) {
      context.handle(
        _photoFoldedMeta,
        photoFolded.isAcceptableOrUnknown(
          data['photo_folded']!,
          _photoFoldedMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId};
  @override
  NoteSearchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteSearchRow(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      )!,
      bodyFolded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_folded'],
      )!,
      photoFolded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_folded'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $NoteSearchTable createAlias(String alias) {
    return $NoteSearchTable(attachedDatabase, alias);
  }
}

class NoteSearchRow extends DataClass implements Insertable<NoteSearchRow> {
  /// Notun kimliği. Not silinince satır de kendiliğinden gider — `beforeOpen`
  /// zaten `foreign_keys` açıyor.
  final int noteId;

  /// Kullanıcının yazdığı notun katlanmış hâli.
  ///
  /// Katlama yazarken bir kez yapılıyor; arama anında yalnızca **sorgu**
  /// katlanıyor. Eskiden her tuş vuruşunda her kaydın metni yeniden
  /// katlanıyordu.
  final String bodyFolded;

  /// Karedeki yazının katlanmış hâli. **Arayüzde hiç gösterilmez.**
  ///
  /// Tek işi aramayı beslemek: kullanıcı "4521" ya da "kombi" yazınca fişin
  /// kendisi bulunsun. Görünmediği için OCR hataları da görünmez — %80
  /// isabetle bile arama işe yarar, oysa aynı metni nota yazsaydık her hata
  /// kullanıcının düzeltmesi gereken bir kir olurdu.
  ///
  /// `null` = henüz okunamadı. Boş metin = tarandı, yazı bulunamadı.
  final String? photoFolded;

  /// Başarısız okuma sayısı.
  ///
  /// Sayaç olmadan bozuk ya da okunamayan tek bir kare, listedeki her
  /// değişimde yeniden taranıyordu — A4 boyunda bir karede bu her seferinde
  /// 1-2 saniye CPU ve boşa giden pil demek.
  final int attempts;
  const NoteSearchRow({
    required this.noteId,
    required this.bodyFolded,
    this.photoFolded,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<int>(noteId);
    map['body_folded'] = Variable<String>(bodyFolded);
    if (!nullToAbsent || photoFolded != null) {
      map['photo_folded'] = Variable<String>(photoFolded);
    }
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  NoteSearchCompanion toCompanion(bool nullToAbsent) {
    return NoteSearchCompanion(
      noteId: Value(noteId),
      bodyFolded: Value(bodyFolded),
      photoFolded: photoFolded == null && nullToAbsent
          ? const Value.absent()
          : Value(photoFolded),
      attempts: Value(attempts),
    );
  }

  factory NoteSearchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteSearchRow(
      noteId: serializer.fromJson<int>(json['noteId']),
      bodyFolded: serializer.fromJson<String>(json['bodyFolded']),
      photoFolded: serializer.fromJson<String?>(json['photoFolded']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<int>(noteId),
      'bodyFolded': serializer.toJson<String>(bodyFolded),
      'photoFolded': serializer.toJson<String?>(photoFolded),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  NoteSearchRow copyWith({
    int? noteId,
    String? bodyFolded,
    Value<String?> photoFolded = const Value.absent(),
    int? attempts,
  }) => NoteSearchRow(
    noteId: noteId ?? this.noteId,
    bodyFolded: bodyFolded ?? this.bodyFolded,
    photoFolded: photoFolded.present ? photoFolded.value : this.photoFolded,
    attempts: attempts ?? this.attempts,
  );
  NoteSearchRow copyWithCompanion(NoteSearchCompanion data) {
    return NoteSearchRow(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      bodyFolded: data.bodyFolded.present
          ? data.bodyFolded.value
          : this.bodyFolded,
      photoFolded: data.photoFolded.present
          ? data.photoFolded.value
          : this.photoFolded,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteSearchRow(')
          ..write('noteId: $noteId, ')
          ..write('bodyFolded: $bodyFolded, ')
          ..write('photoFolded: $photoFolded, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, bodyFolded, photoFolded, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteSearchRow &&
          other.noteId == this.noteId &&
          other.bodyFolded == this.bodyFolded &&
          other.photoFolded == this.photoFolded &&
          other.attempts == this.attempts);
}

class NoteSearchCompanion extends UpdateCompanion<NoteSearchRow> {
  final Value<int> noteId;
  final Value<String> bodyFolded;
  final Value<String?> photoFolded;
  final Value<int> attempts;
  const NoteSearchCompanion({
    this.noteId = const Value.absent(),
    this.bodyFolded = const Value.absent(),
    this.photoFolded = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  NoteSearchCompanion.insert({
    this.noteId = const Value.absent(),
    this.bodyFolded = const Value.absent(),
    this.photoFolded = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  static Insertable<NoteSearchRow> custom({
    Expression<int>? noteId,
    Expression<String>? bodyFolded,
    Expression<String>? photoFolded,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (bodyFolded != null) 'body_folded': bodyFolded,
      if (photoFolded != null) 'photo_folded': photoFolded,
      if (attempts != null) 'attempts': attempts,
    });
  }

  NoteSearchCompanion copyWith({
    Value<int>? noteId,
    Value<String>? bodyFolded,
    Value<String?>? photoFolded,
    Value<int>? attempts,
  }) {
    return NoteSearchCompanion(
      noteId: noteId ?? this.noteId,
      bodyFolded: bodyFolded ?? this.bodyFolded,
      photoFolded: photoFolded ?? this.photoFolded,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (bodyFolded.present) {
      map['body_folded'] = Variable<String>(bodyFolded.value);
    }
    if (photoFolded.present) {
      map['photo_folded'] = Variable<String>(photoFolded.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteSearchCompanion(')
          ..write('noteId: $noteId, ')
          ..write('bodyFolded: $bodyFolded, ')
          ..write('photoFolded: $photoFolded, ')
          ..write('attempts: $attempts')
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
  late final $NoteSearchTable noteSearch = $NoteSearchTable(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notes,
    noteSearch,
    settingsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_search', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      required String imageName,
      Value<String> body,
      required DateTime createdAt,
      Value<Retention> retention,
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
      Value<int> customMinutes,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastSeenAt,
      Value<int> remindAfterDays,
    });

final class $$NotesTableReferences
    extends BaseReferences<_$NotesDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteSearchTable, List<NoteSearchRow>>
  _noteSearchRefsTable(_$NotesDatabase db) => MultiTypedResultKey.fromTable(
    db.noteSearch,
    aliasName: 'notes__id__note_search__note_id',
  );

  $$NoteSearchTableProcessedTableManager get noteSearchRefs {
    final manager = $$NoteSearchTableTableManager(
      $_db,
      $_db.noteSearch,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteSearchRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  Expression<bool> noteSearchRefs(
    Expression<bool> Function($$NoteSearchTableFilterComposer f) f,
  ) {
    final $$NoteSearchTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteSearch,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteSearchTableFilterComposer(
            $db: $db,
            $table: $db.noteSearch,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  Expression<T> noteSearchRefs<T extends Object>(
    Expression<T> Function($$NoteSearchTableAnnotationComposer a) f,
  ) {
    final $$NoteSearchTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteSearch,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteSearchTableAnnotationComposer(
            $db: $db,
            $table: $db.noteSearch,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({bool noteSearchRefs})
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
                customMinutes: customMinutes,
                expiresAt: expiresAt,
                lastSeenAt: lastSeenAt,
                remindAfterDays: remindAfterDays,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({noteSearchRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteSearchRefs) db.noteSearch],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteSearchRefs)
                    await $_getPrefetchedData<Note, $NotesTable, NoteSearchRow>(
                      currentTable: table,
                      referencedTable: $$NotesTableReferences
                          ._noteSearchRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NotesTableReferences(db, table, p0).noteSearchRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.noteId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
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
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({bool noteSearchRefs})
    >;
typedef $$NoteSearchTableCreateCompanionBuilder =
    NoteSearchCompanion Function({
      Value<int> noteId,
      Value<String> bodyFolded,
      Value<String?> photoFolded,
      Value<int> attempts,
    });
typedef $$NoteSearchTableUpdateCompanionBuilder =
    NoteSearchCompanion Function({
      Value<int> noteId,
      Value<String> bodyFolded,
      Value<String?> photoFolded,
      Value<int> attempts,
    });

final class $$NoteSearchTableReferences
    extends BaseReferences<_$NotesDatabase, $NoteSearchTable, NoteSearchRow> {
  $$NoteSearchTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$NotesDatabase db) =>
      db.notes.createAlias('note_search__note_id__notes__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteSearchTableFilterComposer
    extends Composer<_$NotesDatabase, $NoteSearchTable> {
  $$NoteSearchTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bodyFolded => $composableBuilder(
    column: $table.bodyFolded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoFolded => $composableBuilder(
    column: $table.photoFolded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteSearchTableOrderingComposer
    extends Composer<_$NotesDatabase, $NoteSearchTable> {
  $$NoteSearchTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bodyFolded => $composableBuilder(
    column: $table.bodyFolded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoFolded => $composableBuilder(
    column: $table.photoFolded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteSearchTableAnnotationComposer
    extends Composer<_$NotesDatabase, $NoteSearchTable> {
  $$NoteSearchTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bodyFolded => $composableBuilder(
    column: $table.bodyFolded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoFolded => $composableBuilder(
    column: $table.photoFolded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteSearchTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $NoteSearchTable,
          NoteSearchRow,
          $$NoteSearchTableFilterComposer,
          $$NoteSearchTableOrderingComposer,
          $$NoteSearchTableAnnotationComposer,
          $$NoteSearchTableCreateCompanionBuilder,
          $$NoteSearchTableUpdateCompanionBuilder,
          (NoteSearchRow, $$NoteSearchTableReferences),
          NoteSearchRow,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteSearchTableTableManager(_$NotesDatabase db, $NoteSearchTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteSearchTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteSearchTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteSearchTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> noteId = const Value.absent(),
                Value<String> bodyFolded = const Value.absent(),
                Value<String?> photoFolded = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => NoteSearchCompanion(
                noteId: noteId,
                bodyFolded: bodyFolded,
                photoFolded: photoFolded,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> noteId = const Value.absent(),
                Value<String> bodyFolded = const Value.absent(),
                Value<String?> photoFolded = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => NoteSearchCompanion.insert(
                noteId: noteId,
                bodyFolded: bodyFolded,
                photoFolded: photoFolded,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteSearchTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
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
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$NoteSearchTableReferences
                                    ._noteIdTable(db),
                                referencedColumn: $$NoteSearchTableReferences
                                    ._noteIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$NoteSearchTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $NoteSearchTable,
      NoteSearchRow,
      $$NoteSearchTableFilterComposer,
      $$NoteSearchTableOrderingComposer,
      $$NoteSearchTableAnnotationComposer,
      $$NoteSearchTableCreateCompanionBuilder,
      $$NoteSearchTableUpdateCompanionBuilder,
      (NoteSearchRow, $$NoteSearchTableReferences),
      NoteSearchRow,
      PrefetchHooks Function({bool noteId})
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
  $$NoteSearchTableTableManager get noteSearch =>
      $$NoteSearchTableTableManager(_db, _db.noteSearch);
  $$SettingsTableTableTableManager get settingsTable =>
      $$SettingsTableTableTableManager(_db, _db.settingsTable);
}
