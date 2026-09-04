import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/paywall/domain/pro_limits.dart';
import 'package:latermark/features/paywall/data/reminder_quota_store.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

class _FloorQuotaStore extends ReminderQuotaStore {
  _FloorQuotaStore(this.floor);

  final int floor;

  @override
  Future<int?> read() async => floor;
}

class _BlockingQuotaStore extends ReminderQuotaStore {
  final result = Completer<int?>();

  @override
  Future<int?> read() => result.future;
}

/// Hak kapanışının hatırlatmalara dokunuşu.
///
/// Ücretsiz katmana hatırlatma hakkı verildiği anda bu yol bir muhasebe
/// ayrıntısı olmaktan çıkıp **veri kaybı** yoluna dönüştü: eskiden ücretsiz
/// kullanıcının silinecek hatırlatması hiç yoktu, süpürme görünmez bir no-op'tu.
void main() {
  final now = DateTime(2026, 9, 4, 10);

  late NotesDatabase database;
  late SettingsRepository settings;

  setUp(() {
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    settings = SettingsRepository(database);
  });

  tearDown(() => database.close());

  Future<int> noteWithReminder(DateTime at, {int everyDays = 0}) => database
      .into(database.notes)
      .insert(
        NotesCompanion.insert(
          imageName: 'kare.jpg',
          createdAt: now.subtract(const Duration(days: 1)),
          retention: const Value(Retention.off),
          remindAt: Value(at),
          remindEveryDays: Value(everyDays),
        ),
      );

  Future<DateTime?> remindAtOf(int id) async => (await (database.select(
    database.notes,
  )..where((row) => row.id.equals(id))).getSingle()).remindAt;

  test(
    'zaten ücretsizken gelen "sahip değil" cevabı hiçbir şeyi silmiyor',
    () async {
      // Mağazanın bu cevabı bir olay değil: ücretsiz kullanıcı her açılışta
      // alıyor. AppScope'taki karşılaştırma ayarlar henüz yüklenmediyse
      // atlanıyor ve çağrı buraya kadar geliyordu.
      await settings.setReminderEnabled(true);
      final id = await noteWithReminder(now.add(const Duration(days: 3)));

      await settings.setProUnlocked(false, now: now);

      expect(await remindAtOf(id), now.add(const Duration(days: 3)));
      expect((await settings.read()).reminderEnabled, isTrue);
    },
  );

  test('gerçek downgrade ücretsiz katmanın hakkı kadarını bırakıyor', () async {
    await settings.setProUnlocked(true);
    await settings.setReminderEnabled(true);

    // Dört hatırlatma, hepsi önde. Ücretsiz katmanın hakkı ikisine yetiyor.
    final ids = <int>[
      for (var day = 1; day <= 4; day++)
        await noteWithReminder(now.add(Duration(days: day)), everyDays: 7),
    ];

    await settings.setProUnlocked(false, now: now);

    // En yakın ikisi yaşıyor.
    for (var i = 0; i < ProLimits.freeReminders; i++) {
      expect(
        await remindAtOf(ids[i]),
        now.add(Duration(days: i + 1)),
        reason: '${i + 1}. gün',
      );
    }
    // Kotanın ötesindekiler, yeniden Pro alınca sessizce geri gelmesin diye
    // siliniyor.
    for (var i = ProLimits.freeReminders; i < ids.length; i++) {
      expect(await remindAtOf(ids[i]), isNull, reason: '${i + 1}. gün');
    }

    // Sağ kalanlarda ritim yok: tek hakla sınırsız bildirim üretilemez.
    final kept = await (database.select(
      database.notes,
    )..where((row) => row.remindAt.isNotNull())).get();
    expect(kept, hasLength(ProLimits.freeReminders));
    expect(kept.every((note) => note.remindEveryDays == 0), isTrue);

    // Ana şalter açık kalıyor; kapalı bir şalterin arkasında bırakmak
    // hatırlatmaları silmenin sessiz hâli olurdu.
    expect((await settings.read()).reminderEnabled, isTrue);
  });

  test('çalma anı geçmiş hatırlatma ücretsiz slotu yemiyor', () async {
    await settings.setProUnlocked(true);
    final stale = await noteWithReminder(now.subtract(const Duration(days: 2)));
    final upcoming = await noteWithReminder(now.add(const Duration(days: 9)));

    await settings.setProUnlocked(false, now: now);

    // Geçmiş istek zaten geri gelmeyecekti; slot önde durana gidiyor.
    expect(await remindAtOf(stale), isNull);
    expect(await remindAtOf(upcoming), now.add(const Duration(days: 9)));
  });

  test(
    'downgrade daha önce yanmış hakların üstüne yeni slot vermiyor',
    () async {
      await settings.setProUnlocked(true);
      final ids = <int>[
        for (var day = 1; day <= ProLimits.freeReminders + 1; day++)
          await noteWithReminder(now.add(Duration(days: day))),
      ];
      await (database.update(database.settingsTable)
            ..where((row) => row.id.equals(1)))
          .write(const SettingsTableCompanion(freeReminderNotes: Value('900')));

      await settings.setProUnlocked(false, now: now);

      final kept = await (database.select(
        database.notes,
      )..where((row) => row.remindAt.isNotNull())).get();
      expect(kept, hasLength(ProLimits.freeReminders - 1));
      expect(
        kept.map((note) => note.id),
        ids.take(ProLimits.freeReminders - 1),
      );
    },
  );

  test(
    'Keychain tabanı DB boş görünse de downgrade kontenjanını kapatıyor',
    () async {
      settings = SettingsRepository(
        database,
        reminderQuota: _FloorQuotaStore(ProLimits.freeReminders),
      );
      await settings.setProUnlocked(true);
      final id = await noteWithReminder(now.add(const Duration(days: 1)));

      await settings.setProUnlocked(false, now: now);

      expect(await remindAtOf(id), isNull);
    },
  );

  test(
    'Keychain bekleyen eski iade yeni satın alma teyidini ezmiyor',
    () async {
      final quota = _BlockingQuotaStore();
      settings = SettingsRepository(database, reminderQuota: quota);
      await settings.setProUnlocked(true);
      final id = await noteWithReminder(now.add(const Duration(days: 1)));

      final staleRevoke = settings.setProUnlocked(false, now: now);
      // İlk çağrının Keychain bekleyişine girmesine izin ver.
      await Future<void>.delayed(Duration.zero);
      final newerGrant = settings.setProUnlocked(true, now: now);
      quota.result.complete(ProLimits.freeReminders);
      await Future.wait([staleRevoke, newerGrant]);

      expect((await settings.read()).proUnlocked, isTrue);
      expect(await remindAtOf(id), now.add(const Duration(days: 1)));
    },
  );

  test('temizlik yalnız gerçek kapanışta koşuyor', () async {
    // İkinci çağrı bir downgrade değil; ilkinden sağ çıkanlara dokunmamalı.
    await settings.setProUnlocked(true);
    final id = await noteWithReminder(now.add(const Duration(days: 2)));
    final extra = await noteWithReminder(now.add(const Duration(days: 3)));
    final beyond = await noteWithReminder(now.add(const Duration(days: 4)));

    await settings.setProUnlocked(false, now: now);
    expect(await remindAtOf(beyond), isNull);

    await settings.setProUnlocked(false, now: now);
    expect(await remindAtOf(id), now.add(const Duration(days: 2)));
    expect(await remindAtOf(extra), now.add(const Duration(days: 3)));
  });
}
