import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../core/theme/app_accent.dart';
import '../../settings/domain/app_locale.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/note_reminder.dart';
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

  /// Notun yazısının en son ne zaman değiştirildiği; **hiç düzenlenmediyse
  /// `null`**.
  ///
  /// Göçte eski kayıtlara `createdAt` yazılmıyor. Yazılsaydı arşivdeki her not
  /// "düzenlenmiş" görünürdü — oysa hiçbiri düzenlenmedi. `null`, "bu kayda
  /// çekildiğinden beri dokunulmadı" demenin dürüst yolu.
  ///
  /// Kaydın **ömrünü etkilemez**: silinme anı her zaman [createdAt]'ten
  /// hesaplanır, düzenlemek notun ömrünü uzatmaz.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Karenin çekildiği yerin koordinatları; bilinmiyorsa ikisi de `null`.
  ///
  /// **Yer adı saklanmıyor, saklanamaz da.** "41.2607, 29.0421" değerini
  /// "Uludağ, Bursa"ya çevirmek ters geocoding ister ve hem Apple hem Google
  /// bunu kendi sunucularında yapar — yani koordinat cihazdan çıkar. Bu
  /// uygulamanın verdiği söz bunu kaldırmıyor. Koordinat burada durur,
  /// kullanıcı dokunduğunda haritayı **o** açar.
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  /// Hatırlatmanın geleceği an; hatırlatma yoksa `null`.
  ///
  /// Kayıt "kaç gün sonra" değil **hangi an** tutuyor. Gün sayısı saklamak,
  /// kullanıcının gördüğü tarihi ikinci bir hesaba bağımlı kılıyordu: çıpa +
  /// gün. O hesap yedekten dönüşte, yaz saati geçişinde ve ertelemede yeniden
  /// kuruluyor, dolayısıyla kayabiliyordu. Takvimden gün seçilebildiği anda
  /// artık savunulamaz da: kullanıcı "6 Eylül" diyorsa kayıtta 6 Eylül
  /// yazmalı. Bildirim de zaten mutlak bir an istiyor.
  ///
  /// Hatırlatma isteğe bağlıdır ve **not başına** verilir. Eskiden her kayda
  /// otomatik kurulurdu; yüzlerce notu olan biri bakmadığı her kare için
  /// bildirim alıyordu. Üstelik iOS aynı anda yalnızca 64 bekleyen bildirim
  /// tutar — otomatik kurulum o sınırı sessizce aşıyordu.
  ///
  /// Geçmişte kalmış bir an "bu not hatırlatıldı" demektir. Kayıt kullanıcı
  /// kapatana ya da yeni bir gün seçene kadar durur.
  DateTimeColumn get remindAt => dateTime().nullable()();

  /// Tekrar aralığı (gün). `0` ise hatırlatma tek atışlıktır.
  ///
  /// Tekrar için ayrı bir bayrak yok, olması da gerekmiyor: aralık hem "tekrar
  /// var mı" sorusunun hem de "ne kadarda bir" sorusunun cevabı. İki ayrı alan,
  /// birbirinden kayabildikleri (tekrar açık ama aralık sıfır) bir durum
  /// yaratırdı.
  ///
  /// Tekrar açıkken kayıt [remindAt] + k·aralık dizisini üretir; işletim
  /// sistemi tarafında da kullanıcı kapatana ya da not silinene kadar sürer.
  IntColumn get remindEveryDays => integer().withDefault(const Constant(0))();
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

  /// [photoFolded] içeriğinin sürümler arasında kararlı özeti. Spotlight her
  /// açılışta sayfa dolusu OCR metnini belleğe almadan gerçek içerik
  /// değişikliğini bununla görür.
  TextColumn get photoFingerprint => text().nullable()();

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

  /// Küratörlü uygulama vurgu rengi. Turuncu (index 0) eski görünümü korur.
  IntColumn get accent => intEnum<AppAccent>().withDefault(const Constant(0))();

  /// Varsayılan ızgara (index 1): uygulama ilk açıldığında daha çok kayıt
  /// tek bakışta görünsün.
  IntColumn get density =>
      intEnum<FeedDensity>().withDefault(const Constant(1))();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Yeni kayıtlara çekim yeri iliştirilsin mi.
  ///
  /// Varsayılan **kapalı**. Gizlilik iddiası olan bir uygulama konum
  /// toplamaya sessizce başlamaz; anahtar açıldığında izin istenir.
  BoolColumn get locationEnabled =>
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

  /// Paylaşılan notun sonuna Latermark satırı eklensin mi.
  ///
  /// Varsayılan **açık**: imza uygulamanın kendini tanıtma yolu. Kullanıcının
  /// yazdığı metne dokunulduğu için de kapatılabilir olması şart — kapalıyken
  /// mesaj tam olarak notun kendisidir.
  BoolColumn get shareSignature =>
      boolean().withDefault(const Constant(true))();

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
  NotesDatabase() : super(driftDatabase(name: 'latermark_db'));

  /// Test ve önizleme için bellek içi/özel bağlantı.
  NotesDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 9;

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

  /// Uygulama verisiyle birlikte atomik tamamlanması gereken, uygulama-içi
  /// işlemlerin küçük kayıt defterleri.
  ///
  /// Bunlar Drift modeline bilinçli olarak eklenmiyor: kullanıcı verisi değil,
  /// teslim/taşıma protokolünün durumudur. `IF NOT EXISTS` sayesinde eski ve
  /// yeni bütün şemalarda güvenle kurulabilir; schemaVersion'ı sırf bu iç
  /// ayrıntı için yükseltmek gerekmez.
  static const _operationTables = '''
    CREATE TABLE IF NOT EXISTS processed_imports (
      import_id TEXT NOT NULL PRIMARY KEY,
      note_id INTEGER NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      processed_at INTEGER NULL
    );
    CREATE TABLE IF NOT EXISTS processed_reminder_actions (
      event_id TEXT NOT NULL PRIMARY KEY,
      processed_at INTEGER NOT NULL
    );
  ''';

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(_pendingIndex);
    },
    // `latermark_db` v1 zaten not, arama ve ayar tablolarının güncel temelini
    // içeriyor. Önceki `not_app` sürüm zincirini burada tekrar yürütmek v1
    // sütunlarını ikinci kez eklerdi. Bu veritabanının ilk ve tek yükseltmesi
    // seçilen rengi, mevcut satırı ve varsayılan turuncuyu koruyarak ekler.
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(settingsTable, settingsTable.accent);
      // Sütun nullable ve geri doldurulmuyor: mevcut kayıtlar düzenlenmedi.
      if (from < 3) await m.addColumn(notes, notes.updatedAt);
      if (from < 4) {
        await m.addColumn(notes, notes.latitude);
        await m.addColumn(notes, notes.longitude);
        await m.addColumn(settingsTable, settingsTable.locationEnabled);
      }
      // v5 ve v6'nın eklediği iki sütun v8'de yeniden kaldırılıyor; buradaki
      // adımlar yine de duruyor ve ham SQL'e çevrildi. Drift'in tablo tanımı
      // yalnızca **bugünkü** sütunları biliyor, oysa göç zinciri geçmişte
      // gerçekten olanı anlatmak zorunda: v8'in dönüşümü bu iki sütunu okuyor.
      //
      // Varsayılan `false`: o sürümdeki hatırlatmaların hepsi tek atışlıktı ve
      // öyle kalır. Tekrar, kullanıcının açıkça isteyeceği yeni bir şeydi.
      if (from < 5) {
        await customStatement(
          'ALTER TABLE notes ADD COLUMN remind_repeats '
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 6) {
        await customStatement(
          'ALTER TABLE notes ADD COLUMN reminder_anchor_at INTEGER NULL',
        );
        // v5'in dörtlü pencere programı native, kalıcı tekrara dönüşüyor.
        // O programın kesin başlangıç damgası yoktu; mevcut tekrarlı
        // hatırlatmalar için dönüşüm anı yeni, dürüst başlangıçtır.
        await customUpdate(
          'UPDATE notes SET reminder_anchor_at = ? WHERE remind_repeats = 1',
          variables: [
            Variable<int>(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          ],
          updates: {notes},
        );
      }
      if (from < 7) {
        await m.addColumn(noteSearch, noteSearch.photoFingerprint);
        const page = 200;
        for (var offset = 0; ; offset += page) {
          final rows = await customSelect(
            'SELECT note_id, photo_folded FROM note_search '
            'WHERE photo_folded IS NOT NULL '
            'ORDER BY note_id LIMIT $page OFFSET $offset',
          ).get();
          if (rows.isEmpty) break;
          for (final row in rows) {
            final text = row.read<String>('photo_folded');
            await customUpdate(
              'UPDATE note_search SET photo_fingerprint = ? '
              'WHERE note_id = ?',
              variables: [
                Variable<String>(SearchText.fingerprint(text)),
                Variable<int>(row.read<int>('note_id')),
              ],
              updates: {noteSearch},
            );
          }
          if (rows.length < page) break;
        }
      }
      if (from < 8) {
        // Hatırlatma "çıpa + gün sayısı" olmaktan çıkıp mutlak ana dönüyor.
        // Gün sütunu kaybolmuyor, anlamı daralıyor: artık yalnızca tekrar
        // aralığı.
        await m.addColumn(notes, notes.remindAt);
        await m.renameColumn(notes, 'remind_after_days', notes.remindEveryDays);

        // Dönüşüm SQL'de değil Dart'ta yapılıyor: `+ gün·86400` yaz saati
        // geçişini aşan kayıtlarda duvar saatini bir saat kaydırırdı ve
        // kullanıcı kurduğu hatırlatmanın saatini bir daha göremezdi.
        // Sütunlar unix **saniye** tutuyor.
        final pending = await customSelect(
          'SELECT id, created_at, reminder_anchor_at, remind_every_days, '
          'remind_repeats FROM notes WHERE remind_every_days > 0',
        ).get();
        for (final row in pending) {
          final everyDays = row.read<int>('remind_every_days');
          final anchorSeconds =
              row.readNullable<int>('reminder_anchor_at') ??
              row.read<int>('created_at');
          final at = shiftLocalCalendarDays(
            DateTime.fromMillisecondsSinceEpoch(anchorSeconds * 1000),
            everyDays,
          );
          await customUpdate(
            'UPDATE notes SET remind_at = ?, remind_every_days = ? '
            'WHERE id = ?',
            variables: [
              Variable<int>(at.millisecondsSinceEpoch ~/ 1000),
              // Tek atışlık kayıtlarda aralığın işi kalmadı: o sayı zaten
              // yalnızca ilk anı bulmak içindi ve o an artık sütunda duruyor.
              Variable<int>(
                row.read<int>('remind_repeats') != 0 ? everyDays : 0,
              ),
              Variable<int>(row.read<int>('id')),
            ],
            updates: {notes},
          );
        }

        await m.dropColumn(notes, 'reminder_anchor_at');
        await m.dropColumn(notes, 'remind_repeats');
      }
      if (from < 9) {
        // Sütunun varsayılanı açık; mevcut satırlar da öyle doluyor. İmza yeni
        // bir davranış ama kullanıcının metnine ekleniyor, o yüzden anahtar
        // Ayarlar'da görünür yerde duruyor.
        await m.addColumn(settingsTable, settingsTable.shareSignature);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      for (final statement in _operationTables.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
      await customStatement(
        'DELETE FROM processed_reminder_actions WHERE processed_at < ?',
        [
          DateTime.now()
              .subtract(const Duration(days: 180))
              .millisecondsSinceEpoch,
        ],
      );
      // Bildirim düğmeleri uygulamanınkinden **ayrı bir Flutter motorunda**
      // işleniyor ve o motor aynı dosyaya ikinci bir bağlantı açıyor.
      // Drift'in `shareAcrossIsolates` seçeneği burada işe yaramaz: bağımsız
      // motorlar ortak `IsolateNameServer`'ı paylaşmıyor.
      //
      // SQLite'ın varsayılan meşguliyet zaman aşımı **sıfır** — iki bağlantı
      // aynı ana denk gelirse yazan taraf hiç beklemeden `database is locked`
      // alır. Yazmalar milisaniyelik olduğundan birkaç saniyelik bekleme, o
      // çakışmayı kullanıcının hiç görmediği kısa bir gecikmeye çeviriyor.
      await customStatement('PRAGMA busy_timeout = 4000');
      // Tercih satırı her zaman var olmalı; yoksa varsayılanlarla yaratılır.
      // Zaten varsa dokunulmaz.
      await into(settingsTable).insert(
        const SettingsTableCompanion(id: Value(1)),
        mode: InsertMode.insertOrIgnore,
      );
    },
  );
}
