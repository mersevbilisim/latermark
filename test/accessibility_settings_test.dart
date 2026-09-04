import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/presentation/home/home_page.dart';
import 'package:latermark/features/reminders/reminder_service.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/features/settings/presentation/accessibility_page.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository notes;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_accessibility');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    notes = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
  }

  test('iki tercih kapalı doğar ve birbirinden bağımsız saklanır', () async {
    expect((await settings.read()).alwaysHighContrast, isFalse);
    expect((await settings.read()).alwaysReduceMotion, isFalse);

    await settings.setAlwaysHighContrast(true);
    var value = await settings.read();
    expect(value.alwaysHighContrast, isTrue);
    expect(value.alwaysReduceMotion, isFalse);

    await settings.setAlwaysReduceMotion(true);
    value = await settings.read();
    expect(value.alwaysHighContrast, isTrue);
    expect(value.alwaysReduceMotion, isTrue);
  });

  testWidgets('bağımsız sayfadaki anahtarlar gerçek tercihi değiştirir', (
    tester,
  ) async {
    await settings.setLocale(AppLocale.turkish);
    await settings.setThemeMode(AppThemeMode.light);

    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        reminders: ReminderService(),
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          theme: AppTheme.light(),
          home: const AccessibilityPage(),
        ),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('accessibility-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('accessibility-high-contrast')));
    await settle(tester);
    expect((await settings.read()).alwaysHighContrast, isTrue);

    await tester.tap(find.byKey(const Key('accessibility-reduce-motion')));
    await settle(tester);
    expect((await settings.read()).alwaysReduceMotion, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('uygulama tercihi kontrast ve hareketi kökte zorlar', (
    tester,
  ) async {
    await settings.setThemeMode(AppThemeMode.light);
    await settings.setAlwaysHighContrast(true);
    await settings.setAlwaysReduceMotion(true);

    await tester.pumpWidget(LatermarkApp(notes: notes, settings: settings));
    await settle(tester);

    final home = tester.element(find.byType(HomePage));
    expect(MediaQuery.highContrastOf(home), isTrue);
    expect(MediaQuery.disableAnimationsOf(home), isTrue);
    expect(home.palette.highContrast, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('kapalı uygulama anahtarı açık sistem tercihini bastırmaz', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          highContrast: true,
          disableAnimations: true,
          reduceMotion: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await settings.setThemeMode(AppThemeMode.light);
    expect((await settings.read()).alwaysHighContrast, isFalse);
    expect((await settings.read()).alwaysReduceMotion, isFalse);

    await tester.pumpWidget(LatermarkApp(notes: notes, settings: settings));
    await settle(tester);

    final home = tester.element(find.byType(HomePage));
    expect(MediaQuery.highContrastOf(home), isTrue);
    expect(MediaQuery.disableAnimationsOf(home), isTrue);
    expect(home.palette.highContrast, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('erişilebilirlik sayfası dar ekranda bütün dillerde taşmaz', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final locale in L10n.supportedLocales) {
      await tester.pumpWidget(
        AppScope(
          notes: notes,
          settings: settings,
          reminders: ReminderService(),
          child: MaterialApp(
            locale: locale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: L10n.localizationsDelegates,
            theme: AppTheme.light(),
            home: const AccessibilityPage(),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull, reason: locale.toString());

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: locale.toString());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}
