import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/paywall/domain/pro_limits.dart';
import 'package:latermark/features/paywall/presentation/paywall_page.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/pressable.dart';

void main() {
  Finder footerLink(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Pressable));

  Future<void> pumpPaywall(
    WidgetTester tester, {
    required VoidCallback onRestore,
    Locale locale = const Locale('tr'),
    Size logicalSize = const Size(393, 852),
    double bottomSafeArea = 0,
    String price = '₺149,99',
  }) async {
    // Gerçek cihaz sınıfındaki dokunma alanını ve en büyük desteklenen uygulama
    // yazı ölçeğini birlikte koru.
    tester.view.physicalSize = logicalSize * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            padding: EdgeInsets.only(bottom: bottomSafeArea),
          ),
          child: child!,
        ),
        home: PaywallPage(
          price: price,
          onPurchase: () {},
          onRestore: onRestore,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'alt bağlantıların tamamı gerçek cihaz boyunda dokunma alanıdır',
    (tester) async {
      var restoreTaps = 0;
      await pumpPaywall(tester, onRestore: () => restoreTaps++);

      for (final label in [
        'Satın alımları geri yükle',
        'Gizlilik',
        'Kullanım Koşulları',
      ]) {
        final link = footerLink(label);
        expect(link, findsOneWidget);
        expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
      }

      // Metnin üstündeki görünmez genişletilmiş alan da callback'e ulaşmalı;
      // yalnızca 12 px'lik harflerin tam üstüne basmak gerekmemeli.
      final restore = footerLink('Satın alımları geri yükle');
      final target = tester.getRect(restore);
      final text = tester.getRect(find.text('Satın alımları geri yükle'));
      expect(target.top, lessThan(text.top));

      // Yasal bağlantılar üstte yan yana, restore onların altında ve ekranın
      // yatay merkezinde: footer üç noktalı sakin bir üçgen kuruyor.
      final privacy = tester.getRect(footerLink('Gizlilik'));
      final terms = tester.getRect(footerLink('Kullanım Koşulları'));
      expect(privacy.center.dy, closeTo(terms.center.dy, 0.1));
      expect(target.top, greaterThanOrEqualTo(privacy.bottom));
      expect(
        target.center.dx,
        closeTo(
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
          0.1,
        ),
      );

      await tester.tapAt(Offset(target.center.dx, target.top + 2));
      await tester.pump();
      expect(restoreTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dar ekran ve safe area bütün dillerde footer içeriğini örtmez', (
    tester,
  ) async {
    for (final locale in L10n.supportedLocales) {
      final l10n = await L10n.delegate.load(locale);
      await pumpPaywall(
        tester,
        locale: locale,
        logicalSize: const Size(320, 568),
        bottomSafeArea: 34,
        price: 'R\$ 1.499,90',
        onRestore: () {},
      );

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final footer = tester.getRect(find.byKey(const Key('paywall-footer')));
      final lastFeature = tester.getRect(
        find.text(l10n.paywallFeatureWidgetDetail),
      );
      expect(
        lastFeature.bottom,
        lessThanOrEqualTo(footer.top),
        reason: '${locale.toLanguageTag()} footer içeriği örttü',
      );

      final privacy = tester.renderObject<RenderParagraph>(
        find.text(l10n.legalPrivacy),
      );
      final terms = tester.renderObject<RenderParagraph>(
        find.text(l10n.legalTerms),
      );
      expect(
        privacy.didExceedMaxLines,
        isFalse,
        reason: '${locale.toLanguageTag()} gizlilik etiketini kesti',
      );
      expect(
        terms.didExceedMaxLines,
        isFalse,
        reason: '${locale.toLanguageTag()} koşullar etiketini kesti',
      );
      expect(tester.takeException(), isNull);
    }
  });

  /// Sınırın tek kaynağı [ProLimits]. Bir zamanlar özellik listesi dışarıdan
  /// verilen ve kimsenin geçmediği bir varsayılana (30) bakıyordu; aynı ekranın
  /// başlığı gerçek sınırı yazarken liste otuz diyordu.
  testWidgets('paywall her yerde aynı ücretsiz sınırı yazıyor', (tester) async {
    await pumpPaywall(tester, onRestore: () {});

    expect(
      find.textContaining('${ProLimits.freeNotes} adet değil'),
      findsOneWidget,
    );
    // Sabit bir sayı ekrana sızmasın.
    expect(find.textContaining('30 adet'), findsNothing);
  });
}
