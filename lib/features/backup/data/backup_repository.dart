import 'dart:io';

import 'package:drift/drift.dart';

import '../../notes/data/notes_database.dart';
import '../../notes/data/photo_store.dart';
import '../../notes/data/search_text.dart';
import '../../notes/domain/note_reminder.dart';
import '../../notes/domain/retention.dart';
import '../../settings/domain/app_locale.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/domain/pro_downgrade_policy.dart';
import '../../../core/theme/app_accent.dart';
import '../domain/backup_manifest.dart';

/// Yedeğin veritabanı tarafı: dışa aktarma ve **yerine koyma**.
///
/// Yedekleme mantığı `NotesRepository` yerine burada duruyor. Sebebi kapsam:
/// depo arayüzün gündelik kapısı, buradaki tek işlem ise tüm arşivi silip
/// yeniden kuran, geri dönüşü olmayan bir hareket. İkisini aynı sınıfa koymak
/// o hareketi fazla ulaşılabilir kılardı.
class BackupRepository {
  BackupRepository({
    required NotesDatabase database,
    required PhotoStore photos,
  }) : _db = database,
       _store = photos;

  final NotesDatabase _db;
  final PhotoStore _store;

  int get schemaVersion => _db.schemaVersion;

  /// Notları, karedeki yazının katlanmış hâliyle birlikte okur.
  ///
  /// Tek sorguda birleştiriliyor: her not için ayrı bir indeks sorgusu, bin
  /// kayıtlık bir arşivde bin ayrı gidiş dönüş demekti.
  Future<List<BackupNote>> exportNotes() async {
    final query = _db.select(_db.notes).join([
      leftOuterJoin(
        _db.noteSearch,
        _db.noteSearch.noteId.equalsExp(_db.notes.id),
      ),
    ])..orderBy([OrderingTerm.asc(_db.notes.createdAt)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        _toBackupNote(
          row.readTable(_db.notes),
          row.readTableOrNull(_db.noteSearch)?.photoFolded,
        ),
    ];
  }

  Future<File> photoFile(String imageName) async => _store.fileFor(imageName);

  static BackupNote _toBackupNote(Note note, String? photoFolded) => BackupNote(
    imageName: note.imageName,
    originalName: note.originalName,
    body: note.body,
    createdAt: note.createdAt,
    retention: note.retention.index,
    customMinutes: note.customMinutes,
    expiresAt: note.expiresAt,
    lastSeenAt: note.lastSeenAt,
    updatedAt: note.updatedAt,
    latitude: note.latitude,
    longitude: note.longitude,
    remindAt: note.remindAt,
    remindEveryDays: note.remindEveryDays,
    photoText: photoFolded,
  );

  /// Mevcut her şeyi silip yedektekini kurar.
  ///
  /// Kare klasörü önce atomik olarak değiştirilir ama eski klasör DB işlemi
  /// bitene kadar kenarda tutulur. Transaction düşerse fotoğraflar da geri
  /// alınır; kullanıcı yarım bir geri yükleme yüzünden mevcut karelerini
  /// kaybetmez.
  Future<void> replaceAll({
    required List<BackupNote> notes,
    required BackupSettings settings,
    required Directory stagedPhotos,
  }) async {
    final photos = await _store.beginReplaceAllFrom(stagedPhotos);
    final restoredAt = DateTime.now();

    try {
      await _db.transaction(() async {
        final currentSettings = await (_db.select(
          _db.settingsTable,
        )..where((row) => row.id.equals(1))).getSingleOrNull();
        final isPro = currentSettings?.proUnlocked ?? false;

        // `note_search` satırları yabancı anahtar üzerinden kendiliğinden
        // gidiyor (`beforeOpen` içinde `foreign_keys = ON`).
        await _db.delete(_db.notes).go();

        for (final note in notes) {
          final storedRetention = RetentionChoice(
            _retentionOf(note.retention),
            customMinutes: note.customMinutes,
          );
          final effectiveRetention = isPro
              ? FreeNoteRetention(
                  choice: storedRetention,
                  expiresAt: note.expiresAt,
                )
              : freeNoteRetention(
                  current: storedRetention,
                  createdAt: note.createdAt,
                  currentExpiresAt: note.expiresAt,
                );
          // Native bildirim kaydı yedek dosyasının parçası değildir; program
          // geri yüklemeden sonraki ilk senkronda yeniden kurulur.
          //
          // Eski arşivlerde mutlak an yok, yalnızca "kaç gün sonra" var: o
          // kayıtlar için geri sayı **geri yükleme anından** başlar.
          final restored = !isPro
              ? const ReminderChoice.off()
              : ReminderChoice(
                  at:
                      note.remindAt ??
                      (note.legacyRemindAfterDays > 0
                          ? shiftLocalCalendarDays(
                              restoredAt,
                              note.legacyRemindAfterDays,
                            )
                          : null),
                  cadence: ReminderCadence.fromCode(note.remindEveryDays),
                );

          final id = await _db
              .into(_db.notes)
              .insert(
                NotesCompanion.insert(
                  imageName: note.imageName,
                  originalName: Value(note.originalName),
                  body: Value(note.body),
                  createdAt: note.createdAt,
                  retention: Value(effectiveRetention.choice.retention),
                  customMinutes: Value(effectiveRetention.choice.customMinutes),
                  expiresAt: Value(effectiveRetention.expiresAt),
                  lastSeenAt: Value(note.lastSeenAt),
                  updatedAt: Value(note.updatedAt),
                  latitude: Value(note.latitude),
                  longitude: Value(note.longitude),
                  remindAt: Value(restored.at),
                  remindEveryDays: Value(
                    restored.repeats ? restored.everyDays : 0,
                  ),
                ),
              );

          await _db
              .into(_db.noteSearch)
              .insert(
                NoteSearchCompanion.insert(
                  noteId: Value(id),
                  // Gövde indeksi yeni sürümün katlama kuralıyla üretilir.
                  bodyFolded: Value(SearchText.fold(note.body)),
                  photoFolded: Value(note.photoText),
                  attempts: const Value(0),
                ),
              );
        }

        final storedDefault = RetentionChoice(
          _retentionOf(settings.defaultRetention),
          customMinutes: settings.defaultCustomMinutes,
        );
        final effectiveDefault = isPro
            ? storedDefault
            : freeRetentionFallback(storedDefault);

        // Pro hakkı dosyadan gelmez; transaction başında mağaza önbelleğinden
        // okunan mevcut hak korunur ve ücretli alanlar ona göre normalize olur.
        await (_db.update(
          _db.settingsTable,
        )..where((t) => t.id.equals(1))).write(
          SettingsTableCompanion(
            themeMode: Value(_enumOf(AppThemeMode.values, settings.themeMode)),
            accent: Value(_enumOf(AppAccent.values, settings.accent)),
            density: Value(_enumOf(FeedDensity.values, settings.density)),
            reminderEnabled: Value(isPro && settings.reminderEnabled),
            locationEnabled: Value(settings.locationEnabled),
            defaultRetention: Value(effectiveDefault.retention),
            defaultCustomMinutes: Value(effectiveDefault.customMinutes),
            locale: Value(_enumOf(AppLocale.values, settings.locale)),
          ),
        );
      });
      await photos.commit();
    } catch (_) {
      await photos.rollback();
      rethrow;
    }
  }

  Future<BackupSettings> exportSettings() async {
    final row = await (_db.select(
      _db.settingsTable,
    )..where((t) => t.id.equals(1))).getSingleOrNull();

    if (row == null) {
      const defaults = AppSettings();
      return BackupSettings(
        themeMode: defaults.themeMode.index,
        accent: defaults.accent.index,
        density: defaults.density.index,
        reminderEnabled: defaults.reminderEnabled,
        locationEnabled: defaults.locationEnabled,
        defaultRetention: defaults.defaultRetention.index,
        defaultCustomMinutes: defaults.defaultCustomMinutes,
        locale: defaults.locale.index,
      );
    }

    return BackupSettings(
      themeMode: row.themeMode.index,
      accent: row.accent.index,
      density: row.density.index,
      reminderEnabled: row.reminderEnabled,
      locationEnabled: row.locationEnabled,
      defaultRetention: row.defaultRetention.index,
      defaultCustomMinutes: row.defaultCustomMinutes,
      locale: row.locale.index,
    );
  }

  /// Enum indeksleri dosyadan geliyor; aralık dışı bir değer kurcalanmış ya da
  /// başka bir sürümden gelmiş demektir. Çökmek yerine ilk seçeneğe düşülüyor.
  static T _enumOf<T>(List<T> values, int index) =>
      index >= 0 && index < values.length ? values[index] : values.first;

  static Retention _retentionOf(int index) => _enumOf(Retention.values, index);
}
