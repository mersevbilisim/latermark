import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_kind.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// Karesiz kayıt şemayı hiç değiştirmiyor: işaret `imageName`'in boş
/// olmasından ibaret. Bu dosya o sözleşmenin uçlarını kilitliyor — özellikle
/// boş adın **dosya adı sanılabileceği** yerleri.
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
    // Şema artmıyor: hiçbir göç çalışmadı, hiçbir tablo yeniden kurulmadı.
    expect(database.schemaVersion, 10);
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

  test('Pro değilken hatırlatma sessizce düşüyor', () async {
    final id = await repository.createText(
      body: 'Hatırlat',
      retention: const RetentionChoice(Retention.oneWeek),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 2))),
    );

    expect((await noteById(id)).remindAt, isNull);
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
