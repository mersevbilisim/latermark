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
    required Retention retention,
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
            retention: Value(retention),
            expiresAt: Value(retention.expiryFrom(stamp)),
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
    required Retention retention,
  }) {
    final query = _db.update(_db.notes)..where((t) => t.id.equals(note.id));
    return query.write(
      NotesCompanion(
        body: Value(body.trim()),
        retention: Value(retention),
        expiresAt: Value(retention.expiryFrom(note.createdAt)),
      ),
    );
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
