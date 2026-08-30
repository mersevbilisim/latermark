import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';

void main() {
  final base = DateTime(2026, 8, 1, 12);
  final now = DateTime(2026, 8, 2, 12);

  /// Kaydın tuttuğu an: temel günden [days] gün sonrası, aynı saatte.
  DateTime day(int days) => shiftLocalCalendarDays(base, days);

  group('tek atışlık hatırlatma', () {
    test('gelecekteki hatırlatma anını üretir', () {
      expect(pendingReminderAt(remindAt: day(3), now: now), day(3));
    });

    test('geçmiş veya kapalı hatırlatmayı etkin saymaz', () {
      expect(pendingReminderAt(remindAt: null, now: now), isNull);
      expect(pendingReminderAt(remindAt: day(1), now: now), isNull);
    });

    test('tam oluşum anı geçmiş sayılır', () {
      expect(pendingReminderAt(remindAt: now, now: now), isNull);
    });

    test('not daha önce silinecekse hatırlatmayı etkin saymaz', () {
      expect(
        pendingReminderAt(
          remindAt: day(3),
          expiresAt: DateTime(2026, 8, 3, 12),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('tekrarlayan hatırlatma', () {
    test('ritim boyunca ardışık anlar üretir', () {
      expect(
        reminderOccurrences(
          remindAt: day(3),
          cadence: ReminderCadence.weekly,
          now: now,
          limit: 3,
        ),
        [
          DateTime(2026, 8, 4, 12),
          DateTime(2026, 8, 11, 12),
          DateTime(2026, 8, 18, 12),
        ],
      );
    });

    test('aylık ritim olmayan günü ayın sonuna kısar', () {
      // Hesap hep 31 Ocak çıpasından yapılır: Şubat'taki kısılma
      // Mart'ı kalıcı olarak 28'e kaydırmaz.
      expect(
        reminderOccurrences(
          remindAt: DateTime(2026, 1, 31, 9),
          cadence: ReminderCadence.monthly,
          now: DateTime(2026, 1, 1),
          limit: 3,
        ),
        [
          DateTime(2026, 1, 31, 9),
          DateTime(2026, 2, 28, 9),
          DateTime(2026, 3, 31, 9),
        ],
      );
    });

    test('yıllık ritimde 29 Şubat son geçerli güne kısılır', () {
      expect(
        reminderOccurrences(
          remindAt: DateTime(2028, 2, 29, 9),
          cadence: ReminderCadence.yearly,
          now: DateTime(2028, 3, 1),
          limit: 5,
        ),
        [
          DateTime(2029, 2, 28, 9),
          DateTime(2030, 2, 28, 9),
          DateTime(2031, 2, 28, 9),
          DateTime(2032, 2, 29, 9),
          DateTime(2033, 2, 28, 9),
        ],
      );
    });

    test('1 Ocak aylık ritmi her ayın 1’inde kalır', () {
      expect(
        reminderOccurrences(
          remindAt: DateTime(2027, 1, 1, 9),
          cadence: ReminderCadence.monthly,
          now: DateTime(2026, 12, 31),
          limit: 3,
        ),
        [
          DateTime(2027, 1, 1, 9),
          DateTime(2027, 2, 1, 9),
          DateTime(2027, 3, 1, 9),
        ],
      );
    });

    test('geçmişte kalan oluşumları aritmetikle atlar', () {
      expect(
        reminderOccurrences(
          remindAt: day(1),
          cadence: ReminderCadence.daily,
          now: DateTime(2026, 8, 10, 15),
          limit: 2,
        ),
        [DateTime(2026, 8, 11, 12), DateTime(2026, 8, 12, 12)],
      );
    });

    test('saklanan ilk halka gelecekteyse dizinin başı odur', () {
      expect(
        reminderOccurrences(
          remindAt: day(5),
          cadence: ReminderCadence.monthly,
          now: now,
          limit: 2,
        ),
        [DateTime(2026, 8, 6, 12), DateTime(2026, 9, 6, 12)],
      );
    });

    test('tam oluşum anını geçmiş sayar', () {
      expect(
        reminderOccurrences(
          remindAt: day(2),
          cadence: ReminderCadence.daily,
          now: DateTime(2026, 8, 5, 12),
        ),
        [DateTime(2026, 8, 6, 12)],
      );
    });

    test('silinme anından sonrasını planlamaz', () {
      expect(
        reminderOccurrences(
          remindAt: day(2),
          cadence: ReminderCadence.daily,
          expiresAt: DateTime(2026, 8, 6),
          now: now,
          limit: 60,
        ),
        [
          DateTime(2026, 8, 3, 12),
          DateTime(2026, 8, 4, 12),
          DateTime(2026, 8, 5, 12),
        ],
      );
    });

    test('pendingReminderAt sıradaki oluşumu verir', () {
      expect(
        pendingReminderAt(
          remindAt: day(1),
          cadence: ReminderCadence.daily,
          now: DateTime(2026, 8, 10, 15),
        ),
        DateTime(2026, 8, 11, 12),
      );
    });
  });

  group('takvim günü', () {
    test('saat farkı gün sayısını değiştirmez', () {
      expect(
        localCalendarDaysBetween(
          DateTime(2026, 8, 2, 23, 50),
          DateTime(2026, 8, 3, 0, 10),
        ),
        1,
      );
      expect(
        localCalendarDaysBetween(
          DateTime(2026, 8, 2, 0, 10),
          DateTime(2026, 8, 2, 23, 50),
        ),
        0,
      );
    });
  });

  group('bildirim kimlikleri', () {
    test('64 oluşumun tamamı nota geri çözülür', () {
      for (final noteId in [1, 7, 25, 4096]) {
        for (var occurrence = 0; occurrence < kOccurrenceSpan; occurrence++) {
          final id = reminderNotificationId(noteId, occurrence);
          expect(noteIdFromNotificationId(id), noteId);
        }
      }
    });

    test('komşu notların kimlik aralıkları çakışmaz', () {
      final first = {
        for (var i = 0; i < kOccurrenceSpan; i++) reminderNotificationId(12, i),
      };
      final second = {
        for (var i = 0; i < kOccurrenceSpan; i++) reminderNotificationId(13, i),
      };
      expect(first.intersection(second), isEmpty);
    });
  });

  group('program', () {
    ReminderRequest request(
      int id, {
      required DateTime at,
      ReminderCadence cadence = ReminderCadence.once,
      DateTime? expiresAt,
    }) => ReminderRequest(
      noteId: id,
      remindAt: at,
      cadence: cadence,
      expiresAt: expiresAt,
    );

    test('geçmişte kalmış tek atış programa girmez', () {
      final schedule = reminderSchedule(
        requests: [
          request(1, at: day(-2)),
          request(2, at: day(3)),
        ],
        now: now,
      );
      expect(schedule.map((item) => item.noteId), [2]);
    });

    test('aylık tekrar son-gün kuralı için kesin tarihler kullanır', () {
      final schedule = reminderSchedule(
        requests: [request(1, at: day(30), cadence: ReminderCadence.monthly)],
        now: now,
        budget: 3,
        maxPerNote: 3,
      );

      expect(schedule, hasLength(3));
      expect(schedule.every((item) => item.repeat == null), isTrue);
      expect(schedule.map((item) => item.at), [
        DateTime(2026, 8, 31, 12),
        DateTime(2026, 9, 30, 12),
        DateTime(2026, 10, 31, 12),
      ]);
    });

    test('normal yıllık ritim native tek kayıt kullanır', () {
      final schedule = reminderSchedule(
        requests: [request(1, at: day(365), cadence: ReminderCadence.yearly)],
        now: now,
      );
      expect(schedule, hasLength(1));
      expect(schedule.single.repeat, ReminderCadence.yearly);
    });

    test('29 Şubat yıllık ritmi kesin tarihler halinde kurulur', () {
      final schedule = reminderSchedule(
        requests: [
          request(
            1,
            at: DateTime(2028, 2, 29, 9),
            cadence: ReminderCadence.yearly,
          ),
        ],
        now: DateTime(2028, 1, 1),
        budget: 3,
        maxPerNote: 3,
      );

      expect(schedule.map((item) => item.at), [
        DateTime(2028, 2, 29, 9),
        DateTime(2029, 2, 28, 9),
        DateTime(2030, 2, 28, 9),
      ]);
      expect(schedule.every((item) => item.repeat == null), isTrue);
    });

    test('ayın 1–28’indeki aylık ritim native tek kayıt kullanır', () {
      final schedule = reminderSchedule(
        requests: [request(1, at: day(2), cadence: ReminderCadence.monthly)],
        now: now,
      );

      expect(schedule, hasLength(1));
      expect(schedule.single.repeat, ReminderCadence.monthly);
    });

    test('yakın günlük ve haftalık tekrar native tek kayıt kullanır', () {
      final daily = reminderSchedule(
        requests: [request(1, at: day(2), cadence: ReminderCadence.daily)],
        now: now,
      );
      final weekly = reminderSchedule(
        requests: [request(2, at: day(2), cadence: ReminderCadence.weekly)],
        now: now,
      );

      expect(daily.single.repeat, ReminderCadence.daily);
      expect(weekly.single.repeat, ReminderCadence.weekly);
    });

    test('gecikmeli native tekrar erken çalmak yerine kesin kurulur', () {
      final schedule = reminderSchedule(
        requests: [request(1, at: day(30), cadence: ReminderCadence.daily)],
        now: now,
        budget: 3,
        maxPerNote: 3,
      );

      expect(schedule.map((item) => item.at), [
        DateTime(2026, 8, 31, 12),
        DateTime(2026, 9, 1, 12),
        DateTime(2026, 9, 2, 12),
      ]);
      expect(schedule.every((item) => item.repeat == null), isTrue);
    });

    test('silinme tarihi olan tekrar kesin tek-atış dizisi üretir', () {
      // İşletim sistemi notun ne zaman gideceğini bilmiyor; sonsuz bir kayıt
      // silinmiş bir kare için çalmayı sürdürürdü.
      final schedule = reminderSchedule(
        requests: [
          request(
            9,
            at: day(3),
            cadence: ReminderCadence.daily,
            expiresAt: DateTime(2026, 8, 20),
          ),
        ],
        now: now,
        budget: 4,
      );

      expect(schedule, hasLength(4));
      expect(schedule.every((item) => item.repeat == null), isTrue);
      expect(schedule.map((item) => item.at), [
        DateTime(2026, 8, 4, 12),
        DateTime(2026, 8, 5, 12),
        DateTime(2026, 8, 6, 12),
        DateTime(2026, 8, 7, 12),
      ]);
    });

    test('kayan pencere ilerlerken oluşum kimliği sabit kalır', () {
      final requestValue = request(
        9,
        at: day(3),
        cadence: ReminderCadence.daily,
        expiresAt: DateTime(2027, 1, 1),
      );
      final first = reminderSchedule(
        requests: [requestValue],
        now: now,
        budget: 4,
      );
      final later = reminderSchedule(
        requests: [requestValue],
        now: DateTime(2026, 8, 5, 12),
        budget: 4,
      );

      final august7First = first.singleWhere(
        (item) => item.at == DateTime(2026, 8, 7, 12),
      );
      final august7Later = later.singleWhere(
        (item) => item.at == DateTime(2026, 8, 7, 12),
      );
      expect(august7Later.notificationId, august7First.notificationId);
    });

    test(
      'otomatik silinen tekrar yalnız silinmeye kadar tek atışlar üretir',
      () {
        final schedule = reminderSchedule(
          requests: [
            request(
              3,
              at: day(2),
              cadence: ReminderCadence.daily,
              expiresAt: DateTime(2026, 8, 6),
            ),
          ],
          now: now,
        );

        expect(schedule, hasLength(3));
        expect(schedule.every((item) => !item.repeatsIndefinitely), isTrue);
        expect(schedule.map((item) => item.at), [
          DateTime(2026, 8, 3, 12),
          DateTime(2026, 8, 4, 12),
          DateTime(2026, 8, 5, 12),
        ]);
      },
    );

    test('sonlu oluşum kimliği uygulama yeniden açılınca değişmez', () {
      final requestValue = request(
        3,
        at: day(1),
        cadence: ReminderCadence.daily,
        expiresAt: DateTime(2026, 10),
      );
      final first = reminderSchedule(
        requests: [requestValue],
        now: DateTime(2026, 8, 2, 12),
      );
      final later = reminderSchedule(
        requests: [requestValue],
        now: DateTime(2026, 8, 3, 12),
      );

      final august4First = first.singleWhere(
        (item) => item.at == DateTime(2026, 8, 4, 12),
      );
      final august4Later = later.singleWhere(
        (item) => item.at == DateTime(2026, 8, 4, 12),
      );
      expect(august4Later.notificationId, august4First.notificationId);
    });

    test('her not ikinci oluşumundan önce birincisini alır', () {
      final schedule = reminderSchedule(
        requests: [
          request(
            1,
            at: day(1),
            cadence: ReminderCadence.daily,
            expiresAt: DateTime(2026, 9),
          ),
          request(
            2,
            at: day(1),
            cadence: ReminderCadence.daily,
            expiresAt: DateTime(2026, 9),
          ),
        ],
        now: now,
        budget: 3,
      );
      expect(schedule.map((item) => item.noteId), [1, 2, 1]);
    });

    test('bütçe ilk turda dolarsa en yakın hatırlatmalar kazanır', () {
      final schedule = reminderSchedule(
        requests: [
          request(1, at: day(30)),
          request(2, at: day(3)),
          request(3, at: day(10)),
        ],
        now: now,
        budget: 2,
      );
      expect(schedule.map((item) => item.noteId), [2, 3]);
    });

    test('varsayılan bütçe iOS sınırının altında kalır', () {
      final schedule = reminderSchedule(
        requests: [for (var id = 1; id <= 70; id++) request(id, at: day(id))],
        now: now,
      );
      expect(schedule, hasLength(kPendingReminderBudget));
      expect(kPendingReminderBudget, lessThan(64));
    });

    test('tek notun faz koruyan kayan penceresi küçük tutulur', () {
      final schedule = reminderSchedule(
        requests: [
          request(
            9,
            at: day(3),
            cadence: ReminderCadence.weekly,
            expiresAt: DateTime(2030, 1, 1),
          ),
        ],
        now: now,
        maxPerNote: kRollingReminderWindowPerNote,
      );

      expect(schedule, hasLength(kRollingReminderWindowPerNote));
      expect(kRollingReminderWindowPerNote, lessThan(kPendingReminderBudget));
      expect(schedule.every((item) => item.repeat == null), isTrue);
    });
  });
}
