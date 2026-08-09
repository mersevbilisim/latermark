import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/core/utils/app_format.dart';
import 'package:latermark/l10n/app_localizations.dart';

/// Biçimlendirme artık yürürlükteki dile bağlı; testler de bir [L10n] örneği
/// üzerinden çalışıyor. Türkçe seçilmesinin sebebi ARB'lerin şu an Türkçe
/// olması — çeviriler geldiğinde buraya diğer diller için de vaka eklenmeli.
void main() {
  late L10n tr;

  setUpAll(() async {
    await initializeDateFormatting('tr');
    tr = await L10n.delegate.load(const Locale('tr'));
  });

  final now = DateTime(2026, 8, 6, 14, 32);

  group('dayHeader', () {
    test('bugün ve dün adlandırılır', () {
      expect(tr.dayHeader(now, now: now), 'BUGÜN');
      expect(tr.dayHeader(DateTime(2026, 8, 5, 23, 59), now: now), 'DÜN');
    });

    test('son bir hafta gün adıyla gösterilir', () {
      expect(tr.dayHeader(DateTime(2026, 8, 3), now: now), 'PAZARTESİ');
    });

    test('daha eskiler tarihe döner, farklı yılda yıl eklenir', () {
      expect(tr.dayHeader(DateTime(2026, 6, 1), now: now), '1 HAZİRAN');
      expect(tr.dayHeader(DateTime(2025, 6, 1), now: now), '1 HAZİRAN 2025');
    });
  });

  group('kalan süre', () {
    test('rozet biçimi en büyük birime yuvarlar', () {
      expect(
        tr.remainingShort(now.add(const Duration(days: 2, hours: 5)), now: now),
        '2g',
      );
      expect(
        tr.remainingShort(now.add(const Duration(hours: 5)), now: now),
        '5sa',
      );
      expect(
        tr.remainingShort(now.add(const Duration(minutes: 9)), now: now),
        '9dk',
      );
      expect(
        tr.remainingShort(now.add(const Duration(seconds: 20)), now: now),
        '<1dk',
      );
    });

    test('süresi geçmiş kayıt için "şimdi" döner', () {
      expect(
        tr.remainingShort(now.subtract(const Duration(hours: 1)), now: now),
        'şimdi',
      );
    });

    test('uzun biçim iki birim gösterir', () {
      expect(
        tr.remainingLong(now.add(const Duration(days: 2, hours: 4)), now: now),
        '2 gün 4 saat sonra silinecek',
      );
      expect(
        tr.remainingLong(now.add(const Duration(days: 3)), now: now),
        '3 gün sonra silinecek',
      );
      expect(
        tr.remainingLong(
          now.add(const Duration(hours: 1, minutes: 30)),
          now: now,
        ),
        '1 saat 30 dakika sonra silinecek',
      );
    });
  });

  group('relative', () {
    test('eşiklere göre kısalır', () {
      expect(
        tr.relative(now.subtract(const Duration(seconds: 5)), now: now),
        'az önce',
      );
      expect(
        tr.relative(now.subtract(const Duration(minutes: 12)), now: now),
        '12 dk',
      );
      expect(
        tr.relative(now.subtract(const Duration(hours: 3)), now: now),
        '3 sa',
      );
      expect(
        tr.relative(now.subtract(const Duration(days: 1)), now: now),
        'dün',
      );
    });
  });

  test('upper yalnızca Türkçede noktalı i korur', () async {
    final en = await L10n.delegate.load(const Locale('en'));
    expect(tr.upper('Haziran'), 'HAZİRAN');
    expect(en.upper('title'), 'TITLE');
  });
}
