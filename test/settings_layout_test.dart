import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart'
    hide SettingsRow;
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/features/settings/presentation/settings_page.dart';
import 'package:latermark/features/settings/presentation/your_data_page.dart';
import 'package:latermark/features/settings/presentation/widgets/settings_pieces.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository notes;
  late SettingsRepository settings;

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Latermark',
      packageName: 'com.mersev.latermark',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_settings');
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

  void useSurface(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    double topPadding = 24,
    double bottomPadding = 16,
  }) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(
      top: topPadding,
      bottom: bottomPadding,
    );
    tester.platformDispatcher.textScaleFactorTestValue = textScale;

    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpSettingsPage(
    WidgetTester tester, {
    required AppLocale locale,
    bool remindersEnabled = false,
  }) async {
    await settings.setLocale(locale);
    await settings.setThemeMode(AppThemeMode.light);
    await settings.setReminderEnabled(remindersEnabled);

    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        child: MaterialApp(
          locale: locale.locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          theme: AppTheme.light(),
          home: const SettingsPage(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('ayarlar basligi safe area icinde sabitlenip kuculur', (
    tester,
  ) async {
    useSurface(tester, const Size(320, 568));
    await pumpSettingsPage(tester, locale: AppLocale.french);

    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(header.pinned, isTrue);

    final back = find.byIcon(Icons.arrow_back_rounded);
    expect(tester.getTopLeft(back).dy, greaterThanOrEqualTo(24));

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(600);
    await tester.pump();

    expect(tester.getTopLeft(back).dy, moreOrLessEquals(34));
    expect(
      tester.widget<Text>(find.text('Réglages')).style?.fontSize,
      moreOrLessEquals(19),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnnotatedRegion<SystemUiOverlayStyle> &&
            widget.value.statusBarIconBrightness == Brightness.dark,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('uzun Fransizca metinler 320 px ekranda tasmaz', (tester) async {
    useSurface(tester, const Size(320, 568), textScale: 1.3);
    await pumpSettingsPage(
      tester,
      locale: AppLocale.french,
      remindersEnabled: true,
    );

    await tester.scrollUntilVisible(
      find.text('Conditions d’utilisation'),
      240,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );

    final privacy = tester.getRect(find.text('Confidentialité'));
    final terms = tester.getRect(find.text('Conditions d’utilisation'));
    expect(privacy.left, greaterThanOrEqualTo(0));
    expect(privacy.right, lessThanOrEqualTo(320));
    expect(terms.left, greaterThanOrEqualTo(0));
    expect(terms.right, lessThanOrEqualTo(320));
    expect(terms.top, greaterThan(privacy.top));
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('yedekleme ayarlarda tek ve sakin bir giriş olarak görünür', (
    tester,
  ) async {
    useSurface(tester, const Size(320, 568), textScale: 1.3);
    await pumpSettingsPage(tester, locale: AppLocale.turkish);

    final settingsScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-backup')),
      240,
      scrollable: settingsScroll,
    );

    expect(find.text('YEDEKLEME'), findsOneWidget);
    expect(find.text('Yedekleme işlemleri'), findsOneWidget);
    expect(find.byKey(const Key('settings-backup')), findsOneWidget);
    expect(find.byKey(const Key('settings-backup-create')), findsNothing);
    expect(find.byKey(const Key('settings-backup-restore')), findsNothing);
    expect(find.text('Yedek al'), findsNothing);
    expect(find.text('Yedeği geri yükle'), findsNothing);
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('veriler baglantisi yerel aciklama sayfasini acar', (
    tester,
  ) async {
    useSurface(tester, const Size(320, 568), textScale: 1.3);
    await pumpSettingsPage(tester, locale: AppLocale.turkish);

    final settingsScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Latermark ve Verileriniz'),
      240,
      scrollable: settingsScroll,
    );
    await tester.ensureVisible(find.text('Latermark ve Verileriniz'));
    await tester.pump();
    await tester.tap(find.text('Latermark ve Verileriniz'));
    await tester.pumpAndSettle();

    expect(find.byType(YourDataPage), findsOneWidget);
    expect(
      find.text('Gizliliğinizi önemsiyor ve ona saygı duyuyoruz.'),
      findsOneWidget,
    );
    final dataScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Verilerim güvende mi?'),
      180,
      scrollable: dataScroll,
    );
    expect(find.text('Verilerim güvende mi?'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Uygulamayı silersem ne olur?'),
      240,
      scrollable: dataScroll,
    );
    expect(find.text('Uygulamayı silersem ne olur?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('dil paneli kisa ekranda kaydirilarak son secenege ulasir', (
    tester,
  ) async {
    useSurface(tester, const Size(320, 360), textScale: 1.3, bottomPadding: 12);
    AppLocale? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showLanguageSheet(
                  context,
                  value: AppLocale.french,
                  onChanged: (value) => selected = value,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const Key('language-sheet-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.borderRadius, isNull);

    final languageScroll = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Français'),
      60,
      scrollable: languageScroll,
    );
    expect(find.byKey(const Key('language-selected-rule')), findsOneWidget);
    expect(find.byKey(const Key('language-selected-mark')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Italiano'),
      120,
      scrollable: languageScroll,
    );
    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();

    expect(selected, AppLocale.italian);
    expect(find.text('Italiano'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ortak ayar parcalari 240 px ve iki kat yazida uyarlanir', (
    tester,
  ) async {
    useSurface(
      tester,
      const Size(240, 700),
      textScale: 2,
      topPadding: 0,
      bottomPadding: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsSection(
              title: 'Ausserordentlich lange Darstellungseinstellungen',
              children: [
                SettingsRow(
                  title: 'Erscheinungsbild und Darstellungsoptionen',
                  description:
                      'Diese ausfuehrliche Beschreibung muss lesbar bleiben.',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Flexible(child: Text('Portugiesisch (Brasilien)')),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  below: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ChoiceRail<String>(
                      key: const Key('long-choice-rail'),
                      options: const [
                        'Systemdarstellung',
                        'Immer helles Erscheinungsbild',
                        'Immer dunkles Erscheinungsbild',
                      ],
                      value: 'Systemdarstellung',
                      labelOf: (value) => value,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final rail = tester.getRect(find.byKey(const Key('long-choice-rail')));
    expect(rail.height, greaterThan(46));
    for (final label in const [
      'Systemdarstellung',
      'Immer helles Erscheinungsbild',
      'Immer dunkles Erscheinungsbild',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(rail.left));
      expect(rect.right, lessThanOrEqualTo(rail.right));
      expect(rect.top, greaterThanOrEqualTo(rail.top));
      expect(rect.bottom, lessThanOrEqualTo(rail.bottom));
    }
    expect(tester.takeException(), isNull);
  });
}
