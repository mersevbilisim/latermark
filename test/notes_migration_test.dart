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

  test('v12 arşivi ücretsiz hatırlatma sütununa veri kaybetmeden yükseliyor', (
  ) async {
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

    // Yeni sütun **boş** doluyor: yükseltmeden gelen kullanıcı üç hakkının
    // tamamıyla başlıyor. Dolu gelseydi hiç kullanmadığı bir hakkı harcamış
    // sayılırdı.
    expect(settings.read<String>('free_reminder_notes'), '');

    // Ve asıl mesele: arşivin kendisi, hatırlatmasıyla birlikte.
    final notes = await database.customSelect(
      'SELECT * FROM notes ORDER BY id',
    ).get();
    expect(notes, hasLength(2));
    expect(notes.first.read<String>('body'), 'eski kullanıcının karesi');
    expect(notes.first.read<String>('image_name'), 'v12.jpg');
    expect(notes.first.read<int>('remind_at'), 1754500000);
    expect(notes.first.read<int>('remind_every_days'), 7);
    expect(notes.first.read<int>('expires_at'), 1754600000);
    expect(notes.last.read<String>('body'), 'karesiz eski kayıt');
    expect(notes.last.read<String>('image_name'), '');

    await database.close();
  });

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

  test('güncellemeyi alan Pro kullanıcının hatırlatmaları kotadan yemiyor', (
  ) async {
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
    await repository.settleFreeReminders(permissionGranted: true);

    // Pro kullanıcıda hesap hiç açılmıyor.
    expect((await settings.read()).freeReminderNotes, isEmpty);

    // Ve hatırlatmaların ikisi de yerinde.
    final notes = await repository.watchNotes().first;
    expect(notes, hasLength(2));
    expect(notes.every((note) => note.remindAt != null), isTrue);
    expect(
      notes.firstWhere((note) => note.body == 'ileride çalacak').remindEveryDays,
      1,
    );

    await database.close();
  });

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

  test('v10 arşivi kapalı bölüm sütununu boş alıyor', () async {
    // Yükseltmeden gelen kullanıcı: sütun yeni, değeri boş, yani bütün
    // bölümler açık. Görünüm tercihi için eklenen bir sütun kimsenin arşivini
    // değiştirmemeli.
    var database = await open();
    await database.customStatement(
      'ALTER TABLE settings DROP COLUMN collapsed_groups',
    );
    await database.customStatement('PRAGMA user_version = 10');
    await database.close();

    database = await open();
    final settings = await database.select(database.settingsTable).getSingle();
    expect(settings.collapsedGroups, '');
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      database.schemaVersion,
    );
    await database.close();
  });

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
