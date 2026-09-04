import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/shared/widgets/collapsible_sliver.dart';

/// Akordiyon eskiden içeriği ağaca koyup çıkararak çalışıyordu; açılıp kapanma
/// bir anda oluyordu. Perde eklendi ama **kazanç korunmalı**: kapalıyken
/// içerik yine hiç kurulmamalı.
void main() {
  Future<void> pumpFeed(WidgetTester tester, {required bool collapsed}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              CollapsibleSliver(
                collapsed: collapsed,
                sliver: const SliverToBoxAdapter(
                  child: SizedBox(height: 300, child: Text('içerik')),
                ),
              ),
              const SliverToBoxAdapter(child: Text('sonraki')),
            ],
          ),
        ),
      ),
    );
  }

  double nextTop(WidgetTester tester) =>
      tester.getTopLeft(find.text('sonraki')).dy;

  testWidgets('kapanış bir anda değil, boy animasyonla iniyor', (tester) async {
    await pumpFeed(tester, collapsed: false);
    final open = nextTop(tester);
    expect(open, 300);

    await pumpFeed(tester, collapsed: true);
    await tester.pump();
    // Yarı yolda: ne açık ne kapalı. Asıl iddia bu — eskiden ara kare yoktu.
    await tester.pump(const Duration(milliseconds: 150));
    final middle = nextTop(tester);
    expect(middle, greaterThan(0));
    expect(middle, lessThan(open));

    await tester.pump(const Duration(milliseconds: 400));
    expect(nextTop(tester), 0);
  });

  testWidgets('kapalıyken içerik ağaca hiç girmiyor', (tester) async {
    // Uzun bir arşivde asıl kazanç bu; perde onu geri almamalı.
    await pumpFeed(tester, collapsed: true);
    await tester.pumpAndSettle();
    expect(find.text('içerik'), findsNothing);
  });

  testWidgets('açılış da animasyonlu ve sonunda tam boy', (tester) async {
    await pumpFeed(tester, collapsed: true);
    await tester.pumpAndSettle();

    await pumpFeed(tester, collapsed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final middle = nextTop(tester);
    expect(middle, greaterThan(0));
    expect(middle, lessThan(300));

    await tester.pumpAndSettle();
    expect(nextTop(tester), 300);
    expect(find.text('içerik'), findsOneWidget);
  });
}
