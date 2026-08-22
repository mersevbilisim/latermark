import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';

void main() {
  final anchorAt = DateTime(2026, 8, 1, 12);
  final now = DateTime(2026, 8, 2, 12);

  group('tek atışlık hatırlatma', () {
    test('gelecekteki hatırlatma anını üretir', () {
      expect(
        pendingReminderAt(anchorAt: anchorAt, remindAfterDays: 3, now: now),
        DateTime(2026, 8, 4, 12),
      );
    });

    test('geçmiş veya kapalı hatırlatmayı etkin saymaz', () {
      expect(
        pendingReminderAt(anchorAt: anchorAt, remindAfterDays: 0, now: now),
        isNull,
      );
      expect(
        pendingReminderAt(anchorAt: anchorAt, remindAfterDays: 1, now: now),
        isNull,
      );
    });

    test('not daha önce silinecekse hatırlatmayı etkin saymaz', () {
      expect(
        pendingReminderAt(
          anchorAt: anchorAt,
          remindAfterDays: 3,
          expiresAt: DateTime(2026, 8, 3, 12),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('tekrarlayan hatırlatma', () {
    test('aralık boyunca ardışık anlar üretir', () {
      expect(
        reminderOccurrences(
          anchorAt: anchorAt,
          remindAfterDays: 3,
          repeats: true,
          now: now,
          limit: 3,
        ),
        [
          DateTime(2026, 8, 4, 12),
          DateTime(2026, 8, 7, 12),
          DateTime(2026, 8, 10, 12),
        ],
      );
    });

    test('geçmişte kalan oluşumları aritmetikle atlar', () {
      expect(
        reminderOccurrences(
          anchorAt: anchorAt,
          remindAfterDays: 1,
          repeats: true,
          now: DateTime(2026, 8, 10, 15),
          limit: 2,
        ),
        [DateTime(2026, 8, 11, 12), DateTime(2026, 8, 12, 12)],
      );
    });

    test('tam oluşum anını geçmiş sayar', () {
      expect(
        reminderOccurrences(
          anchorAt: anchorAt,
          remindAfterDays: 2,
          repeats: true,
          now: DateTime(2026, 8, 5, 12),
        ),
        [DateTime(2026, 8, 7, 12)],
      );
    });

    test('silinme anından sonrasını planlamaz', () {
      expect(
        reminderOccurrences(
          anchorAt: anchorAt,
          remindAfterDays: 2,
          repeats: true,
          expiresAt: DateTime(2026, 8, 8),
          now: now,
          limit: 60,
        ),
        [
          DateTime(2026, 8, 3, 12),
          DateTime(2026, 8, 5, 12),
          DateTime(2026, 8, 7, 12),
        ],
      );
    });

    test('pendingReminderAt sıradaki oluşumu verir', () {
      expect(
        pendingReminderAt(
          anchorAt: anchorAt,
          remindAfterDays: 1,
          repeats: true,
          now: DateTime(2026, 8, 10, 15),
        ),
        DateTime(2026, 8, 11, 12),
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
      required int days,
      bool repeats = false,
      DateTime? anchor,
      DateTime? expiresAt,
      bool allowNativeRepeat = true,
    }) => ReminderRequest(
      noteId: id,
      anchorAt: anchor ?? anchorAt,
      remindAfterDays: days,
      repeats: repeats,
      expiresAt: expiresAt,
      allowNativeRepeat: allowNativeRepeat,
    );

    test('hatırlatması olmayan not programa girmez', () {
      final schedule = reminderSchedule(
        requests: [request(1, days: 0), request(2, days: 3)],
        now: now,
      );
      expect(schedule.map((item) => item.noteId), [2]);
    });

    test('süresiz tekrar işletim sisteminde tek kayıt kullanır', () {
      final schedule = reminderSchedule(
        requests: [request(1, days: 30, repeats: true)],
        now: now,
      );

      expect(schedule, hasLength(1));
      expect(schedule.single.repeatInterval, const Duration(days: 30));
      expect(schedule.single.repeatsIndefinitely, isTrue);
    });

    test('365 gün gerçekten 365 günlük native aralıktır', () {
      final schedule = reminderSchedule(
        requests: [request(1, days: 365, repeats: true)],
        now: now,
      );
      expect(schedule.single.repeatInterval, const Duration(days: 365));
    });

    test('native fazı kuramayan platform kesin tek-atış dizisi üretir', () {
      final schedule = reminderSchedule(
        requests: [
          request(9, days: 3, repeats: true, allowNativeRepeat: false),
        ],
        now: now,
        budget: 4,
      );

      expect(schedule, hasLength(4));
      expect(schedule.every((item) => item.repeatInterval == null), isTrue);
      expect(schedule.map((item) => item.at), [
        DateTime(2026, 8, 4, 12),
        DateTime(2026, 8, 7, 12),
        DateTime(2026, 8, 10, 12),
        DateTime(2026, 8, 13, 12),
      ]);
    });

    test('exact tekrar penceresi ilerlerken oluşum kimliği sabit kalır', () {
      final requestValue = request(
        9,
        days: 3,
        repeats: true,
        allowNativeRepeat: false,
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
            request(3, days: 2, repeats: true, expiresAt: DateTime(2026, 8, 8)),
          ],
          now: now,
        );

        expect(schedule, hasLength(3));
        expect(schedule.every((item) => !item.repeatsIndefinitely), isTrue);
        expect(schedule.map((item) => item.at), [
          DateTime(2026, 8, 3, 12),
          DateTime(2026, 8, 5, 12),
          DateTime(2026, 8, 7, 12),
        ]);
      },
    );

    test('sonlu oluşum kimliği uygulama yeniden açılınca değişmez', () {
      final requestValue = request(
        3,
        days: 1,
        repeats: true,
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
          request(1, days: 1, repeats: true, expiresAt: DateTime(2026, 9)),
          request(2, days: 1, repeats: true, expiresAt: DateTime(2026, 9)),
        ],
        now: now,
        budget: 3,
      );
      expect(schedule.map((item) => item.noteId), [1, 2, 1]);
    });

    test('bütçe ilk turda dolarsa en yakın hatırlatmalar kazanır', () {
      final schedule = reminderSchedule(
        requests: [
          request(1, days: 30),
          request(2, days: 3),
          request(3, days: 10),
        ],
        now: now,
        budget: 2,
      );
      expect(schedule.map((item) => item.noteId), [2, 3]);
    });

    test('varsayılan bütçe iOS sınırının altında kalır', () {
      final schedule = reminderSchedule(
        requests: [for (var id = 1; id <= 70; id++) request(id, days: id)],
        now: now,
      );
      expect(schedule, hasLength(kPendingReminderBudget));
      expect(kPendingReminderBudget, lessThan(64));
    });

    test('tek notun faz koruyan kayan penceresi küçük tutulur', () {
      final schedule = reminderSchedule(
        requests: [
          request(9, days: 3, repeats: true, allowNativeRepeat: false),
        ],
        now: now,
        maxPerNote: kRollingReminderWindowPerNote,
      );

      expect(schedule, hasLength(kRollingReminderWindowPerNote));
      expect(kRollingReminderWindowPerNote, lessThan(kPendingReminderBudget));
      expect(schedule.every((item) => item.repeatInterval == null), isTrue);
    });
  });
}
