import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/archive_recovery.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_kind.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Veritabanı gittiğinde geriye kalanın kurtarılması.
///
/// Kurtarmanın dayandığı tek şey, kaydederken dosya adına yazılan çekim
/// damgası. Bu testler o dayanağı çiviliyor: adlandırma değişirse burası
/// düşer ve kurtarma sessizce anlamsızlaşmaz.
void main() {
  late Directory sandbox;
  late PhotoStore photos;
  late NotesDatabase database;
  late NotesRepository repository;
  late ArchiveRecovery recovery;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_recovery');
    photos = await PhotoStore.openIn(sandbox);
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(database: database, photos: photos);
    recovery = ArchiveRecovery(photos: photos, databaseDirectory: sandbox);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Uygulamanın kendi adlandırmasıyla bir kare bırakır.
  File dropFrame(DateTime at, {String salt = 'a1b2'}) {
    final file = File(
      '${sandbox.path}/captures/${at.microsecondsSinceEpoch}-$salt.jpg',
    );
    file.parent.createSync(recursive: true);
    return file..writeAsBytesSync(_pixel);
  }

  test('dosya adı çekim anını taşıyor', () {
    final at = DateTime(2026, 8, 14, 17, 42, 9);
    expect(
      ArchiveRecovery.stampOf('${at.microsecondsSinceEpoch}-9f3c.jpg'),
      at,
    );
    // Uygulamanın üretmediği adlar alınmıyor: uydurma bir tarih vermektense o
    // kareyi hiç almamak yeğ.
    expect(ArchiveRecovery.stampOf('IMG_0421.jpg'), isNull);
    expect(ArchiveRecovery.stampOf('12-abc.jpg'), isNull);
  });

  test(
    'tarama kareleri tarihe göre buluyor, küçük kopyaları saymıyor',
    () async {
      dropFrame(DateTime(2026, 8, 2, 9), salt: 'bbbb');
      dropFrame(DateTime(2026, 8, 1, 9), salt: 'aaaa');
      // Küçük kopya ayrı klasörde; kurtarma onu kare sanmamalı.
      final thumb = File('${sandbox.path}/captures/thumbs/x.jpg')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_pixel);
      expect(thumb.existsSync(), isTrue);

      final frames = recovery.scan();
      expect(frames.length, 2);
      expect(frames.first.createdAt, DateTime(2026, 8, 1, 9));
      expect(frames.last.createdAt, DateTime(2026, 8, 2, 9));
    },
  );

  test(
    'kareler kayıt olarak geri alınıyor: tarih korunuyor, yazı boş',
    () async {
      dropFrame(DateTime(2026, 8, 1, 9), salt: 'aaaa');
      dropFrame(DateTime(2026, 8, 2, 9), salt: 'bbbb');

      final adopted = await repository.adoptFrames(recovery.scan());
      expect(adopted, 2);

      final notes = await repository.watchNotes().first;
      expect(notes.length, 2);
      // Akış yeniden eskiye sıralı.
      expect(notes.first.createdAt, DateTime(2026, 8, 2, 9));
      expect(notes.every((note) => note.hasPhoto), isTrue);
      expect(notes.every((note) => note.body.isEmpty), isTrue);
      // Saklama süresi bilinçli olarak süresiz: özgün süre veritabanıyla gitti
      // ve tahmin etmek kareyi kullanıcının istemediği bir anda silerdi.
      expect(notes.every((note) => note.expiresAt == null), isTrue);
      // Dosyalar yerinde: kurtarma kopyalamıyor, kaydı açıyor.
      for (final note in notes) {
        expect(repository.imageOf(note).existsSync(), isTrue);
      }
    },
  );

  test('onarım iki kez koşarsa arşiv ikizlenmiyor', () async {
    dropFrame(DateTime(2026, 8, 1, 9), salt: 'aaaa');
    final frames = recovery.scan();

    expect(await repository.adoptFrames(frames), 1);
    expect(await repository.adoptFrames(frames), 0);
    expect((await repository.watchNotes().first).length, 1);
  });

  test('bozuk veritabanı silinmiyor, yana alınıyor', () async {
    final file = File('${sandbox.path}/${ArchiveRecovery.databaseFileName}')
      ..writeAsStringSync('bozuk');
    // WAL/SHM geride kalırsa taze veritabanı aynı bozulmayı devralır.
    File('${file.path}-wal').writeAsStringSync('wal');

    final aside = await recovery.setAsideDatabase();

    expect(aside, isNotNull);
    expect(aside!.existsSync(), isTrue);
    expect(aside.readAsStringSync(), 'bozuk');
    expect(aside.path, contains('.broken-'));
    // Asıl yol boşaldı: taze veritabanı buraya açılabilir.
    expect(file.existsSync(), isFalse);
    expect(File('${file.path}-wal').existsSync(), isFalse);
  });

  test('veritabanı dosyası yoksa onarım yine de yürüyor', () async {
    expect(await recovery.setAsideDatabase(), isNull);
    dropFrame(DateTime(2026, 8, 1, 9));
    expect(await repository.adoptFrames(recovery.scan()), 1);
  });

  test('kurtarılan kayıt yetim toplayıcıya yem olmuyor', () async {
    // Onarımdan sonraki ilk açılış: kayıtlar var, dosyalar var, hiçbiri
    // yetim değil.
    dropFrame(DateTime(2026, 8, 1, 9), salt: 'aaaa');
    await repository.adoptFrames(recovery.scan());

    await repository.sweepOrphanFiles();

    final note = (await repository.watchNotes().first).single;
    expect(repository.imageOf(note).existsSync(), isTrue);
  });

  test('taze veritabanının yanındaki kareler silinmiyor', () async {
    // Onarım öncesi hâl: veritabanı sıfırdan kuruldu, kayıt yok ama kareler
    // duruyor. Toplayıcı burada çalışırsa kurtaracağımız şeyi siler.
    final frame = dropFrame(
      DateTime.now().subtract(const Duration(days: 2)),
      salt: 'cccc',
    );
    // Yaş engeline takılmasın diye dosya eskitiliyor.
    frame.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 2)),
    );

    await repository.sweepOrphanFiles();

    expect(frame.existsSync(), isTrue, reason: 'Kurtarılacak kare silinmemeli');
  });
}
