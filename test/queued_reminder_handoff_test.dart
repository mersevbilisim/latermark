import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/presentation/home/home_page.dart';
import 'package:latermark/features/paywall/domain/pro_limits.dart';
import 'package:latermark/features/reminders/reminder_service.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/l10n/app_localizations.dart';

class _HandoffReminderService extends ReminderService {
  _HandoffReminderService({this.canSchedule = true}) : super(supported: false);

  bool canSchedule;

  @override
  Future<ReminderPermissionState> refreshPermission() async =>
      ReminderPermissionState.granted;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ReminderSyncResult> sync(
    List<Note> notes,
    AppSettings settings,
    L10n l10n,
  ) async => ReminderSyncResult(
    scheduled: canSchedule
        ? {
            for (final note in notes)
              if (note.remindAt?.isAfter(DateTime.now()) ?? false) note.id,
          }
        : const {},
    scheduleKnown: true,
  );
}

void main() {
  const channel = MethodChannel('latermark/shared_import');
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository notes;
  late SettingsRepository settings;
  late List<MethodCall> calls;
  late bool completed;
  late bool cancelSucceeds;
  late Map<String, Object?> pending;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_handoff');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    notes = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    calls = [];
    completed = false;
    cancelSucceeds = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'takePendingSharedImport':
              return completed ? null : pending;
            case 'claimFreeReminderReservation':
              return true;
            case 'cancelQueuedReminder':
              return cancelSucceeds;
            case 'completeSharedImport':
              completed = true;
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget harness(ReminderService reminders) => AppScope(
    notes: notes,
    settings: settings,
    reminders: reminders,
    child: Builder(
      builder: (context) {
        final preferences = AppScope.preferences(context);
        return MaterialApp(
          theme: AppTheme.light(preferences.accent, preferences.accentHue),
          darkTheme: AppTheme.dark(preferences.accent, preferences.accentHue),
          themeMode: preferences.themeMode.flutterMode,
          locale: const Locale('tr'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: const HomePage(),
        );
      },
    ),
  );

  Future<void> driveUntil(
    WidgetTester tester,
    Future<bool> Function() condition,
  ) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (await tester.runAsync(condition) ?? false) return;
    }
    fail('Asenkron devir zamanında tamamlanmadı.');
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  List<String> handoffCalls() => calls
      .map((call) => call.method)
      .where(
        (method) =>
            method == 'claimFreeReminderReservation' ||
            method == 'cancelQueuedReminder' ||
            method == 'completeSharedImport',
      )
      .toList();

  testWidgets(
    'gelecek Siri alarmı ana programa kurulmadan geçici istek kaldırılmıyor',
    (tester) async {
      usePhoneSurface(tester);
      const importId = 'f58b2919-f053-44f1-9ae4-a6d819923d39';
      final now = DateTime.now();
      final remindAt = now.add(const Duration(hours: 2));
      pending = {
        'id': importId,
        'kind': 'text',
        'path': '',
        'initialText': 'Uçuş kartını kontrol et',
        'createdAtMilliseconds': now.millisecondsSinceEpoch,
        'saveImmediately': true,
        'remindAfterDays': 0,
        'remindAtMilliseconds': remindAt.millisecondsSinceEpoch,
        'freeReminderReserved': true,
        'freeReminderClaimed': false,
        'queuedReminderState': 'scheduled',
      };

      await tester.pumpWidget(harness(_HandoffReminderService()));
      await driveUntil(tester, () async => completed);

      final saved = (await tester.runAsync(
        () => notes.watchNotes().first,
      ))!.single;
      expect(saved.body, 'Uçuş kartını kontrol et');
      expect(
        saved.remindAt!.millisecondsSinceEpoch ~/ 1000,
        remindAt.millisecondsSinceEpoch ~/ 1000,
      );
      final row = await tester.runAsync(
        () => database.select(database.settingsTable).getSingle(),
      );
      expect(row, isNotNull);
      expect(row!.freeReminderArmed, '${saved.id}');
      expect(row.freeReminderNotes, isEmpty);
      expect(handoffCalls(), [
        'claimFreeReminderReservation',
        'cancelQueuedReminder',
        'completeSharedImport',
      ]);
      final claim = calls.singleWhere(
        (call) => call.method == 'claimFreeReminderReservation',
      );
      expect(claim.arguments, {
        'id': importId,
        'databaseRemaining': ProLimits.freeReminders - 1,
      });

      await disposeTree(tester);
    },
  );

  testWidgets(
    'uygulama açılmadan çalan Siri alarmı tepsiden silinse de hakkı kapatıyor',
    (tester) async {
      usePhoneSurface(tester);
      const importId = 'd66b26d9-f40f-4ce2-9b1e-b423a142145a';
      final now = DateTime.now();
      final remindAt = now.subtract(const Duration(minutes: 1));
      pending = {
        'id': importId,
        'kind': 'text',
        'path': '',
        'initialText': 'Fırını kapat',
        'createdAtMilliseconds': now
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        'saveImmediately': true,
        'remindAfterDays': 0,
        'remindAtMilliseconds': remindAt.millisecondsSinceEpoch,
        'freeReminderReserved': true,
        'freeReminderClaimed': false,
        'queuedReminderState': 'scheduled',
      };

      await tester.pumpWidget(harness(_HandoffReminderService()));
      await driveUntil(tester, () async => completed);

      final saved = (await tester.runAsync(
        () => notes.watchNotes().first,
      ))!.single;
      expect(
        saved.remindAt!.millisecondsSinceEpoch ~/ 1000,
        remindAt.millisecondsSinceEpoch ~/ 1000,
      );
      final row = await tester.runAsync(
        () => database.select(database.settingsTable).getSingle(),
      );
      expect(row, isNotNull);
      expect(row!.freeReminderArmed, isEmpty);
      expect(row.freeReminderNotes, '${saved.id}');
      expect(handoffCalls(), [
        'claimFreeReminderReservation',
        'cancelQueuedReminder',
        'completeSharedImport',
      ]);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'ana alarm kurulamazsa rezervasyon ve geçici alarm dokunulmadan kalıyor',
    (tester) async {
      usePhoneSurface(tester);
      const importId = '71063873-990d-4f8e-b669-253ea58e2e4b';
      final now = DateTime.now();
      final remindAt = now.add(const Duration(hours: 2));
      pending = {
        'id': importId,
        'kind': 'text',
        'path': '',
        'initialText': 'Tekrar denenecek devir',
        'createdAtMilliseconds': now.millisecondsSinceEpoch,
        'saveImmediately': true,
        'remindAfterDays': 0,
        'remindAtMilliseconds': remindAt.millisecondsSinceEpoch,
        'freeReminderReserved': true,
        'freeReminderClaimed': false,
        'queuedReminderState': 'scheduled',
      };

      final reminders = _HandoffReminderService(canSchedule: false);
      await tester.pumpWidget(harness(reminders));
      await driveUntil(
        tester,
        () async => (await notes.watchNotes().first).isNotEmpty,
      );

      final saved = (await tester.runAsync(
        () => notes.watchNotes().first,
      ))!.single;
      expect(
        saved.remindAt!.millisecondsSinceEpoch ~/ 1000,
        remindAt.millisecondsSinceEpoch ~/ 1000,
      );
      expect(completed, isFalse);
      expect(handoffCalls(), isEmpty);

      // Bir sonraki foreground turunda aynı import tekrar gelir. DB ledger
      // mevcut notu döndürmeli; alarm kurulunca devir tek kaydı çoğaltmadan
      // kaldığı yerden tamamlanmalı.
      reminders.canSchedule = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await driveUntil(tester, () async => completed);

      final afterRetry = (await tester.runAsync(
        () => notes.watchNotes().first,
      ))!;
      expect(afterRetry, hasLength(1));
      expect(afterRetry.single.id, saved.id);
      expect(handoffCalls(), [
        'claimFreeReminderReservation',
        'cancelQueuedReminder',
        'completeSharedImport',
      ]);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'geçici alarm iptali doğrulanamazsa metadata silinmiyor ve tekrar deneniyor',
    (tester) async {
      usePhoneSurface(tester);
      const importId = '5416ae99-3b76-46fd-a9d9-a9e220727023';
      final now = DateTime.now();
      final remindAt = now.add(const Duration(hours: 2));
      pending = {
        'id': importId,
        'kind': 'text',
        'path': '',
        'initialText': 'İptal yarışı',
        'createdAtMilliseconds': now.millisecondsSinceEpoch,
        'saveImmediately': true,
        'remindAfterDays': 0,
        'remindAtMilliseconds': remindAt.millisecondsSinceEpoch,
        'freeReminderReserved': true,
        'freeReminderClaimed': false,
        'queuedReminderState': 'scheduled',
      };
      cancelSucceeds = false;

      await tester.pumpWidget(harness(_HandoffReminderService()));
      await driveUntil(
        tester,
        () async => handoffCalls().contains('cancelQueuedReminder'),
      );

      expect(completed, isFalse);
      expect(handoffCalls(), [
        'claimFreeReminderReservation',
        'cancelQueuedReminder',
      ]);

      cancelSucceeds = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await driveUntil(tester, () async => completed);

      final saved = (await tester.runAsync(() => notes.watchNotes().first))!;
      expect(saved, hasLength(1));
      expect(handoffCalls().last, 'completeSharedImport');

      await disposeTree(tester);
    },
  );
}
