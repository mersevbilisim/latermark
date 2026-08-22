import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/reminder_action.dart';
import 'package:latermark/features/reminders/reminder_service.dart';

void main() {
  // Bildirim 8 Ağustos saat 09:00'da çaldı, kullanıcı bir dakika sonra cevap
  // verdi. Gerçek hayattaki yaygın durum bu.
  final firedAt = DateTime(2026, 8, 8, 9);
  final now = DateTime(2026, 8, 8, 9, 1);

  /// Ertelemenin gerçekten hangi ana denk geldiğini, kaydın kendisine değil
  /// programı kuran hesaba sorarak doğrular. Asıl önemli olan bu: çıpa bir
  /// ara değer, kullanıcının gördüğü şey sıradaki oluşum.
  DateTime? nextOccurrence(ReminderOutcome outcome, {DateTime? at}) =>
      pendingReminderAt(
        anchorAt: outcome.anchorAt!,
        remindAfterDays: outcome.remindAfterDays,
        repeats: outcome.repeats,
        now: at ?? now,
      );

  group('erteleme', () {
    test('yarın, bildirimin çaldığı saate kurulur', () {
      final outcome = reminderOutcomeFor(
        action: ReminderAction.tomorrow,
        remindAfterDays: 30,
        repeats: false,
        anchorAt: DateTime(2026, 7, 9, 9),
        now: now,
        firedAt: firedAt,
      )!;

      expect(nextOccurrence(outcome), DateTime(2026, 8, 9, 9));
    });

    test('haftaya, yedi gün sonrasına aynı saate kurulur', () {
      final outcome = reminderOutcomeFor(
        action: ReminderAction.nextWeek,
        remindAfterDays: 30,
        repeats: false,
        anchorAt: DateTime(2026, 7, 9, 9),
        now: now,
        firedAt: firedAt,
      )!;

      expect(nextOccurrence(outcome), DateTime(2026, 8, 15, 9));
    });

    test('kullanıcının seçtiği aralık korunur', () {
      // Ertelemek "her 30 günde bir"i "her 1 günde bir" yapmamalı. Aralık
      // bozulsaydı tekrarlayan bir hatırlatma ilk ertelemede sessizce günlük
      // bir alarma dönüşürdü.
      final outcome = reminderOutcomeFor(
        action: ReminderAction.tomorrow,
        remindAfterDays: 30,
        repeats: true,
        anchorAt: DateTime(2026, 7, 9, 9),
        now: now,
        firedAt: firedAt,
      )!;

      expect(outcome.remindAfterDays, 30);
      expect(outcome.repeats, isTrue);
      // Ertelenen oluşumdan sonrası yine 30 günlük aralıkla sürer.
      expect(nextOccurrence(outcome), DateTime(2026, 8, 9, 9));
      expect(
        nextOccurrence(outcome, at: DateTime(2026, 8, 9, 9, 1)),
        DateTime(2026, 9, 8, 9),
      );
    });

    test('geç cevap verilse de saat korunur, an geleceğe taşınır', () {
      // Kullanıcı bildirimi üç gün sonra fark etti. "Yarın" o hâlde geçmiş
      // bir an olurdu; gün ileri sarılır ama saat aynı kalır.
      final outcome = reminderOutcomeFor(
        action: ReminderAction.tomorrow,
        remindAfterDays: 30,
        repeats: false,
        anchorAt: DateTime(2026, 7, 9, 9),
        now: DateTime(2026, 8, 11, 14, 30),
        firedAt: firedAt,
      )!;

      expect(
        nextOccurrence(outcome, at: DateTime(2026, 8, 11, 14, 30)),
        DateTime(2026, 8, 12, 9),
      );
    });

    test('çok eski bir bildirimde referans şimdiki an olur', () {
      // İki ay önceki bir satıra bugün basılıyorsa "aynı saat" sözünün
      // anlamı kalmıyor; ileri sarmak yerine şimdiden sayılır.
      final outcome = reminderOutcomeFor(
        action: ReminderAction.nextWeek,
        remindAfterDays: 30,
        repeats: false,
        anchorAt: DateTime(2026, 5, 1, 9),
        now: DateTime(2026, 8, 8, 16, 20),
        firedAt: DateTime(2026, 6, 1, 9),
      )!;

      expect(
        nextOccurrence(outcome, at: DateTime(2026, 8, 8, 16, 20)),
        DateTime(2026, 8, 15, 16, 20),
      );
    });

    test('bildirimin anı bilinmiyorsa şimdiden sayılır', () {
      final outcome = reminderOutcomeFor(
        action: ReminderAction.tomorrow,
        remindAfterDays: 3,
        repeats: false,
        anchorAt: DateTime(2026, 8, 5, 9),
        now: now,
      )!;

      expect(nextOccurrence(outcome), DateTime(2026, 8, 9, 9, 1));
    });
  });

  group('tamam', () {
    test('tek atışlık hatırlatmayı kapatır, notu bırakır', () {
      final outcome = reminderOutcomeFor(
        action: ReminderAction.done,
        remindAfterDays: 30,
        repeats: false,
        anchorAt: DateTime(2026, 7, 9, 9),
        now: now,
        firedAt: firedAt,
      )!;

      expect(outcome.cleared, isTrue);
      expect(outcome.remindAfterDays, 0);
      expect(outcome.anchorAt, isNull);
      expect(outcome.repeats, isFalse);
    });

    test('tekrarlayan hatırlatmada yalnızca bu oluşumu kapatır', () {
      // "Her 30 günde bir kombiyi kontrol et" için "Tamam", diziyi bitirmek
      // değil bu turu kapatmak demek. Kapatsaydı kullanıcı bir daha hiç
      // hatırlatılmazdı ve bunu ancak aylar sonra fark ederdi.
      final outcome = reminderOutcomeFor(
        action: ReminderAction.done,
        remindAfterDays: 30,
        repeats: true,
        anchorAt: DateTime(2026, 7, 9, 9),
        now: now,
        firedAt: firedAt,
      )!;

      expect(outcome.cleared, isFalse);
      expect(outcome.remindAfterDays, 30);
      expect(outcome.repeats, isTrue);
      expect(nextOccurrence(outcome), DateTime(2026, 9, 7, 9, 1));
    });
  });

  group('bildirimleri kapat', () {
    for (final repeats in [false, true]) {
      test(
        '${repeats ? 'tekrarlı' : 'tek atışlı'} hatırlatmanın bütün alanlarını temizler',
        () {
          final outcome = reminderOutcomeFor(
            action: ReminderAction.turnOff,
            remindAfterDays: 30,
            repeats: repeats,
            anchorAt: DateTime(2026, 7, 9, 9),
            now: now,
            firedAt: firedAt,
          )!;

          expect(outcome.cleared, isTrue);
          expect(outcome.remindAfterDays, 0);
          expect(outcome.anchorAt, isNull);
          expect(outcome.repeats, isFalse);
        },
      );
    }
  });

  test('hatırlatması olmayan notta yapacak iş yok', () {
    for (final action in ReminderAction.values) {
      expect(
        reminderOutcomeFor(
          action: action,
          remindAfterDays: 0,
          repeats: false,
          anchorAt: DateTime(2026, 7, 9, 9),
          now: now,
        ),
        isNull,
        reason: '$action',
      );
    }
  });

  group('eylem kimlikleri', () {
    test('bildirim kapatma kimliği kalıcıdır', () {
      expect(ReminderAction.turnOff.id, 'latermark.reminder.turn_off');
    });

    test('tepside bekleyen bir bildirimden geri okunur', () {
      for (final action in ReminderAction.values) {
        expect(ReminderAction.fromId(action.id), action);
      }
    });

    test('tanınmayan kimlik yok sayılır', () {
      expect(ReminderAction.fromId(null), isNull);
      expect(
        ReminderAction.fromId('com.apple.UNNotificationDefaultAction'),
        isNull,
      );
    });
  });

  group("payload'dan bildirimin çaldığı an", () {
    test('tek atışta doğrudan okunur', () {
      final at = DateTime(2026, 8, 8, 9);
      final payload = 'note/7/v3/at/${at.toUtc().millisecondsSinceEpoch}';
      expect(reminderFiredAt(payload, now: now), at);
    });

    test('süresiz tekrarda geçmişteki son oluşum hesaplanır', () {
      final anchor = DateTime(2026, 5, 10, 9);
      final payload =
          'note/7/v3/every/30/${anchor.toUtc().millisecondsSinceEpoch}';
      // 10 Mayıs + 90 gün = 8 Ağustos; sıradaki oluşum henüz gelmedi.
      expect(
        reminderFiredAt(payload, now: DateTime(2026, 8, 8, 9, 1)),
        DateTime(2026, 8, 8, 9),
      );
    });

    test('debug dakika tekrarında geçmişteki son oluşum hesaplanır', () {
      final anchor = DateTime(2026, 8, 8, 9);
      final payload =
          'note/7/v3/every_minutes/3/'
          '${anchor.toUtc().millisecondsSinceEpoch}';
      expect(
        reminderFiredAt(payload, now: DateTime(2026, 8, 8, 9, 7, 30)),
        DateTime(2026, 8, 8, 9, 6),
      );
    });

    test('okunamayan ya da yabancı payload null döner', () {
      expect(reminderFiredAt(null, now: now), isNull);
      expect(reminderFiredAt('note/7', now: now), isNull);
      expect(reminderFiredAt('baska/7/v3/at/123', now: now), isNull);
      expect(reminderFiredAt('note/7/v3/at/abc', now: now), isNull);
    });
  });
}
