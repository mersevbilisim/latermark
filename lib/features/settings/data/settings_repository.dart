import 'package:drift/drift.dart';

import '../../../core/theme/app_accent.dart';
import '../../notes/data/notes_database.dart';
import '../../notes/domain/retention.dart';
import '../domain/app_locale.dart';
import '../domain/app_settings.dart';
import '../domain/pro_downgrade_policy.dart';

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

  Future<void> setAccent(AppAccent value) =>
      _write(SettingsTableCompanion(accent: Value(value)));

  Future<void> setDensity(FeedDensity value) =>
      _write(SettingsTableCompanion(density: Value(value)));

  /// Konum tercihi. Hatırlatmanın aksine Pro'ya bağlı değil: konum bir
  /// ücretli özellik değil, kaydın bir alanı.
  Future<void> setLocationEnabled(bool value) =>
      _write(SettingsTableCompanion(locationEnabled: Value(value)));

  Future<void> setReminderEnabled(bool value) => _db.transaction(() async {
    final row = await _db.select(_db.settingsTable).getSingleOrNull();
    // İzin istemi veya eski bir sheet downgrade'dan sonra tamamlanırsa free
    // kullanıcı ana şalteri yeniden açamamalı.
    final effective = value && (row?.proUnlocked ?? false);
    await _write(SettingsTableCompanion(reminderEnabled: Value(effective)));
  });

  Future<void> setDefaultRetention(RetentionChoice value) => _db.transaction(
    () async {
      final row = await _db.select(_db.settingsTable).getSingleOrNull();
      // Downgrade ile aynı transaction kuyruğunda okunur. Böylece Pro açıkken
      // açılmış bir custom sheet, hak kapandıktan sonra sonucu geç teslim etse
      // bile custom varsayılanı geri yazamaz.
      final isPro = row?.proUnlocked ?? false;
      final effective = isPro ? value : freeRetentionFallback(value);
      await _write(
        SettingsTableCompanion(
          defaultRetention: Value(effective.retention),
          defaultCustomMinutes: Value(effective.customMinutes),
        ),
      );
    },
  );

  Future<void> setLocale(AppLocale value) =>
      _write(SettingsTableCompanion(locale: Value(value)));

  Future<void> setProUnlocked(bool value) async {
    if (value) {
      await _write(const SettingsTableCompanion(proUnlocked: Value(true)));
      return;
    }

    // Hak ve Pro'ya özel gelecek-varsayılanı atomik değişir. Arada bir kare
    // kaydedilirse custom süreyle free kayıt üretilemez.
    await _db.transaction(() async {
      final row = await _db.select(_db.settingsTable).getSingleOrNull();
      final current = row == null
          ? const RetentionChoice.off()
          : RetentionChoice(
              row.defaultRetention,
              customMinutes: row.defaultCustomMinutes,
            );
      final fallback = freeRetentionFallback(current);

      // Mevcut custom notlar premium bir durum taşımaya devam etmez; ancak
      // free karşılığa geçiş hiçbir notun bitişini erkene çekemez. Hesap saf
      // domain politikasında, yazma ise hak değişimiyle aynı transaction'da.
      final customNotes = await (_db.select(
        _db.notes,
      )..where((note) => note.retention.equalsValue(Retention.custom))).get();
      for (final note in customNotes) {
        final normalized = freeNoteRetention(
          current: RetentionChoice.custom(note.customMinutes),
          createdAt: note.createdAt,
          currentExpiresAt: note.expiresAt,
        );
        await (_db.update(
          _db.notes,
        )..where((row) => row.id.equals(note.id))).write(
          NotesCompanion(
            retention: Value(normalized.choice.retention),
            customMinutes: const Value(0),
            expiresAt: Value(normalized.expiresAt),
          ),
        );
      }

      // Hem kurulmuş programı tetikleyen ana şalteri hem notların yeniden Pro
      // alınca sessizce geri gelebilecek isteklerini temizle. Tek SQL yazımı,
      // not akışına downgrade transaction'ı tamamlandığında yayın yapar.
      await _db
          .update(_db.notes)
          .write(const NotesCompanion(remindAfterDays: Value(0)));

      await _write(
        SettingsTableCompanion(
          proUnlocked: const Value(false),
          reminderEnabled: const Value(false),
          defaultRetention: Value(fallback.retention),
          defaultCustomMinutes: Value(fallback.customMinutes),
        ),
      );
    });
  }

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

  static AppSettings _toModel(SettingsRow? row) {
    if (row == null) return const AppSettings();

    final storedRetention = RetentionChoice(
      row.defaultRetention,
      customMinutes: row.defaultCustomMinutes,
    );
    // Eski sürümden ya da elle değiştirilmiş DB'den free+custom birleşimi
    // gelirse, kalıcı düzeltme yapılana kadar bile Compose güvenli değeri okur.
    final effectiveRetention = row.proUnlocked
        ? storedRetention
        : freeRetentionFallback(storedRetention);

    return AppSettings(
      themeMode: row.themeMode,
      accent: row.accent,
      density: row.density,
      reminderEnabled: row.proUnlocked && row.reminderEnabled,
      locationEnabled: row.locationEnabled,
      defaultRetention: effectiveRetention.retention,
      defaultCustomMinutes: effectiveRetention.customMinutes,
      locale: row.locale,
      proUnlocked: row.proUnlocked,
    );
  }
}
