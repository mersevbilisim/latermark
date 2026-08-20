import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_link.dart';
import 'package:latermark/features/home_widget/home_widget_link.dart';

void main() {
  test('not bağlantısı çözülür', () {
    expect(
      appLinkFromUri(Uri.parse('latermark://note/12')),
      const OpenNoteLink(12),
    );
  });

  test('widget bağlantısı da aynı sözleşmeyi konuşur', () {
    // İki kapı da `latermark://note/<id>` diyor. Widget'ınki ek olarak
    // `homeWidget` parametresi taşıyor ama adres aynı; bir yönlendirmenin
    // anlamı hangi kapıdan girdiğine bağlı olmamalı.
    expect(
      appLinkFromUri(Uri.parse('latermark://note/12?homeWidget')),
      const OpenNoteLink(12),
    );
    expect(
      noteIdFromWidgetUri(Uri.parse('latermark://note/12?homeWidget')),
      12,
    );
  });

  test('geçersiz ve yabancı adresler yok sayılır', () {
    for (final raw in <String>[
      'latermark://note/0',
      'latermark://note/-3',
      'latermark://note/abc',
      'latermark://note',
      'latermark://note/12/extra',
      'latermark://capture',
      'https://latermark.app/note/12',
      'baska://note/12',
    ]) {
      expect(appLinkFromUri(Uri.parse(raw)), isNull, reason: raw);
    }
    expect(appLinkFromUri(null), isNull);
  });
}
