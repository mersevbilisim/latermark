import 'dart:io';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart';

import '../domain/note_reminder.dart';
import '../domain/reminder_action.dart';
import '../domain/retention.dart';
import '../../settings/domain/pro_downgrade_policy.dart';
import 'location_service.dart';
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
  static const none = SearchHits(query: '', ids: <int>{}, photoOnly: <int>{});

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

final class _CreateResult {
  const _CreateResult(this.noteId, {this.reused = false});

  final int noteId;
  final bool reused;
}

final class _ProcessedImport {
  const _ProcessedImport({required this.noteId, required this.completed});

  final int? noteId;
  final bool completed;
}

void _ensureReminderBeforeExpiry({
  required DateTime? remindAt,
  required DateTime? expiresAt,
}) {
  if (remindAt != null && expiresAt != null && !expiresAt.isAfter(remindAt)) {
    throw const ReminderAfterExpiryException();
  }
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

  /// Izgaranın çizeceği dosya: varsa küçük kopya, yoksa tam kare.
  ///
  /// Akışta yüzlerce kare aynı anda çözülüyor ve 2048'lik kaynaktan çözmek
  /// kare başına altı kat pahalı. Küçük kopyası henüz üretilmemiş kayıt tam
  /// kareyi çizmeye devam ediyor — yükseltmeden gelen kullanıcı hiçbir şey
  /// eksik görmüyor, akış kopyalar üretildikçe hızlanıyor.
  File gridImageOf(Note note) => _store.gridFileFor(note.imageName);

  /// Küçük kopyası olmayan kayıtlar için kopyayı üretir.
  Future<bool> ensureThumbnail(Note note) =>
      _store.ensureThumbnail(note.imageName);

  /// Küçük kopyası hazır mı. Ölçüm ve teşhis için.
  bool hasThumbnail(Note note) => _store.thumbFor(note.imageName).existsSync();

  /// Bu ortamda küçük kopya üretilebiliyor mu.
  bool get canThumbnail => _store.canThumbnail;

  /// Kamera çıktısını kalıcılaştırır ve notu yazar. Yeni notun kimliğini döner.
  ///
  /// [createdAt] verilmezse şimdiki an kullanılır. Çekim ekranı, kaydın
  /// zamanının *deklanşöre basıldığı an* olması için bunu açıkça geçer.
  Future<int> create({
    required XFile capture,
    required String body,
    required RetentionChoice retention,
    ReminderChoice reminder = const ReminderChoice.off(),
    DateTime? createdAt,
    NoteLocation? location,
    String? importId,
  }) async {
    final normalizedImportId = importId?.trim();
    if (normalizedImportId != null &&
        (normalizedImportId.isEmpty || normalizedImportId.length > 128)) {
      throw ArgumentError.value(
        importId,
        'importId',
        'Geçersiz import kimliği',
      );
    }
    if (normalizedImportId != null) {
      final processed = await _processedImport(normalizedImportId);
      if (processed?.completed == true && processed?.noteId != null) {
        return processed!.noteId!;
      }
    }

    final stamp = createdAt ?? DateTime.now();
    final imageName = await _store.persist(capture);
    final text = body.trim();

    try {
      final result = await _db.transaction(() async {
        if (normalizedImportId != null) {
          final claimed = await _db.customUpdate(
            'INSERT OR IGNORE INTO processed_imports '
            '(import_id, completed) VALUES (?, 0)',
            variables: [Variable<String>(normalizedImportId)],
            updates: const {},
          );
          if (claimed == 0) {
            final processed = await _processedImport(normalizedImportId);
            if (processed?.completed == true && processed?.noteId != null) {
              return _CreateResult(processed!.noteId!, reused: true);
            }
            await _db.customUpdate(
              'DELETE FROM processed_imports '
              'WHERE import_id = ? AND completed = 0',
              variables: [Variable<String>(normalizedImportId)],
              updates: const {},
            );
            await _db.customUpdate(
              'INSERT INTO processed_imports '
              '(import_id, completed) VALUES (?, 0)',
              variables: [Variable<String>(normalizedImportId)],
              updates: const {},
            );
          }
        }

        final id = await _insertNote(
          imageName: imageName,
          text: text,
          stamp: stamp,
          retention: retention,
          reminder: reminder,
          location: location,
        );
        if (normalizedImportId != null) {
          await _db.customUpdate(
            'UPDATE processed_imports SET '
            'note_id = ?, completed = 1, processed_at = ? '
            'WHERE import_id = ?',
            variables: [
              Variable<int>(id),
              Variable<int>(DateTime.now().millisecondsSinceEpoch),
              Variable<String>(normalizedImportId),
            ],
            updates: const {},
          );
        }
        return _CreateResult(id);
      });

      if (result.reused) await _store.remove(imageName);
      return result.noteId;
    } catch (_) {
      await _store.remove(imageName);
      rethrow;
    }
  }

  /// Not ile arama satırını tek transaction içinde oluşturur.
  Future<int> _insertNote({
    required String imageName,
    required String text,
    required DateTime stamp,
    required RetentionChoice retention,
    required ReminderChoice reminder,
    required NoteLocation? location,
  }) async {
    final isPro = await _isProUnlocked();
    final effectiveRetention = isPro
        ? retention
        : freeRetentionFallback(retention);
    final effectiveReminder = isPro ? reminder : const ReminderChoice.off();
    final expiry = effectiveRetention.expiryFrom(stamp);
    _ensureReminderBeforeExpiry(
      remindAt: effectiveReminder.at,
      expiresAt: expiry,
    );
    final id = await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            imageName: imageName,
            body: Value(text),
            createdAt: stamp,
            retention: Value(effectiveRetention.retention),
            customMinutes: Value(effectiveRetention.customMinutes),
            expiresAt: Value(expiry),
            remindAt: Value(effectiveReminder.at),
            remindEveryDays: Value(
              effectiveReminder.repeats ? effectiveReminder.everyDays : 0,
            ),
            latitude: Value(location?.latitude),
            longitude: Value(location?.longitude),
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
  }

  Future<_ProcessedImport?> _processedImport(String importId) async {
    final row = await _db
        .customSelect(
          'SELECT note_id, completed FROM processed_imports '
          'WHERE import_id = ? LIMIT 1',
          variables: [Variable<String>(importId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return _ProcessedImport(
      noteId: row.readNullable<int>('note_id'),
      completed: row.read<int>('completed') != 0,
    );
  }

  /// Aynı platform tesliminin daha önce atomik olarak kaydedilip
  /// kaydedilmediği. UI bunu yalnızca yeni-not limitini mevcut bir kaydın
  /// cleanup tekrarında yanlışlıkla göstermemek için sorar.
  Future<bool> hasProcessedImport(String importId) async {
    final processed = await _processedImport(importId.trim());
    return processed?.completed == true;
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
    required ReminderChoice reminder,
  }) {
    final text = body.trim();

    return _db.transaction(() async {
      final isPro = await _isProUnlocked();
      final effective = isPro ? reminder : const ReminderChoice.off();
      final everyDays = effective.repeats ? effective.everyDays : 0;
      final hasLegacyReminderExpiry = isReminderExpiry(
        remindAt: note.remindAt,
        expiresAt: note.expiresAt,
      );
      _ensureReminderBeforeExpiry(
        remindAt: effective.at,
        expiresAt: hasLegacyReminderExpiry ? null : note.expiresAt,
      );

      // Damga yalnızca gerçekten bir şey değiştiyse vurulur. Düzenleme
      // ekranını açıp hiçbir şeye dokunmadan kaydetmek notu "düzenlenmiş"
      // yapmamalı; aksi hâlde damga zamanla anlamını yitirirdi.
      final changed =
          text != note.body ||
          effective.at != note.remindAt ||
          everyDays != note.remindEveryDays;

      // Hatırlatmadan türeyen silinme sözü hatırlatmayla birlikte kalkar.
      // Kullanıcı anahtarı kapattığında geriye çalmayacak bir bildirimin
      // saatine ayarlanmış bir silme kalmamalı.
      final dropsReminderExpiry =
          effective.at == null && hasLegacyReminderExpiry;

      await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
        NotesCompanion(
          body: Value(text),
          remindAt: Value(effective.at),
          remindEveryDays: Value(everyDays),
          retention: dropsReminderExpiry
              ? const Value(Retention.off)
              : const Value.absent(),
          customMinutes: dropsReminderExpiry
              ? const Value(0)
              : const Value.absent(),
          expiresAt: dropsReminderExpiry
              ? const Value(null)
              : const Value.absent(),
          updatedAt: changed ? Value(DateTime.now()) : const Value.absent(),
        ),
      );

      // İndeks nota bağlı kalmalı: düzenlenen bir not eski metniyle
      // bulunmaya devam ederse arama yalan söylüyor demektir.
      await (_db.update(_db.noteSearch)..where((t) => t.noteId.equals(note.id)))
          .write(NoteSearchCompanion(bodyFolded: Value(SearchText.fold(text))));
    });
  }

  /// Kaydedilmiş bir nota, planlama ekranında seçilen hatırlatmayı yazar.
  ///
  /// [update]'ten ayrı duruyor çünkü burada not düzenlenmiyor: gövde el
  /// değmeden kalıyor ve [Note.updatedAt] damgası vurulmuyor. Aksi hâlde
  /// kaydettiği kareye hatırlatma kuran herkesin notu, daha ilk dakikasında
  /// "düzenlenmiş" görünürdü.
  ///
  /// Hak kontrolü aynı transaction içinde: hakkı düşmüş bir kullanıcı
  /// hatırlatma kuramaz.
  ///
  /// [deleteAfterReminder] açıkken notun silinme anı hatırlatmadan türetilir
  /// ([reminderExpiryFor]). Ayrı bir sütun eklenmiyor: uygulamanın otomatik
  /// silme düzeneği zaten `expiresAt` üzerinden çalışıyor ve kayıt bu değeri
  /// oluşturma anından türeyen bir saklama süresi olarak taşımaya devam
  /// ediyor — yedekleme, hak düşümü ve kalan ömür göstergesi olduğu gibi
  /// çalışsın diye.
  ///
  /// Söz **hatırlatmaya bağlı**: hatırlatma kalkarsa ya da tekrarlıya
  /// dönerse ondan türeyen silinme anı da kalkar. Aksi hâlde hiç çalmayacak
  /// bir bildirimin ardından not sessizce kaybolurdu.
  Future<void> setReminder(
    int noteId,
    ReminderChoice reminder, {
    bool deleteAfterReminder = false,
  }) {
    return _db.transaction(() async {
      final note = await noteById(noteId);
      if (note == null) return;

      final isPro = await _isProUnlocked();
      final effective = isPro ? reminder : const ReminderChoice.off();
      final at = effective.at;

      // Tekrarlı bir hatırlatmanın ardından silmek kendi kendini yiyen bir
      // söz olurdu: ikinci oluşum hiç gelmez.
      final wantsExpiry =
          deleteAfterReminder && at != null && !effective.repeats;
      final hadReminderExpiry = isReminderExpiry(
        remindAt: note.remindAt,
        expiresAt: note.expiresAt,
      );
      _ensureReminderBeforeExpiry(
        remindAt: wantsExpiry ? null : at,
        expiresAt: hadReminderExpiry ? null : note.expiresAt,
      );

      var retention = const Value<Retention>.absent();
      var customMinutes = const Value<int>.absent();
      var expiresAt = const Value<DateTime?>.absent();

      if (wantsExpiry) {
        final expiry = reminderExpiryFor(at);
        retention = const Value(Retention.custom);
        // Süre kaydın kendi başlangıcından ölçülür: bütün saklama düzeneği
        // ömrü `createdAt`ten sayıyor ve hak düşümü de oradan yeniden
        // hesaplıyor.
        customMinutes = Value(
          math.max(1, expiry.difference(note.createdAt).inMinutes),
        );
        expiresAt = Value(expiry);
      } else if (hadReminderExpiry) {
        retention = const Value(Retention.off);
        customMinutes = const Value(0);
        expiresAt = const Value(null);
      }

      await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
        NotesCompanion(
          remindAt: Value(effective.at),
          remindEveryDays: Value(effective.repeats ? effective.everyDays : 0),
          retention: retention,
          customMinutes: customMinutes,
          expiresAt: expiresAt,
        ),
      );
    });
  }

  /// Bildirim üzerindeki bir düğmenin cevabını nota yazar.
  ///
  /// Yalnızca hatırlatma alanlarına dokunuyor. [update]'ten ayrı durmasının
  /// sebebi bu: kullanıcı notu düzenlemedi, hatırlatmaya cevap verdi —
  /// gövdeye ve [Note.updatedAt] damgasına dokunmak o damganın anlamını
  /// yitirmesi demek olurdu.
  ///
  /// Not **silinmiyor**; "Tamam" en fazla hatırlatmayı kapatır.
  ///
  /// Değişen kaydı döner; not yoksa, hatırlatması yoksa ya da hak kapalıysa
  /// `null`. Hak kontrolü aynı transaction içinde yapılıyor: eylem, hakkı
  /// düşmüş bir kullanıcının hatırlatmasını geri getiremez.
  Future<Note?> applyReminderAction(
    int noteId,
    ReminderAction action, {
    DateTime? firedAt,
    DateTime? now,
    String? eventId,
  }) {
    final moment = now ?? DateTime.now();

    return _db.transaction(() async {
      if (eventId != null) {
        final claimed = await _db.customUpdate(
          'INSERT OR IGNORE INTO processed_reminder_actions '
          '(event_id, processed_at) VALUES (?, ?)',
          variables: [
            Variable<String>(eventId),
            Variable<int>(moment.millisecondsSinceEpoch),
          ],
          updates: const {},
        );
        if (claimed == 0) return null;
      }
      final note = await noteById(noteId);
      if (note == null || !await _isProUnlocked()) return null;

      final outcome = reminderOutcomeFor(
        action: action,
        reminder: ReminderChoice(
          at: note.remindAt,
          cadence: ReminderCadence.fromCode(note.remindEveryDays),
        ),
        now: moment,
        firedAt: firedAt,
      );
      if (outcome == null) return null;

      // Erteleme silinme sözünü de ileri taşır. Taşımasaydı "yarın" diyen
      // kullanıcının notu, ertelenen bildirim hiç gelmeden, eski saatin bir
      // saat sonrasında silinirdi. "Tamam" ve "kapat" ise sözü olduğu gibi
      // bırakır: kullanıcı hatırlatmayı gördü, kare bir saat sonra gidecek.
      final movesReminderExpiry =
          outcome.at != null &&
          isReminderExpiry(remindAt: note.remindAt, expiresAt: note.expiresAt);

      await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
        NotesCompanion(
          remindAt: Value(outcome.at),
          remindEveryDays: Value(outcome.everyDays),
          expiresAt: movesReminderExpiry
              ? Value(reminderExpiryFor(outcome.at!))
              : const Value.absent(),
          customMinutes: movesReminderExpiry
              ? Value(
                  math.max(
                    1,
                    reminderExpiryFor(
                      outcome.at!,
                    ).difference(note.createdAt).inMinutes,
                  ),
                )
              : const Value.absent(),
        ),
      );

      return noteById(noteId);
    });
  }

  /// Bu bağlantının dışında değişmiş olabilecek satırları yeniden yaydırır.
  ///
  /// Bildirim düğmeleri ayrı bir Flutter motorunda, yani **ayrı bir SQLite
  /// bağlantısında** işleniyor. Drift akış geçersizleştirmesi süreç içi
  /// olduğu için o yazma, açık duran uygulamanın listesine kendiliğinden
  /// yansımaz; kart hatırlatmanın eski tarihini göstermeye devam ederdi.
  /// Bu çağrı sorguları yeniden koşturur, veriye dokunmaz.
  void reloadFromDisk() => _db.markTablesUpdated({_db.notes});

  /// Spotlight diff'i için OCR içeriğinin küçük, kararlı özeti.
  ///
  /// Metnin kendisi yalnız gerçekten yeniden indekslenecek kayıtta okunur.
  /// Eski şemadan veya backup'tan özetsiz gelen satırlar burada bir kez geri
  /// doldurulur; sonraki açılışlar yalnız sekiz karakterlik imzaları taşır.
  Future<Map<int, String?>> spotlightPhotoFingerprints() async {
    var rows = await _db.select(_db.noteSearch).get();
    final missing = [
      for (final row in rows)
        if (row.photoFolded != null && row.photoFingerprint == null) row,
    ];
    if (missing.isNotEmpty) {
      await _db.transaction(() async {
        for (final row in missing) {
          await (_db.update(
            _db.noteSearch,
          )..where((search) => search.noteId.equals(row.noteId))).write(
            NoteSearchCompanion(
              photoFingerprint: Value(SearchText.fingerprint(row.photoFolded!)),
            ),
          );
        }
      });
      rows = await _db.select(_db.noteSearch).get();
    }
    return {for (final row in rows) row.noteId: row.photoFingerprint};
  }

  /// Verilen kayıtların karedeki yazısı. Yalnızca indekslenecekler için
  /// çağrılır; taranmamış kayıtlar sonuçta hiç görünmez.
  Future<Map<int, String>> photoTextOf(Iterable<int> ids) async {
    final wanted = ids.toList();
    if (wanted.isEmpty) return const {};

    final rows = await (_db.select(
      _db.noteSearch,
    )..where((t) => t.noteId.isIn(wanted) & t.photoFolded.isNotNull())).get();
    return {
      for (final row in rows)
        if (row.photoFolded case final text? when text.isNotEmpty)
          row.noteId: text,
    };
  }

  /// Pro alanları yazılırken entitlement'ı aynı transaction içinde yeniden
  /// okur. Böylece açık kalmış compose/edit ekranı downgrade temizliğinden
  /// sonra custom süre veya hatırlatmayı geri getiremez.
  Future<bool> _isProUnlocked() async {
    final query = _db.select(_db.settingsTable)
      ..where((row) => row.id.equals(1));
    return (await query.getSingleOrNull())?.proUnlocked ?? false;
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
        await (_db.update(
          _db.noteSearch,
        )..where((t) => t.noteId.equals(id))).write(
          NoteSearchCompanion(
            photoFolded: Value(folded),
            photoFingerprint: Value(SearchText.fingerprint(folded)),
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
            photoFingerprint: Value(SearchText.fingerprint(folded)),
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
                    _db.noteSearch.attempts.isSmallerThanValue(maxScanAttempts),
              )
              ..limit(limit))
            .get();
    if (pending.isEmpty) return const [];

    final ids = [for (final row in pending) row.read(_db.noteSearch.noteId)!];
    final query = _db.select(_db.notes)..where((t) => t.id.isIn(ids));
    return query.get();
  }

  /// Nota bakıldığını işaretler.
  ///
  /// Hatırlatma bundan bağımsız [Note.remindAt] alanında tutulur; nota bakmak
  /// kullanıcının seçtiği günü değiştirmez.
  Future<void> markSeen(int id) {
    final query = _db.update(_db.notes)..where((t) => t.id.equals(id));
    return query.write(NotesCompanion(lastSeenAt: Value(DateTime.now())));
  }

  /// Notu ve fotoğrafını birlikte siler.
  Future<void> delete(Note note) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(note.id))).go();
    await _store.remove(note.imageName);
  }

  /// Birden çok kaydı **tek** silme deyiminde kaldırır.
  ///
  /// Döngüyle tek tek silmek her kayıtta akışa yeni bir değer yayardı: liste
  /// on kayıt için on kez yeniden çizilir, kartlar birer birer eriyip giderdi.
  /// Tek deyim tek yayın üretir; seçim topluca ve tek karede kalkar.
  Future<void> deleteAll(Iterable<Note> notes) async {
    final doomed = notes.toList(growable: false);
    if (doomed.isEmpty) return;

    final ids = [for (final note in doomed) note.id];
    await (_db.delete(_db.notes)..where((t) => t.id.isIn(ids))).go();
    await _store.removeAll(doomed.map((note) => note.imageName));
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
