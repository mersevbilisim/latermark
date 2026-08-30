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
  turnOff('latermark.reminder.turn_off'),
  tomorrow('latermark.reminder.tomorrow'),
  nextWeek('latermark.reminder.next_week');

  const ReminderAction(this.id);

  final String id;

  /// Ertelemenin kaç gün ittiği. [done] ve [turnOff] ertelemiyor.
  int? get snoozeDays => switch (this) {
    ReminderAction.done => null,
    ReminderAction.turnOff => null,
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
///
/// Erteleme artık bir çıpayı geriye kaydırmıyor; hedef tarihi doğrudan yazıyor.
/// Kayıt zaten mutlak bir an tuttuğu için "sıradaki oluşum hedefe düşsün diye
/// başlangıcı bir aralık geri al" oyununa gerek kalmadı.
ReminderChoice? reminderOutcomeFor({
  required ReminderAction action,
  required ReminderChoice reminder,
  required DateTime now,
  DateTime? firedAt,
}) {
  if (!reminder.isOn) return null;

  // "Bildirimleri kapat" tek bir oluşumu değil, notun hatırlatma tercihini
  // kapatır. Tek atış/tekrar ayrımı bu eylem için anlamsızdır.
  if (action == ReminderAction.turnOff) return const ReminderChoice.off();

  final snoozeDays = action.snoozeDays;
  if (snoozeDays == null) {
    // "Tamam". Tekrarlayan bir hatırlatmada bu **oluşum** kapanır, dizi sürer:
    // sıradaki halka bir aralık sonrasına düşer. Tek atışlıkta ise geriye
    // kapatmaktan başka bir anlam kalmıyor.
    //
    // Not hiçbir durumda silinmiyor. Uygulamanın "tamamlandı" diye bir kaydı
    // yok; olan tek şey hatırlatmanın kendisi.
    // Yinelenen kayıtta çıpaya **dokunulmuyor**: dizi zaten çıpadan türüyor ve
    // sıradaki halka kendiliğinden geliyor. Çıpayı "şimdi + bir aralık"a
    // taşımak, ritmi kullanıcının cevap verdiği saate göre yeniden fazlardı —
    // ayın 1'inde 09:00'a kurulmuş aylık bir hatırlatma, 14:00'te "Tamam"
    // denince gelecek ay 14:00'e kayardı.
    return reminder.repeats ? reminder : const ReminderChoice.off();
  }

  final base = firedAt == null || now.difference(firedAt) > _staleNotification
      ? now
      : firedAt;

  // Hedef takvimle hesaplanıyor, `Duration` ile değil: yaz saati geçişinde
  // 24 saat eklemek duvar saatini bir saat kaydırırdı.
  var target = shiftLocalCalendarDays(base, snoozeDays);
  // Kullanıcı bildirime saatler sonra cevap vermiş olabilir; hedef geçmişte
  // kalıyorsa aynı saati koruyarak ileri sarılır.
  while (!target.isAfter(now)) {
    target = shiftLocalCalendarDays(target, snoozeDays);
  }

  // Kullanıcının seçtiği ritim korunuyor: ertelenen yalnızca dizinin çıpası.
  return ReminderChoice(at: target, cadence: reminder.cadence);
}
