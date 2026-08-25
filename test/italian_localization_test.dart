import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  late L10n it;

  setUpAll(() async {
    it = await L10n.delegate.load(const Locale('it'));
  });

  test('İtalyanca desteklenen dillerde ve seçim listesinin sonunda', () {
    expect(L10n.supportedLocales, contains(const Locale('it')));
    expect(AppLocale.values.last, AppLocale.italian);
    expect(AppLocale.italian.nativeName, 'Italiano');
  });

  test('tekil ve çoğul metinler İtalyanca kurallarla üretilir', () {
    expect(it.noteCount(0), 'Nessuna nota');
    expect(it.noteCount(1), '1 nota');
    expect(it.noteCount(3), '3 note');
    expect(it.searchResults(1), '1 risultato');
    expect(it.searchResults(4), '4 risultati');
  });

  test('ürün dili ve paywall metinleri İngilizceye düşmez', () {
    expect(it.inviteTitle, 'Tocca per scattare');
    expect(it.paywallHeadline, 'Non lasciare indietro ciò che conta.');
    expect(it.notificationTitle, 'Promemoria');
  });
}
