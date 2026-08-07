import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../settings/domain/app_locale.dart';
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

  /// Karedeki yazının makine okuması. **Arayüzde hiç gösterilmez.**
  ///
  /// Tek işi aramayı beslemek: kullanıcı "4521" ya da "kombi" yazınca fişin
  /// kendisi bulunsun. Görünmediği için OCR hataları da görünmez — %80
  /// isabetle bile arama işe yarar, oysa aynı metni nota yazsaydık her hata
  /// kullanıcının düzeltmesi gereken bir kir olurdu.
  ///
  /// `null` = henüz taranmadı. Boş metin = tarandı, yazı bulunamadı.
  TextColumn get ocrText => text().nullable()();

  /// Özel saklama süresi (dakika). Yalnızca [Retention.custom] için anlamlı.
  ///
  /// Ayrı sütun gerekiyor: enum indeksi sabit bir değer taşır, kullanıcının
  /// seçtiği süre ise her kayıtta farklı olabilir.
  IntColumn get customMinutes => integer().withDefault(const Constant(0))();

  /// Süreli notlar için hesaplanmış silinme anı; süresizse `null`.
  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// Nota en son ne zaman bakıldığı. Detay ekranında tazelenir.
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  /// "Beni bu kadar gün sonra hatırlat." `0` ise hatırlatma yok.
  ///
  /// Hatırlatma isteğe bağlıdır ve **not başına** verilir. Eskiden her kayda
  /// otomatik kurulurdu; yüzlerce notu olan biri bakmadığı her kare için
  /// bildirim alıyordu. Üstelik iOS aynı anda yalnızca 64 bekleyen bildirim
  /// tutar — otomatik kurulum o sınırı sessizce aşıyordu.
  IntColumn get remindAfterDays => integer().withDefault(const Constant(0))();
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

  /// Varsayılan koyu (index 2): uygulama fotoğrafın önde durduğu bir arayüz
  /// ve karanlık zemin kareyi öne çıkarıyor.
  IntColumn get themeMode =>
      intEnum<AppThemeMode>().withDefault(const Constant(2))();

  /// Varsayılan ızgara (index 1): uygulama ilk açıldığında daha çok kayıt
  /// tek bakışta görünsün.
  IntColumn get density =>
      intEnum<FeedDensity>().withDefault(const Constant(1))();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Yeni kayıtların varsayılan saklama süresi.
  ///
  /// Otomatik silme artık her çekimde sorulmaz; buradan bir kez seçilir ve
  /// kayıtlar onunla açılır. Böylece çekim akışında tek bir karar kalır.
  IntColumn get defaultRetention =>
      intEnum<Retention>().withDefault(const Constant(0))();

  /// Dil tercihi. Varsayılan sistem dili.
  IntColumn get locale => intEnum<AppLocale>().withDefault(const Constant(0))();

  /// Yeni kayıtların varsayılan özel süresi (dakika).
  IntColumn get defaultCustomMinutes =>
      integer().withDefault(const Constant(0))();

  /// Pro hakkının son bilinen durumu.
  ///
  /// Doğruluk kaynağı **mağaza**; bu yalnızca önbellek. Soğuk açılışta mağaza
  /// cevabı gelene kadar ödemiş bir kullanıcıya paywall göstermemek için var.
  BoolColumn get proUnlocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes, SettingsTable])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase() : super(driftDatabase(name: 'not_app'));

  /// Test ve önizleme için bellek içi/özel bağlantı.
  NotesDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(notes, notes.lastSeenAt);
        await m.createTable(settingsTable);
      }
      if (from < 3) {
        await m.addColumn(notes, notes.remindAfterDays);
        // Hatırlatma süresi artık genel bir tercih değil, notun kendi alanı.
        // Sütunu düşürmek tabloyu yeniden kurmayı gerektiriyor.
        await m.alterTable(
          TableMigration(
            settingsTable,
            newColumns: [settingsTable.defaultRetention],
          ),
        );
      }
      if (from < 4) {
        await m.addColumn(settingsTable, settingsTable.locale);
      }
      if (from < 5) {
        await m.addColumn(settingsTable, settingsTable.proUnlocked);
      }
      if (from < 6) {
        await m.addColumn(notes, notes.customMinutes);
        await m.addColumn(settingsTable, settingsTable.defaultCustomMinutes);
      }
      if (from < 7) {
        await m.addColumn(notes, notes.ocrText);
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
