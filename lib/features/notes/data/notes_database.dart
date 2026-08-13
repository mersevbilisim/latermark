import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../core/theme/app_accent.dart';
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

  /// "Beni bu kadar gün sonra hatırlat." `0` ise hatırlatma yok.
  ///
  /// Hatırlatma isteğe bağlıdır ve **not başına** verilir. Eskiden her kayda
  /// otomatik kurulurdu; yüzlerce notu olan biri bakmadığı her kare için
  /// bildirim alıyordu. Üstelik iOS aynı anda yalnızca 64 bekleyen bildirim
  /// tutar — otomatik kurulum o sınırı sessizce aşıyordu.
  IntColumn get remindAfterDays => integer().withDefault(const Constant(0))();

  /// Hatırlatma sayacının başladığı an.
  ///
  /// Karenin [createdAt] damgasından ayrıdır: galeriden eski bir fotoğraf
  /// alınabilir veya yıllar önceki bir nota bugün hatırlatma eklenebilir.
  /// Kullanıcının yazdığı "30 gün", ayarlandığı andan itibaren sayar.
  /// Aralık ya da tekrar kipi değiştirilmedikçe bu damga korunur; uygulamayı
  /// açmak geri sayımı başa sarmaz.
  DateTimeColumn get reminderAnchorAt => dateTime().nullable()();

  /// Hatırlatma [remindAfterDays] günde bir tekrarlansın mı.
  ///
  /// `false` iken kayıt tek bir kez, [reminderAnchorAt] +
  /// [remindAfterDays] anında hatırlatılır. `true` iken aynı aralık,
  /// kullanıcı kapatana ya da not silinene kadar sistem tarafında tekrar
  /// eder.
  ///
  /// Ayrı bir "tekrar aralığı" sütunu yok, olması da gerekmiyor: kullanıcı tek
  /// bir sayı veriyor ve o sayı iki modda da aynı şeyi söylüyor. İkinci bir
  /// sütun, ikisinin birbirinden kayabildiği bir durum yaratırdı.
  BoolColumn get remindRepeats =>
      boolean().withDefault(const Constant(false))();
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
  int get schemaVersion => 6;

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
      // Varsayılan `false`: mevcut hatırlatmaların hepsi tek atışlıktı ve öyle
      // kalır. Tekrar, kullanıcının açıkça isteyeceği yeni bir şey.
      if (from < 5) await m.addColumn(notes, notes.remindRepeats);
      if (from < 6) {
        await m.addColumn(notes, notes.reminderAnchorAt);
        // v5'in dörtlü pencere programı native, kalıcı tekrara dönüşüyor.
        // O programın kesin başlangıç damgası yoktu; mevcut tekrarlı
        // hatırlatmalar için dönüşüm anı yeni, dürüst başlangıçtır.
        await (update(notes)..where((note) => note.remindRepeats.equals(true)))
            .write(NotesCompanion(reminderAnchorAt: Value(DateTime.now())));
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
