import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart';

import '../domain/retention.dart';
import 'notes_database.dart';
import 'photo_store.dart';

/// Arayüzün veriye tek giriş kapısı.
///
/// Ekranlar Drift'i veya dosya sistemini doğrudan tanımaz; hepsi buradan geçer.
class NotesRepository {
  NotesRepository({required NotesDatabase database, required PhotoStore photos})
    : _db = database,
      _store = photos;

  final NotesDatabase _db;
  final PhotoStore _store;

  /// Yeniden eskiye sıralı canlı akış. Drift her yazmadan sonra kendiliğinden
  /// yeni değer yayar, ekranlar elle tazeleme yapmaz.
  Stream<List<Note>> watchNotes() {
    final query = _db.select(_db.notes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
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

    return _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            imageName: imageName,
            body: Value(body.trim()),
            createdAt: stamp,
            retention: Value(retention.retention),
            customMinutes: Value(retention.customMinutes),
            expiresAt: Value(retention.expiryFrom(stamp)),
            remindAfterDays: Value(remindAfterDays),
          ),
        );
  }

  /// Metni ve saklama süresini günceller.
  ///
  /// Süre her zaman *oluşturma* anına göre yeniden hesaplanır; düzenleme notun
  /// ömrünü uzatmaz.
  Future<void> update(
    Note note, {
    required String body,
    required RetentionChoice retention,
  }) {
    final query = _db.update(_db.notes)..where((t) => t.id.equals(note.id));
    return query.write(
      NotesCompanion(
        body: Value(body.trim()),
        retention: Value(retention.retention),
        customMinutes: Value(retention.customMinutes),
        expiresAt: Value(retention.expiryFrom(note.createdAt)),
      ),
    );
  }

  /// Nota ve karesindeki yazıya göre arar.
  ///
  /// Sorgu iki alanda birden geçer: kullanıcının yazdığı not ve **görünmeyen**
  /// OCR metni. İkincisi sayesinde "4521" yazınca fişin kendisi bulunuyor —
  /// kullanıcı o numarayı nota hiç yazmamış olsa bile.
  /// Tek bir kaydın sorguyla eşleşip eşleşmediği.
  ///
  /// Saf fonksiyon: akışı değiştirmeden listeyi süzmek için arayüz de bunu
  /// çağırıyor. Böylece arama, veri katmanıyla aynı kuralı kullanıyor.
  static bool matches(Note note, String query) {
    final needle = _foldTurkish(query.trim());
    if (needle.isEmpty) return true;
    return _foldTurkish('${note.body} ${note.ocrText ?? ''}').contains(needle);
  }

  /// Eşleşme **yalnızca** karedeki yazıdan mı geliyor?
  ///
  /// Arayüz bunu işaretlemek zorunda: notu "Fiş" olan bir kayıt "4521"
  /// aramasında çıktığında, sebebi görünmüyorsa kullanıcı bunu hata sanar.
  static bool matchedInPhotoOnly(Note note, String query) {
    final needle = _foldTurkish(query.trim());
    if (needle.isEmpty) return false;
    final inBody = _foldTurkish(note.body).contains(needle);
    final inPhoto = _foldTurkish(note.ocrText ?? '').contains(needle);
    return inPhoto && !inBody;
  }

  Stream<List<Note>> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return watchNotes();

    // Türkçe'de büyük/küçük harf eşlemesi SQLite'ın ASCII `LIKE`'ıyla doğru
    // çalışmıyor (`İ`/`i`, `I`/`ı`). Karşılaştırmayı Dart tarafında yapmak
    // hem doğru hem de bu boyuttaki bir listede yeterince hızlı.
    return watchNotes().map(
      (notes) => notes.where((note) => matches(note, trimmed)).toList(),
    );
  }

  /// Aramada büyük/küçük ve diakritik farklarını yok sayar.
  ///
  /// OCR `ı` ile `i`yi sık karıştırıyor; kullanıcının yazdığı da her zaman
  /// diakritikli olmuyor. İkisini de sadeleştirmek eşleşme şansını artırıyor.
  static String _foldTurkish(String value) {
    const map = {
      'ı': 'i', 'İ': 'i', 'I': 'i', 'i': 'i',
      'ğ': 'g', 'Ğ': 'g',
      'ü': 'u', 'Ü': 'u',
      'ş': 's', 'Ş': 's',
      'ö': 'o', 'Ö': 'o',
      'ç': 'c', 'Ç': 'c',
    };
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      buffer.write(map[char] ?? char.toLowerCase());
    }
    return buffer.toString();
  }

  /// Tek bir kaydı okur. Yazılan değerin doğrulanması için.
  Future<Note?> noteById(int id) {
    final query = _db.select(_db.notes)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Arka planda okunan kare yazısını kaydeder.
  Future<void> saveOcrText(int id, String text) {
    final query = _db.update(_db.notes)..where((t) => t.id.equals(id));
    return query.write(NotesCompanion(ocrText: Value(text)));
  }

  /// Henüz taranmamış kayıtlar. Uygulama eskiden kalan kareleri de indeksler.
  Future<List<Note>> unscanned({int limit = 20}) {
    final query = _db.select(_db.notes)
      ..where((t) => t.ocrText.isNull())
      ..limit(limit);
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
