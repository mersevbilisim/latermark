import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Tarih, saat ve süre metinleri.
///
/// Eskiden burada sabit Türkçe biçimler vardı. Uygulama çok dilli olunca hem
/// *kalıplar* (14:32 · 6 Ağustos vs. 2:32 PM · August 6) hem de *sözcükler*
/// dile göre değişmek zorunda: kalıpları [DateFormat] yürürlükteki yerelle
/// çözüyor, sözcükler ARB'den geliyor.
///
/// [L10n] üzerine uzantı olarak durur; böylece çağrı yerinde
/// `context.l10n.time(note.createdAt)` yazmak yetiyor ve dil ayrıca
/// taşınmıyor — zaten [L10n]'in içinde.
extension AppFormat on L10n {
  /// Yerele göre saat: `14:32` ya da `2:32 PM`.
  String time(DateTime at) => DateFormat.jm(localeName).format(at);

  /// Yerele göre takvim tarihi: `8 Ağustos 2026` ya da `August 8, 2026`.
  String calendarDate(DateTime at) => DateFormat.yMMMMd(localeName).format(at);

  /// `6 Ağustos 2026 · 14:32`
  String stamp(DateTime at) => '${calendarDate(at)} · ${time(at)}';

  /// Bir hatırlatmanın künyede görünen değeri.
  ///
  /// Tek atışta yalnızca an yazılır — tekrar eklenmeden önceki metnin aynısı.
  /// Tekrarlıda aralık da söylenir: yoksa `6 Ağustos 2026 · 14:32` gören
  /// kullanıcı bunu son hatırlatma sanardı, oysa arkası geliyor.
  ///
  /// Kart ile detay aynı cümleyi kurmak zorunda; iki yerde ayrı
  /// biçimlendirmek, birini değiştirip diğerini unutmanın kısa yolu.
  String reminderValue({
    required DateTime at,
    required bool repeats,
    required int everyDays,
  }) => repeats && everyDays > 0
      ? reminderRepeatingValue(everyDays, stamp(at))
      : stamp(at);

  /// Akıştaki gün ayıracı: `BUGÜN`, `DÜN`, `PAZARTESİ`, `6 AĞUSTOS`.
  String dayHeader(DateTime at, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final day = _startOfDay(at);
    final diff = today.difference(day).inDays;

    final label = switch (diff) {
      0 => dayToday,
      1 => dayYesterday,
      < 7 => DateFormat.EEEE(localeName).format(at),
      _ when at.year == today.year => DateFormat.MMMMd(localeName).format(at),
      _ => DateFormat.yMMMMd(localeName).format(at),
    };
    return upper(label);
  }

  /// Göreli zaman: `az önce`, `12 dk`, `3 sa`, `dün`.
  String relative(DateTime at, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final elapsed = reference.difference(at);

    if (elapsed.inSeconds < 60) return relativeJustNow;
    if (elapsed.inMinutes < 60) return relativeMinutes(elapsed.inMinutes);
    if (elapsed.inHours < 24) return relativeHours(elapsed.inHours);
    if (elapsed.inDays == 1) return relativeYesterday;
    if (elapsed.inDays < 7) return relativeDays(elapsed.inDays);
    return DateFormat.MMMMd(localeName).format(at);
  }

  /// Silinmeye kalan sürenin kısa biçimi: `2g`, `5sa`, `9dk`.
  String remainingShort(DateTime expiresAt, {DateTime? now}) {
    final left = expiresAt.difference(now ?? DateTime.now());
    if (left.isNegative) return remainingNow;
    if (left.inDays >= 1) return remainingShortDays(left.inDays);
    if (left.inHours >= 1) return remainingShortHours(left.inHours);
    if (left.inMinutes >= 1) return remainingShortMinutes(left.inMinutes);
    return remainingShortLessThanMinute;
  }

  /// Uzun biçim: `2 gün 4 saat sonra silinecek`.
  String remainingLong(DateTime expiresAt, {DateTime? now}) {
    final left = expiresAt.difference(now ?? DateTime.now());
    if (left.isNegative) return remainingSoon;

    if (left.inDays >= 1) {
      final hours = left.inHours % 24;
      return hours > 0
          ? remainingLongDaysHours(left.inDays, hours)
          : remainingLongDays(left.inDays);
    }
    if (left.inHours >= 1) {
      final minutes = left.inMinutes % 60;
      return minutes > 0
          ? remainingLongHoursMinutes(left.inHours, minutes)
          : remainingLongHours(left.inHours);
    }
    return remainingLongMinutes(left.inMinutes);
  }

  /// Yerele duyarlı büyük harf.
  ///
  /// Dart'ın [String.toUpperCase] metodu yerelden bağımsızdır ve Türkçe'de
  /// noktalı `i` harfini `I` yapar: "Haziran" → "HAZIRAN". Türkçe'de bu elle
  /// düzeltilir; diğer dillerde standart davranış zaten doğru.
  String upper(String value) => localeName.startsWith('tr')
      ? value.replaceAll('i', 'İ').toUpperCase()
      : value.toUpperCase();

  static DateTime _startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);
}
