import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/features/paywall/domain/pro_limits.dart';

/// Sınır, para kazandıran yol olduğu kadar **kullanıcıyı kırabilecek** yol da;
/// davranışı testle sabitlenmeli.
void main() {
  group('yeni kayıt engeli', () {
    test('Pro kullanıcı hiçbir sayıda engellenmez', () {
      expect(ProLimits.blocksNewNote(0, isPro: true), isFalse);
      expect(ProLimits.blocksNewNote(999, isPro: true), isFalse);
    });

    test('ücretsizde sınırın altında serbest', () {
      expect(ProLimits.blocksNewNote(0, isPro: false), isFalse);
      expect(
        ProLimits.blocksNewNote(ProLimits.freeNotes - 1, isPro: false),
        isFalse,
      );
    });

    test('ücretsizde sınıra ulaşınca engellenir', () {
      expect(
        ProLimits.blocksNewNote(ProLimits.freeNotes, isPro: false),
        isTrue,
      );
    });

    test('silmek yer açar — engel kalıcı değil', () {
      // Sınır *aynı anda* tutulan kare sayısı üzerinden çalışır. Kümülatif
      // olsaydı burası da engelli dönerdi ve ücretsiz katman bir noktadan
      // sonra tamamen kullanılamaz hâle gelirdi.
      expect(
        ProLimits.blocksNewNote(ProLimits.freeNotes - 1, isPro: false),
        isFalse,
      );
    });
  });

  group('sayaç görünürlüğü', () {
    test('Pro kullanıcıda sayaç yok', () {
      expect(ProLimits.showsCounter(ProLimits.freeNotes, isPro: true), isFalse);
    });

    test('sınıra yaklaşınca görünür, uzakken görünmez', () {
      expect(ProLimits.showsCounter(0, isPro: false), isFalse);
      expect(
        ProLimits.showsCounter(ProLimits.freeNotes - 3, isPro: false),
        isTrue,
      );
      expect(
        ProLimits.showsCounter(ProLimits.freeNotes, isPro: false),
        isTrue,
      );
    });
  });
}
