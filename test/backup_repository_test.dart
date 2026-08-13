import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/backup/data/backup_repository.dart';
import 'package:latermark/features/backup/domain/backup_manifest.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late PhotoStore photos;
  late BackupRepository repository;
  var databaseClosed = false;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_backup_repo');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    photos = await PhotoStore.openIn(sandbox);
    repository = BackupRepository(database: database, photos: photos);
    // beforeOpen çalışsın ve ayar satırı oluşsun.
    await database.select(database.settingsTable).get();
  });

  tearDown(() async {
    if (!databaseClosed) await database.close();
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  BackupNote imported(String imageName) => BackupNote(
    imageName: imageName,
    body: 'İçe aktarılan',
    createdAt: DateTime(2026, 8, 1),
    retention: Retention.custom.index,
    customMinutes: 360,
    expiresAt: DateTime(2026, 8, 1, 6),
    remindAfterDays: 30,
    remindRepeats: true,
  );

  const settings = BackupSettings(
    themeMode: 2,
    accent: 0,
    density: 1,
    reminderEnabled: true,
    locationEnabled: true,
    defaultRetention: 3,
    defaultCustomMinutes: 360,
    locale: 0,
  );

  test(
    'Pro hakkı dosyadan taşınmaz ve ücretli alanlar normalize olur',
    () async {
      final staging = Directory('${sandbox.path}/staging')..createSync();
      await File('${staging.path}/new.jpg').writeAsBytes([4, 5, 6]);

      await repository.replaceAll(
        notes: [imported('new.jpg')],
        settings: settings,
        stagedPhotos: staging,
      );

      final note = await database.select(database.notes).getSingle();
      expect(note.remindAfterDays, 0);
      expect(note.remindRepeats, isFalse);
      expect(note.reminderAnchorAt, isNull);
      expect(note.retention, Retention.threeDays);
      expect(note.customMinutes, 0);

      final restoredSettings = await database
          .select(database.settingsTable)
          .getSingle();
      expect(restoredSettings.proUnlocked, isFalse);
      expect(restoredSettings.reminderEnabled, isFalse);
      expect(restoredSettings.defaultRetention, Retention.threeDays);
      expect(restoredSettings.defaultCustomMinutes, 0);
      expect(photos.fileFor('new.jpg').readAsBytesSync(), [4, 5, 6]);
    },
  );

  test('DB yazımı başlamazsa eski fotoğraflar rollback ile korunur', () async {
    await photos.fileFor('old.jpg').writeAsBytes([1, 2, 3]);
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File('${staging.path}/new.jpg').writeAsBytes([4, 5, 6]);

    await database.close();
    databaseClosed = true;

    await expectLater(
      repository.replaceAll(
        notes: [imported('new.jpg')],
        settings: settings,
        stagedPhotos: staging,
      ),
      throwsA(isA<Object>()),
    );

    expect(photos.fileFor('old.jpg').readAsBytesSync(), [1, 2, 3]);
    expect(photos.fileFor('new.jpg').existsSync(), isFalse);
  });
}
