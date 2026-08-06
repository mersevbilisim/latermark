import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../settings/domain/app_settings.dart';
import '../domain/retention.dart';

part 'notes_database.g.dart';

/// Tek amaç: bir fotoğraf + bir not + bir zaman damgası.
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Yalnızca dosya adı saklanır (ör. `1754...-4821.jpg`).
  ///
  /// Mutlak yol saklamak iOS'ta hataya yol açar: uygulama konteyner yolu her
  /// kurulumda değişir ve kayıtlı yollar geçersizleşir. Klasör her açılışta
  /// fotoğraf deposu tarafından yeniden çözülür.
  TextColumn get imageName => text()();

  TextColumn get body => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get retention =>
      intEnum<Retention>().withDefault(const Constant(0))();

  /// Süreli notlar için hesaplanmış silinme anı; süresizse `null`.
  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// Nota en son ne zaman bakıldığı.
  ///
  /// Hatırlatıcı bunun üzerine kurulur: "şu kadar gün bakmazsan hatırlat".
  /// Kayıt açıldığında tazelenir, böylece hatırlatma ileri atılır.
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
}

/// Tek satırlık tercih tablosu.
///
/// Ayrı bir tercih paketi yerine burada durması, ayarların da Drift akışıyla
/// canlı yayınlanmasını sağlıyor: tema değiştiğinde arayüz kendiliğinden döner.
@DataClassName('SettingsRow')
class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  /// Her zaman 1. Tabloda tek satır bulunur.
  IntColumn get id => integer().withDefault(const Constant(1))();

  IntColumn get themeMode =>
      intEnum<AppThemeMode>().withDefault(const Constant(0))();

  IntColumn get density =>
      intEnum<FeedDensity>().withDefault(const Constant(0))();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  IntColumn get reminderDelay =>
      intEnum<ReminderDelay>().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes, SettingsTable])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase() : super(driftDatabase(name: 'not_app'));

  /// Test ve önizleme için bellek içi/özel bağlantı.
  NotesDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(notes, notes.lastSeenAt);
        await m.createTable(settingsTable);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Tercih satırı her zaman var olmalı; yoksa varsayılanlarla yaratılır.
      // Zaten varsa dokunulmaz.
      await into(settingsTable).insert(
        const SettingsTableCompanion(id: Value(1)),
        mode: InsertMode.insertOrIgnore,
      );
    },
  );
}
