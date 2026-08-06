import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/features/notes/data/notes_database.dart';
import 'package:not_app/features/notes/data/notes_repository.dart';
import 'package:not_app/features/notes/data/photo_store.dart';
import 'package:not_app/features/notes/domain/retention.dart';

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late PhotoStore photos;
  late NotesRepository repository;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('not_app_test');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    photos = await PhotoStore.openIn(sandbox);
    repository = NotesRepository(database: database, photos: photos);
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
      retention: Retention.off,
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

  test('süreli kayıt için son kullanma tarihi hesaplanır', () async {
    final created = DateTime(2026, 8, 6, 14, 32);

    await repository.create(
      capture: await fakeCapture(),
      body: 'Araba P10',
      retention: Retention.threeDays,
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
      retention: Retention.threeDays,
      createdAt: now.subtract(const Duration(days: 4)),
    );
    // Hâlâ yaşıyor.
    await repository.create(
      capture: await fakeCapture(),
      body: 'taze',
      retention: Retention.oneWeek,
      createdAt: now.subtract(const Duration(days: 1)),
    );
    // Süresiz.
    await repository.create(
      capture: await fakeCapture(),
      body: 'kalıcı',
      retention: Retention.off,
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

  test('düzenleme notun ömrünü uzatmaz', () async {
    final created = DateTime(2026, 8, 6, 14, 32);
    await repository.create(
      capture: await fakeCapture(),
      body: 'ilk',
      retention: Retention.threeDays,
      createdAt: created,
    );

    final note = (await repository.watchNotes().first).single;
    await repository.update(note, body: 'ikinci', retention: Retention.oneWeek);

    final updated = (await repository.watchNotes().first).single;
    expect(updated.body, 'ikinci');
    // Süre düzenleme anına değil, hâlâ oluşturma anına göre.
    expect(updated.expiresAt, DateTime(2026, 8, 13, 14, 32));
  });

  test('silme kaydı ve fotoğrafı birlikte kaldırır', () async {
    await repository.create(
      capture: await fakeCapture(),
      body: 'gidecek',
      retention: Retention.off,
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
      retention: Retention.off,
    );

    final orphan = File('${sandbox.path}/captures/yetim.jpg');
    await orphan.writeAsBytes([1, 2, 3]);

    await repository.sweepOrphanFiles();

    expect(orphan.existsSync(), isFalse);
    final note = (await repository.watchNotes().first).single;
    expect(repository.imageOf(note).existsSync(), isTrue);
  });
}
