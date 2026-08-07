import 'package:drift/drift.dart';

import '../../notes/data/notes_database.dart';
import '../../notes/domain/retention.dart';
import '../domain/app_locale.dart';
import '../domain/app_settings.dart';

/// Tercihlerin tek giriş kapısı.
///
/// Drift üzerinden yayınlandığı için tema veya görünüm değiştiğinde arayüz
/// kendiliğinden döner; ayrıca uygulama kapansa da tercih kalıcıdır.
class SettingsRepository {
  SettingsRepository(this._db);

  final NotesDatabase _db;

  Stream<AppSettings> watch() =>
      _db.select(_db.settingsTable).watchSingleOrNull().map(_toModel);

  Future<AppSettings> read() async =>
      _toModel(await _db.select(_db.settingsTable).getSingleOrNull());

  Future<void> setThemeMode(AppThemeMode value) =>
      _write(SettingsTableCompanion(themeMode: Value(value)));

  Future<void> setDensity(FeedDensity value) =>
      _write(SettingsTableCompanion(density: Value(value)));

  Future<void> setReminderEnabled(bool value) =>
      _write(SettingsTableCompanion(reminderEnabled: Value(value)));

  Future<void> setDefaultRetention(RetentionChoice value) => _write(
    SettingsTableCompanion(
      defaultRetention: Value(value.retention),
      defaultCustomMinutes: Value(value.customMinutes),
    ),
  );

  Future<void> setLocale(AppLocale value) =>
      _write(SettingsTableCompanion(locale: Value(value)));

  Future<void> setProUnlocked(bool value) =>
      _write(SettingsTableCompanion(proUnlocked: Value(value)));

  Future<void> _write(SettingsTableCompanion changes) async {
    final query = _db.update(_db.settingsTable)..where((t) => t.id.equals(1));
    final updated = await query.write(changes);
    // Satır beklenmedik biçimde yoksa (ör. elle silinmişse) yeniden kur.
    if (updated == 0) {
      await _db
          .into(_db.settingsTable)
          .insert(changes.copyWith(id: const Value(1)));
    }
  }

  static AppSettings _toModel(SettingsRow? row) => row == null
      ? const AppSettings()
      : AppSettings(
          themeMode: row.themeMode,
          density: row.density,
          reminderEnabled: row.reminderEnabled,
          defaultRetention: row.defaultRetention,
          defaultCustomMinutes: row.defaultCustomMinutes,
          locale: row.locale,
          proUnlocked: row.proUnlocked,
        );
}
