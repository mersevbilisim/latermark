import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/accent_tone.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// Göç zincirinin **tekrar koşulabilirliği**.
///
/// Zincir "kayıtlı sürüm neyse oradan devam et" varsayımıyla yazılmış, ama
/// SQLite'ın `user_version`'ı bu varsayımı her zaman taşımıyor: cihaza yeni
/// bir sürüm kurulup sonra eskisine dönülürse tablo yeni sütunu taşımaya devam
/// ederken sürüm numarası geriye yazılıyor. Geliştirme sırasında sürümler arası
/// gidip gelmek, TestFlight'ta eski bir yapıya dönmek bunu üretiyor.
///
/// Sonuç açılış yolunda patlıyordu: `main()` `runApp`'ten önce veritabanına
/// dokunuyor ve buradan gelen istisna uygulamayı hiç geçmeyen bir açılış
/// ekranında bırakıyordu.
void main() {
  late Directory sandbox;
  late File file;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_migration');
    file = File('${sandbox.path}/latermark_db.sqlite');
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Bağlantıyı gerçekten açtırır: Drift tembel açıyor, ilk sorguya kadar
  /// göçler koşmuyor.
  Future<NotesDatabase> open() async {
    final database = NotesDatabase.forExecutor(NativeDatabase(file));
    await database.customSelect('SELECT 1').get();
    return database;
  }

  test('geriye yazılmış sürüm numarası açılışı çökertmiyor', () async {
    // Güncel şemayla kurulmuş bir arşiv.
    var database = await open();
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      database.schemaVersion,
    );
    await database.close();

    // Eski bir yapı kurulmuş: tablo yeni sütunları taşımaya devam ediyor ama
    // sürüm numarası geri düşmüş. Cihazda kalan hâl budur.
    database = NotesDatabase.forExecutor(NativeDatabase(file));
    await database.customStatement('PRAGMA user_version = 1');
    await database.close();

    // Zincir baştan koşuyor. Guard olmasaydı ilk eklemede
    // `duplicate column name` ile düşerdi.
    database = await open();
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      database.schemaVersion,
    );
    await database.close();
  });

  test('v11 arşivi özel renk sütununa veri kaybetmeden yükseliyor', () async {
    var database = await open();

    // Cihazda v11'den kalan hâl: tablo özel ton sütununu tanımıyor.
    await database.customStatement(
      'ALTER TABLE settings DROP COLUMN accent_hue',
    );
    await database.customStatement(
      'UPDATE settings SET theme_mode = 1, accent = 4, locale = 3, '
      'density = 0, pro_unlocked = 1, reminder_enabled = 1',
    );
    await database.customStatement(
      "INSERT INTO notes (image_name, body, created_at, retention) "
      "VALUES ('v11.jpg', 'yükseltmeden gelen kayıt', 1754000000, 0)",
    );
    await database.customStatement('PRAGMA user_version = 11');
    await database.close();

    database = await open();
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      database.schemaVersion,
    );

    // Tercihlerin tamamı yerinde; yeni sütun dürüst varsayılanıyla doldu.
    final settings = await database
        .customSelect('SELECT * FROM settings WHERE id = 1')
        .getSingle();
    expect(settings.read<int>('theme_mode'), 1);
    expect(settings.read<int>('accent'), 4);
    expect(settings.read<int>('locale'), 3);
    expect(settings.read<int>('density'), 0);
    expect(settings.read<int>('pro_unlocked'), 1);
    expect(settings.read<int>('reminder_enabled'), 1);
    expect(settings.read<int>('accent_hue'), AccentTone.defaultHue);

    // Ve asıl mesele: kullanıcının arşivi.
    final notes = await database.customSelect('SELECT * FROM notes').get();
    expect(notes, hasLength(1));
    expect(notes.single.read<String>('body'), 'yükseltmeden gelen kayıt');

    await database.close();
  });

  test('v12 arşivi v11\'e düşüp tekrar yükselince de açılıyor', () async {
    // TestFlight'ta eski yapıya dönen kullanıcının hâli: sütun tabloda
    // duruyor ama sürüm numarası geriye yazılmış. Guard olmasaydı zincir
    // sütunu ikinci kez eklemeye kalkar ve açılış yolunda `duplicate column
    // name` ile düşerdi.
    var database = await open();
    await database.customStatement(
      'UPDATE settings SET accent = 6, accent_hue = 214',
    );
    await database.customStatement('PRAGMA user_version = 11');
    await database.close();

    database = await open();
    final settings = await database
        .customSelect('SELECT * FROM settings WHERE id = 1')
        .getSingle();
    // Seçim de tonu da olduğu gibi duruyor; sütun sıfırlanmadı.
    expect(settings.read<int>('accent'), 6);
    expect(settings.read<int>('accent_hue'), 214);
    await database.close();
  });

  test(
    'v12 arşivi ücretsiz hatırlatma sütununa veri kaybetmeden yükseliyor',
    () async {
      var database = await open();

      // Cihazda v12'den kalan hâl: tablo yeni sütunu tanımıyor. Bu, güncellemeyi
      // alan **mevcut kullanıcının** durumu.
      await database.customStatement(
        'ALTER TABLE settings DROP COLUMN free_reminder_notes',
      );
      await database.customStatement(
        'UPDATE settings SET theme_mode = 1, accent = 6, accent_hue = 214, '
        'locale = 3, density = 0, pro_unlocked = 0, reminder_enabled = 1, '
        'default_retention = 2, share_signature = 0',
      );
      await database.customStatement(
        "INSERT INTO notes (image_name, body, created_at, retention, expires_at, "
        "remind_at, remind_every_days) VALUES "
        "('v12.jpg', 'eski kullanıcının karesi', 1754000000, 2, 1754600000, "
        "1754500000, 7)",
      );
      await database.customStatement(
        "INSERT INTO notes (image_name, body, created_at, retention) "
        "VALUES ('', 'karesiz eski kayıt', 1754000001, 0)",
      );
      await database.customStatement('PRAGMA user_version = 12');
      await database.close();

      database = await open();
      expect(
        await database
            .customSelect('PRAGMA user_version')
            .map((row) => row.read<int>('user_version'))
            .getSingle(),
        database.schemaVersion,
      );

      // Tercihlerin tamamı yerinde.
      final settings = await database
          .customSelect('SELECT * FROM settings WHERE id = 1')
          .getSingle();
      expect(settings.read<int>('theme_mode'), 1);
      expect(settings.read<int>('accent'), 6);
      expect(settings.read<int>('accent_hue'), 214);
      expect(settings.read<int>('locale'), 3);
      expect(settings.read<int>('density'), 0);
      expect(settings.read<int>('reminder_enabled'), 1);
      expect(settings.read<int>('default_retention'), 2);
      expect(settings.read<int>('share_signature'), 0);

      // Yeni sütun **boş** doluyor: yükseltmeden gelen kullanıcı haklarının
      // tamamıyla başlıyor. Dolu gelseydi hiç kullanmadığı bir hakkı harcamış
      // sayılırdı.
      expect(settings.read<String>('free_reminder_notes'), '');

      // Ve asıl mesele: arşivin kendisi, hatırlatmasıyla birlikte.
      final notes = await database
          .customSelect('SELECT * FROM notes ORDER BY id')
          .get();
      expect(notes, hasLength(2));
      expect(notes.first.read<String>('body'), 'eski kullanıcının karesi');
      expect(notes.first.read<String>('image_name'), 'v12.jpg');
      expect(notes.first.read<int>('remind_at'), 1754500000);
      expect(notes.first.read<int>('remind_every_days'), 7);
      expect(notes.first.read<int>('expires_at'), 1754600000);
      expect(notes.last.read<String>('body'), 'karesiz eski kayıt');
      expect(notes.last.read<String>('image_name'), '');

      await database.close();
    },
  );

  test('v13 arşivi v12\'ye düşüp tekrar yükselince de açılıyor', () async {
    // TestFlight'ta eski yapıya dönen kullanıcının hâli: sütun tabloda duruyor
    // ama sürüm numarası geriye yazılmış. Guard olmasaydı zincir sütunu ikinci
    // kez eklemeye kalkar ve açılış yolunda düşerdi.
    var database = await open();
    await database.customStatement(
      "UPDATE settings SET free_reminder_notes = '4,9'",
    );
    await database.customStatement('PRAGMA user_version = 12');
    await database.close();

    database = await open();
    final settings = await database
        .customSelect('SELECT * FROM settings WHERE id = 1')
        .getSingle();
    // Harcanmış hak sıfırlanmadı: sütun olduğu gibi duruyor.
    expect(settings.read<String>('free_reminder_notes'), '4,9');
    await database.close();
  });

  test(
    'v14 arşivi erişilebilirlik ayarlarını veri kaybetmeden alıyor',
    () async {
      var database = await open();

      // v14'ün gerçek sınırı: yeni iki sütun yok, kullanıcının bütün eski
      // tercihleri ve kota defterleri ise dolu olabilir.
      await database.customStatement(
        'UPDATE settings SET theme_mode = 1, accent = 6, accent_hue = 214, '
        'locale = 3, density = 0, pro_unlocked = 1, reminder_enabled = 1, '
        "collapsed_groups = 'today,week', free_reminder_notes = '4,9', "
        "free_reminder_armed = '11'",
      );
      await database.customStatement(
        "INSERT INTO notes (image_name, body, created_at, retention, remind_at) "
        "VALUES ('v14.jpg', 'dokunulmaması gereken kayıt', 1754000000, 0, "
        '4102444800)',
      );
      await database.customStatement(
        'ALTER TABLE settings DROP COLUMN always_high_contrast',
      );
      await database.customStatement(
        'ALTER TABLE settings DROP COLUMN always_reduce_motion',
      );
      await database.customStatement('PRAGMA user_version = 14');
      await database.close();

      database = await open();
      final row = await database.select(database.settingsTable).getSingle();
      expect(row.themeMode.index, 1);
      expect(row.accent.index, 6);
      expect(row.accentHue, 214);
      expect(row.locale.index, 3);
      expect(row.density.index, 0);
      expect(row.proUnlocked, isTrue);
      expect(row.reminderEnabled, isTrue);
      expect(row.collapsedGroups, 'today,week');
      expect(row.freeReminderNotes, '4,9');
      expect(row.freeReminderArmed, '11');
      expect(row.alwaysHighContrast, isFalse);
      expect(row.alwaysReduceMotion, isFalse);

      final note = await database.select(database.notes).getSingle();
      expect(note.imageName, 'v14.jpg');
      expect(note.body, 'dokunulmaması gereken kayıt');
      expect(note.remindAt, DateTime.fromMillisecondsSinceEpoch(4102444800000));
      await database.close();
    },
  );

  test(
    'güncellemeyi alan Pro kullanıcının hatırlatmaları kotadan yemiyor',
    () async {
      // Kullanıcının en çok korkacağı senaryo: güncellemeyi al, kurulu
      // hatırlatmaları kaybet. Kota kimseden var olan bir şeyi alamamalı.
      //
      // İki ayrı güvence ölçülüyor. Birincisi Pro kullanıcı kapıdan hiç
      // geçmiyor. İkincisi daha ince: hak **teslimde** yandığı için, çoktan
      // çalmış eski hatırlatmalar da geriye dönük olarak hak yakmamalı.
      var database = await open();
      await database.customStatement(
        'ALTER TABLE settings DROP COLUMN free_reminder_notes',
      );
      await database.customStatement(
        'UPDATE settings SET pro_unlocked = 1, reminder_enabled = 1',
      );
      await database.customStatement(
        "INSERT INTO notes (image_name, body, created_at, retention, remind_at) "
        "VALUES ('gecmis.jpg', 'çoktan çalmış', 1754000000, 0, 1754000600)",
      );
      await database.customStatement(
        "INSERT INTO notes (image_name, body, created_at, retention, remind_at, "
        "remind_every_days) VALUES ('gelecek.jpg', 'ileride çalacak', "
        "1754000000, 0, 4102444800, 1)",
      );
      await database.customStatement('PRAGMA user_version = 12');
      await database.close();

      database = await open();
      final photos = await PhotoStore.openIn(sandbox);
      final repository = NotesRepository(database: database, photos: photos);
      final settings = SettingsRepository(database);

      // Senkron her öne dönüşte koşuyor; güncellemeden sonraki ilk açılış da bu.
      await repository.settleFreeReminders(deliveredNoteIds: const {1, 2});

      // Pro kullanıcıda hesap hiç açılmıyor.
      expect((await settings.read()).freeReminderNotes, isEmpty);

      // Ve hatırlatmaların ikisi de yerinde.
      final notes = await repository.watchNotes().first;
      expect(notes, hasLength(2));
      expect(notes.every((note) => note.remindAt != null), isTrue);
      expect(
        notes
            .firstWhere((note) => note.body == 'ileride çalacak')
            .remindEveryDays,
        1,
      );

      await database.close();
    },
  );

  test('gerçek yükseltme hâlâ koşuyor: v7 kaydı mutlak ana dönüyor', () async {
    // Korumanın asıl riski bu: "zaten dönüşmüş" ölçütü, gerçekten dönüşmesi
    // gereken arşivi de atlarsa yükseltmeden gelen kullanıcının hatırlatması
    // sessizce kaybolur.
    var database = await open();
    // Güncel şema v7 hâline geri sarılıyor; cihazda o sürümden kalan tablo
    // budur.
    await database.customStatement('ALTER TABLE notes DROP COLUMN remind_at');
    await database.customStatement(
      'ALTER TABLE notes RENAME COLUMN remind_every_days TO remind_after_days',
    );
    await database.customStatement(
      'ALTER TABLE notes ADD COLUMN remind_repeats INTEGER NOT NULL DEFAULT 0',
    );
    await database.customStatement(
      'ALTER TABLE notes ADD COLUMN reminder_anchor_at INTEGER NULL',
    );
    await database.customStatement(
      'ALTER TABLE notes DROP COLUMN original_name',
    );
    await database.customStatement(
      'ALTER TABLE settings DROP COLUMN share_signature',
    );

    // 1 Ağustos'ta kurulmuş, üç gün sonrasına bakan tekrarlı bir hatırlatma.
    final anchor = DateTime(2026, 8, 1, 9);
    await database.customStatement(
      'INSERT INTO notes (image_name, body, created_at, retention, '
      'custom_minutes, remind_after_days, remind_repeats, reminder_anchor_at) '
      'VALUES (?, ?, ?, 0, 0, 3, 1, ?)',
      [
        'kare.jpg',
        'lastikleri sor',
        anchor.millisecondsSinceEpoch,
        anchor.millisecondsSinceEpoch ~/ 1000,
      ],
    );
    await database.customStatement('PRAGMA user_version = 7');
    await database.close();

    database = await open();
    final note = await database.select(database.notes).getSingle();
    // v8 dönüşümü koştu: çıpa + gün sayısı mutlak ana çevrildi.
    expect(note.remindAt, DateTime(2026, 8, 4, 9));
    // Tekrarlı olduğu için aralık korundu; v9 ve v10 sütunları da geldi.
    expect(note.remindEveryDays, 3);
    expect(note.originalName, isNull);
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      database.schemaVersion,
    );
    await database.close();
  });

  test(
    'sıfırdan kurulan veritabanı yanındaki kareleri yetim saymıyor',
    () async {
      // "Boş arşiv" iki bambaşka durumun aynı görüntüsü. Kullanıcı her şeyi
      // sildiyse kareler gerçekten yetim; veritabanı kaybolduysa kareler
      // kullanıcının tek kopyası ve toplayıcı onları silerse geri dönüşü yok.
      final database = await open();
      expect(database.createdFresh, isTrue);
      await database.close();

      // İkinci açılış: dosya duruyor, yeniden kurulmuyor.
      final again = NotesDatabase.forExecutor(NativeDatabase(file));
      await again.customSelect('SELECT 1').get();
      expect(again.createdFresh, isFalse);
      await again.close();
    },
  );

  for (final isPro in [false, true]) {
    test(
      'gerçek 1.0.3/v10 ${isPro ? 'Pro' : 'Free'} arşivi eksiksiz açılıyor',
      () async {
        // Güncel tabloyu kırparak eskiyi taklit etmek gelecekteki sütunları
        // yanlışlıkla fixture'da bırakabiliyor. Burada 1.0.3'ün üretilmiş
        // Drift şeması baştan kuruluyor; dolayısıyla v10 -> güncel zincir gerçek
        // cihaz dosyasında karşılaşacağı biçimle sınanıyor.
        var database = await open();
        await database.customStatement('DROP TABLE note_search');
        await database.customStatement('DROP TABLE notes');
        await database.customStatement('DROP TABLE settings');
        await database.customStatement('''
          CREATE TABLE notes (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            image_name TEXT NOT NULL,
            original_name TEXT NULL,
            body TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            retention INTEGER NOT NULL DEFAULT 0,
            custom_minutes INTEGER NOT NULL DEFAULT 0,
            expires_at INTEGER NULL,
            last_seen_at INTEGER NULL,
            updated_at INTEGER NULL,
            latitude REAL NULL,
            longitude REAL NULL,
            remind_at INTEGER NULL,
            remind_every_days INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.customStatement('''
          CREATE TABLE note_search (
            note_id INTEGER NOT NULL REFERENCES notes (id) ON DELETE CASCADE,
            body_folded TEXT NOT NULL DEFAULT '',
            photo_folded TEXT NULL,
            photo_fingerprint TEXT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (note_id)
          )
        ''');
        await database.customStatement('''
          CREATE TABLE settings (
            id INTEGER NOT NULL DEFAULT 1,
            theme_mode INTEGER NOT NULL DEFAULT 2,
            accent INTEGER NOT NULL DEFAULT 0,
            density INTEGER NOT NULL DEFAULT 1,
            reminder_enabled INTEGER NOT NULL DEFAULT 0
              CHECK (reminder_enabled IN (0, 1)),
            location_enabled INTEGER NOT NULL DEFAULT 0
              CHECK (location_enabled IN (0, 1)),
            default_retention INTEGER NOT NULL DEFAULT 0,
            locale INTEGER NOT NULL DEFAULT 0,
            default_custom_minutes INTEGER NOT NULL DEFAULT 0,
            share_signature INTEGER NOT NULL DEFAULT 1
              CHECK (share_signature IN (0, 1)),
            pro_unlocked INTEGER NOT NULL DEFAULT 0
              CHECK (pro_unlocked IN (0, 1)),
            PRIMARY KEY (id)
          )
        ''');

        final remindAt = isPro ? 4102444800 : null;
        await database.customStatement(
          'INSERT INTO settings (id, theme_mode, accent, density, '
          'reminder_enabled, location_enabled, default_retention, locale, '
          'default_custom_minutes, share_signature, pro_unlocked) '
          'VALUES (1, 1, 4, 0, ?, 1, 2, 3, 0, 0, ?)',
          [isPro ? 1 : 0, isPro ? 1 : 0],
        );
        await database.customStatement(
          'INSERT INTO notes (image_name, original_name, body, created_at, '
          'retention, expires_at, remind_at, remind_every_days) '
          "VALUES ('v103.jpg', 'v103-original.jpg', '1.0.3 kaydı', "
          '1754000000, 2, 1754600000, ?, ?)',
          [remindAt, isPro ? 7 : 0],
        );
        await database.customStatement(
          "INSERT INTO note_search (note_id, body_folded, photo_folded, "
          "photo_fingerprint, attempts) VALUES (1, '103 kaydı', 'ocr', "
          "'fingerprint', 1)",
        );
        await database.customStatement('PRAGMA user_version = 10');
        await database.close();

        database = await open();
        final row = await database.select(database.notes).getSingle();
        expect(row.imageName, 'v103.jpg');
        expect(row.originalName, 'v103-original.jpg');
        expect(row.body, '1.0.3 kaydı');
        expect(row.expiresAt, isNotNull);
        expect(row.remindAt, isPro ? isNotNull : isNull);
        expect(row.remindEveryDays, isPro ? 7 : 0);

        final search = await database.select(database.noteSearch).getSingle();
        expect(search.photoFolded, 'ocr');
        expect(search.photoFingerprint, 'fingerprint');
        expect(search.attempts, 1);

        final rawSettings = await database
            .select(database.settingsTable)
            .getSingle();
        expect(rawSettings.themeMode.index, 1);
        expect(rawSettings.accent.index, 4);
        expect(rawSettings.density.index, 0);
        expect(rawSettings.locationEnabled, isTrue);
        expect(rawSettings.defaultRetention.index, 2);
        expect(rawSettings.locale.index, 3);
        expect(rawSettings.shareSignature, isFalse);
        expect(rawSettings.proUnlocked, isPro);
        expect(rawSettings.reminderEnabled, isPro);
        expect(rawSettings.collapsedGroups, '');
        expect(rawSettings.accentHue, AccentTone.defaultHue);
        expect(rawSettings.freeReminderNotes, '');
        expect(rawSettings.freeReminderArmed, '');
        expect(rawSettings.alwaysHighContrast, isFalse);
        expect(rawSettings.alwaysReduceMotion, isFalse);

        final settings = SettingsRepository(database);
        final model = await settings.read();
        expect(model.proUnlocked, isPro);
        expect(model.reminderEnabled, isPro);
        if (!isPro) {
          // 1.0.3 Free kullanıcının yeni haklara erişmesi için eski kapalı
          // anahtar, kullanıcı açtığında artık Pro önbelleğine takılmamalı.
          await settings.setReminderEnabled(true);
          expect((await settings.read()).reminderEnabled, isTrue);
        }

        expect(
          await database
              .customSelect('PRAGMA user_version')
              .map((row) => row.read<int>('user_version'))
              .getSingle(),
          database.schemaVersion,
        );
        await database.close();
      },
    );
  }

  test('kayıtlar ve ayarlar zincir yeniden koşunca yerinde kalıyor', () async {
    var database = await open();
    await database.customStatement(
      'INSERT INTO notes (image_name, body, created_at, retention, '
      'custom_minutes, remind_every_days) VALUES (?, ?, ?, 0, 0, 0)',
      ['kare.jpg', 'faturayı öde', DateTime(2026, 8, 1).millisecondsSinceEpoch],
    );
    await database.close();

    database = NotesDatabase.forExecutor(NativeDatabase(file));
    await database.customStatement('PRAGMA user_version = 1');
    await database.close();

    database = await open();
    final rows = await database.select(database.notes).get();
    expect(rows.single.body, 'faturayı öde');
    // Yükseltme adımı atlandı, ama sütunun kendisi duruyor: kayıt eskisi gibi
    // "orijinali yok" hâlinde.
    expect(rows.single.originalName, isNull);
    await database.close();
  });
}
