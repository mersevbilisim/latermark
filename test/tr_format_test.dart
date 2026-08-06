import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:not_app/core/utils/tr_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final now = DateTime(2026, 8, 6, 14, 32);

  group('dayHeader', () {
    test('bugün ve dün adlandırılır', () {
      expect(TrFormat.dayHeader(now, now: now), 'BUGÜN');
      expect(
        TrFormat.dayHeader(DateTime(2026, 8, 5, 23, 59), now: now),
        'DÜN',
      );
    });

    test('son bir hafta gün adıyla gösterilir', () {
      expect(TrFormat.dayHeader(DateTime(2026, 8, 3), now: now), 'PAZARTESİ');
    });

    test('daha eskiler tarihe döner, farklı yılda yıl eklenir', () {
      expect(TrFormat.dayHeader(DateTime(2026, 6, 1), now: now), '1 HAZİRAN');
      expect(
        TrFormat.dayHeader(DateTime(2025, 6, 1), now: now),
        '1 HAZİRAN 2025',
      );
    });
  });

  group('kalan süre', () {
    test('rozet biçimi en büyük birime yuvarlar', () {
      expect(
        TrFormat.remainingShort(now.add(const Duration(days: 2, hours: 5)), now: now),
        '2g',
      );
      expect(
        TrFormat.remainingShort(now.add(const Duration(hours: 5)), now: now),
        '5sa',
      );
      expect(
        TrFormat.remainingShort(now.add(const Duration(minutes: 9)), now: now),
        '9dk',
      );
      expect(
        TrFormat.remainingShort(now.add(const Duration(seconds: 20)), now: now),
        '<1dk',
      );
    });

    test('süresi geçmiş kayıt için "şimdi" döner', () {
      expect(
        TrFormat.remainingShort(now.subtract(const Duration(hours: 1)), now: now),
        'şimdi',
      );
    });

    test('uzun biçim iki birim gösterir', () {
      expect(
        TrFormat.remainingLong(now.add(const Duration(days: 2, hours: 4)), now: now),
        '2 gün 4 saat sonra silinecek',
      );
      expect(
        TrFormat.remainingLong(now.add(const Duration(days: 3)), now: now),
        '3 gün sonra silinecek',
      );
      expect(
        TrFormat.remainingLong(now.add(const Duration(hours: 1, minutes: 30)), now: now),
        '1 saat 30 dakika sonra silinecek',
      );
    });
  });

  group('relative', () {
    test('eşiklere göre kısalır', () {
      expect(TrFormat.relative(now.subtract(const Duration(seconds: 5)), now: now), 'az önce');
      expect(TrFormat.relative(now.subtract(const Duration(minutes: 12)), now: now), '12 dk');
      expect(TrFormat.relative(now.subtract(const Duration(hours: 3)), now: now), '3 sa');
      expect(TrFormat.relative(now.subtract(const Duration(days: 1)), now: now), 'dün');
    });
  });

  test('stamp tarih ve saati birlikte verir', () {
    expect(TrFormat.stamp(now), '6 Ağustos 2026 · 14:32');
  });
}
