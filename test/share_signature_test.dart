import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Paylaşım imzasının tercihi. Metnin kendisi `share_message_test.dart`'ta;
/// burada sınanan şey anahtarın nerede durduğu ve **açık** doğduğu.
void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_signature');
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('yeni kurulumda imza açık gelir', () async {
    final database = NotesDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);

    expect((await SettingsRepository(database).read()).shareSignature, isTrue);
  });

  test('kapatma kalıcıdır', () async {
    final path = '${sandbox.path}/prefs.sqlite';
    var database = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    await SettingsRepository(database).setShareSignature(false);
    await database.close();

    database = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    addTearDown(database.close);
    expect((await SettingsRepository(database).read()).shareSignature, isFalse);
  });

  test('v8 kurulumunda imza açık olarak doğar', () async {
    // Mevcut kullanıcılar için de varsayılan açık: anahtar Ayarlar'da görünür
    // yerde duruyor ve kapatılabiliyor.
    final path = '${sandbox.path}/v8.sqlite';
    final seed = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    await seed.select(seed.settingsTable).get();
    await seed.close();

    final v8 = raw.sqlite3.open(path);
    v8.execute(
      'ALTER TABLE notes DROP COLUMN original_name; '
      'ALTER TABLE settings DROP COLUMN share_signature; '
      'PRAGMA user_version = 8;',
    );
    v8.close();

    final migrated = NotesDatabase.forExecutor(NativeDatabase(File(path)));
    addTearDown(migrated.close);
    expect((await SettingsRepository(migrated).read()).shareSignature, isTrue);
  });
}
