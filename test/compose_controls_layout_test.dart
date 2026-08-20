import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/presentation/widgets/note_option_label.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/colophon_bar.dart';

Widget _harness({required Widget child}) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('tr'),
  localizationsDelegates: L10n.localizationsDelegates,
  supportedLocales: L10n.supportedLocales,
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  testWidgets('metadata label ve kaydet şeridi dar ekranda uyarlanir', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    // Yatay uyarlamayı 240 px'te zorlarken, iki kat yazının doğal yüksekliğini
    // yapay olarak kesmemek için dikeyde erişilebilir bir telefon yüzeyi.
    tester.view.physicalSize = const Size(240, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    var taps = 0;
    await tester.pumpWidget(
      _harness(
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
            ColophonBar(
              actions: [
                ColophonAction(
                  key: const ValueKey('compose-action-save'),
                  label: 'Kaydet',
                  semanticLabel: 'Kaydet',
                  onPressed: () => taps++,
                ),
              ],
            ),
          ],
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
    // İki kat yazıyla bile şerit taşmıyor: ad tek satır, gerekirse kısalır.
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('KAYDET'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('şerit çalışırken kilitlenir ve kelime nefes alır', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 300);
    addTearDown(tester.view.reset);

    var taps = 0;
    await tester.pumpWidget(
      _harness(
        child: Column(
          children: [
            const Spacer(),
            ColophonBar(
              actions: [
                ColophonAction(
                  key: const ValueKey('compose-action-save'),
                  label: 'Kaydet',
                  semanticLabel: 'Kaydet',
                  busy: true,
                  onPressed: () => taps++,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    // Spinner yok; beklendiğini kelimenin kendisi söylüyor.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('KAYDET'), findsOneWidget);

    double opacityOf() => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const ValueKey('compose-action-save')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    expect(opacityOf(), 1.0);
    await tester.pump(const Duration(milliseconds: 550));
    expect(opacityOf(), lessThan(1.0));

    // Çalışırken ikinci dokunuş kaydı tekrar tetiklemiyor.
    await tester.tap(find.text('KAYDET'));
    await tester.pump();
    expect(taps, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('hareketi azalt açıkken nefes durur ama sönüklük kalır', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _harness(
          child: Column(
            children: [
              const Spacer(),
              ColophonBar(
                actions: [
                  ColophonAction(
                    key: const ValueKey('compose-action-save'),
                    label: 'Kaydet',
                    semanticLabel: 'Kaydet',
                    busy: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final first = tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const ValueKey('compose-action-save')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(first, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 550));
    final second = tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const ValueKey('compose-action-save')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(second, first);
  });
}
