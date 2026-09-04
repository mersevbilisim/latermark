import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../domain/note_kind.dart';
import '../domain/note_reminder.dart';
import '../domain/reminder_action.dart';
import '../domain/retention.dart';
import '../../paywall/data/reminder_quota_store.dart';
import '../../paywall/domain/pro_limits.dart';
import '../../settings/domain/pro_downgrade_policy.dart';
import 'archive_recovery.dart';
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
  NotesRepository({
    required NotesDatabase database,
    required PhotoStore photos,
    @visibleForTesting ReminderQuotaStore? quota,
  }) : _db = database,
       _store = photos,
       _quota = quota ?? ReminderQuotaStore();

  /// Okunamayan bir kare kaç kez yeniden denenir.
  ///
  /// Sınırsız deneme, bozuk ya da yazısız-ama-zor tek bir karenin listedeki
  /// her değişimde yeniden taranması demekti. Üç deneme, ML Kit modelinin
  /// Play Services'ten inmesini beklemeye fazlasıyla yeter; ötesi pil yakar.
  static const maxScanAttempts = 3;

  final NotesDatabase _db;
  final PhotoStore _store;

  /// Silinmeyen hak sayacı. Bkz. [loadFreeReminderFloor].
  final ReminderQuotaStore _quota;

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
  Future<bool> ensureThumbnail(Note note) => note.hasPhoto
      ? _store.ensureThumbnail(note.imageName)
      : Future.value(false);

  /// Bir notun sahip olduğu bütün dosya adları.
  ///
  /// Silme ve yetim toplama tek tek `imageName` sayıyordu; orijinali de
  /// tutabilen bir kayıtta bu, dosyayı diskte sahipsiz bırakırdı. Sahiplik
  /// sorusunun tek bir cevabı olsun diye burada toplanıyor.
  /// Karesiz kayıtta bu liste boş döner: boş `imageName` bir dosya adı değil,
  /// "dosya yok" demek. Süzülmezse silme ve yetim toplama klasörün kendi
  /// yolunu dosya sanardı.
  static Iterable<String> filesOf(Note note) => [
    if (note.hasPhoto) note.imageName,
    ?note.originalName,
  ];

  /// Detay ekranının ve paylaşımın kullanacağı dosya.
  ///
  /// Orijinali varsa o; yoksa işlenmiş kare. Ayrı bir "orijinali göster"
  /// anahtarı yok ve olmamalı: kullanıcı o kare için orijinali saklamayı zaten
  /// açıkça seçti, fotoğrafa baktığı tek yerde ona sakladığı şeyi göstermek
  /// istediği şeyin ta kendisi. İkinci bir soru sormak seçimi iki kez sormak
  /// olurdu.
  ///
  /// Izgara, arama, ana ekran ve widget'lar bu yolu **kullanmıyor** — orada
  /// her zaman küçük kopya ve işlenmiş kare çiziliyor.
  File fullImageOf(Note note) => originalOf(note) ?? imageOf(note);

  /// Notun dokunulmamış karesi. Kullanıcı saklamadıysa `null`.
  File? originalOf(Note note) {
    final name = note.originalName;
    if (name == null) return null;
    final file = _store.fileFor(name);
    return file.existsSync() ? file : null;
  }

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
    bool keepOriginal = false,
  }) async {
    if (reminder.isOn) await loadFreeReminderFloor();
    final normalizedImportId = _normalizedImportId(importId);
    final reused = await _reusedNoteId(normalizedImportId);
    if (reused != null) return reused;

    final stamp = createdAt ?? DateTime.now();
    final imageName = await _store.persist(capture);
    // Orijinal, işlenmiş karenin **yanına** yazılıyor; yerine değil.
    final originalName = keepOriginal
        ? await _store.persistOriginal(capture)
        : null;

    try {
      final result = await _claimAndInsert(
        importId: normalizedImportId,
        imageName: imageName,
        originalName: originalName,
        text: body.trim(),
        stamp: stamp,
        retention: retention,
        reminder: reminder,
        location: location,
      );

      if (result.reused) await _store.remove(imageName);
      return result.noteId;
    } catch (_) {
      await _store.remove(imageName);
      rethrow;
    }
  }

  /// Karesiz kayıt: yalnızca yazı.
  ///
  /// [create] ile aynı kapıdan geçiyor — aynı Pro kapısı, aynı saklama
  /// süresi, aynı hatırlatma kuralı, aynı `importId` tekilliği. Tek farkı
  /// diskte dosyası olmaması; `imageName` boş kalıyor (bkz. `NoteKind`).
  ///
  /// Dosya yazılmadığı için [create]'in temizlik dalları da yok: burada
  /// başarısız bir işlemin geride bırakacağı bir şey yok.
  Future<int> createText({
    required String body,
    required RetentionChoice retention,
    ReminderChoice reminder = const ReminderChoice.off(),
    DateTime? createdAt,
    NoteLocation? location,
    String? importId,
  }) async {
    if (reminder.isOn) await loadFreeReminderFloor();
    final normalizedImportId = _normalizedImportId(importId);
    final reused = await _reusedNoteId(normalizedImportId);
    if (reused != null) return reused;

    final result = await _claimAndInsert(
      importId: normalizedImportId,
      imageName: '',
      originalName: null,
      text: body.trim(),
      stamp: createdAt ?? DateTime.now(),
      retention: retention,
      reminder: reminder,
      location: location,
    );
    return result.noteId;
  }

  /// Dış teslim kimliğini doğrular ve boşlukları kırpar.
  static String? _normalizedImportId(String? importId) {
    final normalized = importId?.trim();
    if (normalized != null && (normalized.isEmpty || normalized.length > 128)) {
      throw ArgumentError.value(
        importId,
        'importId',
        'Geçersiz import kimliği',
      );
    }
    return normalized;
  }

  /// Bu teslim daha önce tamamlandıysa o kaydın kimliği.
  ///
  /// Aynı paylaşım/kısayol iki kez düşerse ikinci kayıt açılmamalı.
  Future<int?> _reusedNoteId(String? importId) async {
    if (importId == null) return null;
    final processed = await _processedImport(importId);
    if (processed?.completed == true && processed?.noteId != null) {
      return processed!.noteId!;
    }
    return null;
  }

  /// Teslim kimliğini sahiplenip notu tek transaction içinde yazar.
  Future<_CreateResult> _claimAndInsert({
    required String? importId,
    required String imageName,
    required String? originalName,
    required String text,
    required DateTime stamp,
    required RetentionChoice retention,
    required ReminderChoice reminder,
    required NoteLocation? location,
  }) {
    return _db.transaction(() async {
      if (importId != null) {
        final claimed = await _db.customUpdate(
          'INSERT OR IGNORE INTO processed_imports '
          '(import_id, completed) VALUES (?, 0)',
          variables: [Variable<String>(importId)],
          updates: const {},
        );
        if (claimed == 0) {
          final processed = await _processedImport(importId);
          if (processed?.completed == true && processed?.noteId != null) {
            return _CreateResult(processed!.noteId!, reused: true);
          }
          await _db.customUpdate(
            'DELETE FROM processed_imports '
            'WHERE import_id = ? AND completed = 0',
            variables: [Variable<String>(importId)],
            updates: const {},
          );
          await _db.customUpdate(
            'INSERT INTO processed_imports '
            '(import_id, completed) VALUES (?, 0)',
            variables: [Variable<String>(importId)],
            updates: const {},
          );
        }
      }

      final id = await _insertNote(
        imageName: imageName,
        originalName: originalName,
        text: text,
        stamp: stamp,
        retention: retention,
        reminder: reminder,
        location: location,
      );
      if (importId != null) {
        await _db.customUpdate(
          'UPDATE processed_imports SET '
          'note_id = ?, completed = 1, processed_at = ? '
          'WHERE import_id = ?',
          variables: [
            Variable<int>(id),
            Variable<int>(DateTime.now().millisecondsSinceEpoch),
            Variable<String>(importId),
          ],
          updates: const {},
        );
      }
      return _CreateResult(id);
    });
  }

  /// Not ile arama satırını tek transaction içinde oluşturur.
  Future<int> _insertNote({
    required String imageName,
    required String? originalName,
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

    // Ücretsiz katmanda hatırlatma tümden kapalı değil, **sayılı**. Yeni
    // kaydın kimliği henüz yok; kapı "hak kaldı mı" diye soruyor ve hak
    // eklemeden sonra, gerçek kimlikle harcanıyor.
    final used = isPro ? const <int>{} : await _freeReminderNotes();
    final grantsFree =
        !isPro &&
        reminder.isOn &&
        ProLimits.allowsReminder(
          isPro: false,
          usedNoteIds: used,
          burnedFloor: _burnedFloor,
          inFlight: await _inFlightFreeReminders(used, stamp),
        );
    final effectiveReminder = isPro || grantsFree
        ? ReminderChoice(
            at: reminder.at,
            cadence: ProLimits.effectiveCadence(reminder.cadence, isPro: isPro),
          )
        : const ReminderChoice.off();
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
            originalName: Value(originalName),
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
            // Karesiz kayıtta `photoFolded` **boş string**, `null` değil.
            // `unscanned()` kuyruğu `photoFolded IS NULL` ile besleniyor;
            // null bırakılsaydı okunacak karesi olmayan her kayıt, deneme
            // hakkı bitene kadar OCR sırasında dönüp dururdu.
            photoFolded: Value(imageName.isEmpty ? '' : null),
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
  }) async {
    if (reminder.isOn) await loadFreeReminderFloor();
    final text = body.trim();

    await _db.transaction(() async {
      final isPro = await _isProUnlocked();
      // Kayıt hakkını daha önce almışsa yeniden ücretlendirilmiyor: kullanıcı
      // kendi kurduğu hatırlatmayı kapatıp açabilir, saatini değiştirebilir,
      // bildirimden erteleyebilir.
      final used = isPro ? const <int>{} : await _freeReminderNotes();
      final allowed = ProLimits.allowsReminder(
        isPro: isPro,
        usedNoteIds: used,
        burnedFloor: _burnedFloor,
        inFlight: isPro
            ? 0
            : await _inFlightFreeReminders(
                used,
                DateTime.now(),
                exceptNoteId: note.id,
              ),
        noteId: note.id,
      );
      // Ekran açıkken başka bir giriş (ör. Siri) son slotu almış olabilir.
      // Böyle bir yarışta kullanıcının mevcut hatırlatmasını silme; gövdeyi
      // kaydet, planlama ekranındaki ikinci kapı yeni isteği görünür biçimde
      // reddetsin.
      final effective = !allowed && reminder.isOn
          ? ReminderChoice(
              at: note.remindAt,
              cadence: ReminderCadence.fromCode(note.remindEveryDays),
            )
          : allowed
          ? ReminderChoice(
              at: reminder.at,
              cadence: ProLimits.effectiveCadence(
                reminder.cadence,
                isPro: isPro,
              ),
            )
          : const ReminderChoice.off();
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
  ///
  /// Söz, notun **kendi saklama süresinin yerine geçer** — kısaltabilir de,
  /// uzatabilir de. Normalde silinme anından sonraya kurulan bir hatırlatma
  /// [ReminderAfterExpiryException] atar; burada atmıyor, çünkü kullanıcı o
  /// çelişkiyi zaten çözmüş oluyor: "hatırlatana kadar dursun, sonra gitsin"
  /// daha yeni ve daha özel bir talimat. Üç günlük bir notu on gün sonrasına
  /// kurup sözü açmak notu on gün bir saat yaşatır. Sessiz kalmasın diye
  /// planlama ekranı hem sonucun tarihini hem de sözün mevcut sürenin yerine
  /// geçtiğini yazıyor.
  Future<bool> setReminder(
    int noteId,
    ReminderChoice reminder, {
    bool deleteAfterReminder = false,
  }) async {
    if (reminder.isOn) await loadFreeReminderFloor();
    return _db.transaction(() async {
      final note = await noteById(noteId);
      if (note == null) return false;

      final isPro = await _isProUnlocked();
      // Planlama ekranı ve bildirim düğmeleri buradan geçiyor. Erteleme aynı
      // kaydın hakkını yeniden yemez; kural [ProLimits.allowsReminder] içinde.
      final used = isPro ? const <int>{} : await _freeReminderNotes();
      final allowed = ProLimits.allowsReminder(
        isPro: isPro,
        usedNoteIds: used,
        burnedFloor: _burnedFloor,
        inFlight: isPro
            ? 0
            : await _inFlightFreeReminders(
                used,
                DateTime.now(),
                exceptNoteId: noteId,
              ),
        noteId: noteId,
      );
      // Kota ekran açıkken tükenmişse mevcut kayda dokunmadan sonucu çağırana
      // bildir. Sessizce `off` yazmak hem sahte başarı hem veri kaybıydı.
      if (reminder.isOn && !allowed) return false;
      final effective = allowed
          ? ReminderChoice(
              at: reminder.at,
              cadence: ProLimits.effectiveCadence(
                reminder.cadence,
                isPro: isPro,
              ),
            )
          : const ReminderChoice.off();
      // Çalmadan iptal edilen ya da ileri atılan hatırlatma kurulu listeden
      // düşüyor: ortada teslim edilmiş bir değer yok.
      if (!isPro) {
        await _disarmIfUnfired(noteId, note.remindAt, effective.at);
      }
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
      return !reminder.isOn || effective.isOn;
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
  }) async {
    await loadFreeReminderFloor();
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
      if (note == null) return null;
      final isPro = await _isProUnlocked();
      if (!ProLimits.remindersAvailable(isPro: isPro)) return null;

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

      // Bu yol yalnız işletim sisteminin teslim ettiği bir bildirimin düğmesinden
      // gelir. Erteleme `remindAt` alanını geleceğe taşımadan önceki teslimatın
      // hakkı aynı transaction'da kapanır; aksi hâlde Free kullanıcı aynı notu
      // sonsuza kadar erteleyebilirdi.
      if (!isPro) await _burnFreeReminders([noteId]);

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

  /// Yeniden kurulumdan sonra da duran hak tabanı.
  ///
  /// Veritabanındaki kimlik listesi kuruluma özel; silinip yeniden kurulunca
  /// boş başlıyor. Bu sayı Keychain'de duruyor ve o listeye bir **taban**
  /// koyuyor: harcanan hak, listedeki kayıt sayısı ile bu tabandan hangisi
  /// büyükse odur.
  ///
  /// Sıfır kalması güvenli yön: okunamadığında davranış eski hâline, yani
  /// yalnız veritabanına dönüyor. Kullanıcıdan fazla hak almaktansa
  /// kaçırmak yeğdir.
  int _burnedFloor = 0;

  /// Taban bu oturumda okundu mu.
  ///
  /// Senkron her öne dönüşte ve her kayıt değişiminde koşuyor; tabanı orada
  /// her seferinde okumak, oturum boyunca yüzlerce kez Keychain'e gitmek
  /// olurdu. Sayı yalnız bizim yazdığımız zaman değiştiği için bir kez okumak
  /// yetiyor.
  bool _floorLoaded = false;

  /// Aynı anda AppScope ve bir kayıt akışı başlarsa Keychain'i iki kez okuma.
  Future<bool>? _floorLoading;

  /// Yeniden kurulumdan sonra da duran hak tabanı; arayüz kalan hakkı
  /// hesaplarken buna da bakıyor.
  int get freeReminderFloor => _burnedFloor;

  /// Drift'in şu anda bildiği kesin Free boşluğu.
  ///
  /// App Intents rezervasyonu nota devredilirken App Group aynası da aynı
  /// değerle güncellenir. Pro'da `null`: o katmanda Free sayacı karar kaynağı
  /// değildir ve downgrade senkronu gerektiğinde aynayı yeniden kurar.
  Future<int?> remainingFreeReminders() async {
    if (await _isProUnlocked()) return null;
    await loadFreeReminderFloor();
    final used = await _freeReminderNotes();
    final inFlight = await _inFlightFreeReminders(used, DateTime.now());
    return ProLimits.remainingReminders(
      used,
      burnedFloor: _burnedFloor,
      inFlight: inFlight,
    );
  }

  /// Silinmeyen tabanı okur.
  ///
  /// Açılışta bir kez çağrılıyor. Pro kullanıcıda hiç çağrılmıyor: hak
  /// kontrolü ona hiç uğramıyor, dolayısıyla Keychain'e ne bakılıyor ne
  /// yazılıyor.
  Future<bool> loadFreeReminderFloor() {
    if (_floorLoaded) return Future.value(false);
    final loading = _floorLoading;
    if (loading != null) return loading;

    late final Future<bool> operation;
    operation = _loadFreeReminderFloor().whenComplete(() {
      if (identical(_floorLoading, operation)) _floorLoading = null;
    });
    return _floorLoading = operation;
  }

  Future<bool> _loadFreeReminderFloor() async {
    // Pro'da bayrak **bırakılmıyor**: iade sonrası ilk senkron tabanı
    // yükleyebilsin.
    if (await _isProUnlocked()) return false;
    final stored = await _quota.read();
    // Okuma başarısız olsa da bir daha denenmiyor. Sayı yalnız büyüyor ve
    // yazan taraf da biz olduğumuz için kaçırılan bir okumanın bedeli, o
    // oturumda veritabanına düşmek — yani kullanıcının lehine. Uygulama
    // yeniden açıldığında tekrar deneniyor.
    _floorLoaded = true;
    if (stored == null || stored <= _burnedFloor) return false;
    _burnedFloor = stored;
    return true;
  }

  /// Ücretsiz hatırlatma hakkını harcamış kayıtların kimlikleri.
  Future<Set<int>> _freeReminderNotes() async {
    final query = _db.select(_db.settingsTable)
      ..where((row) => row.id.equals(1));
    final raw = (await query.getSingleOrNull())?.freeReminderNotes ?? '';
    return {
      for (final id in raw.split(','))
        if (int.tryParse(id.trim()) case final parsed?)
          if (parsed > 0) parsed,
    };
  }

  /// Kurulu ama henüz çalmamış hatırlatma sayısı.
  ///
  /// [exceptNoteId] kapının değerlendirildiği kaydın kendisi: kendi kurulu
  /// hatırlatmasını sayarsa kullanıcı onun saatini bile değiştiremezdi.
  Future<int> _inFlightFreeReminders(
    Set<int> used,
    DateTime now, {
    int? exceptNoteId,
  }) async {
    final pending = await (_db.select(
      _db.notes,
    )..where((t) => t.remindAt.isBiggerThanValue(now))).get();
    return pending
        .where((note) => note.id != exceptNoteId && !used.contains(note.id))
        .length;
  }

  /// Çalmış hatırlatmaları ücretsiz haktan düşer.
  ///
  /// Hak kurulumda değil **teslimde** yanıyor: kurup vazgeçen kullanıcıdan bir
  /// şey alınmaz, çünkü ortada teslim edilmiş bir değer yok. Ölçüt de bu
  /// yüzden zamanın kendisi — geçmişte kalmış bir `remindAt`, işletim
  /// sisteminin o bildirimi göstermiş olması demek.
  ///
  /// [deliveredNoteIds] yalnız işletim sisteminin aktif tepsisinden veya bir
  /// bildirim etkileşiminden gelir. İzin, tarih ya da veritabanı niyeti tek
  /// başına teslimat kanıtı sayılmaz.
  ///
  /// Pro kullanıcıda hiç çalışmaz; iade sonrası kullanıcı kaldığı yerden
  /// devam eder. Zaten hak düşüşü sırasında Pro'dan düşen kullanıcının
  /// notlarındaki hatırlatmalar `SettingsRepository` tarafından temizlendiği
  /// için geriye dönük bir ceza da oluşmuyor.
  /// Kurulu ama çalmamış ücretsiz hatırlatmaların kimlikleri.
  Future<Set<int>> _armedFreeReminders() async {
    final query = _db.select(_db.settingsTable)
      ..where((row) => row.id.equals(1));
    final raw = (await query.getSingleOrNull())?.freeReminderArmed ?? '';
    return {
      for (final id in raw.split(','))
        if (int.tryParse(id.trim()) case final parsed?)
          if (parsed > 0) parsed,
    };
  }

  Future<void> _writeArmed(Set<int> armed) async {
    final ordered = armed.toList()..sort();
    await (_db.update(_db.settingsTable)..where((t) => t.id.equals(1))).write(
      SettingsTableCompanion(freeReminderArmed: Value(ordered.join(','))),
    );
  }

  /// İşletim sistemine kurulmuş ücretsiz hatırlatmaları kaydeder.
  ///
  /// Kanıt tepsi **değil** kurulumun kendisi: tepsi anlık bir fotoğraf ve
  /// kullanıcı bildirimi kaydırıp sildiğinde geriye iz kalmıyor. Kurulum ise
  /// bizim yaptığımız ve kaydedebildiğimiz bir olay.
  Future<void> armFreeReminders(Iterable<int> noteIds) async {
    final ids = {
      for (final id in noteIds)
        if (id > 0) id,
    };
    if (ids.isEmpty) return;
    if (await _isProUnlocked()) return;
    await loadFreeReminderFloor();
    await _db.transaction(() async {
      final armed = await _armedFreeReminders();
      final burned = await _freeReminderNotes();
      final next = {...armed, ...ids.where((id) => !burned.contains(id))};
      if (next.length == armed.length) return;
      await _writeArmed(next);
    });
  }

  /// Kurulu sayılan kayıtları işletim sisteminin **gerçek programıyla**
  /// uzlaştırır.
  ///
  /// Defter tek yönlü büyüyordu: [armFreeReminders] ekliyor, yalnız notun
  /// kendi hatırlatması değiştiğinde ([_disarmIfUnfired]) düşüyordu. Ana
  /// şalteri kapatan kullanıcının alarmı `cancelAll` ile kalkıyor ama kaydı
  /// defterde kalıyor; zamanı geçince hiç çalmamış bir bildirim için hak
  /// yanıyordu.
  ///
  /// Yalnız **çıkarma** yapıyor ve tek bir şeyi çıkarıyor: programda olmayan
  /// **ve** çalmış olması mümkün olmayan kayıtlar. Zamanı geçmiş bir kayıt
  /// programdan zaten kalkar; onu düşürmek teslim edilmiş değeri bedavaya
  /// çevirirdi. Silinmiş notlar ve hatırlatması boşalmış kayıtlar da düşüyor:
  /// ikisi de [settleFreeReminders] tarafından asla kapatılamaz, defterde
  /// ömür boyu birikirlerdi.
  Future<void> reconcileFreeReminders({
    required Set<int> scheduled,
    DateTime? now,
  }) async {
    if (await _isProUnlocked()) return;
    final moment = now ?? DateTime.now();
    await _db.transaction(() async {
      final armed = await _armedFreeReminders();
      final orphans = armed.difference(scheduled);
      if (orphans.isEmpty) return;

      // Hâlâ kapatılabilecek olanlar: kaydı duran ve anı geçmiş hatırlatmalar.
      final settleable =
          await (_db.select(_db.notes)..where(
                (t) =>
                    t.id.isIn(orphans) &
                    t.remindAt.isSmallerOrEqualValue(moment),
              ))
              .get();
      final next = armed.difference(
        orphans.difference(settleable.map((note) => note.id).toSet()),
      );
      if (next.length == armed.length) return;
      await _writeArmed(next);
    });
  }

  /// Çalmadan iptal edilen hatırlatmanın kurulu kaydını düşürür.
  ///
  /// Kurup vazgeçen kullanıcıdan bir şey alınmıyor: ortada teslim edilmiş bir
  /// değer yok. Zamanı geçmiş bir kayıt buradan **düşmez**; o artık yanmıştır.
  Future<void> _disarmFreeReminder(int noteId) async {
    final armed = await _armedFreeReminders();
    if (!armed.remove(noteId)) return;
    await _writeArmed(armed);
  }

  /// Hatırlatma çalmadan kaldırıldıysa kurulu kaydı düşürür.
  ///
  /// Zamanı geçmiş bir kayıt düşmez: o artık yanmıştır ve kullanıcı onu
  /// kapatarak hakkını geri alamamalı.
  Future<void> _disarmIfUnfired(
    int noteId,
    DateTime? previous,
    DateTime? next,
  ) async {
    if (previous == null) return;
    if (!previous.isAfter(DateTime.now())) return;
    if (next != null && next == previous) return;
    await _disarmFreeReminder(noteId);
  }

  Future<void> settleFreeReminders({
    required Iterable<int> deliveredNoteIds,
    DateTime? now,
  }) async {
    final delivered = {
      for (final id in deliveredNoteIds)
        if (id > 0) id,
    };
    await loadFreeReminderFloor();
    final moment = now ?? DateTime.now();
    await _settle(moment, delivered);
  }

  Future<void> _settle(DateTime moment, Set<int> deliveredNoteIds) async {
    // Pro kontrolü transaction'ın **dışında**.
    //
    // İçeride olduğunda Pro kullanıcı her senkronda boşuna bir transaction
    // açıyordu — ve senkron her öne dönüşte, her kayıt değişiminde, her ayar
    // yayınında koşuyor. Yapılacak işi olmayan bir kilit, en pahalı hiçbir
    // şeydir.
    if (await _isProUnlocked()) return;
    await _db.transaction(() async {
      // İki kanıt birleşiyor. **Kurulu olup zamanı geçmiş** kayıt asıl
      // ölçüt: dayanıklı, çünkü kurulumu biz yaptık ve yazdık. Tepside
      // görülen kayıt ise erken kapanış — kullanıcı bildirimi silmeden
      // uygulamayı açtıysa hesap o turda kapanıyor.
      final armed = await _armedFreeReminders();
      final candidates = {...armed, ...deliveredNoteIds};
      if (candidates.isEmpty) return;
      final fired =
          await (_db.select(_db.notes)..where(
                (t) =>
                    t.id.isIn(candidates) &
                    t.remindAt.isSmallerOrEqualValue(moment),
              ))
              .get();
      final firedIds = fired.map((note) => note.id).toSet();
      if (firedIds.isNotEmpty && armed.intersection(firedIds).isNotEmpty) {
        await _writeArmed(armed.difference(firedIds));
      }
      await _burnFreeReminders(firedIds);
    });
  }

  /// Verilen kayıtları ücretsiz hakkı yakmış sayar.
  ///
  /// Çağıran zaten bir transaction içinde olmalı ve Pro kontrolünü yapmış
  /// olmalı.
  Future<void> _burnFreeReminders(Iterable<int> noteIds) async {
    final used = await _freeReminderNotes();
    final next = {...used, ...noteIds};
    if (next.length == used.length) return;
    final ordered = next.toList()..sort();
    await (_db.update(_db.settingsTable)..where((t) => t.id.equals(1))).write(
      SettingsTableCompanion(freeReminderNotes: Value(ordered.join(','))),
    );
    // Silinmeyen taban da yükseliyor. Yazma beklenmeden gidiyor: bu tur
    // başarısız olsa bile veritabanı doğruyu taşıyor ve bir sonraki yakma
    // aynı sayıyı yeniden gönderiyor.
    if (next.length > _burnedFloor) {
      _burnedFloor = next.length;
      unawaited(_quota.write(_burnedFloor));
    }
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
    await _store.removeAll(filesOf(note));
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
    await _store.removeAll(doomed.expand(filesOf));
  }

  /// Süresi dolmuş notları temizler. Açılışta, uygulama öne geldiğinde ve
  /// önplandayken dakikada bir çalışır.
  ///
  /// Silinen not sayısını döner.
  Future<int> purgeExpired({
    Iterable<int> deliveredReminderNoteIds = const <int>{},
  }) async {
    final now = DateTime.now();
    final query = _db.select(_db.notes)
      ..where((t) => t.expiresAt.isSmallerOrEqualValue(now));
    final expired = await query.get();
    if (expired.isEmpty) return 0;

    final delivered = deliveredReminderNoteIds.toSet();
    if (delivered.isNotEmpty) await loadFreeReminderFloor();
    final ids = expired.map((note) => note.id).toList();
    await _db.transaction(() async {
      // Silmeden **önce** hak hesabı kapanıyor.
      //
      // "Hatırlat, sonra sil" seçildiğinde not bildirimden yarım saat sonra
      // gidiyor; yani ücretsiz hakkın en sık kullanıldığı yol tam da burası.
      // Süpürme hesaptan önce koşarsa çalmış hatırlatmayı taşıyan kayıt yok
      // oluyor ve hak sessizce geri geliyordu — kullanıcı aynı hakları
      // sonsuza kadar yeniden kullanabilirdi.
      //
      // Yalnız tepside gerçekten görülmüş kayıtlar yakılır. İzin açık olsa da
      // programlama başarısız olmuş veya alarm daha önce iptal edilmiş olabilir.
      if (delivered.isNotEmpty && !await _isProUnlocked()) {
        await _burnFreeReminders(
          expired
              .where(
                (note) =>
                    delivered.contains(note.id) &&
                    note.remindAt != null &&
                    !note.remindAt!.isAfter(now),
              )
              .map((note) => note.id),
        );
      }
      await (_db.delete(_db.notes)..where((t) => t.id.isIn(ids))).go();
    });
    await _store.removeAll(expired.expand(filesOf));
    return expired.length;
  }

  /// Diskte bulunmuş kareleri kayıt olarak geri alır ve kaç tanesini aldığını
  /// döner.
  ///
  /// Onarımın son adımı: dosya zaten depoda duruyor, burada yalnızca satırı
  /// açılıyor. [create]'in yolundan geçmiyor çünkü o dosyayı depoya
  /// **kopyalar** — burada kopyalanacak bir şey yok, kaybolan taraf kayıttı.
  ///
  /// Saklama süresi bilinçli olarak [Retention.off]: kurtarılan kaydın özgün
  /// süresi veritabanıyla birlikte gitti ve tahmin etmek, kullanıcının hiç
  /// istemediği bir anda kareyi silmek demek olurdu. Süresiz kalması geri
  /// alınabilir; silinmesi değil.
  ///
  /// Aynı dosya adına kayıt varsa atlanıyor: onarım iki kez koşarsa arşiv
  /// ikizlenmemeli.
  Future<int> adoptFrames(Iterable<RecoveredFrame> frames) async {
    final wanted = frames.toList(growable: false);
    if (wanted.isEmpty) return 0;

    return _db.transaction(() async {
      final existing = {
        for (final note in await _db.select(_db.notes).get())
          if (note.hasPhoto) note.imageName,
      };

      var adopted = 0;
      for (final frame in wanted) {
        if (existing.contains(frame.imageName)) continue;
        await _insertNote(
          imageName: frame.imageName,
          originalName: null,
          text: '',
          stamp: frame.createdAt,
          retention: const RetentionChoice.off(),
          reminder: const ReminderChoice.off(),
          location: null,
        );
        adopted++;
      }
      return adopted;
    });
  }

  /// Kaydı olmayan fotoğrafları diskten atar. Yalnızca açılışta çağrılır.
  ///
  /// Veritabanı bu açılışta sıfırdan kurulduysa **hiçbir şey silinmiyor.**
  /// Toplayıcının ölçütü "tabloda karşılığı yok"; taze bir tablonun yanında bu
  /// ölçüt bütün arşivi yetim ilan eder. Oysa o kareler kullanıcının tek
  /// kopyası ve kaybolan şey veritabanı — silinmesi gereken kare değil.
  /// Bu, uygulamanın kendini onarabileceği tek durumun da ön koşulu: taze
  /// veritabanı kurulup kareler yerinde bırakılırsa geri alınabilirler.
  Future<void> sweepOrphanFiles() async {
    final rows = await _db.select(_db.notes).get();
    if (_db.createdFresh && rows.isEmpty) {
      debugPrint(
        'Veritabanı bu açılışta sıfırdan kuruldu; yetim toplama atlandı.',
      );
      return;
    }
    await _store.pruneOrphans(rows.expand(filesOf).toSet());
  }

  Future<void> close() => _db.close();
}
