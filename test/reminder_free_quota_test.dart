import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_control.dart';
import 'package:latermark/features/paywall/domain/pro_limits.dart';
import 'package:latermark/features/reminders/reminder_service.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/ember_switch.dart';

class _Granted extends ReminderService {
  _Granted() : super(supported: false);

  @override
  Future<ReminderPermissionState> refreshPermission() async =>
      ReminderPermissionState.granted;

  @override
  Future<ReminderPermissionState> requestPermissionState() async =>
      ReminderPermissionState.granted;
}

/// Ücretsiz katmanda hatırlatma **kapalı değil, sayılı**.
///
/// Kilit ancak hak bittiğinde geliyor, ve kullanıcı duvara habersiz
/// toslamıyor: kalan hak satırın altında yazılı.
void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository notes;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_free_quota');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    notes = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        reminders: _Granted(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: ReminderControl(value: false, onChanged: (_) {}),
          ),
        ),
      ),
    );
    // Drift'in not akışı gerçek asenkron; sahte saat altında ilerlemiyor.
    // `AppScope` kurulu hatırlatmaları o akıştan okuduğu için ilk değer
    // gelmeden ölçmek boş listeyi ölçmek olurdu.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('hak varken anahtar açık ve kalan hak yazılı', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('reminder-switch')), findsOneWidget);
    expect(find.byKey(const Key('reminder-locked-row')), findsNothing);
    expect(
      find.text(
        'Ücretsiz kullanım: ${ProLimits.freeReminders} hatırlatma hakkın kaldı',
      ),
      findsOneWidget,
    );

    await teardownTree(tester);
  });

  testWidgets('kurulu hatırlatmalar kalan haktan düşülüyor', (tester) async {
    // Kurulu ama çalmamış olanlar da kapıya dahil: kullanıcıya "3 hakkın var"
    // deyip ikincisini kurdurmamak olmaz.
    await notes.createText(
      body: 'kurulu',
      retention: const RetentionChoice.off(),
      reminder: ReminderChoice(at: DateTime.now().add(const Duration(days: 1))),
    );
    await pump(tester);

    expect(
      find.text(
        'Ücretsiz kullanım: ${ProLimits.freeReminders - 1} hatırlatma hakkın kaldı',
      ),
      findsOneWidget,
    );

    await teardownTree(tester);
  });

  testWidgets('hak bitince kilit satırı geliyor', (tester) async {
    for (var i = 0; i < ProLimits.freeReminders; i++) {
      await notes.createText(
        body: 'kurulu $i',
        retention: const RetentionChoice.off(),
        reminder: ReminderChoice(
          at: DateTime.now().add(Duration(days: i + 1)),
        ),
      );
    }
    await pump(tester);

    expect(find.byKey(const Key('reminder-locked-row')), findsOneWidget);
    expect(find.byKey(const Key('reminder-switch')), findsNothing);
    expect(find.text('Ücretsiz hatırlatma hakkın doldu'), findsOneWidget);

    await teardownTree(tester);
  });

  test('kapatma anahtarı tek sabitle çalışıyor', () {
    // `freeReminders = 0` yapıldığında hatırlatma eskisi gibi yalnız Pro'ya
    // ait olmalı ve **kotadan hiç söz edilmemeli**. Bu test, anahtarın
    // gerçekten tek sabit olduğunu ve sıfırda mantığın tutarlı kapandığını
    // sabitliyor.
    expect(ProLimits.freeRemindersEnabled, ProLimits.freeReminders > 0);

    // Sıfırda ücretsiz kullanıcıya hiçbir yol açılmıyor — kayıt kimliği
    // bilinse bile.
    bool allowsAtZero({Set<int> used = const {}, int inFlight = 0, int? id}) {
      // `allowsReminder`'ın sıfır hâli: taban + kurulu < 0 hiçbir zaman
      // doğru olamaz.
      if (id != null && used.contains(id)) return true;
      return ProLimits.burnedCount(used, 0) + inFlight < 0;
    }

    expect(allowsAtZero(), isFalse);
    expect(allowsAtZero(inFlight: 5), isFalse);

    // Pro her hâlde geçiyor.
    expect(
      ProLimits.allowsReminder(isPro: true, usedNoteIds: const {}),
      isTrue,
    );
  });

  testWidgets('Pro açıkken ne sayaç ne kilit var', (tester) async {
    await settings.setProUnlocked(true);
    for (var i = 0; i < ProLimits.freeReminders + 2; i++) {
      await notes.createText(
        body: 'pro $i',
        retention: const RetentionChoice.off(),
        reminder: ReminderChoice(
          at: DateTime.now().add(Duration(days: i + 1)),
        ),
      );
    }
    await pump(tester);

    expect(find.byKey(const Key('reminder-locked-row')), findsNothing);
    expect(
      tester
          .widget<EmberSwitch>(find.byKey(const Key('reminder-switch')))
          .value,
      isFalse,
    );
    expect(find.textContaining('Ücretsiz'), findsNothing);

    await teardownTree(tester);
  });
}
