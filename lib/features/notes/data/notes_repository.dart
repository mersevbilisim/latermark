import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart';

import '../domain/retention.dart';
import 'notes_database.dart';
import 'photo_store.dart';
import 'search_text.dart';

/// Bir aramanın sonucu: eşleşen kayıtların **kimlikleri**.
///
/// Metin değil kimlik taşınıyor. Eşleşmeyi veritabanı kendi isolate'inde
/// buluyor, arayüze yalnızca birkaç yüz bayt tam sayı geçiyor; sayfa dolusu
/// OCR metni UI thread'ine hiç uğramıyor.
class SearchHits {
  const SearchHits({
    required this.query,
    required this.ids,
    required this.photoOnly,
  });

  /// Süzme yok: arama kapalı ya da sorgu boş.
  static const none = SearchHits(
    query: '',
    ids: <int>{},
    photoOnly: <int>{},
  );

  /// Bu sonucu üreten katlanmış sorgu. Arayüz, geciken bir cevabın hâlâ
  /// ekrandaki metne ait olup olmadığını bununla anlıyor.
  final String query;

  final Set<int> ids;

  /// Eşleşmesi **yalnızca** karedeki yazıdan gelen kayıtlar.
  ///
  /// Arayüz bunu işaretlemek isteyebilir: notu "Fiş" olan bir kayıt "4521"
  /// aramasında çıktığında, sebebi görünmüyorsa kullanıcı bunu hata sanar.
  final Set<int> photoOnly;

  bool get filtering => query.isNotEmpty;

  bool contains(int id) => !filtering || ids.contains(id);
}

/// Arayüzün veriye tek giriş kapısı.
///
/// Ekranlar Drift'i veya dosya sistemini doğrudan tanımaz; hepsi buradan geçer.
class NotesRepository {
  NotesRepository({required NotesDatabase database, required PhotoStore photos})
    : _db = database,
      _store = photos;

  /// Okunamayan bir kare kaç kez yeniden denenir.
  ///
  /// Sınırsız deneme, bozuk ya da yazısız-ama-zor tek bir karenin listedeki
  /// her değişimde yeniden taranması demekti. Üç deneme, ML Kit modelinin
  /// Play Services'ten inmesini beklemeye fazlasıyla yeter; ötesi pil yakar.
  static const maxScanAttempts = 3;

  final NotesDatabase _db;
  final PhotoStore _store;

