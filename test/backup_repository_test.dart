import 'dart:io';

import 'package:cross_file/cross_file.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/backup/data/backup_repository.dart';
import 'package:latermark/features/backup/domain/backup_manifest.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

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
    remindAt: DateTime(2026, 8, 31),
    remindEveryDays: 30,
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
      expect(note.remindAt, isNull);
      expect(note.remindEveryDays, 0);
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

  test('Pro açıkken hatırlatma dosyadaki anıyla geri gelir', () async {
    await SettingsRepository(database).setProUnlocked(true);
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File('${staging.path}/new.jpg').writeAsBytes([4, 5, 6]);

    await repository.replaceAll(
      notes: [imported('new.jpg')],
      settings: settings,
      stagedPhotos: staging,
    );

    final note = await database.select(database.notes).getSingle();
    expect(note.remindAt, DateTime(2026, 8, 31));
    expect(note.remindEveryDays, 30);
  });

  test('hatırlattıktan sonra sil sözü yedekten aynen döner', () async {
    final settingsRepository = SettingsRepository(database);
    await settingsRepository.setProUnlocked(true);

    // Kayıt gerçek akıştaki gibi kuruluyor: planlama ekranı silinme anını
    // hatırlatmadan türetiyor.
    final notes = NotesRepository(database: database, photos: photos);
    final capture = File('${sandbox.path}/shot.jpg')
      ..writeAsBytesSync([7, 7, 7]);
    // Saniyesi olan bir başlangıç: dakikaya bölünmeyen ömür de dosyadan
    // aynen dönmeli.
    final createdAt = DateTime(2026, 8, 1, 12, 30, 45);
    final id = await notes.create(
      capture: XFile(capture.path),
      body: 'faturayı öde',
      retention: RetentionChoice(Retention.off),
      createdAt: createdAt,
    );
    final at = DateTime(2026, 9, 3, 21, 30);
    await notes.setReminder(
      id,
      ReminderChoice(at: at),
      deleteAfterReminder: true,
    );

    final exported = await repository.exportNotes();
    expect(exported.single.expiresAt, reminderExpiryFor(at));
    expect(exported.single.remindAt, at);

    // Geri yükleme her şeyi siler ve dosyadakini kurar.
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File(
      '${staging.path}/${exported.single.imageName}',
    ).writeAsBytes([7, 7, 7]);
    await repository.replaceAll(
      notes: exported,
      settings: settings,
      stagedPhotos: staging,
    );

    final restored = await database.select(database.notes).getSingle();
    expect(restored.remindAt, at);
    expect(restored.expiresAt, reminderExpiryFor(at));
    // Söz hâlâ hatırlatmadan türemiş olarak tanınıyor: kullanıcı hatırlatmayı
    // kaldırırsa silme de kalkacak.
    expect(
      isReminderExpiry(
        remindAt: restored.remindAt,
        expiresAt: restored.expiresAt,
      ),
      isTrue,
    );
  });

  test('hak kapalıyken silme sözü notu erkene çekmez', () async {
    final at = DateTime(2026, 9, 3, 21, 30);
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File('${staging.path}/new.jpg').writeAsBytes([4, 5, 6]);
    final createdAt = DateTime(2026, 8, 1, 12);

    await repository.replaceAll(
      notes: [
        BackupNote(
          imageName: 'new.jpg',
          body: 'faturayı öde',
          createdAt: createdAt,
          retention: Retention.custom.index,
          customMinutes: reminderExpiryFor(at).difference(createdAt).inMinutes,
          expiresAt: reminderExpiryFor(at),
          remindAt: at,
        ),
      ],
      settings: settings,
      stagedPhotos: staging,
    );

    final note = await database.select(database.notes).getSingle();
    // Hatırlatma Pro; hakkı olmayan katmanda kurulmuyor. Silme anı da
    // erkene çekilmiyor — geri yükleme hiçbir kaydın ömrünü kısaltmaz.
    expect(note.remindAt, isNull);
    expect(note.retention, isNot(Retention.custom));
    expect(
      note.expiresAt == null ||
          !note.expiresAt!.isBefore(reminderExpiryFor(at)),
      isTrue,
    );
  });

  test('eski arşivin gün sayısı geri yükleme anından sayılır', () async {
    // O sürümler mutlak bir an saklamıyordu; dosyada yalnızca "kaç gün sonra"
    // vardı ve o sorunun cihazdan bağımsız bir cevabı yok. Dürüst tek
    // başlangıç geri yükleme anı.
    await SettingsRepository(database).setProUnlocked(true);
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File('${staging.path}/eski.jpg').writeAsBytes([7, 8, 9]);
    final legacy = BackupNote.fromJson({
      'image': 'eski.jpg',
      'body': 'Eski yedek',
      'created': DateTime(2026, 8, 1).toUtc().millisecondsSinceEpoch,
      'retention': 0,
      'remindDays': 7,
      'remindRepeats': true,
    });
    final before = DateTime.now();

    await repository.replaceAll(
      notes: [legacy],
      settings: settings,
      stagedPhotos: staging,
    );

    final note = await database.select(database.notes).getSingle();
    expect(note.remindEveryDays, 7);
    // Sütun unix saniye tutuyor; karşılaştırma da o çözünürlükte.
    expect(
      note.remindAt!.millisecondsSinceEpoch,
      closeTo(shiftLocalCalendarDays(before, 7).millisecondsSinceEpoch, 2000),
      reason: 'geri sayı geri yükleme anından başlamalı',
    );
  });

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
