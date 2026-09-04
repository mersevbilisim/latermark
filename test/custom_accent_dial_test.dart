import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/settings/presentation/widgets/custom_accent_sheet.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/primary_button.dart';

/// Özel vurgu rengi kadranı.
///
/// Kadran kaydırılabilir bir panelin içinde yaşıyor: panelin kendi kapanma
/// jesti ve içindeki kaydırma, dikey bileşeni olan her el hareketini kadranın
/// elinden alıyordu. Tutamak yerinde kalıyor, onun yerine panel kayıyordu.
void main() {
  const dial = Key('custom-accent-dial');
  const surface = Key('custom-accent-sheet-surface');

  late int? applied;

  Future<void> open(WidgetTester tester) async {
    applied = null;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('tr'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCustomAccentSheet(
              context,
              hue: 0,
              onChanged: (value) => applied = value,
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
  }

  testWidgets('halkanın yanından dikey çevirmek tonu döndürüyor', (
    tester,
  ) async {
    await open(tester);

    final center = tester.getCenter(find.byKey(dial));
    final radius = tester.getSize(find.byKey(dial)).width / 2;
    final before = tester.getTopLeft(find.byKey(surface));

    // Kadranın solu: buradan aşağı çekmek neredeyse tamamen dikey bir el
    // hareketi. Eski hâlinde bu hareketi panel kapıyordu.
    final gesture = await tester.startGesture(
      center + Offset(-(radius - 8), 0),
    );
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // Panel ne kapandı ne de kaydı.
    expect(find.byKey(surface), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(surface)), before);

    await apply(tester);
    // Sol taraf 270°; 40 piksel aşağısı yaklaşık 251°.
    expect(applied, isNotNull);
    expect(applied, closeTo(251, 3));
  });

  testWidgets('deklanşörün üstünden başlayan el hareketi tonu bozmuyor', (
    tester,
  ) async {
    await open(tester);

    // Ortadaki önizleme bir denetim değil: oradan başlayan sürükleme kadranı
    // çevirmiyor, panelin kendi jestine kalıyor.
    final center = tester.getCenter(find.byKey(dial));
    final gesture = await tester.startGesture(center + const Offset(0, 20));
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(surface), findsOneWidget);
    await apply(tester);
    expect(applied, 0);
  });
}