  /// Yeniden eskiye sıralı canlı akış. Drift her yazmadan sonra kendiliğinden
  /// yeni değer yayar, ekranlar elle tazeleme yapmaz.
  Stream<List<Note>> watchNotes() {
    final query = _db.select(_db.notes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  /// Yalnızca kayıt sayısı.
  ///
  /// Ayarlardaki Pro kartı doluluğu gösteriyor ama listeye ihtiyacı yok;
  /// `COUNT(*)` tek bir sayı döndürüyor, satırlar Dart'a hiç geçmiyor.
  Stream<int> watchNoteCount() {
    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// En yeni kayıtlar, en çok [limit] tane.
  ///
  /// Ayarlardaki kontakt baskısı ücretsiz katmanın gözlerini kullanıcının
  /// kendi kareleriyle dolduruyor; bunun için tüm arşivi taşımak gereksiz.
  Stream<List<Note>> watchRecent({required int limit}) {
    final query = _db.select(_db.notes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return query.watch();
  }

  Stream<Note?> watchNote(int id) {
    final query = _db.select(_db.notes)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull();
  }

  /// Kayıtlı bir notun fotoğrafını diskte gösterir.
  File imageOf(Note note) => _store.fileFor(note.imageName);

  /// Kamera çıktısını kalıcılaştırır ve notu yazar. Yeni notun kimliğini döner.
  ///
  /// [createdAt] verilmezse şimdiki an kullanılır. Çekim ekranı, kaydın
  /// zamanının *deklanşöre basıldığı an* olması için bunu açıkça geçer.
  Future<int> create({
    required XFile capture,
    required String body,
    required RetentionChoice retention,
    int remindAfterDays = 0,
    DateTime? createdAt,
  }) async {
    final stamp = createdAt ?? DateTime.now();
    final imageName = await _store.persist(capture);
    final text = body.trim();

    // Not ile indeks satırı **aynı işlemde** yazılıyor. Her notun bir indeks
    // satırı olması taramanın da aramanın da dayandığı değişmez: satırı
    // olmayan bir kayıt ne aranabilir ne de sıraya girer, üstelik ikisi de
    // sessizce olur.
    return _db.transaction(() async {
      final id = await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              imageName: imageName,
              body: Value(text),
              createdAt: stamp,
              retention: Value(retention.retention),
              customMinutes: Value(retention.customMinutes),
              expiresAt: Value(retention.expiryFrom(stamp)),
              remindAfterDays: Value(remindAfterDays),
            ),
          );

      await _db
          .into(_db.noteSearch)
          .insert(
            NoteSearchCompanion.insert(
              noteId: Value(id),
              bodyFolded: Value(SearchText.fold(text)),
            ),
          );

      return id;
    });
  }

  /// Notun yazısını ve hatırlatmasını günceller.
  ///
  /// Saklama süresine **dokunulmaz**. Süre artık kayıt başına düzenlenmiyor;
  /// Ayarlar'daki varsayılan, kayıt oluşurken bir kez uygulanıyor. Böylece
  /// düzenlemenin notun ömrünü uzatması da yapısal olarak imkânsız — eskiden
  /// bu, süreyi her seferinde oluşturma anına göre yeniden hesaplayan bir
  /// kuralla korunuyordu.
  Future<void> update(
    Note note, {
    required String body,
    required int remindAfterDays,
  }) {
    final text = body.trim();

    return _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
        NotesCompanion(
          body: Value(text),
          remindAfterDays: Value(remindAfterDays),
        ),
      );

      // İndeks nota bağlı kalmalı: düzenlenen bir not eski metniyle
      // bulunmaya devam ederse arama yalan söylüyor demektir.
      await (_db.update(
        _db.noteSearch,
      )..where((t) => t.noteId.equals(note.id))).write(
        NoteSearchCompanion(bodyFolded: Value(SearchText.fold(text))),
      );
    });
  }

  /// Nota ve karesindeki yazıya göre arar.
  ///
  /// Sorgu iki alanda birden geçer: kullanıcının yazdığı not ve **görünmeyen**
  /// OCR metni. İkincisi sayesinde "4521" yazınca fişin kendisi bulunuyor —
  /// kullanıcı o numarayı nota hiç yazmamış olsa bile.
  ///
  /// Eşleştirme SQL'de yapılıyor, Dart'ta değil. Eski hâl her tuş vuruşunda
  /// her kaydın metnini yeniden katlıyordu; bin notluk bir arşivde bu, tuş
  /// başına milyonlarca geçici nesne demekti — üstelik `build` içinde, yani
  /// doğrudan UI thread'inde. Şimdi metin veritabanının isolate'inden hiç
  /// çıkmıyor ve karşılaştırma önceden katlanmış sütunlar üzerinde dönüyor.
  ///
  /// `LIKE` deseni indeks kullanamaz, tabloyu tarar — ve bu bilinçli: "4521"
  /// aramasının fişin **ortasındaki** numarayı bulması bu özelliğin bütün
  /// değeri. FTS5 kelime başlarına bakar, o yüzden burada işe yaramaz.
  /// Tarama arka plan isolate'inde döndüğü için de arayüze yansımıyor.
  Future<SearchHits> search(String query) async {
    final needle = SearchText.fold(query.trim());
    if (needle.isEmpty) return SearchHits.none;

    final pattern = SearchText.likePattern(needle);
    final rows = await _db
        .customSelect(
          r"SELECT note_id, (body_folded LIKE ? ESCAPE '\') AS in_body "
          r"FROM note_search "
          r"WHERE body_folded LIKE ? ESCAPE '\' "
          r"   OR photo_folded LIKE ? ESCAPE '\'",
          variables: [
            Variable<String>(pattern),
            Variable<String>(pattern),
            Variable<String>(pattern),
          ],
          readsFrom: {_db.noteSearch},
        )
        .get();

    final ids = <int>{};
    final photoOnly = <int>{};
    for (final row in rows) {
      final id = row.read<int>('note_id');
      ids.add(id);
      if (row.read<int>('in_body') == 0) photoOnly.add(id);
    }

    return SearchHits(query: needle, ids: ids, photoOnly: photoOnly);
  }

  /// Tek bir kaydı okur.
  Future<Note?> noteById(int id) {
    final query = _db.select(_db.notes)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Arka planda okunan kare yazısını indekse yazar.
  ///
  /// [text] `null` ise okuma **başarısız** olmuştur: metin yazılmaz, yalnızca
  /// deneme sayacı artar. Boş dize ise kare okundu ama yazı yok demektir ve
  /// kayıt taranmış sayılır.
  ///
  /// Yazma yalnızca `note_search`'e gidiyor; `notes` tablosuna dokunulmuyor.
  /// Bu kritik: eskiden her tarama sonucu not satırını güncelliyor, bu da
  /// `watchNotes` akışını yeniden yaydırıyordu — yani her taranan kare tüm
  /// listeyi baştan kurduruyordu. Arşiv büyüdükçe tarama kendi kuyruğunu
  /// yavaşlatıyordu.
  Future<void> saveScan(int id, String? text) async {
    if (text == null) {
      await _db.customStatement(
        'UPDATE note_search SET attempts = attempts + 1 WHERE note_id = ?',
        [id],
      );
      return;
    }

    final folded = SearchText.fold(SearchText.normalize(text));
    final written =
        await (_db.update(_db.noteSearch)
              ..where((t) => t.noteId.equals(id)))
            .write(
              NoteSearchCompanion(
                photoFolded: Value(folded),
                attempts: const Value(0),
              ),
            );
    if (written > 0) return;

    // İndeks satırı yoksa kendini onarır. Buraya normalde hiç girilmez —
    // satır notla aynı işlemde yaratılıyor — ama girilirse kaydın sonsuza
    // dek yeniden taranmasındansa satırın tamamlanması yeğdir.
    final note = await noteById(id);
    if (note == null) return;
    await _db
        .into(_db.noteSearch)
        .insert(
          NoteSearchCompanion.insert(
            noteId: Value(id),
            bodyFolded: Value(SearchText.fold(note.body)),
            photoFolded: Value(folded),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Sırada bekleyen kayıtlar: hiç okunamamış ve deneme hakkı kalmış olanlar.
  ///
  /// Önce indeks tablosuna soruluyor, sonra çıkan kimlikler için not satırı
  /// alınıyor. Tek bir birleşim sorgusu yerine iki adım olmasının sebebi
  /// `note_search_pending` kısmi indeksi: her şey tarandığında o indeks boş
  /// olduğu için sorgu hiçbir veri sayfasına dokunmuyor. Bu sorgu listedeki
  /// **her** değişimde çalıştığı için ucuz olması önemli.
  Future<List<Note>> unscanned({int limit = 20}) async {
    final pending =
        await (_db.selectOnly(_db.noteSearch)
              ..addColumns([_db.noteSearch.noteId])
              ..where(
                _db.noteSearch.photoFolded.isNull() &
                    _db.noteSearch.attempts.isSmallerThanValue(
                      maxScanAttempts,
                    ),
              )
              ..limit(limit))
            .get();
    if (pending.isEmpty) return const [];

    final ids = [
      for (final row in pending) row.read(_db.noteSearch.noteId)!,
    ];
    final query = _db.select(_db.notes)..where((t) => t.id.isIn(ids));
    return query.get();
  }

  /// Nota bakıldığını işaretler.
  ///
  /// Hatırlatıcı bu damgadan sayar; kaydı açmak hatırlatmayı ileri atar.
  Future<void> markSeen(int id) {
    final query = _db.update(_db.notes)..where((t) => t.id.equals(id));
    return query.write(NotesCompanion(lastSeenAt: Value(DateTime.now())));
  }

  /// Notu ve fotoğrafını birlikte siler.
  Future<void> delete(Note note) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(note.id))).go();
    await _store.remove(note.imageName);
  }

  /// Süresi dolmuş notları temizler. Açılışta, uygulama öne geldiğinde ve
  /// önplandayken dakikada bir çalışır.
  ///
  /// Silinen not sayısını döner.
  Future<int> purgeExpired() async {
    final now = DateTime.now();
    final query = _db.select(_db.notes)
      ..where((t) => t.expiresAt.isSmallerOrEqualValue(now));
    final expired = await query.get();
    if (expired.isEmpty) return 0;

    final ids = expired.map((note) => note.id).toList();
    await (_db.delete(_db.notes)..where((t) => t.id.isIn(ids))).go();
    await _store.removeAll(expired.map((note) => note.imageName));
    return expired.length;
  }

  /// Kaydı olmayan fotoğrafları diskten atar. Yalnızca açılışta çağrılır.
  Future<void> sweepOrphanFiles() async {
    final rows = await _db.select(_db.notes).get();
    await _store.pruneOrphans(rows.map((note) => note.imageName).toSet());
  }

  Future<void> close() => _db.close();
}
