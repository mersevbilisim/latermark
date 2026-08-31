import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_control.dart';
import 'package:latermark/features/reminders/reminder_service.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/ember_switch.dart';

/// İzin cevabını sabitleyen servis. Gerçek kanal yerine kullanılıyor ki
/// "izin yok" hâli deterministik olsun.
class _FixedPermission extends ReminderService {
  _FixedPermission(this._state) : super(supported: false);

  final ReminderPermissionState _state;
  int requests = 0;

  @override
  Future<ReminderPermissionState> refreshPermission() async => _state;

  @override
  Future<ReminderPermissionState> requestPermissionState() async {
    requests++;
    return _state;
  }
}

/// Denetimi compose/edit ekranlarındaki gibi durumla besleyen kabuk.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _value = false;

  @override
  Widget build(BuildContext context) => ReminderControl(
        value: _value,
        onChanged: (value) => setState(() => _value = value),
      );
}

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository notes;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_reminder_control');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    notes = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    // Hatırlatma Pro'ya bağlı; kilit satırı değil anahtar görünsün.
    await settings.setProUnlocked(true);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, ReminderService reminders) async {
    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        reminders: reminders,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: _Harness()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester) => tester
      .widget<EmberSwitch>(find.byKey(const Key('reminder-switch')))
      .value;

  /// Sessizce hiçbir şey yapmamak en kötüsü: kullanıcı hatırlatmanın
  /// kurulduğunu sanırdı. Anahtar niyeti gösterir, uyarı da bildirimin
  /// çalmayacağını söyler — ikisi birlikte olmalı.
  testWidgets('izin reddedilince anahtar açık kalır ama uyarı çıkar', (
    tester,
  ) async {
    final reminders = _FixedPermission(ReminderPermissionState.denied);
    await pump(tester, reminders);

    expect(switchOn(tester), isFalse);
    expect(find.byType(ReminderBlockedNotice), findsNothing);

    await tester.tap(find.byKey(const Key('reminder-switch-row')));
    await tester.pumpAndSettle();

    // İzin tam da niyetin gösterildiği anda isteniyor.
    expect(reminders.requests, 1);
    // Niyet korunuyor: kullanıcı Sistem Ayarları'ndan izni açtığında aynı
    // nota dönüp seçimi yeniden yapmak zorunda kalmasın.
    expect(switchOn(tester), isTrue);
    expect((await settings.read()).reminderEnabled, isTrue);
    // Ve ekran bildirimin çalmayacağını açıkça söylüyor.
    expect(find.byType(ReminderBlockedNotice), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('izin verilmişse uyarı hiç görünmez', (tester) async {
    final reminders = _FixedPermission(ReminderPermissionState.granted);
    await pump(tester, reminders);

    await tester.tap(find.byKey(const Key('reminder-switch-row')));
    await tester.pumpAndSettle();

    expect(switchOn(tester), isTrue);
    expect(find.byType(ReminderBlockedNotice), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  /// Anahtar kapatılınca uyarı da kalkmalı: ortada beklenen bir bildirim yok.
  testWidgets('anahtar kapatılınca uyarı da kalkıyor', (tester) async {
    final reminders = _FixedPermission(ReminderPermissionState.denied);
    await pump(tester, reminders);

    await tester.tap(find.byKey(const Key('reminder-switch-row')));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderBlockedNotice), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-switch-row')));
    await tester.pumpAndSettle();

    expect(switchOn(tester), isFalse);
    expect(find.byType(ReminderBlockedNotice), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
