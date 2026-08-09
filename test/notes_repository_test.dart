import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/location_service.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
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
    await repository.update(note, body: 'ikinci', remindAfterDays: 4);

    final updated = (await repository.watchNotes().first).single;
    expect(updated.body, 'ikinci');
    expect(updated.remindAfterDays, 4);
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
      remindAfterDays: fresh.remindAfterDays,
    );
    expect((await repository.watchNotes().first).single.updatedAt, isNull);

    await repository.update(fresh, body: 'ikinci', remindAfterDays: 0);
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
      remindAfterDays: 7,
    );

    final note = (await repository.watchNotes().first).single;
    await repository.update(note, body: note.body, remindAfterDays: 0);

    expect((await repository.watchNotes().first).single.remindAfterDays, 0);
  });

  test(
    'free durumda gecikmiş Pro alanları veritabanına geri yazılamaz',
    () async {
      await repository.create(
        capture: await fakeCapture(),
        body: 'gecikmiş sheet',
        retention: RetentionChoice.custom(const Duration(days: 5).inMinutes),
        remindAfterDays: 4,
        createdAt: DateTime(2026, 8, 8, 12),
      );

      var note = (await repository.watchNotes().first).single;
      expect(note.retention, Retention.oneWeek);
      expect(note.customMinutes, 0);
      expect(note.remindAfterDays, 0);

      await repository.update(note, body: note.body, remindAfterDays: 9);
      note = (await repository.watchNotes().first).single;
      expect(note.remindAfterDays, 0);
    },
  );

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

  test('sweepOrphanFiles kaydı olmayan dosyaları atar', () async {
    await repository.create(
      capture: await fakeCapture(),
      body: 'kalan',
      retention: RetentionChoice(Retention.off),
    );

    final orphan = File('${sandbox.path}/captures/yetim.jpg');
    await orphan.writeAsBytes([1, 2, 3]);

    await repository.sweepOrphanFiles();

    expect(orphan.existsSync(), isFalse);
    final note = (await repository.watchNotes().first).single;
    expect(repository.imageOf(note).existsSync(), isTrue);
  });
}
