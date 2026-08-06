import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/features/notes/domain/retention.dart';

void main() {
  group('Retention', () {
    test('kapalıyken son kullanma tarihi üretmez', () {
      expect(Retention.off.duration, isNull);
      expect(Retention.off.isTimed, isFalse);
      expect(Retention.off.expiryFrom(DateTime(2026, 8, 6)), isNull);
    });

    test('3 gün ve 1 hafta oluşturma anına eklenir', () {
      final created = DateTime(2026, 8, 6, 14, 32);

      expect(
        Retention.threeDays.expiryFrom(created),
        DateTime(2026, 8, 9, 14, 32),
      );
      expect(
        Retention.oneWeek.expiryFrom(created),
        DateTime(2026, 8, 13, 14, 32),
      );
    });

    test('veritabanı sırası değişmemiş', () {
      // Değer `index` olarak saklandığı için bu sıra kayıtların anlamıdır.
      expect(Retention.values.map((r) => r.name), [
        'off',
        'threeDays',
        'oneWeek',
      ]);
    });
  });
}
