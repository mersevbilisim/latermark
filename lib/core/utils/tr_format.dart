import 'package:intl/intl.dart';

/// Türkçe tarih/saat metinleri. Arayüzde elle string birleştirme yapılmaz.
abstract final class TrFormat {
  static const _locale = 'tr_TR';

  /// Türkçe farkındalıklı büyük harf.
  ///
  /// Dart'ın [String.toUpperCase] metodu Unicode'un yerelden bağımsız
  /// kurallarını uygular ve noktalı `i` harfini `I` yapar: "Haziran" →
  /// "HAZIRAN", "Otomatik" → "OTOMATIK". Küçük kapitel kullanan her yerde
  /// bunun yerine bu metot çağrılmalı.
  static String upper(String value) =>
      value.replaceAll('i', 'İ').toUpperCase();

  static final _time = DateFormat('HH:mm', _locale);
  static final _dayMonth = DateFormat('d MMMM', _locale);
  static final _dayMonthYear = DateFormat('d MMMM yyyy', _locale);
  static final _weekday = DateFormat('EEEE', _locale);

  /// `14:32`
  static String time(DateTime at) => _time.format(at);

  /// `6 Ağustos 2026 · 14:32`
  static String stamp(DateTime at) =>
      '${_dayMonthYear.format(at)} · ${_time.format(at)}';

  /// Akıştaki gün ayıracı: `BUGÜN`, `DÜN`, `PAZARTESİ`, `6 AĞUSTOS`.
  static String dayHeader(DateTime at, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final day = _startOfDay(at);
    final diff = today.difference(day).inDays;

    final label = switch (diff) {
      0 => 'Bugün',
      1 => 'Dün',
      < 7 => _weekday.format(at),
      _ when at.year == today.year => _dayMonth.format(at),
      _ => _dayMonthYear.format(at),
    };
    return upper(label);
  }

  /// Kart üstündeki göreli zaman: `az önce`, `12 dk`, `3 sa`, `dün`.
  static String relative(DateTime at, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final elapsed = reference.difference(at);

    if (elapsed.inSeconds < 60) return 'az önce';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} dk';
    if (elapsed.inHours < 24) return '${elapsed.inHours} sa';
    if (elapsed.inDays == 1) return 'dün';
    if (elapsed.inDays < 7) return '${elapsed.inDays} gün';
    return _dayMonth.format(at);
  }

  /// Silinmeye kalan süre. Kısa biçim rozetlerde kullanılır: `2g`, `5sa`, `9dk`.
  static String remainingShort(DateTime expiresAt, {DateTime? now}) {
    final left = expiresAt.difference(now ?? DateTime.now());
    if (left.isNegative) return 'şimdi';
    if (left.inDays >= 1) return '${left.inDays}g';
    if (left.inHours >= 1) return '${left.inHours}sa';
    if (left.inMinutes >= 1) return '${left.inMinutes}dk';
    return '<1dk';
  }

  /// Detay ekranındaki uzun biçim: `2 gün 4 saat sonra silinecek`.
  static String remainingLong(DateTime expiresAt, {DateTime? now}) {
    final left = expiresAt.difference(now ?? DateTime.now());
    if (left.isNegative) return 'Birazdan silinecek';

    if (left.inDays >= 1) {
      final hours = left.inHours % 24;
      final tail = hours > 0 ? ' $hours saat' : '';
      return '${left.inDays} gün$tail sonra silinecek';
    }
    if (left.inHours >= 1) {
      final minutes = left.inMinutes % 60;
      final tail = minutes > 0 ? ' $minutes dakika' : '';
      return '${left.inHours} saat$tail sonra silinecek';
    }
    return '${left.inMinutes} dakika sonra silinecek';
  }

  /// `12 not` / `1 not`
  static String noteCount(int count) => '$count not';

  static DateTime _startOfDay(DateTime at) => DateTime(at.year, at.month, at.day);
}
