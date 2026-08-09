import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/pro_downgrade_policy.dart';

void main() {
  test(
    'custom varsayilan daha erken silmeyen en yakin free secenege duser',
    () {
      expect(
        freeRetentionFallback(RetentionChoice.custom(60)).retention,
        Retention.threeDays,
      );
      expect(
        freeRetentionFallback(
          RetentionChoice.custom(const Duration(days: 5).inMinutes),
        ).retention,
        Retention.oneWeek,
      );
      expect(
        freeRetentionFallback(
          RetentionChoice.custom(const Duration(days: 8).inMinutes),
        ).retention,
        Retention.off,
      );
    },
  );

  test('mevcut custom notun yeni bitisi eskisinden erken olmaz', () {
    final createdAt = DateTime(2026, 8, 1, 12);
    final currentExpiry = createdAt.add(const Duration(days: 5));
    final normalized = freeNoteRetention(
      current: RetentionChoice.custom(const Duration(days: 1).inMinutes),
      createdAt: createdAt,
      // Tutarsız/eski bir DB satırı olsa bile üç güne kısaltılmamalı.
      currentExpiresAt: currentExpiry,
    );

    expect(normalized.choice.retention, Retention.oneWeek);
    expect(normalized.expiresAt, createdAt.add(const Duration(days: 7)));
    expect(normalized.expiresAt!.isBefore(currentExpiry), isFalse);

    final long = freeNoteRetention(
      current: RetentionChoice.custom(const Duration(days: 8).inMinutes),
      createdAt: createdAt,
      currentExpiresAt: createdAt.add(const Duration(days: 8)),
    );
    expect(long.choice.retention, Retention.off);
    expect(long.expiresAt, isNull);
  });

  test(
    'downgrade varsayilani temizler, mevcut notun omrunu kisaltmaz',
    () async {
      final database = NotesDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = SettingsRepository(database);
      final createdAt = DateTime(2026, 8, 8, 12);
      final customMinutes = const Duration(days: 5).inMinutes;
      final expiresAt = createdAt.add(Duration(minutes: customMinutes));

      await settings.setProUnlocked(true);
      await settings.setReminderEnabled(true);
      await settings.setDefaultRetention(RetentionChoice.custom(customMinutes));
      final noteId = await database
          .into(database.notes)
          .insert(
            NotesCompanion.insert(
              imageName: 'kept.jpg',
              createdAt: createdAt,
              retention: const Value(Retention.custom),
              customMinutes: Value(customMinutes),
              expiresAt: Value(expiresAt),
              remindAfterDays: const Value(2),
            ),
          );
      final longCustomMinutes = const Duration(days: 8).inMinutes;
      final longNoteId = await database
          .into(database.notes)
          .insert(
            NotesCompanion.insert(
              imageName: 'kept-long.jpg',
              createdAt: createdAt,
              retention: const Value(Retention.custom),
              customMinutes: Value(longCustomMinutes),
              expiresAt: Value(
                createdAt.add(Duration(minutes: longCustomMinutes)),
              ),
              remindAfterDays: const Value(5),
            ),
          );

      await settings.setProUnlocked(false);

      final downgraded = await settings.read();
      expect(downgraded.proUnlocked, isFalse);
      expect(downgraded.reminderEnabled, isFalse);
      expect(downgraded.defaultRetention, Retention.oneWeek);
      expect(downgraded.defaultCustomMinutes, 0);

      final note = await (database.select(
        database.notes,
      )..where((row) => row.id.equals(noteId))).getSingle();
      expect(note.retention, Retention.oneWeek);
      expect(note.customMinutes, 0);
      expect(note.expiresAt, createdAt.add(const Duration(days: 7)));
      expect(note.expiresAt!.isBefore(expiresAt), isFalse);
      expect(note.remindAfterDays, 0);

      final longNote = await (database.select(
        database.notes,
      )..where((row) => row.id.equals(longNoteId))).getSingle();
      expect(longNote.retention, Retention.off);
      expect(longNote.customMinutes, 0);
      expect(longNote.expiresAt, isNull);
      expect(longNote.remindAfterDays, 0);

      // Downgrade'dan önce açılmış bir custom seçim geç sonuçlansa bile yeniden
      // Pro varsayılanı yazamaz.
      await settings.setDefaultRetention(
        RetentionChoice.custom(const Duration(days: 8).inMinutes),
      );
      final stored = await database.select(database.settingsTable).getSingle();
      expect(stored.defaultRetention, Retention.off);
      expect(stored.defaultCustomMinutes, 0);

      // İzin isteği downgrade'dan sonra geç tamamlansa bile şalter açılamaz.
      await settings.setReminderEnabled(true);
      expect((await settings.read()).reminderEnabled, isFalse);
    },
  );
}
