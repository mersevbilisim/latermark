/// Bildirimin üzerindeki düğmelerin not üzerinde ne yaptığı.
///
/// Hesap burada, saf fonksiyonlarda duruyor: eylem arka plan isolate'inde
/// işleniyor ve orada bir veritabanı ya da bildirim eklentisi kurmadan
/// doğrulanabilir olması gerekiyor.
library;

import 'note_reminder.dart';

/// Bildirimde görünen düğmeler.
///
/// [id] işletim sistemine verilen eylem kimliği. Kalıcıdır: tepside bekleyen
/// eski bir bildirim de bu kimlikle geri döner, dolayısıyla değiştirmek
/// kullanıcının dokunduğu düğmeyi tanınmaz yapar.
enum ReminderAction {
  done('latermark.reminder.done'),
  tomorrow('latermark.reminder.tomorrow'),
  nextWeek('latermark.reminder.next_week');

  const ReminderAction(this.id);

  final String id;

  /// Ertelemenin kaç gün ittiği. [done] ertelemiyor.
  int? get snoozeDays => switch (this) {
    ReminderAction.done => null,
    ReminderAction.tomorrow => 1,
    ReminderAction.nextWeek => 7,
  };

  static ReminderAction? fromId(String? id) {
    if (id == null) return null;
    for (final action in ReminderAction.values) {
      if (action.id == id) return action;
    }
    return null;
  }
}

/// Bir eylemin nota yazılacak yeni hatırlatma durumu.
///
/// Üç alanın üçü de `notes` tablosunda zaten var; eylemler yeni bir sütun
/// gerektirmiyor. "Sıradaki hatırlatma ne zaman" sorusu bu üçlüden
/// hesaplanıyor ([reminderOccurrences]), dolayısıyla ertelemek de yeni bir
/// tarih yazmak değil, **çıpayı kaydırmak** demek.
final class ReminderOutcome {
  const ReminderOutcome({
    required this.remindAfterDays,
    required this.anchorAt,
    required this.repeats,
  });

  final int remindAfterDays;
  final DateTime? anchorAt;
  final bool repeats;

  bool get cleared => remindAfterDays <= 0;

  @override
  bool operator ==(Object other) =>
      other is ReminderOutcome &&
      other.remindAfterDays == remindAfterDays &&
      other.anchorAt == anchorAt &&
      other.repeats == repeats;

  @override
  int get hashCode => Object.hash(remindAfterDays, anchorAt, repeats);

  @override
  String toString() =>
      'ReminderOutcome($remindAfterDays gün, çıpa: $anchorAt, '
      'tekrar: $repeats)';
}

/// Çok eski bir bildirime verilen cevap, "aynı saatte" sözünü anlamsız kılar.
///
/// Kullanıcı iki ay önceki bir satırı bugün erteliyorsa referans o günün saati
/// değil, şu an olmalı; aksi hâlde hedefi bulmak için iki ay ileri sarmak
/// gerekirdi.
const _staleNotification = Duration(days: 30);

/// Bir bildirim düğmesinin nota bıraktığı yeni durum.
///
/// [firedAt] bildirimin temsil ettiği oluşum anı — payload'dan okunur ve
/// "ertesi gün aynı saat" sözünü tutmayı sağlar. Bilinmiyorsa [now] kullanılır.
///
/// Hatırlatması olmayan bir not için `null` döner: eylem yapacak bir şey yok.
ReminderOutcome? reminderOutcomeFor({
  required ReminderAction action,
  required int remindAfterDays,
  required bool repeats,
  required DateTime anchorAt,
  required DateTime now,
  DateTime? firedAt,
}) {
  if (remindAfterDays <= 0) return null;

  final snoozeDays = action.snoozeDays;
  if (snoozeDays == null) {
    // "Tamam". Tekrarlayan bir hatırlatmada bu **oluşum** kapanır, dizi
    // sürer: çıpa şimdiye alınınca sıradaki oluşum bir aralık sonrasına
    // düşer. Tek atışlıkta ise geriye kapatmaktan başka bir anlam kalmıyor.
    //
    // Not hiçbir durumda silinmiyor. Uygulamanın "tamamlandı" diye bir kaydı
    // yok; olan tek şey hatırlatmanın kendisi.
    return repeats
        ? ReminderOutcome(
            remindAfterDays: remindAfterDays,
            anchorAt: now,
            repeats: true,
          )
        : const ReminderOutcome(
            remindAfterDays: 0,
            anchorAt: null,
            repeats: false,
          );
  }

  final base = firedAt == null || now.difference(firedAt) > _staleNotification
      ? now
      : firedAt;

  // Hedef takvimle hesaplanıyor, `Duration` ile değil: yaz saati geçişinde 24
  // saat eklemek duvar saatini bir saat kaydırırdı, oysa söz verilen şey
  // "ertesi gün **aynı saat**".
  var target = shiftLocalCalendarDays(base, snoozeDays);
  // Kullanıcı bildirime saatler sonra cevap vermiş olabilir; hedef geçmişte
  // kalıyorsa aynı saati koruyarak ileri sarılır.
  while (!target.isAfter(now)) {
    target = shiftLocalCalendarDays(target, snoozeDays);
  }

  // Çıpa, hedeften bir aralık geriye konuyor: `reminderOccurrences` çıpaya
  // aralığın katlarını eklediği için sıradaki oluşum tam olarak hedefe düşer
  // ve kullanıcının seçtiği aralık ("30 günde bir") bozulmadan kalır.
  return ReminderOutcome(
    remindAfterDays: remindAfterDays,
    anchorAt: shiftLocalCalendarDays(target, -remindAfterDays),
    repeats: repeats,
  );
}
