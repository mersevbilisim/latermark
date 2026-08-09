import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/presentation/detail/widgets/photo_dismiss_surface.dart';

void main() {
  testWidgets('kısa çekiş geri yaylanır, kararlı çekiş detayı kapatır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var progress = 0.0;
    var dismissCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoDismissSurface(
            onProgressChanged: (value) => progress = value,
            onDismissed: () => dismissCount++,
            child: const SizedBox.expand(
              child: ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PhotoDismissSurface));
    final shortPull = await tester.startGesture(center);
    for (var step = 0; step < 8; step++) {
      await shortPull.moveBy(const Offset(1, 9));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(progress, greaterThan(0));
    await shortPull.up();
    await tester.pumpAndSettle();

    expect(dismissCount, 0);
    expect(progress, closeTo(0, .001));

    final committedPull = await tester.startGesture(center);
    for (var step = 0; step < 10; step++) {
      await committedPull.moveBy(const Offset(1.8, 19));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await committedPull.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(dismissCount, 1);
  });

  testWidgets('alt tutamak kısa başparmak çekişiyle kapatır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var offset = 0.0;
    var dismissCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PullDownDismissRegion(
              onDismissRequested: () async => true,
              onOffsetChanged: (value) => offset = value,
              onDismissed: () => dismissCount++,
              child: const SizedBox(width: double.infinity, height: 40),
            ),
          ),
        ),
      ),
    );

    final handle = find.byType(PullDownDismissRegion);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    for (var step = 0; step < 6; step++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(offset, greaterThanOrEqualTo(82));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(dismissCount, 1);
  });
}
