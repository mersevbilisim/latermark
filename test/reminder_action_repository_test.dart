import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/reminder_action.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// Bildirim düğmelerinin veriye ne yazdığı.
///
/// Saf hesap `reminder_action_test.dart` içinde; burada test edilen şey
/// yazmanın kendisi: hangi alanlara dokunulduğu, hangilerine **dokunulmadığı**
/// ve hak kontrolünün yazma anında yapıldığı.
void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_action_test');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setProUnlocked(true);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<XFile> fakeCapture() async {
    final file = File(
      '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(List<int>.filled(64, 7));
    return XFile(file.path);
  }

  /// Hatırlatması olan bir kayıt.
  Future<Note> noteWithReminder({
    DateTime? remindAt,
    ReminderCadence cadence = ReminderCadence.once,
  }) async {
    final id = await repository.create(
      capture: await fakeCapture(),
      body: 'Kombi bakımı',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(
        at: remindAt ?? DateTime(2026, 8, 8, 9),
        cadence: cadence,
      ),
    );
    return (await repository.noteById(id))!;
  }

  test('erteleme sıradaki hatırlatmayı yarına taşır', () async {
    final note = await noteWithReminder();
    final firedAt = DateTime(2026, 8, 8, 9);
    final now = DateTime(2026, 8, 8, 9, 1);

    final updated = await repository.applyReminderAction(
      note.id,
      ReminderAction.tomorrow,
      firedAt: firedAt,
      now: now,
    );

    expect(updated, isNotNull);
    expect(
      pendingReminderAt(
        remindAt: updated!.remindAt,
        cadence: ReminderCadence.fromCode(updated.remindEveryDays),
        now: now,
      ),
      DateTime(2026, 8, 9, 9),
    );
  });

  test('eylem notun gövdesine ve düzenleme damgasına dokunmaz', () async {
    // Kullanıcı notu düzenlemedi, hatırlatmaya cevap verdi. Damga vurulsaydı
    // arşivdeki her ertelenmiş kayıt "düzenlenmiş" görünürdü ve damga zamanla
    // anlamını yitirirdi.
    final note = await noteWithReminder();
    expect(note.updatedAt, isNull);

    final updated = await repository.applyReminderAction(
      note.id,
      ReminderAction.nextWeek,
    );

    expect(updated!.body, 'Kombi bakımı');
    expect(updated.updatedAt, isNull);
    expect(updated.createdAt, note.createdAt);
    expect(updated.expiresAt, note.expiresAt);
  });

  test('tamam tek atışlık hatırlatmayı kapatır ama notu silmez', () async {
    final note = await noteWithReminder();

    final updated = await repository.applyReminderAction(
      note.id,
      ReminderAction.done,
    );

    expect(updated!.remindAt, isNull);
    expect(updated.remindEveryDays, 0);
    expect(await repository.noteById(note.id), isNotNull);
    expect(await repository.watchNotes().first, hasLength(1));
  });

  test('tamam tekrarlayan hatırlatmayı sürdürür', () async {
    final note = await noteWithReminder(cadence: ReminderCadence.monthly);
    final now = DateTime(2026, 8, 8, 9);

    final updated = await repository.applyReminderAction(
      note.id,
      ReminderAction.done,
      now: now,
    );

    expect(
      ReminderCadence.fromCode(updated!.remindEveryDays),
      ReminderCadence.monthly,
    );
    expect(
      pendingReminderAt(remindAt: updated.remindAt, cadence: ReminderCadence.monthly, now: now),
      DateTime(2026, 9, 8, 9),
    );
  });

  test('bildirimleri kapat tek atış ve tekrar alanlarını temizler', () async {
    for (final cadence in [ReminderCadence.once, ReminderCadence.monthly]) {
      final note = await noteWithReminder(cadence: cadence);

      final updated = await repository.applyReminderAction(
        note.id,
        ReminderAction.turnOff,
      );

      expect(updated, isNotNull);
      expect(updated!.remindAt, isNull);
      expect(updated.remindEveryDays, 0);
      expect(updated.body, note.body);
      expect(updated.updatedAt, note.updatedAt);
      expect(await repository.noteById(note.id), isNotNull);
    }

    expect(await repository.watchNotes().first, hasLength(2));
  });

  test(
    'aynı notification action yeniden teslim edilirse ikinci kez yazmaz',
    () async {
      final note = await noteWithReminder(cadence: ReminderCadence.weekly);
      final firedAt = DateTime(2026, 8, 8, 9);
      final now = DateTime(2026, 8, 8, 9, 1);
      const eventId = '2560:latermark.reminder.tomorrow:payload-v3';

      final first = await repository.applyReminderAction(
        note.id,
        ReminderAction.tomorrow,
        firedAt: firedAt,
        now: now,
        eventId: eventId,
      );
      final momentAfterFirst = first!.remindAt;
      final replay = await repository.applyReminderAction(
        note.id,
        ReminderAction.tomorrow,
        firedAt: firedAt,
        now: now.add(const Duration(seconds: 1)),
        eventId: eventId,
      );

      expect(replay, isNull);
      expect((await repository.noteById(note.id))!.remindAt, momentAfterFirst);
    },
  );

  test('hak kapandıysa eylem hatırlatmayı geri getiremez', () async {
    // Bildirim tepside kalmış olabilir ve hak düştüğünde kayıtların
    // hatırlatması zaten temizleniyor. Bir düğmeye basmak o temizliği geri
    // alıp ücretsiz kullanıcıya hatırlatma yazdırmamalı.
    final note = await noteWithReminder();
    await settings.setProUnlocked(false);

    final downgraded = await repository.noteById(note.id);
    expect(downgraded!.remindAt, isNull);

    final updated = await repository.applyReminderAction(
      note.id,
      ReminderAction.tomorrow,
    );

    expect(updated, isNull);
    final unchanged = await repository.noteById(note.id);
    expect(unchanged!.remindAt, isNull);
    expect(unchanged.remindEveryDays, 0);
  });

  test('hatırlatması olmayan ve silinmiş notlar sessizce geçilir', () async {
    final plain = await repository.create(
      capture: await fakeCapture(),
      body: 'Hatırlatmasız',
      retention: const RetentionChoice.off(),
    );

    expect(
      await repository.applyReminderAction(plain, ReminderAction.done),
      isNull,
    );
    expect(
      await repository.applyReminderAction(9999, ReminderAction.tomorrow),
      isNull,
    );
  });
}
