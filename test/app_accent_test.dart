import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_accent.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/features/settings/presentation/widgets/settings_pieces.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

void main() {
  test(
    'varsayilan turuncu kalir, secim yalniz vurgu kanallarini degistirir',
    () {
      expect(const AppSettings().accent, AppAccent.orange);

      for (final accent in AppAccent.values) {
        final palette = AppPalette.forAccent(Brightness.light, accent);
        expect(palette.ember, accent.colorFor(Brightness.light));
        expect(palette.onPhotoAccent, accent.onPhotoFor());
        expect(palette.canvas, AppPalette.light.canvas);
        expect(palette.ink, AppPalette.light.ink);
        expect(palette.danger, AppPalette.light.danger);

        final darkCopy = palette.copyWith(brightness: Brightness.dark);
        expect(darkCopy.accent, accent);
        expect(darkCopy.ember, accent.colorFor(Brightness.dark));
      }
    },
  );

  testWidgets(
    'renk prova seridi secimi erisilebilir bir dokunusla degistirir',
    (tester) async {
      var selected = AppAccent.orange;
      var customTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Center(
                child: SizedBox(
                  width: 300,
                  child: AccentRail(
                    value: selected,
                    labelOf: (accent) => accent.name,
                    onChanged: (accent) => setState(() => selected = accent),
                    customHue: 210,
                    onCustom: () => customTaps++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('app-accent-violet')));
      await tester.pumpAndSettle();

      expect(selected, AppAccent.violet);

      // Özel yuva seçimi doğrudan değiştirmiyor: ton görülmeden "özel"e
      // geçmek anlamsız bir ara durum olurdu, panel açılıyor.
      await tester.tap(find.byKey(const ValueKey('app-accent-custom')));
      await tester.pumpAndSettle();
      expect(selected, AppAccent.violet);
      expect(customTaps, 1);
      for (final accent in AppAccent.strip) {
        final size = tester.getSize(
          find.byKey(ValueKey('app-accent-${accent.name}')),
        );
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      expect(
        tester.getSemantics(find.byKey(const ValueKey('app-accent-violet'))),
        matchesSemantics(
          label: 'violet',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
    },
  );

  test('latermark_db v1 renk sutununa veri kaybetmeden yukselir', () async {
    final sandbox = await Directory.systemTemp.createTemp('latermark_accent');
    final photoStore = await PhotoStore.openIn(sandbox);
    final path = '${sandbox.path}/v1.sqlite';
    final legacy = raw.sqlite3.open(path);
    // v1'in **tamamı** kuruluyor: not, arama ve ayar tabloları. Eskiden burada
    // yalnız `settings` vardı ve göç `notes`'a sütun eklemeye çalışırken
    // patlıyordu — gerçek bir telefonda olamayacak bir başlangıç durumu, çünkü
    // o veritabanını yaratan eski uygulama sürümü üç tabloyu da kurmuştu.
    legacy.execute('''
      CREATE TABLE notes (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        image_name TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        retention INTEGER NOT NULL DEFAULT 0,
        custom_minutes INTEGER NOT NULL DEFAULT 0,
        expires_at INTEGER NULL,
        last_seen_at INTEGER NULL,
        remind_after_days INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE note_search (
        note_id INTEGER NOT NULL PRIMARY KEY
          REFERENCES notes (id) ON DELETE CASCADE,
        body_folded TEXT NOT NULL DEFAULT '',
        photo_folded TEXT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE settings (
        id INTEGER NOT NULL DEFAULT 1,
        theme_mode INTEGER NOT NULL DEFAULT 2,
        density INTEGER NOT NULL DEFAULT 1,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        default_retention INTEGER NOT NULL DEFAULT 0,
        locale INTEGER NOT NULL DEFAULT 0,
        default_custom_minutes INTEGER NOT NULL DEFAULT 0,
        pro_unlocked INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      -- Pro açık: hatırlatma şalteri modelde `proUnlocked && reminderEnabled`
      -- ile maskeleniyor, ücretsiz bir satırda korunduğu görülemezdi.
      INSERT INTO settings (
        id, theme_mode, density, reminder_enabled, locale, pro_unlocked
      ) VALUES (1, 1, 0, 1, 3, 1);
      INSERT INTO notes (
        image_name, body, created_at, remind_after_days
      ) VALUES ('eski.jpg', 'v1 kaydı', 1754000000, 7);
      INSERT INTO note_search (note_id, body_folded, photo_folded)
        VALUES (1, 'v1 kaydi', 'fatura 4521');
      PRAGMA user_version = 1;
    ''');
    legacy.close();

    var database = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    var repository = SettingsRepository(database);
    final migrated = await repository.read();

    expect(migrated.themeMode, AppThemeMode.light);
    expect(migrated.density, FeedDensity.single);
    expect(migrated.reminderEnabled, isTrue);
    expect(migrated.accent, AppAccent.orange);

    // Kayıt göçten sağ çıktı ve v1'de olmayan sütunlar dürüst varsayılanlarla
    // doldu. v1'deki "7 gün sonra" mutlak ana çevrildi: o sürümde sayaç
    // başlangıcı olmadığı için kaydın kendi zamanından sayılır. Tek atışlıktı,
    // öyle de kaldı — aralık sıfır.
    final notes = NotesRepository(database: database, photos: photoStore);
    final restored = await notes.watchNotes().first;
    expect(restored, hasLength(1));
    expect(restored.single.body, 'v1 kaydı');
    expect(
      restored.single.remindAt,
      shiftLocalCalendarDays(restored.single.createdAt, 7),
    );
    expect(restored.single.remindEveryDays, 0);
    expect(restored.single.updatedAt, isNull);
    expect(restored.single.latitude, isNull);

    // Arama indeksi de göçten geçti: karedeki yazı hâlâ bulunuyor.
    expect((await notes.search('4521')).ids, {restored.single.id});

    await repository.setAccent(AppAccent.green);
    await database.close();

    database = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    repository = SettingsRepository(database);
    expect((await repository.read()).accent, AppAccent.green);

    await database.close();
    await sandbox.delete(recursive: true);
  });
}
