import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/reminder/reminder_schedule_page.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/ember_switch.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Kaydedilmiş bir karenin "ne zaman dönsün" ekranı.
///
/// Kayıt bu ekrana gelmeden önce diske yazıldı: buradan vazgeçmek notu değil,
/// yalnızca hatırlatmayı iptal eder.
void main() {
  // Sabit bir "şimdi": takvimin bugünü, geçmiş günleri ve hazır saatleri
  // testin çalıştığı ana göre kaymasın. 8 Ağustos 2026, saat 10:00.
  final now = DateTime(2026, 8, 8, 10);

  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;
  late int noteId;
  late GlobalKey<NavigatorState> navigatorKey;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    navigatorKey = GlobalKey<NavigatorState>();
    sandbox = await Directory.systemTemp.createTemp('lm_reminder_schedule');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setLocale(AppLocale.turkish);
    // Hatırlatma Pro'ya kilitli; kilitliyken kayda hiçbir şey yazılmaz.
    await settings.setProUnlocked(true);
    final photo = File('${sandbox.path}/p.png')..writeAsBytesSync(_pixel);
    noteId = await repository.create(
      capture: XFile(photo.path),
      body: 'Kışlık lastikleri sormayı unutma.',
      retention: const RetentionChoice.off(),
    );
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
    ReminderChoice initial = const ReminderChoice.off(),
    bool deleteAfter = false,
    Size size = const Size(393, 852),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      AppScope(
        notes: repository,
        settings: settings,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.dark(),
          locale: locale,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await _settle(tester);

    // Sayfa yığına itilerek açılıyor: "Şimdi değil" gerçekten geri dönebilsin.
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ReminderSchedulePage(
            noteId: noteId,
            initial: initial,
            initialDeleteAfter: deleteAfter,
            now: now,
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  Future<void> saveAndClose(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('reminder-schedule-save')));
    await _settle(tester);
  }

  Future<Note> readNote() async => (await repository.noteById(noteId))!;

  /// Ağaç testin **içinde** sökülüyor: AppScope kapanırken Drift'in akış
  /// temizliği sıfır süreli bir timer bırakıyor ve bir kare daha atılmazsa
  /// "bekleyen timer" olarak sayılıyor.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('boş takvimle karşılamaz: yarın, aynı saatte önerilir', (
    tester,
  ) async {
    await open(tester);
    await saveAndClose(tester);

    expect((await readNote()).remindAt, DateTime(2026, 8, 9, 10));
    await close(tester);
  });

  testWidgets('geçmiş gün seçilemez, ileri bir gün kayda yazılır', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('reminder-day-2026-8-7')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reminder-day-2026-8-20')));
    await _settle(tester);
    await saveAndClose(tester);

    expect((await readNote()).remindAt, DateTime(2026, 8, 20, 10));
    await close(tester);
  });

  testWidgets('yazılan saat kayda geçer', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('reminder-time-hour')), '07');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('reminder-time-minute')), '45');
    await _settle(tester);
    await saveAndClose(tester);

    expect((await readNote()).remindAt, DateTime(2026, 8, 9, 7, 45));
    await close(tester);
  });

  testWidgets('saat dolunca odak dakikaya geçer, geçmiş saatte de', (
    tester,
  ) async {
    await open(tester);

    // Bugün 10:00'da bugünü seçmek 11:00 öneriyor. Kullanıcı "10" yazdığında
    // an henüz geçmişte; alan yine de dakikaya devretmeli, yoksa iki hane
    // dolduğu için yazmaya devam edemez.
    await tester.tap(find.byKey(const Key('reminder-day-2026-8-8')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('reminder-time-hour')), '10');
    await _settle(tester);

    final minute = tester.widget<TextField>(
      find.byKey(const Key('reminder-time-minute')),
    );
    expect(minute.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byKey(const Key('reminder-time-minute')), '45');
    await _settle(tester);
    await saveAndClose(tester);

    expect((await readNote()).remindAt, DateTime(2026, 8, 8, 10, 45));
    await close(tester);
  });

  testWidgets('bugüne düşen geçmiş saat kayda yazılmaz', (tester) async {
    await open(tester);

    // Bugün seçilebilir ama saati geçmiş olamaz: 10:00'da seçilen bugün için
    // varsayılan bir sonraki tam saat, yazılan 09:00 ise sessizce reddedilir.
    await tester.tap(find.byKey(const Key('reminder-day-2026-8-8')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('reminder-time-hour')), '09');
    await _settle(tester);
    await saveAndClose(tester);

    expect((await readNote()).remindAt, DateTime(2026, 8, 8, 11));
    await close(tester);
  });

  testWidgets('sürekli hatırlat aralığı seçilen güne göre kurar', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('reminder-day-2026-8-15')));
    await _settle(tester);
    // Kip rayında "sürekli"ye geçmek aralığı seçilen güne göre kurar.
    await tester.tap(find.text('Sürekli hatırlat'));
    await _settle(tester);
    await saveAndClose(tester);

    final note = await readNote();
    expect(note.remindAt, DateTime(2026, 8, 15, 10));
    expect(note.remindEveryDays, 7);
    await close(tester);
  });

  testWidgets('silme sözü yalnız tek atışta görünür ve kayda geçer', (
    tester,
  ) async {
    await open(tester);

    final row = find.byKey(const Key('reminder-delete-after-row'));
    expect(row, findsOneWidget);

    // Sürekli hatırlatmada söz anlamsız: ikinci oluşum hiç gelmezdi.
    await tester.tap(find.text('Sürekli hatırlat'));
    await _settle(tester);
    expect(row, findsNothing);

    await tester.tap(find.text('Bir kere hatırlat'));
    await _settle(tester);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await _settle(tester);
    await saveAndClose(tester);

    final note = await readNote();
    expect(note.remindAt, DateTime(2026, 8, 9, 10));
    expect(note.expiresAt, DateTime(2026, 8, 9, 10).add(kReminderExpiryGrace));
    await close(tester);
  });

  testWidgets('kayıtlı silme sözüyle açılınca anahtar açık gelir', (
    tester,
  ) async {
    await open(
      tester,
      initial: ReminderChoice(at: DateTime(2026, 9, 3, 21, 30)),
      deleteAfter: true,
    );

    expect(
      tester
          .widget<EmberSwitch>(
            find.byKey(const Key('reminder-delete-after-switch')),
          )
          .value,
      isTrue,
    );

    await saveAndClose(tester);
    expect(
      (await readNote()).expiresAt,
      DateTime(2026, 9, 3, 21, 30).add(kReminderExpiryGrace),
    );
    await close(tester);
  });

  testWidgets('şimdi değil hatırlatmayı kurmaz, kayıt yerinde kalır', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('reminder-schedule-skip')));
    await _settle(tester);

    final note = await readNote();
    expect(note.remindAt, isNull);
    expect(note.body, 'Kışlık lastikleri sormayı unutma.');
    expect(find.byType(ReminderSchedulePage), findsNothing);
    await close(tester);
  });

  testWidgets('kayıtlı hatırlatma açıldığında seçili gelir', (tester) async {
    await open(
      tester,
      initial: ReminderChoice(at: DateTime(2026, 9, 3, 21, 30)),
    );
    await saveAndClose(tester);

    expect((await readNote()).remindAt, DateTime(2026, 9, 3, 21, 30));
    await close(tester);
  });

  testWidgets('klavye açıkken kaydet şeridi görünür kalır', (tester) async {
    await open(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    tester.view.padding = const FakeViewPadding(top: 47);
    await _settle(tester);

    final save = tester.getRect(
      find.byKey(const ValueKey('reminder-schedule-save')),
    );
    expect(save.bottom, lessThanOrEqualTo(852 - 336));
    await close(tester);
  });

  testWidgets('bütün dillerde dar ekranda ve büyük yazıyla taşmaz', (
    tester,
  ) async {
    for (final locale in L10n.supportedLocales) {
      await open(
        tester,
        locale: locale,
        size: const Size(320, 900),
        textScale: 1.3,
      );

      expect(
        tester.takeException(),
        isNull,
        reason: '${locale.toLanguageTag()} dilinde planlama ekranı taştı',
      );
      await tester.tap(find.byKey(const ValueKey('reminder-schedule-skip')));
      await _settle(tester);
    }
    await close(tester);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}
