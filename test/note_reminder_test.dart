import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';

void main() {
  final createdAt = DateTime(2026, 8, 1, 12);
  final now = DateTime(2026, 8, 2, 12);

  test('gelecekteki hatırlatma anını üretir', () {
    expect(
      pendingReminderAt(createdAt: createdAt, remindAfterDays: 3, now: now),
      DateTime(2026, 8, 4, 12),
    );
  });

  test('geçmiş veya kapalı hatırlatmayı etkin saymaz', () {
    expect(
      pendingReminderAt(createdAt: createdAt, remindAfterDays: 0, now: now),
      isNull,
    );
    expect(
      pendingReminderAt(createdAt: createdAt, remindAfterDays: 1, now: now),
      isNull,
    );
  });

  test('not daha önce silinecekse hatırlatmayı etkin saymaz', () {
    expect(
      pendingReminderAt(
        createdAt: createdAt,
        remindAfterDays: 3,
        expiresAt: DateTime(2026, 8, 3, 12),
        now: now,
      ),
      isNull,
    );
  });
}
