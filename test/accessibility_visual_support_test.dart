import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_routes.dart';
import 'package:latermark/core/theme/accent_tone.dart';
import 'package:latermark/core/theme/app_accent.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/settings/presentation/widgets/settings_pieces.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/app_toast.dart';
import 'package:latermark/shared/widgets/aperture.dart';

double _contrast(Color foreground, Color background) {
  final composited = Color.alphaBlend(foreground, background);
  final first = composited.computeLuminance();
  final second = background.computeLuminance();
  final light = first > second ? first : second;
  final dark = first > second ? second : first;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  test('varsayılan paletler de iki temada AA eşiğini tutuyor', () {
    // Yüksek kontrast isteğe bağlı bir anahtar; Apple'ın ölçütü uygulamanın
    // **varsayılan** görünümü için. Eşiğin altında kalan bir metin, hiyerarşinin
    // alt basamağı değil kayıp bilgi.
    for (final brightness in Brightness.values) {
      for (final accent in AppAccent.values) {
        final palette = AppPalette.forAccent(
          brightness,
          accent,
          customHue: 214,
        );
        final grounds = {
          'canvas': palette.canvas,
          'lift': palette.canvasLift,
          // Seçim rayının oluğu: hücre etiketleri bu zeminin üstünde duruyor.
          'sunk': palette.canvasSunk,
        };

        for (final ground in grounds.entries) {
          for (final ink in {
            'soft': palette.inkSoft,
            'faint': palette.inkFaint,
          }.entries) {
            expect(
              _contrast(ink.value, ground.value),
              greaterThanOrEqualTo(4.5),
              reason: '$brightness/$accent ${ink.key} ${ground.key}',
            );
          }

          // En sessiz kat yazı taşımıyor (yer tutucu, devre dışı denetim);
          // AA aranmıyor ama görünmez de olmuyor.
          expect(
            _contrast(palette.inkGhost, ground.value),
            greaterThanOrEqualTo(3),
            reason: '$brightness/$accent ghost ${ground.key}',
          );
        }

        // Vurgu rengi yazı da renklendiriyor ("LATERMARK PRO", "HATIRLAT").
        // Oluk zemini vurgulu yazı taşımıyor, o yüzden ölçüt sayfa ve yükselti.
        for (final ground in {
          'canvas': palette.canvas,
          'lift': palette.canvasLift,
        }.entries) {
          expect(
            _contrast(palette.ember, ground.value),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness/$accent ember ${ground.key}',
          );
        }
      }
    }
  });

  test('özel tonun tamamı da eşiği tutuyor', () {
    for (var hue = 0; hue < AccentTone.hueCount; hue++) {
      for (final brightness in Brightness.values) {
        final palette = AppPalette.forAccent(
          brightness,
          AppAccent.custom,
          customHue: hue,
        );
        expect(
          _contrast(palette.ember, palette.canvas),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness ton $hue',
        );
      }
    }
  });

  test('yüksek kontrast varsayılanın üstüne çıkıyor', () {
    // Anahtar bir adım **daha** olmalı; varsayılan eşiğe çekilince yüksek
    // kontrastın kendisi anlamsızlaşmasın.
    for (final brightness in Brightness.values) {
      final base = AppPalette.forAccent(brightness, AppAccent.orange);
      final strong = AppPalette.forAccent(
        brightness,
        AppAccent.orange,
        highContrast: true,
      );
      for (final pair in [
        (base.inkSoft, strong.inkSoft, 'soft'),
        (base.inkFaint, strong.inkFaint, 'faint'),
        (base.inkGhost, strong.inkGhost, 'ghost'),
      ]) {
        expect(
          _contrast(pair.$2, strong.canvas),
          greaterThan(_contrast(pair.$1, base.canvas)),
          reason: '$brightness ${pair.$3}',
        );
      }
    }
  });

  test('yüksek kontrast ikincil metinleri iki temada AA eşiğinde tutar', () {
    for (final brightness in Brightness.values) {
      for (final accent in AppAccent.values) {
        final palette = AppPalette.forAccent(
          brightness,
          accent,
          customHue: 214,
          highContrast: true,
        );

        expect(palette.highContrast, isTrue);
        expect(palette.accent, accent);
        expect(
          _contrast(palette.inkSoft, palette.canvas),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness/$accent soft canvas',
        );
        expect(
          _contrast(palette.inkFaint, palette.canvas),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness/$accent faint canvas',
        );
        expect(
          _contrast(palette.inkSoft, palette.canvasLift),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness/$accent soft lift',
        );
        expect(
          _contrast(palette.inkFaint, palette.canvasLift),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness/$accent faint lift',
        );
      }
    }
  });

  testWidgets('sistem yüksek kontrastı MaterialApp temasını değiştirir', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    late AppPalette palette;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        highContrastTheme: AppTheme.lightHighContrast(),
        home: Builder(
          builder: (context) {
            palette = context.palette;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(palette.highContrast, isTrue);
  });

  testWidgets('hareketi azalt açıkken diyaframın dekoratif nefesi durur', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          reduceMotion: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: ApertureButton(
              breathing: true,
              semanticLabel: 'Kamera',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    double openness() =>
        tester.widget<Aperture>(find.byType(Aperture)).openness;
    final first = openness();
    await tester.pump(const Duration(seconds: 3));

    expect(openness(), first);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('hareketi azalt açıkken sayfa büyümez, yalnız solar', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          reduceMotion: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(AppRoutes.shutter(const SizedBox(key: Key('destination')))),
            child: const Text('Aç'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('destination')), findsOneWidget);
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(ScaleTransition), findsNothing);
  });

  testWidgets('seçili vurgu rengi rengin kendisiyle değil imle işaretleniyor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: AccentRail(
              value: AppAccent.orange,
              labelOf: (accent) => accent.name,
              onChanged: (_) {},
              customHue: 214,
              onCustom: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Renk körü bir kullanıcı için turuncuyu maviden ayırmak güvenilir değil;
    // seçimi taşıyan şey imin kendisi. Yalnız seçili yuvada bulunmalı.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('hata ve onay hapları renkten bağımsız olarak ayrılıyor', (
    tester,
  ) async {
    Widget host(bool error) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showToast(context, 'İleti', error: error),
            child: const Text('bas'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(false));
    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);

    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
  });
}
