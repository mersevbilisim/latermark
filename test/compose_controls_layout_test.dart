import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/presentation/compose/widgets/compose_save_action.dart';
import 'package:latermark/features/notes/presentation/compose/widgets/note_composer.dart';
import 'package:latermark/features/notes/presentation/widgets/note_option_label.dart';

void main() {
  testWidgets('metadata label ve kaydet rayi dar ekranda uyarlanir', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    // Yatay uyarlamayı 240 px'te zorlarken, iki kat yazının doğal yüksekliğini
    // yapay olarak kesmemek için dikeyde erişilebilir bir telefon yüzeyi.
    tester.view.physicalSize = const Size(240, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                NoteOptionRow(
                  label: const NoteOptionLabel(
                    key: ValueKey('option-label'),
                    icon: Icons.notifications_none_rounded,
                    title: 'Hatırlat',
                    detail: 'Bu kareyi seçtiğin gün yeniden karşına çıkarır.',
                    active: false,
                  ),
                  trailing: const SizedBox(
                    key: ValueKey('option-control'),
                    width: 112,
                    height: 44,
                  ),
                ),
                const Spacer(),
                ComposeSaveAction(label: 'Kaydet', onPressed: () => taps++),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final label = tester.getRect(find.byKey(const ValueKey('option-label')));
    final control = tester.getRect(
      find.byKey(const ValueKey('option-control')),
    );
    expect(control.top, greaterThanOrEqualTo(label.bottom));
    expect(control.right, lessThanOrEqualTo(224));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('kayit rayi mekanik durumda kilitlenir ve marka izini korur', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ComposeSaveAction(
            label: 'Kaydet',
            phase: ComposeSavePhase.saving,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('compose-save-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-save-aperture')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(taps, 0);

    // Gecikmeli mekanik ticker test sonuna sarkmasın.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dar yukseklikte metadata kayar ve kaydet altta kalir', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 360);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: NoteComposer(
              controller: controller,
              autofocus: false,
              hintText: 'Not',
              extra: const Column(
                children: [
                  NoteOptionRow(
                    label: NoteOptionLabel(
                      icon: Icons.notifications_none_rounded,
                      title: 'Hatırlat',
                      detail: 'Bu kareyi seçtiğin gün yeniden karşına çıkarır.',
                      active: false,
                    ),
                    trailing: SizedBox(width: 112, height: 44),
                  ),
                  SizedBox(height: 100),
                ],
              ),
              action: const SizedBox(key: ValueKey('pinned-save'), height: 64),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('pinned-save'))).bottom,
      lessThanOrEqualTo(344),
    );
    expect(tester.takeException(), isNull);
  });
}
