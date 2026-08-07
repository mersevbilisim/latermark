import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/features/notes/domain/retention.dart';

void main() {
  group('RetentionChoice', () {
    test('kapalıyken son kullanma tarihi üretmez', () {
      const choice = RetentionChoice.off();
      expect(choice.duration, isNull);
      expect(choice.isTimed, isFalse);
      expect(choice.expiryFrom(DateTime(2026, 8, 6)), isNull);
    });

    test('3 gün ve 1 hafta oluşturma anına eklenir', () {
      final created = DateTime(2026, 8, 6, 14, 32);

      expect(
        const RetentionChoice(Retention.threeDays).expiryFrom(created),
        DateTime(2026, 8, 9, 14, 32),
      );
      expect(
        const RetentionChoice(Retention.oneWeek).expiryFrom(created),
        DateTime(2026, 8, 13, 14, 32),
      );
    });

    test('özel süre dakikadan hesaplanır', () {
      final created = DateTime(2026, 8, 6, 14, 32);

      // Park senaryosu: hazır seçenekler bunun için fazla kaba.
      expect(
        RetentionChoice.custom(360).expiryFrom(created),
        DateTime(2026, 8, 6, 20, 32),
      );
      expect(
        RetentionChoice.custom(1440 * 2).expiryFrom(created),
        DateTime(2026, 8, 8, 14, 32),
      );
    });

    test('özel seçilip süre verilmediyse süresiz sayılır', () {
      // Yarım kalmış bir seçim, notu kazara silinecek hâle getirmemeli.
      const choice = RetentionChoice(Retention.custom);
      expect(choice.duration, isNull);
      expect(choice.isTimed, isFalse);
    });

    test('veritabanı sırası değişmemiş', () {
      // Değer `index` olarak saklandığı için bu sıra kayıtların anlamıdır.
      // Yeni seçenekler yalnızca sona eklenebilir.
      expect(Retention.values.map((r) => r.name), [
        'off',
        'threeDays',
        'oneWeek',
        'custom',
      ]);
    });
  });
}
