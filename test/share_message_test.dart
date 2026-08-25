import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/domain/share_message.dart';

/// Paylaşımda giden metin. İmza kullanıcının cümlesine ekleniyor; bu yüzden
/// nerede durduğu ve ne zaman hiç durmadığı ayrı ayrı sınanıyor.
void main() {
  test('imza notun arkasına, boş satırla ayrılarak gelir', () {
    expect(
      shareMessage(
        body: 'Kombi bakımı',
        signature: 'Latermark iOS ile gönderildi',
      ),
      'Kombi bakımı\n\n— Latermark iOS ile gönderildi',
    );
  });

  test('imza kapalıyken metin tam olarak notun kendisidir', () {
    expect(shareMessage(body: 'Kombi bakımı'), 'Kombi bakımı');
  });

  test('notun baştaki ve sondaki boşlukları kırpılır', () {
    expect(shareMessage(body: '  Fiş  '), 'Fiş');
  });

  test('ne not ne imza varsa metin hiç gönderilmez', () {
    expect(shareMessage(body: ''), isNull);
    expect(shareMessage(body: '   ', signature: '  '), isNull);
  });

  test('notsuz karede imza tek başına gider', () {
    // Ayar açıkken beklenen davranış bu: kare paylaşılıyor, mesajın metni de
    // yalnızca imza oluyor.
    expect(
      shareMessage(body: '', signature: 'Latermark Android ile gönderildi'),
      '— Latermark Android ile gönderildi',
    );
  });
}
