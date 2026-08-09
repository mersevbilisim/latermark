import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/widgets/retention_selector.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  final longLocales = <({String name, Locale locale, List<String> labels})>[
    (
      name: 'Fransizca',
      locale: const Locale('fr'),
      labels: const ['Désactivée', '3 jours', '1 semaine', 'Personnalisée'],
    ),
    (
      name: 'Italyanca',
      locale: const Locale('it'),
      labels: const [
        'Disattivata',
        '3 giorni',
        '1 settimana',
        'Personalizzata',
      ],
    ),
    (
      name: 'Ispanyolca',
      locale: const Locale('es'),
      labels: const ['Desactivado', '3 días', '1 semana', 'Personalizado'],
    ),
    (
      name: 'Portekizce',
      locale: const Locale('pt', 'BR'),
      labels: const ['Desativado', '3 dias', '1 semana', 'Personalizado'],
    ),
  ];

  void useSurface(
    WidgetTester tester, {
    required double textScale,
    required double physicalWidth,
  }) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(physicalWidth, 640);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pumpSelector(
    WidgetTester tester, {
    required Locale locale,
    required double width,
    required double textScale,
    ValueChanged<RetentionChoice>? onChanged,
  }) async {
    useSurface(
      tester,
      textScale: textScale,
      physicalWidth: width > 320 ? width + 44 : 320,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: RetentionSelector(
                key: const Key('retention-selector'),
                value: const RetentionChoice(Retention.off),
                showTitle: false,
                onChanged: onChanged ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final scenario in longLocales) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
        '${scenario.name} etiketler 240 px ve ${scale}x olcekte eksiksizdir',
        (tester) async {
          await pumpSelector(
            tester,
            locale: scenario.locale,
            width: 240,
            textScale: scale,
          );

          final selector = tester.getRect(
            find.byKey(const Key('retention-selector')),
          );
          expect(selector.height, greaterThan(46));

          for (final label in scenario.labels) {
            final finder = find.text(label);
            expect(finder, findsOneWidget);
            final text = tester.widget<Text>(finder);
            final rect = tester.getRect(finder);
            expect(text.overflow, isNull);
            expect(rect.left, greaterThanOrEqualTo(selector.left));
            expect(rect.right, lessThanOrEqualTo(selector.right));
            expect(rect.top, greaterThanOrEqualTo(selector.top));
            expect(rect.bottom, lessThanOrEqualTo(selector.bottom));
          }

          // Dört dar hücre yerine iki okunaklı satır oluştu.
          expect(
            tester.getTopLeft(find.text(scenario.labels.last)).dy,
            greaterThan(tester.getTopLeft(find.text(scenario.labels.first)).dy),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('genis compose yerlesimi tek sirali ve etkilesimli kalir', (
    tester,
  ) async {
    RetentionChoice? changed;
    await pumpSelector(
      tester,
      locale: const Locale('en'),
      width: 346,
      textScale: 1,
      onChanged: (value) => changed = value,
    );

    final selectorSize = tester.getSize(
      find.byKey(const Key('retention-selector')),
    );
    expect(selectorSize.height, 46);
    await tester.tap(find.text('3 Days'));
    await tester.pump();

    expect(changed?.retention, Retention.threeDays);
    expect(tester.takeException(), isNull);
  });
}
