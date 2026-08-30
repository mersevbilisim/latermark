import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/location_service.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/reminder_action.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late PhotoStore photos;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_test');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    photos = await PhotoStore.openIn(sandbox);
    repository = NotesRepository(database: database, photos: photos);
    settings = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Kameradan gelmiş gibi geçici bir kare üretir.
  Future<XFile> fakeCapture() async {
    final file = File(
      '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(List<int>.filled(64, 7));
    return XFile(file.path);
  }

  test('kayıt fotoğrafı kalıcı klasöre kopyalar', () async {
    final id = await repository.create(
      capture: await fakeCapture(),
      body: '  Muhasebeye göndereceğim  ',
      retention: RetentionChoice(Retention.off),
    );

    final notes = await repository.watchNotes().first;
    expect(notes, hasLength(1));

    final note = notes.single;
    expect(note.id, id);
    // Baştaki ve sondaki boşluklar kırpılır.
    expect(note.body, 'Muhasebeye göndereceğim');
    expect(note.expiresAt, isNull);
    expect(repository.imageOf(note).existsSync(), isTrue);
  });

  test(
    'aynı platform importu iki kez teslim edilse de tek kayıt oluşur',
    () async {
      final capture = await fakeCapture();
      const importId = '3b8ed5a6-6633-4f72-b4fe-3c79fba1d958';

      final first = await repository.create(
        capture: capture,
        body: 'Paylaşılan kare',
        retention: const RetentionChoice(Retention.off),
        importId: importId,
      );
      final replay = await repository.create(
        capture: capture,
        body: 'İkinci teslim',
        retention: const RetentionChoice(Retention.off),
        importId: importId,
      );

      expect(replay, first);
      expect(await repository.hasProcessedImport(importId), isTrue);
      expect(await repository.watchNotes().first, hasLength(1));
      expect(
        Directory('${sandbox.path}/captures').listSync().whereType<File>(),
        hasLength(1),
      );

      // Cleanup gecikti, kullanıcı ise kaydı sildi: eski teslim notu yeniden
      // diriltmemeli.
      await repository.delete((await repository.watchNotes().first).single);
      expect(
        await repository.create(
          capture: capture,
          body: 'Üçüncü teslim',
          retention: const RetentionChoice(Retention.off),
          importId: importId,
        ),
        first,
      );
      expect(await repository.watchNotes().first, isEmpty);
    },
  );

  test('konum enlem ve boylam olarak notla birlikte saklanır', () async {
    await repository.create(
      capture: await fakeCapture(),
      body: 'Araba burada',
      retention: RetentionChoice(Retention.off),
      location: const NoteLocation(latitude: 41.2607, longitude: 29.0421),
    );

    final note = (await repository.watchNotes().first).single;
    expect(note.latitude, 41.2607);
    expect(note.longitude, 29.0421);
  });

  test('süreli kayıt için son kullanma tarihi hesaplanır', () async {
    final created = DateTime(2026, 8, 6, 14, 32);

    await repository.create(
      capture: await fakeCapture(),
      body: 'Araba P10',
      retention: RetentionChoice(Retention.threeDays),
      createdAt: created,
    );

    final note = (await repository.watchNotes().first).single;
    expect(note.retention, Retention.threeDays);
    expect(note.expiresAt, DateTime(2026, 8, 9, 14, 32));
  });

  test('purgeExpired yalnızca süresi dolanları ve dosyalarını siler', () async {
    final now = DateTime.now();

    // Süresi dün dolmuş.
    await repository.create(
      capture: await fakeCapture(),
      body: 'eski',
      retention: RetentionChoice(Retention.threeDays),
      createdAt: now.subtract(const Duration(days: 4)),
    );
    // Hâlâ yaşıyor.
    await repository.create(
      capture: await fakeCapture(),
      body: 'taze',
      retention: RetentionChoice(Retention.oneWeek),
      createdAt: now.subtract(const Duration(days: 1)),
    );
    // Süresiz.
    await repository.create(
      capture: await fakeCapture(),
      body: 'kalıcı',
      retention: RetentionChoice(Retention.off),
      createdAt: now.subtract(const Duration(days: 400)),
    );

    final before = await repository.watchNotes().first;
    final doomed = before.firstWhere((note) => note.body == 'eski');

    expect(await repository.purgeExpired(), 1);

    final after = await repository.watchNotes().first;
    expect(after.map((note) => note.body), unorderedEquals(['taze', 'kalıcı']));
    expect(repository.imageOf(doomed).existsSync(), isFalse);
    for (final note in after) {
      expect(repository.imageOf(note).existsSync(), isTrue);
    }
  });

  test('düzenleme saklama süresine dokunmaz', () async {
    await settings.setProUnlocked(true);
    final created = DateTime(2026, 8, 6, 14, 32);
    await repository.create(
      capture: await fakeCapture(),
      body: 'ilk',
      retention: RetentionChoice(Retention.threeDays),
      createdAt: created,
    );

    final note = (await repository.watchNotes().first).single;
    final remindAt = DateTime(2026, 8, 9, 9);
    await repository.update(
      note,
      body: 'ikinci',
      reminder: ReminderChoice(at: remindAt),
    );

    final updated = (await repository.watchNotes().first).single;
    expect(updated.body, 'ikinci');
    expect(updated.remindAt, remindAt);
    // Saklama süresi artık kayıt başına düzenlenmiyor: kaydın ömrü
    // oluşturulduğu andaki tercihe bağlı kalır, düzenleme onu ne uzatır ne
    // kısaltır.
    expect(updated.retention, Retention.threeDays);
    expect(updated.expiresAt, DateTime(2026, 8, 9, 14, 32));
  });

  test('düzenleme damgası yalnızca gerçek bir değişiklikte vurulur', () async {
    await settings.setProUnlocked(true);
    final created = DateTime(2026, 8, 6, 14, 32);
    await repository.create(
      capture: await fakeCapture(),
      body: 'ilk',
      retention: RetentionChoice(Retention.threeDays),
      createdAt: created,
    );

    final fresh = (await repository.watchNotes().first).single;
    // Çekildiğinden beri dokunulmamış bir kayıt "düzenlenmiş" görünmez.
    expect(fresh.updatedAt, isNull);

    // Düzenleyiciyi açıp hiçbir şeye dokunmadan kaydetmek de değişiklik
    // değildir; damga zamanla anlamını yitirmemeli.
    await repository.update(
      fresh,
      body: fresh.body,
      reminder: ReminderChoice(
        at: fresh.remindAt,
        cadence: ReminderCadence.fromCode(fresh.remindEveryDays),
      ),
    );
    expect((await repository.watchNotes().first).single.updatedAt, isNull);

    await repository.update(
      fresh,
      body: 'ikinci',
      reminder: const ReminderChoice.off(),
    );
    final edited = (await repository.watchNotes().first).single;
    expect(edited.updatedAt, isNotNull);
    expect(edited.updatedAt!.isAfter(created), isTrue);
    // Damga ömre karışmaz: silinme anı hâlâ oluşturulma anından hesaplanır.
    expect(edited.expiresAt, DateTime(2026, 8, 9, 14, 32));
    expect(edited.createdAt, created);
  });

  test('hatırlatma düzenlemeden kaldırılabilir', () async {
    await settings.setProUnlocked(true);
    await repository.create(
      capture: await fakeCapture(),
      body: 'hatırlatmalı',
      retention: RetentionChoice(Retention.off),
      reminder: ReminderChoice(at: DateTime(2026, 8, 13, 9)),
    );

    final note = (await repository.watchNotes().first).single;
    await repository.update(
      note,
      body: note.body,
      reminder: const ReminderChoice.off(),
    );

    expect((await repository.watchNotes().first).single.remindAt, isNull);
  });

  test(
    'free durumda gecikmiş Pro alanları veritabanına geri yazılamaz',
    () async {
      await repository.create(
        capture: await fakeCapture(),
        body: 'gecikmiş sheet',
        retention: RetentionChoice.custom(const Duration(days: 5).inMinutes),
        reminder: ReminderChoice(at: DateTime(2026, 8, 12, 12)),
        createdAt: DateTime(2026, 8, 8, 12),
      );

      var note = (await repository.watchNotes().first).single;
      expect(note.retention, Retention.oneWeek);
      expect(note.customMinutes, 0);
      expect(note.remindAt, isNull);

      await repository.update(
        note,
        body: note.body,
        reminder: ReminderChoice(at: DateTime(2026, 8, 17, 12)),
      );
      note = (await repository.watchNotes().first).single;
      expect(note.remindAt, isNull);
    },
  );

  test(
    'planlama ekranı hatırlatmayı yazar, düzenleme damgasına dokunmaz',
    () async {
      await settings.setProUnlocked(true);
      final id = await repository.create(
        capture: await fakeCapture(),
        body: 'kışlık lastik',
        retention: RetentionChoice(Retention.off),
        createdAt: DateTime(2026, 8, 8, 12),
      );

      final before = (await repository.watchNotes().first).single;
      await repository.setReminder(
        id,
        ReminderChoice(
          at: DateTime(2026, 8, 20, 9),
          cadence: ReminderCadence.fromCode(12),
        ),
      );

      final after = (await repository.watchNotes().first).single;
      expect(after.remindAt, DateTime(2026, 8, 20, 9));
      expect(
        ReminderCadence.fromCode(after.remindEveryDays),
        ReminderCadence.monthly,
      );
      // Hatırlatma kurmak notu düzenlemek değil: gövde de damga da yerinde.
      expect(after.body, before.body);
      expect(after.updatedAt, before.updatedAt);
    },
  );

  test('not silindikten sonraya hatırlatma kurulamaz', () async {
    await settings.setProUnlocked(true);
    final created = DateTime(2026, 8, 8, 12);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'kısa ömürlü',
      retention: const RetentionChoice(Retention.threeDays),
      createdAt: created,
    );

    await expectLater(
      repository.setReminder(id, ReminderChoice(at: DateTime(2026, 8, 11, 12))),
      throwsA(isA<ReminderAfterExpiryException>()),
    );
    expect((await repository.noteById(id))!.remindAt, isNull);

    await repository.setReminder(
      id,
      ReminderChoice(at: DateTime(2026, 8, 11, 11, 59)),
    );
    expect(
      (await repository.noteById(id))!.remindAt,
      DateTime(2026, 8, 11, 11, 59),
    );
  });

  test('oluştururken de silinme sonrası hatırlatma reddedilir', () async {
    await settings.setProUnlocked(true);
    final created = DateTime(2026, 8, 8, 12);

    await expectLater(
      repository.create(
        capture: await fakeCapture(),
        body: 'yetişmeyen',
        retention: RetentionChoice.custom(60),
        reminder: ReminderChoice(at: created.add(const Duration(hours: 1))),
        createdAt: created,
      ),
      throwsA(isA<ReminderAfterExpiryException>()),
    );
    expect(await repository.watchNotes().first, isEmpty);
  });

  test('hak kapalıyken planlama ekranı hatırlatma yazamaz', () async {
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'ücretsiz katman',
      retention: RetentionChoice(Retention.off),
    );

    await repository.setReminder(id, ReminderChoice(at: DateTime(2026, 9, 1)));

    expect((await repository.watchNotes().first).single.remindAt, isNull);
  });

  test('tek atış planlandığında tekrar aralığı sıfırlanır', () async {
    await settings.setProUnlocked(true);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'tekrarlıydı',
      retention: RetentionChoice(Retention.off),
      reminder: ReminderChoice(
        at: DateTime(2026, 8, 10, 9),
        cadence: ReminderCadence.weekly,
      ),
    );

    await repository.setReminder(
      id,
      ReminderChoice(at: DateTime(2026, 8, 21, 9)),
    );

    final note = (await repository.watchNotes().first).single;
    expect(note.remindAt, DateTime(2026, 8, 21, 9));
    expect(note.remindEveryDays, 0);
  });

  test(
    'hatırlattıktan sonra sil, silinme anını hatırlatmadan türetir',
    () async {
      await settings.setProUnlocked(true);
      final created = DateTime(2026, 8, 8, 12);
      final id = await repository.create(
        capture: await fakeCapture(),
        body: 'faturayı öde',
        retention: RetentionChoice(Retention.off),
        createdAt: created,
      );

      final at = DateTime(2026, 8, 20, 9);
      await repository.setReminder(
        id,
        ReminderChoice(at: at),
        deleteAfterReminder: true,
      );

      final note = (await repository.watchNotes().first).single;
      expect(note.remindAt, at);
      expect(note.expiresAt, at.add(kReminderExpiryGrace));
      // Ömür kaydın kendi başlangıcından ölçülür; hak düşümü de oradan
      // yeniden hesaplayabilsin.
      expect(note.retention, Retention.custom);
      expect(
        note.customMinutes,
        at.add(kReminderExpiryGrace).difference(created).inMinutes,
      );
    },
  );

  test('tekrarlı hatırlatmada silme sözü yazılmaz', () async {
    await settings.setProUnlocked(true);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'her hafta',
      retention: RetentionChoice(Retention.off),
    );

    await repository.setReminder(
      id,
      ReminderChoice(
        at: DateTime(2026, 8, 20, 9),
        cadence: ReminderCadence.weekly,
      ),
      deleteAfterReminder: true,
    );

    expect((await repository.watchNotes().first).single.expiresAt, isNull);
  });

  test('hatırlatma kalkınca ona bağlı silinme sözü de kalkar', () async {
    await settings.setProUnlocked(true);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'vazgeçilen söz',
      retention: RetentionChoice(Retention.off),
    );
    await repository.setReminder(
      id,
      ReminderChoice(at: DateTime(2026, 8, 20, 9)),
      deleteAfterReminder: true,
    );

    // Planlama ekranından kapatmak.
    await repository.setReminder(id, const ReminderChoice.off());

    var note = (await repository.watchNotes().first).single;
    expect(note.expiresAt, isNull);
    expect(note.retention, Retention.off);

    // Düzenleme panelinden anahtarı kapatmak da aynı sonucu vermeli.
    await repository.setReminder(
      id,
      ReminderChoice(at: DateTime(2026, 8, 20, 9)),
      deleteAfterReminder: true,
    );
    note = (await repository.watchNotes().first).single;
    await repository.update(
      note,
      body: note.body,
      reminder: const ReminderChoice.off(),
    );

    note = (await repository.watchNotes().first).single;
    expect(note.expiresAt, isNull);
    expect(note.remindAt, isNull);
  });

  test('erteleme silinme anını da ileri taşır', () async {
    await settings.setProUnlocked(true);
    final at = DateTime(2026, 8, 20, 9);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'ertelenecek',
      retention: RetentionChoice(Retention.off),
      createdAt: DateTime(2026, 8, 8, 12),
    );
    await repository.setReminder(
      id,
      ReminderChoice(at: at),
      deleteAfterReminder: true,
    );

    final moved = await repository.applyReminderAction(
      id,
      ReminderAction.tomorrow,
      firedAt: at,
      now: at.add(const Duration(minutes: 3)),
    );

    // Taşımasaydı ertelenen bildirim hiç gelmeden not silinirdi.
    expect(moved!.remindAt, DateTime(2026, 8, 21, 9));
    expect(moved.expiresAt, DateTime(2026, 8, 21, 9).add(kReminderExpiryGrace));
  });

  test('"tamam" silme sözünü olduğu gibi bırakır', () async {
    await settings.setProUnlocked(true);
    final at = DateTime(2026, 8, 20, 9);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'görüldü',
      retention: RetentionChoice(Retention.off),
    );
    await repository.setReminder(
      id,
      ReminderChoice(at: at),
      deleteAfterReminder: true,
    );

    final answered = await repository.applyReminderAction(
      id,
      ReminderAction.done,
      firedAt: at,
      now: at.add(const Duration(minutes: 5)),
    );

    expect(answered!.remindAt, isNull);
    expect(answered.expiresAt, at.add(kReminderExpiryGrace));
  });

  test('süresi dolan hatırlatma sözü temizlikte gerçekten siliniyor', () async {
    await settings.setProUnlocked(true);
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'bir saat sonra gider',
      retention: RetentionChoice(Retention.off),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    // Hatırlatma çalmış ve payı da dolmuş bir kayıt.
    await repository.setReminder(
      id,
      ReminderChoice(at: DateTime.now().subtract(kReminderExpiryGrace * 2)),
      deleteAfterReminder: true,
    );

    final note = (await repository.watchNotes().first).single;
    final photo = repository.imageOf(note);
    expect(photo.existsSync(), isTrue);

    expect(await repository.purgeExpired(), 1);
    expect(await repository.watchNotes().first, isEmpty);
    expect(photo.existsSync(), isFalse);
  });

  test('silme kaydı ve fotoğrafı birlikte kaldırır', () async {
    await repository.create(
      capture: await fakeCapture(),
      body: 'gidecek',
      retention: RetentionChoice(Retention.off),
    );

    final note = (await repository.watchNotes().first).single;
    final image = repository.imageOf(note);
    expect(image.existsSync(), isTrue);

    await repository.delete(note);

    expect(await repository.watchNotes().first, isEmpty);
    expect(image.existsSync(), isFalse);
  });

  test(
    'toplu silme yalnızca verilen kayıtları ve karelerini kaldırır',
    () async {
      for (final body in ['ilk', 'ikinci', 'kalan']) {
        await repository.create(
          capture: await fakeCapture(),
          body: body,
          retention: RetentionChoice(Retention.off),
        );
      }

      final all = await repository.watchNotes().first;
      final doomed = all.where((note) => note.body != 'kalan').toList();
      final doomedImages = [
        for (final note in doomed) repository.imageOf(note),
      ];
      final survivor = all.firstWhere((note) => note.body == 'kalan');
      final survivorImage = repository.imageOf(survivor);

      await repository.deleteAll(doomed);

      final left = await repository.watchNotes().first;
      expect(left.map((note) => note.body), ['kalan']);
      for (final image in doomedImages) {
        expect(image.existsSync(), isFalse);
      }
      expect(survivorImage.existsSync(), isTrue);
    },
  );

  test('boş seçimle silme çağrısı hiçbir kaydı düşürmez', () async {
    await repository.create(
      capture: await fakeCapture(),
      body: 'duruyor',
      retention: RetentionChoice(Retention.off),
    );

    await repository.deleteAll(const []);

    expect(await repository.watchNotes().first, hasLength(1));
  });

  test('sweepOrphanFiles kaydı olmayan dosyaları atar', () async {
    await repository.create(
      capture: await fakeCapture(),
      body: 'kalan',
      retention: RetentionChoice(Retention.off),
    );

    final orphan = File('${sandbox.path}/captures/yetim.jpg');
    await orphan.writeAsBytes([1, 2, 3]);
    // Süpürme taze dosyalara dokunmuyor: `persist()` kareyi satırdan önce
    // yazdığı için o pencerede kaydedilen kare yetim sanılıp siliniyordu.
    // Gerçek bir yetim ise eskidir.
    orphan.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 2)),
    );

    await repository.sweepOrphanFiles();

    expect(orphan.existsSync(), isFalse);
    final note = (await repository.watchNotes().first).single;
    expect(repository.imageOf(note).existsSync(), isTrue);
  });

  test('sweepOrphanFiles az önce kaydedilmiş kareye dokunmaz', () async {
    // Açılış süpürmesi isim listesini önden alıp `unawaited` koşuyor; tam o
    // sırada paylaşımdan gelen bir kare kaydedilebiliyor. Kullanıcı notu
    // görür, fotoğrafı gitmiş olurdu.
    final fresh = File('${sandbox.path}/captures/taze.jpg');
    await fresh.writeAsBytes([1, 2, 3]);

    await repository.sweepOrphanFiles();

    expect(fresh.existsSync(), isTrue);
  });

  group('göç', () {
    /// v7 şemasını gerçek güncel şemadan geriye kurar: hatırlatma o sürümde
    /// "çıpa + kaç gün sonra" olarak duruyordu.
    Future<String> seedV7() async {
      final path = '${sandbox.path}/v7.sqlite';
      final seed = NotesDatabase.forExecutor(NativeDatabase(File(path)));
      await seed.select(seed.notes).get();
      await seed.close();

      final v7 = raw.sqlite3.open(path);
      v7.execute(
        'ALTER TABLE settings DROP COLUMN share_signature; '
        'ALTER TABLE notes DROP COLUMN remind_at; '
        'ALTER TABLE notes RENAME COLUMN remind_every_days '
        'TO remind_after_days; '
        'ALTER TABLE notes ADD COLUMN reminder_anchor_at INTEGER NULL; '
        'ALTER TABLE notes ADD COLUMN remind_repeats '
        'INTEGER NOT NULL DEFAULT 0; '
        'PRAGMA user_version = 7;',
      );
      v7.close();
      return path;
    }

    int seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

    test('v7 hatırlatmaları mutlak ana çevrilir', () async {
      final path = await seedV7();
      final createdAt = DateTime(2026, 8, 2, 8);
      final onceAnchor = DateTime(2026, 8, 1, 9);
      final repeatAnchor = DateTime(2026, 7, 1, 21, 30);

      final v7 = raw.sqlite3.open(path);
      void insert(
        String image,
        DateTime created,
        int days,
        DateTime? anchor,
        bool repeats,
      ) => v7.execute(
        'INSERT INTO notes (image_name, body, created_at, '
        'remind_after_days, reminder_anchor_at, remind_repeats) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          image,
          image,
          seconds(created),
          days,
          anchor == null ? null : seconds(anchor),
          repeats ? 1 : 0,
        ],
      );
      insert('once.jpg', createdAt, 3, onceAnchor, false);
      insert('repeat.jpg', createdAt, 30, repeatAnchor, true);
      insert('anchorless.jpg', createdAt, 7, null, false);
      insert('silent.jpg', createdAt, 0, null, false);
      v7.close();

      final migrated = NotesDatabase.forExecutor(NativeDatabase(File(path)));
      addTearDown(migrated.close);
      final notes = {
        for (final note in await migrated.select(migrated.notes).get())
          note.imageName: note,
      };

      // Tek atış: çıpa + gün, artık kaydın kendisinde duran an.
      expect(notes['once.jpg']!.remindAt, DateTime(2026, 8, 4, 9));
      // Aralık yalnızca tekrar için anlamlı; tek atışta sıfırlanır.
      expect(notes['once.jpg']!.remindEveryDays, 0);

      // Tekrarlıda dizinin ilk halkası yazılır, aralık korunur: faz bozulmaz.
      expect(notes['repeat.jpg']!.remindAt, DateTime(2026, 7, 31, 21, 30));
      expect(notes['repeat.jpg']!.remindEveryDays, 30);

      // Çıpası olmayan eski kayıtta sayaç kaydın kendi zamanından başlıyordu.
      expect(notes['anchorless.jpg']!.remindAt, DateTime(2026, 8, 9, 8));

      expect(notes['silent.jpg']!.remindAt, isNull);
      expect(notes['silent.jpg']!.remindEveryDays, 0);
    });

    test('tekrarın bekleyen oluşumu göçten önceki ile aynı kalır', () async {
      // Göçün asıl sınavı bu: kullanıcının kurduğu "her 30 günde bir"
      // programı, sütun değiştirdi diye bir gün bile kaymamalı.
      final path = await seedV7();
      final anchor = DateTime(2026, 7, 1, 21, 30);
      final now = DateTime(2026, 8, 15, 12);
      final before = pendingReminderAt(
        remindAt: shiftLocalCalendarDays(anchor, 30),
        cadence: ReminderCadence.monthly,
        now: now,
      );

      final v7 = raw.sqlite3.open(path);
      v7.execute(
        'INSERT INTO notes (image_name, body, created_at, '
        'remind_after_days, reminder_anchor_at, remind_repeats) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        ['a.jpg', 'Kombi', seconds(anchor), 30, seconds(anchor), 1],
      );
      v7.close();

      final migrated = NotesDatabase.forExecutor(NativeDatabase(File(path)));
      addTearDown(migrated.close);
      final note = await migrated.select(migrated.notes).getSingle();

      expect(
        pendingReminderAt(
          remindAt: note.remindAt,
          cadence: ReminderCadence.fromCode(note.remindEveryDays),
          now: now,
        ),
        before,
      );
    });
  });
}
