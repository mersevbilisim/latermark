import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_aspect.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';

/// 4×2 kırmızı PNG. Oranı 2.0 — hata durumunda yazılan 1.0'dan ayırt edilebilir
/// olması şart, yoksa "çözülemedi" ile "kare" birbirine karışır.
final _wide = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAIAAADwyuo0AAAAEElEQVR4nGP4z8AARwzI'
  'HABvqgf5gNwAKAAAAABJRU5ErkJggg==',
);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    PhotoAspect.clear();
    sandbox = await Directory.systemTemp.createTemp('lm_load');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setLocale(AppLocale.turkish);
    await settings.setProUnlocked(true);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  testWidgets('1000 kayıt / 200 hatırlatma yükü', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();

    final seed = Stopwatch()..start();
    await tester.runAsync(() async {
      for (var i = 0; i < 1000; i++) {
        final file = File('${sandbox.path}/k$i.png');
        await file.writeAsBytes(_wide);
        await repository.create(
          capture: XFile(file.path),
          body: 'kayit $i',
          retention: const RetentionChoice(Retention.off),
          createdAt: now.subtract(Duration(hours: i * 8)),
          // Her beşinci kayda hatırlatma: 200 tane.
          reminder: i % 5 == 0
              ? ReminderChoice(at: now.add(Duration(days: 1 + i ~/ 5)))
              : const ReminderChoice.off(),
        );
      }
    });
    seed.stop();

    final all = await tester.runAsync(
      () async => repository.watchNotes().first,
    );
    final names = [for (final note in all!) note.imageName];
    expect(all.where((note) => note.remindAt != null).length, 200);
    debugPrint('KURULUM ${seed.elapsedMilliseconds} ms');

    // --- Akışın ilk karesi ---
    final firstFrame = Stopwatch()..start();
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    firstFrame.stop();
    debugPrint('ILK KARE ${firstFrame.elapsedMilliseconds} ms');

    // Oranların çözülmesi için gerçek zaman gerekiyor.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // --- Kaç kare oranı doğru çözüldü? ---
    var resolved = 0;
    var wrong = 0;
    for (final name in names) {
      final aspect = PhotoAspect.peek(name);
      if (aspect == null) continue;
      resolved++;
      // Hata durumunda 1.0 yazılıyor; gerçek oran 2.0.
      if ((aspect - 2.0).abs() > 0.01) wrong++;
    }
    debugPrint('ORAN toplam=${names.length} cozulen=$resolved yanlis=$wrong');

    // --- Kaydırma sırasında kare süresi ---
    final scrollable = find.byType(Scrollable).first;
    final frames = <int>[];
    for (var step = 0; step < 15; step++) {
      final frame = Stopwatch()..start();
      await tester.drag(scrollable, const Offset(0, -700));
      await tester.pump();
      frame.stop();
      frames.add(frame.elapsedMilliseconds);
    }
    frames.sort();
    debugPrint('KAYDIRMA ortanca=${frames[frames.length ~/ 2]} ms '
        'en_kotu=${frames.last} ms');

    expect(find.byType(NoteCard), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('1000 karenin oranını çözmenin maliyeti', (tester) async {
    final files = <String, File>{};
    await tester.runAsync(() async {
      for (var i = 0; i < 1000; i++) {
        final file = File('${sandbox.path}/o$i.png');
        await file.writeAsBytes(_wide);
        files['o$i.png'] = file;
      }
    });

    PhotoAspect.clear();
    final watch = Stopwatch()..start();
    await tester.runAsync(() => PhotoAspect.warm(files));
    watch.stop();

    debugPrint('WARM 1000 kare ${watch.elapsedMilliseconds} ms');
    expect(PhotoAspect.peek('o999.png'), closeTo(2.0, 0.01));
  });

  test('200 hatırlatmadan iOS bütçesine en yakın olanlar seçiliyor', () {
    final now = DateTime.now();
    final requests = [
      for (var i = 0; i < 200; i++)
        ReminderRequest(
          noteId: i,
          remindAt: now.add(Duration(days: i + 1)),
          cadence: ReminderCadence.once,
          expiresAt: null,
        ),
    ];

    final schedule = reminderSchedule(
      requests: requests,
      now: now,
      maxPerNote: kRollingReminderWindowPerNote,
    );

    debugPrint('PROGRAM ${schedule.length} kayit (butce $kPendingReminderBudget)');
    expect(schedule.length, lessThanOrEqualTo(kPendingReminderBudget));

    // En yakın zamanlılar kazanmalı: seçilen kimlikler 0..59 olmalı.
    final ids = schedule.map((r) => r.noteId).toSet();
    expect(ids.every((id) => id < kPendingReminderBudget), isTrue,
        reason: 'uzaktaki hatırlatma yakındakinin yerini alamaz');
  });
}
