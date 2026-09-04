import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// Ücretsiz hak defterinin işletim sisteminin gerçek programıyla uzlaşması.
///
/// Defter tek yönlü büyüyordu: kurulum ekliyor, yalnız notun kendi
/// hatırlatması değiştiğinde düşüyordu. Ana şalteri kapatan kullanıcının
/// alarmı `cancelAll` ile kalkıyor ama kaydı defterde kalıyordu; zamanı
/// gelince hiç çalmamış bir bildirim için hak yanıyordu.
void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_reconcile');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<String> armedRaw() async =>
      (await database.select(database.settingsTable).getSingle())
          .freeReminderArmed;

  Future<int> armedNote(
    String body, {
    Duration ahead = const Duration(days: 1),
  }) async {
    final id = await repository.createText(
      body: body,
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(ahead)),
    );
    await repository.armFreeReminders({id});
    return id;
  }

  /// Kaydın anını geçmişe alır: bildirim çalmış sayılır.
  Future<void> movePast(int id) =>
      database.customStatement('UPDATE notes SET remind_at = ? WHERE id = ?', [
        DateTime.now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
        id,
      ]);

  test('program boşalınca çalmamış kayıt defterden düşüyor', () async {
    final id = await armedNote('şalter kapanacak');
    expect(await armedRaw(), '$id');

    // Ana şalter kapandı: `cancelAll` çalıştı, program **bilinen** biçimde boş.
    await repository.reconcileFreeReminders(scheduled: const {});
    expect(await armedRaw(), isEmpty);

    // Ve zamanı geçse bile hak yanmıyor: ortada teslim edilmiş bir değer yok.
    await movePast(id);
    await repository.settleFreeReminders(deliveredNoteIds: const <int>{});
    expect((await settings.read()).freeReminderNotes, isEmpty);
  });

  test('zamanı geçmiş kayıt uzlaştırmada düşmüyor', () async {
    final id = await armedNote('çalmış olacak');
    await movePast(id);

    // Çalan hatırlatma programdan zaten kalkar. Onu defterden düşürmek teslim
    // edilmiş değeri bedavaya çevirirdi.
    await repository.reconcileFreeReminders(scheduled: const {});
    expect(await armedRaw(), '$id');

    await repository.settleFreeReminders(deliveredNoteIds: const <int>{});
    expect((await settings.read()).freeReminderNotes, {id});
  });

  test('programda duran kayda dokunulmuyor', () async {
    final kept = await armedNote('duruyor');
    final dropped = await armedNote(
      'iptal edildi',
      ahead: const Duration(days: 2),
    );

    await repository.reconcileFreeReminders(scheduled: {kept});

    expect(await armedRaw(), '$kept');
    expect(dropped, isNot(kept));
  });

  test('silinmiş notun kimliği defterde birikmiyor', () async {
    final id = await armedNote('silinecek');
    await repository.delete((await repository.noteById(id))!);

    // Kapatılamayacak bir kayıt: `settleFreeReminders` onu asla bulamaz,
    // eskiden defterde ömür boyu kalırdı.
    await repository.reconcileFreeReminders(scheduled: const {});
    expect(await armedRaw(), isEmpty);
  });

  test('Pro açıkken defter hiç okunmuyor', () async {
    final id = await armedNote('pro');
    await settings.setProUnlocked(true);

    await repository.reconcileFreeReminders(scheduled: const {});
    // Kota Pro'da işlemiyor; defter olduğu gibi duruyor.
    expect(await armedRaw(), '$id');
  });
}
