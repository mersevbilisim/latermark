import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../settings/domain/app_locale.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/retention.dart';
import 'search_text.dart';

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

/// Aramanın beslendiği yan tablo. **Arayüz bu tabloyu hiç okumaz.**
///
/// Ayrı durmasının sebebi mimari, düzen değil: [Notes] üzerindeki her yazma
/// Drift'in `watch` akışını yeniden yayar ve akış her satırı **bütün
/// sütunlarıyla** Dart'a taşır. OCR metni not satırındayken bir A4 sayfası
/// dolusu yazı, notu açmak ya da süresi dolan bir kaydı silmek gibi arama ile
/// hiç ilgisi olmayan her olayda yeniden belleğe kopyalanıyordu. Üstelik
/// taramanın kendisi de not satırına yazdığı için akışı tetikliyordu: her
/// taranan kare tüm listeyi yeniden kurduruyordu.
///
/// Burada tutulduğunda arama metni yalnızca arama sorgusunun içinde, o da
/// veritabanının kendi isolate'inde var oluyor. UI thread'i hiç görmüyor.
@DataClassName('NoteSearchRow')
class NoteSearch extends Table {
  @override
  String get tableName => 'note_search';

  /// Notun kimliği. Not silinince satır de kendiliğinden gider — `beforeOpen`
  /// zaten `foreign_keys` açıyor.
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// Kullanıcının yazdığı notun katlanmış hâli.
  ///
  /// Katlama yazarken bir kez yapılıyor; arama anında yalnızca **sorgu**
  /// katlanıyor. Eskiden her tuş vuruşunda her kaydın metni yeniden
  /// katlanıyordu.
  TextColumn get bodyFolded => text().withDefault(const Constant(''))();

  /// Karedeki yazının katlanmış hâli. **Arayüzde hiç gösterilmez.**
  ///
  /// Tek işi aramayı beslemek: kullanıcı "4521" ya da "kombi" yazınca fişin
  /// kendisi bulunsun. Görünmediği için OCR hataları da görünmez — %80
  /// isabetle bile arama işe yarar, oysa aynı metni nota yazsaydık her hata
  /// kullanıcının düzeltmesi gereken bir kir olurdu.
  ///
  /// `null` = henüz okunamadı. Boş metin = tarandı, yazı bulunamadı.
  TextColumn get photoFolded => text().nullable()();

  /// Başarısız okuma sayısı.
  ///
  /// Sayaç olmadan bozuk ya da okunamayan tek bir kare, listedeki her
  /// değişimde yeniden taranıyordu — A4 boyunda bir karede bu her seferinde
  /// 1-2 saniye CPU ve boşa giden pil demek.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {noteId};
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

@DriftDatabase(tables: [Notes, NoteSearch, SettingsTable])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase() : super(driftDatabase(name: 'not_app'));

  /// Test ve önizleme için bellek içi/özel bağlantı.
  NotesDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 8;

  /// Taranmayı bekleyen kayıtların kısmi indeksi.
  ///
  /// `_scanPending` liste her değiştiğinde "sırada ne var?" diye soruyor.
  /// İndekssiz hâlde bu soru, her satırında bir sayfa dolusu metin taşıyan
  /// tabloyu baştan sona okumak demek. Kısmi indeks yalnızca bekleyenleri
  /// tuttuğu için her şey tarandığında **boş** kalıyor: yaygın durumda sorgu
  /// hiçbir veri sayfasına dokunmuyor.
  static const _pendingIndex =
      'CREATE INDEX IF NOT EXISTS note_search_pending '
      'ON note_search (note_id) WHERE photo_folded IS NULL';

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(_pendingIndex);
    },
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
        // v7'nin OCR sütunu v8'de yan tabloya taşındı. Burada eklenmesinin
        // sebebi aşağıdaki taşımanın onu okuyabilmesi: 6'dan 8'e atlayan bir
        // kurulumda sütun hiç var olmasaydı taşıma sorgusu patlardı.
        await m.database.customStatement(
          'ALTER TABLE notes ADD COLUMN ocr_text TEXT NULL',
        );
      }
      if (from < 8) {
        // Okunmuş yazıyı çöpe atmak, kullanıcının tüm arşivini yeniden
        // taratmak demek — kare başına 1-2 saniye CPU. Sütun düşmeden önce
        // FK'sız bir ara tabloya alınıyor.
        await m.database.customStatement(
          'CREATE TABLE _ocr_carry (note_id INTEGER NOT NULL, text TEXT NOT NULL)',
        );
        await m.database.customStatement(
          'INSERT INTO _ocr_carry (note_id, text) '
          'SELECT id, ocr_text FROM notes WHERE ocr_text IS NOT NULL',
        );

        // `notes` yeni tanımıyla yeniden kurulur; `ocrText` böylece düşer.
        // Yan tablo **sonra** yaratılıyor: rebuild sırasında ona bakan bir
        // yabancı anahtar bulunmasın.
        await m.alterTable(TableMigration(notes));
        await m.createTable(noteSearch);
        await m.database.customStatement(_pendingIndex);

        // Katlama Dart tarafında yapıldığı için satırlar sayfa sayfa geçiyor;
        // arşivin tamamını birden belleğe almanın gereği yok.
        const page = 200;
        for (var offset = 0; ; offset += page) {
          final rows = await m.database
              .customSelect(
                'SELECT n.id AS id, n.body AS body, c.text AS ocr '
                'FROM notes n LEFT JOIN _ocr_carry c ON c.note_id = n.id '
                'ORDER BY n.id LIMIT $page OFFSET $offset',
              )
              .get();
          if (rows.isEmpty) break;

          await m.database.batch(
            (batch) => batch.insertAll(noteSearch, [
              for (final row in rows)
                NoteSearchCompanion.insert(
                  noteId: Value(row.read<int>('id')),
                  bodyFolded: Value(SearchText.fold(row.read<String>('body'))),
                  photoFolded: Value(
                    switch (row.read<String?>('ocr')) {
                      final text? => SearchText.fold(
                        SearchText.normalize(text),
                      ),
                      null => null,
                    },
                  ),
                ),
            ]),
          );
          if (rows.length < page) break;
        }

        await m.database.customStatement('DROP TABLE _ocr_carry');
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
