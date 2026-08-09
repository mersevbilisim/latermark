import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_accent.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
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
        expect(palette.onPhotoAccent, accent.onPhoto);
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
      expect(
        tester.getSemantics(find.byKey(const ValueKey('app-accent-violet'))),
        matchesSemantics(
          label: 'violet',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    },
  );

  test('latermark_db v1 renk sutununa veri kaybetmeden yukselir', () async {
    final sandbox = await Directory.systemTemp.createTemp('latermark_accent');
    final path = '${sandbox.path}/v1.sqlite';
    final legacy = raw.sqlite3.open(path);
    legacy.execute('''
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
      INSERT INTO settings (
        id, theme_mode, density, reminder_enabled, locale
      ) VALUES (1, 1, 0, 1, 3);
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

    await repository.setAccent(AppAccent.green);
    await database.close();

    database = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    repository = SettingsRepository(database);
    expect((await repository.read()).accent, AppAccent.green);

    await database.close();
    await sandbox.delete(recursive: true);
  });
}
