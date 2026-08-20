import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_field.dart';
import 'package:latermark/l10n/app_localizations.dart';

/// Hatırlatma ana formda tek bir özet satırıdır. Süre, özel değer ve tekrar
/// kipi klavyeyle yarışmayan geçici bir yüzeyde birlikte düzenlenir.
void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required Locale locale,
    required int days,
    required bool repeats,
    required double width,
    double textScale = 1,
    ValueChanged<int>? onChanged,
    ValueChanged<bool>? onRepeatsChanged,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ReminderField(
              days: days,
              repeats: repeats,
              prominent: true,
              onChanged: onChanged ?? (_) {},
              onRepeatsChanged: onRepeatsChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('özet satırı bütün dillerde dar ekrana sığar', (tester) async {
    for (final locale in L10n.supportedLocales) {
      await pumpField(
        tester,
        locale: locale,
        days: 30,
        repeats: true,
        width: 320,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${locale.toLanguageTag()} dilinde özet taştı',
      );
    }
  });

  testWidgets('seçim paneli büyük yazıyla dar ekranda taşmaz', (tester) async {
    await pumpField(
      tester,
      locale: const Locale('de'),
      days: 30,
      repeats: true,
      width: 320,
      textScale: 2,
    );

    await tester.tap(find.byKey(const Key('reminder-field-control')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hızlı seçenekler bütün dillerde sığar', (tester) async {
    for (final locale in L10n.supportedLocales) {
      await pumpField(
        tester,
        locale: locale,
        days: 0,
        repeats: false,
        width: 320,
        textScale: 1.3,
      );

      await tester.tap(find.byKey(const Key('reminder-field-control')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminder-preset-0')), findsOneWidget);
      expect(find.byKey(const Key('reminder-preset-1')), findsOneWidget);
      expect(find.byKey(const Key('reminder-preset-7')), findsOneWidget);
      expect(find.byKey(const Key('reminder-preset-custom')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '${locale.toLanguageTag()} dilinde hızlı seçenekler taştı',
      );
      await tester.tap(find.byKey(const Key('reminder-sheet-cancel')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('sheet alt kenara oturur ve seçenek yazıları merkezlenir', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 0,
      repeats: false,
      width: 390,
    );

    await tester.tap(find.byKey(const Key('reminder-field-control')));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byKey(const Key('reminder-sheet')));
    expect(sheet.bottom, 900);

    final option = find.byKey(const Key('reminder-preset-1'));
    final label = find.descendant(of: option, matching: find.text('1 day'));
    final optionRect = tester.getRect(option);
    final labelRect = tester.getRect(label);
    expect(labelRect.center.dx, closeTo(optionRect.center.dx, 0.5));
    expect(labelRect.center.dy, closeTo(optionRect.center.dy, 0.5));
  });

  testWidgets('özet satırının tamamı parmak ölçüsünde tek hedef', (
    tester,
  ) async {
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: false,
      width: 390,
    );

    final box = tester.getRect(find.byKey(const Key('reminder-field-control')));
    expect(box.width, greaterThanOrEqualTo(44));
    expect(box.height, greaterThanOrEqualTo(44));
  });

  testWidgets('hızlı süre ile tekrar tek panelde birlikte uygulanır', (
    tester,
  ) async {
    int? changedDays;
    bool? changedRepeats;
    await pumpField(
      tester,
      locale: const Locale('tr'),
      days: 0,
      repeats: false,
      width: 390,
      onChanged: (value) => changedDays = value,
      onRepeatsChanged: (value) => changedRepeats = value,
    );

    await tester.tap(find.byKey(const Key('reminder-field-control')));
    await tester.pumpAndSettle();

    // Süre yokken tekrar kipi etkisizdir.
    await tester.tap(
      find.byKey(const Key('reminder-mode-repeat')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(changedRepeats, isNull);

    await tester.tap(find.byKey(const Key('reminder-preset-7')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reminder-mode-repeat')));
    await tester.pump();

    // Sheet içindeki geçici seçim nota henüz yazılmaz.
    expect(changedDays, isNull);
    expect(changedRepeats, isNull);
    expect(find.text('Her 7 günde bir hatırlatılır.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-sheet-save')));
    await tester.pumpAndSettle();

    expect(changedDays, 7);
    expect(changedRepeats, isTrue);
  });

  testWidgets('özel gün üst sınıra çekilir', (tester) async {
    int? changedDays;
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 0,
      repeats: false,
      width: 390,
      onChanged: (value) => changedDays = value,
    );

    await tester.tap(find.byKey(const Key('reminder-field-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-preset-custom')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('reminder-custom-days')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('reminder-custom-days')),
      '999',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('reminder-custom-days')),
        matching: find.text('365'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('reminder-sheet-save')));
    await tester.tap(find.byKey(const Key('reminder-sheet-save')));
    await tester.pumpAndSettle();
    expect(changedDays, 365);
  });

  testWidgets('vazgeç geçici seçimleri geri taşımıyor', (tester) async {
    int? changedDays;
    bool? changedRepeats;
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: true,
      width: 390,
      onChanged: (value) => changedDays = value,
      onRepeatsChanged: (value) => changedRepeats = value,
    );

    await tester.tap(find.byKey(const Key('reminder-field-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-preset-1')));
    await tester.tap(find.byKey(const Key('reminder-mode-once')));
    await tester.tap(find.byKey(const Key('reminder-sheet-cancel')));
    await tester.pumpAndSettle();

    expect(changedDays, isNull);
    expect(changedRepeats, isNull);
  });

  testWidgets('açık seçim özet satırında süre ve kipi gösterir', (
    tester,
  ) async {
    await pumpField(
      tester,
      locale: const Locale('tr'),
      days: 3,
      repeats: true,
      width: 390,
    );

    expect(find.text('3 gün'), findsOneWidget);
    expect(find.text('Hatırlatmayı tekrarla'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('etiket telefon eninde özetle sıkışmaz', (tester) async {
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: true,
      width: 390,
    );

    final detail = tester.getRect(
      find.text('Bring this frame back on the day you choose.'),
    );
    expect(detail.width, greaterThanOrEqualTo(145));
    expect(tester.takeException(), isNull);
  });
}
