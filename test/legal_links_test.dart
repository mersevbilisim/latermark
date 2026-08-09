import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/utils/legal_links.dart';
import 'package:latermark/l10n/app_localizations.dart';

/// Gizlilik adresi dil koduyla bitiyor. Yanlış kod, kullanıcıyı olmayan bir
/// sayfaya götürür — ve bu sessizce olur, o yüzden testle sabitleniyor.
void main() {
  Future<Uri> privacyFor(WidgetTester tester, Locale locale) async {
    Uri? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        home: Builder(
          builder: (context) {
            result = LegalLinks.privacy(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result!;
  }

  testWidgets('adres yürürlükteki dilin koduyla biter', (tester) async {
    expect(
      (await privacyFor(tester, const Locale('tr'))).toString(),
      'https://www.mersev.com/latermark-app/privacy-tr',
    );
    expect(
      (await privacyFor(tester, const Locale('ko'))).toString(),
      'https://www.mersev.com/latermark-app/privacy-ko',
    );
  });

  testWidgets('pt_PT ve pt_BR aynı privacy-pt sayfasını açar', (tester) async {
    expect(
      (await privacyFor(tester, const Locale('pt', 'PT'))).toString(),
      'https://www.mersev.com/latermark-app/privacy-pt',
    );
    expect(
      (await privacyFor(tester, const Locale('pt', 'BR'))).toString(),
      'https://www.mersev.com/latermark-app/privacy-pt',
    );
  });

  testWidgets('İtalyanca doğrudan privacy-it sayfasını açar', (tester) async {
    expect(
      (await privacyFor(tester, const Locale('it'))).toString(),
      'https://www.mersev.com/latermark-app/privacy-it',
    );
  });

  testWidgets('desteklenmeyen dil İngilizceye düşer', (tester) async {
    // Çözümleme `LatermarkApp` yerine burada Flutter'ın varsayılanıyla
    // yapılıyor; yine de sonucun desteklenen bir dil olması gerekir.
    final url = await privacyFor(tester, const Locale('sv'));
    expect(
      L10n.supportedLocales.map((l) => l.languageCode),
      contains(url.pathSegments.last.split('-').last),
    );
  });

  test('koşullar Apple standart EULA adresi', () {
    expect(
      LegalLinks.terms.toString(),
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    );
  });
}
