import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_kind.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/paywall/data/reminder_quota_store.dart';
import 'package:latermark/features/paywall/domain/pro_limits.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// Karesiz kayıt şemayı hiç değiştirmiyor: işaret `imageName`'in boş
/// olmasından ibaret. Bu dosya o sözleşmenin uçlarını kilitliyor — özellikle
/// boş adın **dosya adı sanılabileceği** yerleri.
/// Silinmeyen sayacın yerine geçen defter.
class _FakeQuota implements ReminderQuotaStore {
  _FakeQuota(this._stored);

  final int? _stored;
  int reads = 0;
  final writes = <int>[];

  @override
  Future<int?> read() async {
    reads++;
    return _stored;
  }

  @override
  Future<void> write(int value) async => writes.add(value);
}

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late PhotoStore photos;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_text_note');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    photos = await PhotoStore.openIn(sandbox);
    repository = NotesRepository(database: database, photos: photos);
    settings = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<Note> noteById(int id) => (database.select(
    database.notes,
  )..where((t) => t.id.equals(id))).getSingle();

  test('karesiz kayıt boş dosya adıyla yazılıyor', () async {
    final id = await repository.createText(
      body: 'Akşam Claude ile olan işi hatırlat',
      retention: const RetentionChoice(Retention.oneWeek),
    );

    final note = await noteById(id);
    expect(note.imageName, '');
    expect(note.isTextOnly, isTrue);
    expect(note.hasPhoto, isFalse);
    expect(note.body, 'Akşam Claude ile olan işi hatırlat');
    // Asıl iddia: karesiz kayıt için şemaya **işaret sütunu eklenmedi**.
    // Ölçüt boş `image_name`, başka hiçbir şey.
    //
    // Burada eskiden mutlak sürüm numarası (`schemaVersion == 10`) çivili
    // duruyordu. O sayı bu iddiayı hiç kanıtlamıyordu ve başka bir sebeple
    // sürüm arttığında da kırılıyordu.
    final columns = await database
        .customSelect('PRAGMA table_info("notes")')
        .map((row) => row.read<String>('name'))
        .get();
    expect(columns, contains('image_name'));
    expect(columns, isNot(contains('kind')));
    expect(columns, isNot(contains('note_type')));
    expect(columns, isNot(contains('is_text')));
  });

  test('boş dosya adı sahiplenilmiş dosya sayılmıyor', () async {
    final id = await repository.createText(
      body: 'Not',
      retention: const RetentionChoice(Retention.oneWeek),
    );
    final note = await noteById(id);

    // Süzülmeseydi silme ve yetim toplama, fotoğraf klasörünün **kendi
    // yolunu** bir dosya sanardı.
    expect(NotesRepository.filesOf(note), isEmpty);
  });

  test('karesiz kayıt OCR kuyruğuna hiç girmiyor', () async {
    await repository.createText(
      body: 'Okunacak kare yok',
      retention: const RetentionChoice(Retention.oneWeek),
    );

    // `photoFolded` null bırakılsaydı bu kayıt, deneme hakkı bitene kadar
    // her liste değişiminde sırada dönerdi.
    expect(await repository.unscanned(), isEmpty);
  });

  test('küçük kopya üretimi karesiz kayıtta denenmiyor', () async {
    final id = await repository.createText(
      body: 'Not',
      retention: const RetentionChoice(Retention.oneWeek),
    );

    expect(await repository.ensureThumbnail(await noteById(id)), isFalse);
  });

  test(
    'karesiz kayıt silinince fotoğraf klasörü olduğu yerde kalıyor',
    () async {
      final id = await repository.createText(
        body: 'Not',
        retention: const RetentionChoice(Retention.oneWeek),
      );
      // Boş ad süzülmeseydi silme, klasörün kendi yolunu dosya sanıp silmeye
      // çalışırdı.
      await repository.delete(await noteById(id));

      expect(photos.fileFor('kare.jpg').parent.existsSync(), isTrue);
    },
  );

  test('hatırlatma kuralları kareli kayıtla aynı', () async {
    await settings.setProUnlocked(true);
    final at = DateTime.now().add(const Duration(days: 2));

    final id = await repository.createText(
      body: 'Hatırlat',
      retention: const RetentionChoice(Retention.oneWeek),
      reminder: ReminderChoice(at: at),
    );

    final note = await noteById(id);
    expect(note.remindAt, isNotNull);
  });

  test('Pro değilken hatırlatma kurulabiliyor, hak bitince düşüyor', () async {
    // Ücretsiz katmanda hatırlatma tümden kapalı değil, **sayılı**: kullanıcı
    // ürünün sözünü (kaydın doğru anda geri gelmesi) hiç yaşamadan ödemeye
    // çağrılmamalı. Bkz. [ProLimits.freeReminders].
    final at = DateTime.now().add(const Duration(days: 2));
    final granted = <int>[];
    for (var i = 0; i < ProLimits.freeReminders; i++) {
      granted.add(
        await repository.createText(
          body: 'Hatırlat $i',
          retention: const RetentionChoice(Retention.oneWeek),
          reminder: ReminderChoice(at: at),
        ),
      );
    }
    for (final id in granted) {
      expect((await noteById(id)).remindAt, isNotNull, reason: 'kayıt $id');
    }

    // Kurulu olanlar da kapıya dahil: hiçbiri çalmadan sınırsız kurmak
    // mümkün olmamalı.
    final overflow = await repository.createText(
      body: 'Dördüncü',
      retention: const RetentionChoice(Retention.oneWeek),
      reminder: ReminderChoice(at: at),
    );
    expect((await noteById(overflow)).remindAt, isNull);
  });

  test('hak kurulumda değil teslimde yanıyor', () async {
    // Kurup vazgeçen kullanıcıdan bir şey alınmaz: ortada teslim edilmiş bir
    // değer yok. Ölçüt zamanın kendisi — geçmişte kalmış bir `remindAt`,
    // bildirimin gösterilmiş olması demek.
    final id = await repository.createText(
      body: 'Vazgeçilen',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 2))),
    );
    await repository.settleFreeReminders(deliveredNoteIds: {id});
    expect((await settings.read()).freeReminderNotes, isEmpty);

    // Aynı kayıt geçmişe alınınca hak yanıyor.
    await repository.setReminder(
      id,
      ReminderChoice(at: DateTime.now().subtract(const Duration(minutes: 5))),
    );
    await repository.settleFreeReminders(deliveredNoteIds: {id});
    expect((await settings.read()).freeReminderNotes, {id});
  });

  test(
    'zamanı geçen ama teslimat kanıtı olmayan hatırlatma hakkı yakmıyor',
    () async {
      final id = await repository.createText(
        body: 'Kurulamadı',
        retention: const RetentionChoice.off(),
        reminder: ReminderChoice(
          at: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

      await repository.settleFreeReminders(deliveredNoteIds: const {});

      expect((await settings.read()).freeReminderNotes, isEmpty);
      expect((await repository.noteById(id))!.remindAt, isNotNull);
    },
  );

  test('bildirim izni yokken hak yanmıyor', () async {
    // İzin kapalıyken program hiç kurulmuyor; kullanıcının görmediği bir şey
    // için hak yakmak haksızlık olurdu.
    final id = await repository.createText(
      body: 'Görülmedi',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    expect(id, isPositive);
    await repository.settleFreeReminders(deliveredNoteIds: const {});
    expect((await settings.read()).freeReminderNotes, isEmpty);
  });

  test('süpürme, çalmış hatırlatmanın hakkını silmeden önce yakıyor', () async {
    // En sık kullanılan yol tam da burası: "hatırlat, sonra sil" seçildiğinde
    // not bildirimden yarım saat sonra gidiyor. Süpürme hesaptan önce
    // koşarsa kayıt yok oluyor ve hak sessizce geri geliyordu — kullanıcı
    // aynı hakları sonsuza kadar yeniden kullanabilirdi.
    final id = await repository.createText(
      body: 'çaldı ve silinecek',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(
        at: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    // Kaydı süresi dolmuş hâle getir: süpürme onu silecek.
    await database
        .customStatement('UPDATE notes SET expires_at = ? WHERE id = ?', [
          DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          id,
        ]);

    expect(await repository.purgeExpired(deliveredReminderNoteIds: {id}), 1);
    expect(await database.select(database.notes).get(), isEmpty);
    // Kayıt gitti ama hak yandı.
    expect((await settings.read()).freeReminderNotes, {id});
  });

  test('süpürme, hiç çalmamış hatırlatmanın hakkını yakmıyor', () async {
    // Kayıt süresi dolduğu için silindi ama hatırlatma zamanı gelmemişti;
    // ortada teslim edilmiş bir değer yok.
    final id = await repository.createText(
      body: 'çalmadan silindi',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 3))),
    );
    await database
        .customStatement('UPDATE notes SET expires_at = ? WHERE id = ?', [
          DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          id,
        ]);

    expect(await repository.purgeExpired(deliveredReminderNoteIds: {id}), 1);
    expect((await settings.read()).freeReminderNotes, isEmpty);
  });

  test('ücretsiz katmanda tekrar yok, tek atışa iniyor', () async {
    // Hak "üç bildirim" demek. Tekrarlı bir hatırlatma tek hakla sınırsız
    // bildirim üretirdi: günlük tekrar kuran biri bir slotla ömür boyu
    // hatırlatma alır ve sayının hiçbir anlamı kalmazdı.
    final id = await repository.createText(
      body: 'her gün olsun',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(
        at: DateTime.now().add(const Duration(days: 1)),
        cadence: ReminderCadence.daily,
      ),
    );

    final note = await noteById(id);
    expect(note.remindAt, isNotNull, reason: 'hatırlatmanın kendisi duruyor');
    expect(note.remindEveryDays, 0, reason: 'ritim tek atışa indi');
  });

  test('silinmeyen taban, yeniden kurulumda hakkı geri vermiyor', () async {
    // Latermark'ı yalnız hatırlatma için kullanan birinin kaybedecek arşivi
    // yok; silip yeniden kurmak ona bedelsiz. Veritabanı boş başlasa da
    // Keychain'deki sayı duruyor.
    //
    // Burada tam o hâl kuruluyor: taban 3, veritabanı bomboş.
    final store = _FakeQuota(3);
    final fresh = NotesRepository(
      database: database,
      photos: photos,
      quota: store,
    );
    await fresh.loadFreeReminderFloor();
    expect(fresh.freeReminderFloor, 3);

    final id = await fresh.createText(
      body: 'yeniden kurdum',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 1))),
    );
    expect((await noteById(id)).remindAt, isNull, reason: 'hak yok');
  });

  test('ilk kayıt silinmeyen tabanı kendisi yüklemeden geçemiyor', () async {
    // AppScope henüz ilk senkronunu tamamlamadan Share/Siri ya da hızlı bir
    // kullanıcı kaydı gelebilir. Güvenlik yalnız açılış sırasına bağlıysa bu
    // dar pencerede yeniden kurulum hakları geri verirdi.
    final store = _FakeQuota(ProLimits.freeReminders);
    final fresh = NotesRepository(
      database: database,
      photos: photos,
      quota: store,
    );

    final id = await fresh.createText(
      body: 'açılıştan önce',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 1))),
    );

    expect(store.reads, 1);
    expect(fresh.freeReminderFloor, ProLimits.freeReminders);
    expect((await noteById(id)).remindAt, isNull, reason: 'hak geri açılmadı');
  });

  test('Pro açıkken silinmeyen sayaca hiç uğranmıyor', () async {
    await settings.setProUnlocked(true);
    final store = _FakeQuota(3);
    final pro = NotesRepository(
      database: database,
      photos: photos,
      quota: store,
    );

    await pro.loadFreeReminderFloor();
    expect(store.reads, 0, reason: 'Pro kullanıcıda okuma yok');
    expect(pro.freeReminderFloor, 0);

    final id = await pro.createText(
      body: 'Pro hatırlatması',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 1))),
    );
    expect((await noteById(id)).remindAt, isNotNull);
    expect(store.writes, isEmpty, reason: 'Pro etkinliği sayaca yazılmaz');
  });

  test('hak yakılınca silinmeyen sayaç yükseliyor', () async {
    final store = _FakeQuota(null);
    final repo = NotesRepository(
      database: database,
      photos: photos,
      quota: store,
    );
    await repo.loadFreeReminderFloor();

    final id = await repo.createText(
      body: 'çalacak',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    expect(id, isPositive);
    await repo.settleFreeReminders(deliveredNoteIds: {id});

    expect(store.writes, [1]);
    expect(repo.freeReminderFloor, 1);
  });

  test('taban oturumda bir kez okunuyor', () async {
    // Senkron her öne dönüşte ve her kayıt değişiminde koşuyor; tabanı orada
    // her seferinde okumak oturum boyunca yüzlerce Keychain çağrısı demekti.
    final store = _FakeQuota(2);
    final repo = NotesRepository(
      database: database,
      photos: photos,
      quota: store,
    );

    await repo.loadFreeReminderFloor();
    await repo.loadFreeReminderFloor();
    await repo.loadFreeReminderFloor();

    expect(store.reads, 1);
    expect(repo.freeReminderFloor, 2);
  });

  test('güncellemeyi alan kullanıcı hakkını kaybetmiyor', () async {
    // Keychain boş; yani bu sertleştirmeyi ilk kez alan mevcut kullanıcı.
    // Davranış eskisiyle birebir aynı kalmalı: hakların tamamı yerinde.
    final store = _FakeQuota(null);
    final repo = NotesRepository(
      database: database,
      photos: photos,
      quota: store,
    );
    await repo.loadFreeReminderFloor();
    expect(repo.freeReminderFloor, 0);

    final at = DateTime.now().add(const Duration(days: 1));
    for (var i = 0; i < ProLimits.freeReminders; i++) {
      final id = await repo.createText(
        body: 'hak $i',
        retention: const RetentionChoice.off(),
        reminder: ReminderChoice(at: at),
      );
      expect((await noteById(id)).remindAt, isNotNull, reason: 'kayıt $i');
    }
  });

  test('tepsiden silinen bildirim hakkı kaçırmıyor', () async {
    // Ölçülmüş bir sızıntının testi. Kanıt olarak yalnız tepsi
    // (`getActiveNotifications`) kullanıldığında, kullanıcı çalan bildirimi
    // kaydırıp silince geriye hiç iz kalmıyordu: hak hiç yanmıyor ve aynı üç
    // hak sonsuza kadar yeniden kullanılabiliyordu.
    //
    // Dayanıklı kanıt kurulumun kendisi. Burada bildirim kuruluyor, sonra
    // tepside **hiç görünmeden** zamanı geçiyor.
    final id = await repository.createText(
      body: 'tepsiden silinecek',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 1))),
    );
    await repository.armFreeReminders({id});

    // Kurulduğu an değil, zamanı geçtiğinde yanıyor.
    await repository.settleFreeReminders(deliveredNoteIds: const <int>{});
    expect((await settings.read()).freeReminderNotes, isEmpty);

    await database.customStatement(
      'UPDATE notes SET remind_at = ? WHERE id = ?',
      [
        DateTime.now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
        id,
      ],
    );
    // Tepsi **boş** — kullanıcı bildirimi sildi.
    await repository.settleFreeReminders(deliveredNoteIds: const <int>{});
    expect((await settings.read()).freeReminderNotes, {id});
  });

  test('çalmadan iptal edilen hatırlatma hakkı geri veriyor', () async {
    final id = await repository.createText(
      body: 'vazgeçilecek',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 1))),
    );
    await repository.armFreeReminders({id});

    // Kapı kurulu kaydı sayıyor.
    expect(
      await repository.setReminder(id, const ReminderChoice.off()),
      isTrue,
    );

    // Kurulu listeden düştüğü için zamanı geçse bile yanmıyor: ortada teslim
    // edilmiş bir değer yok.
    await database.customStatement(
      'UPDATE notes SET remind_at = ? WHERE id = ?',
      [
        DateTime.now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
        id,
      ],
    );
    await repository.settleFreeReminders(deliveredNoteIds: const <int>{});
    expect((await settings.read()).freeReminderNotes, isEmpty);
  });

  test('aynı teslim kimliği ikinci kaydı açmıyor', () async {
    final first = await repository.createText(
      body: 'Siri',
      retention: const RetentionChoice(Retention.oneWeek),
      importId: 'siri-1',
    );
    final second = await repository.createText(
      body: 'Siri',
      retention: const RetentionChoice(Retention.oneWeek),
      importId: 'siri-1',
    );

    expect(second, first);
    expect((await database.select(database.notes).get()).length, 1);
  });
}
