import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/shared/widgets/primary_button.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required bool busy,
    VoidCallback? onPressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Kaydet',
            busy: busy,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('kısa süren iş spinner göstermez', (tester) async {
    await pumpButton(tester, busy: false);
    await pumpButton(tester, busy: true);

    // İş başlar başlamaz spinner yok; etiket yerinde duruyor.
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Kaydet'), findsOneWidget);

    // Ve iş gecikme dolmadan biterse hiç görünmüyor: aksi hâlde bir kare
    // belirip kaybolan spinner, arayüzün tökezlediği izlenimini verirdi.
    await pumpButton(tester, busy: false);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('uzayan iş spinner gösterir', (tester) async {
    await pumpButton(tester, busy: false);
    await pumpButton(tester, busy: true);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('iş sürerken düğme hemen kilitlenir', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Kaydet',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    // Spinner henüz görünmüyor ama koruma çoktan devrede: gecikme yalnızca
    // görsel, tıklamayı geciktirmiyor.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(taps, 0);
  });
}
