import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/theme/accent_tone.dart';
import '../../../core/theme/app_accent.dart';
import '../../notes/data/notes_database.dart';
import '../../notes/domain/retention.dart';
import '../../paywall/domain/pro_limits.dart';
import '../../paywall/data/reminder_quota_store.dart';
import '../domain/app_locale.dart';
import '../domain/app_settings.dart';
import '../domain/pro_downgrade_policy.dart';

/// Tercihlerin tek giriş kapısı.
///
/// Drift üzerinden yayınlandığı için tema veya görünüm değiştiğinde arayüz
/// kendiliğinden döner; ayrıca uygulama kapansa da tercih kalıcıdır.
class SettingsRepository {
  SettingsRepository(
    this._db, {
    @visibleForTesting ReminderQuotaStore? reminderQuota,
  }) : _reminderQuota = reminderQuota ?? ReminderQuotaStore();

  final NotesDatabase _db;
  final ReminderQuotaStore _reminderQuota;
  Future<void>? _proWriteQueue;
  int _proWriteRevision = 0;

  Stream<AppSettings> watch() =>
      _db.select(_db.settingsTable).watchSingleOrNull().map(_toModel);

  Future<AppSettings> read() async =>
      _toModel(await _db.select(_db.settingsTable).getSingleOrNull());

  Future<void> setThemeMode(AppThemeMode value) =>
      _write(SettingsTableCompanion(themeMode: Value(value)));

  Future<void> setAccent(AppAccent value) =>
      _write(SettingsTableCompanion(accent: Value(value)));

  /// Özel vurgu tonunu yazar ve seçimi [AppAccent.custom]'a alır.
  ///
  /// İkisi tek yazıda: ayrı ayrı yazılsaydı arada bir akış yayını çıkar ve
  /// arayüz bir kare boyunca eski renkle yeni tonu karıştırırdı.
  Future<void> setCustomAccent(int hue) => _write(
    SettingsTableCompanion(
      accent: const Value(AppAccent.custom),
      accentHue: Value(AccentTone.normalizeHue(hue)),
    ),
  );

  Future<void> setDensity(FeedDensity value) =>
      _write(SettingsTableCompanion(density: Value(value)));

  /// Paylaşım imzası. Pro'ya bağlı değil; herkesin kapatabildiği bir tercih.
  Future<void> setShareSignature(bool value) =>
      _write(SettingsTableCompanion(shareSignature: Value(value)));

  /// Yalnız Latermark'ın sunum katmanını güçlendirir. Sistem erişilebilirlik
  /// tercihlerinin önceliği uygulamanın kökünde ayrıca korunur.
  Future<void> setAlwaysHighContrast(bool value) =>
      _write(SettingsTableCompanion(alwaysHighContrast: Value(value)));

  Future<void> setAlwaysReduceMotion(bool value) =>
      _write(SettingsTableCompanion(alwaysReduceMotion: Value(value)));

  /// Ana akışta kapatılmış zaman bölümleri.
  ///
  /// Boş ad süzülüyor ve sıra sabitleniyor: aynı küme her zaman aynı metne
  /// dönsün, yoksa değişmeyen bir tercih diske yeniden yazılır ve ayar akışı
  /// boşuna yayın yapar.
  Future<void> setCollapsedGroups(Set<String> value) {
    final names = value.where((name) => name.trim().isNotEmpty).toList()
      ..sort();
    return _write(
      SettingsTableCompanion(collapsedGroups: Value(names.join(','))),
    );
  }

  /// Konum tercihi. Hatırlatmanın aksine Pro'ya bağlı değil: konum bir
  /// ücretli özellik değil, kaydın bir alanı.
  Future<void> setLocationEnabled(bool value) =>
      _write(SettingsTableCompanion(locationEnabled: Value(value)));

  Future<void> setReminderEnabled(bool value) => _db.transaction(() async {
    final row = await _db.select(_db.settingsTable).getSingleOrNull();
    // İzin istemi veya eski bir sheet, ücretsiz deneme özelliği tümden
    // kapatıldıktan sonra tamamlanırsa ana şalteri yeniden açamamalı. Kota bu
    // katmanda aranmaz: hakkı yanmış bir not yeniden kurulabilir.
    final effective =
        value && ProLimits.remindersAvailable(isPro: row?.proUnlocked ?? false);
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

  /// Hakkı yazar; kapanışta downgrade temizliğini de koşturur.
  ///
  /// [now] yalnız testler içindir: hangi hatırlatmaların hâlâ önde olduğunu
  /// bu ana göre seçiyoruz.
  Future<void> setProUnlocked(
    bool value, {
    DateTime? now,
    int burnedFloor = 0,
  }) {
    final revision = ++_proWriteRevision;
    final previous = _proWriteQueue;
    late final Future<void> operation;
    operation = (() async {
      if (previous != null) {
        // Önceki çağrının ürün hatasını sonraki mağaza kararına taşıma. Kuyruk
        // yalnız sıralama sağlar; her çağıran kendi operation hatasını görür.
        try {
          await previous;
        } on Object {
          // Önceki operation'ın hatası zaten kendi çağıranına teslim edildi.
        }
      }

      try {
        await _applyProUnlocked(
          value,
          revision: revision,
          now: now,
          burnedFloor: burnedFloor,
        );
      } finally {
        // Yalnız kuyruğun sonundaki çağrı kilidi açar. Boş kuyrukta araya bir
        // Future koymamak, Drift işlemini çağıranın Zone'unda başlatır; bu hem
        // widget FakeAsync yaşam döngüsünü hem de uygulama kapanışını korur.
        if (identical(_proWriteQueue, operation)) _proWriteQueue = null;
      }
    })();
    _proWriteQueue = operation;
    return operation;
  }

  Future<void> _applyProUnlocked(
    bool value, {
    required int revision,
    required DateTime? now,
    required int burnedFloor,
  }) async {
    if (revision != _proWriteRevision) return;
    if (value) {
      await _write(const SettingsTableCompanion(proUnlocked: Value(true)));
      return;
    }

    // Keychain çağrısını SQLite transaction'ının içinde bekletme. Önce ucuz
    // bir snapshot ile bunun gerçekten downgrade olup olmadığını belirle;
    // transaction yine kendi satırını yeniden okuyup yarışı doğrular.
    final snapshot = await _db.select(_db.settingsTable).getSingleOrNull();
    if (!(snapshot?.proUnlocked ?? false)) return;
    final persistedFloor = await _reminderQuota.read() ?? 0;
    // Keychain beklerken daha yeni bir satın alma teyidi geldiyse bu iade
    // fotoğrafı artık eskidir. Destructive downgrade hiç başlamamalı.
    if (revision != _proWriteRevision) return;
    final effectiveFloor = persistedFloor > burnedFloor
        ? persistedFloor
        : burnedFloor;

    // Hak ve Pro'ya özel gelecek-varsayılanı atomik değişir. Arada bir kare
    // kaydedilirse custom süreyle free kayıt üretilemez.
    try {
      await _db.transaction(() async {
        final row = await _db.select(_db.settingsTable).getSingleOrNull();

        // Zaten ücretsiz katmandaysa **indirilecek bir hak yok**.
        //
        // Mağazanın "sahip değil" cevabı bir olay değil, ücretsiz kullanıcının
        // her açılışta aldığı normal cevap. Bu kapı olmadan o cevap downgrade
        // temizliğini yeniden koşturuyordu; hiç Pro olmamış birinin ücretsiz
        // hatırlatmaları da o süpürmeye giriyordu. Temizlik yıkıcı ve geri
        // alınamaz olduğu için önkoşulu çağıranın zamanlamasına bırakılamaz.
        if (!(row?.proUnlocked ?? false)) return;

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

        // Ücretsiz katmanın kendi hakkı downgrade'den sağ çıkıyor.
        //
        // Hepsini silmek, kullanıcının bu katmanda kurmaya **hakkı olan** bir
        // şeyi paywall yüzünden silmek olurdu. Önde duran en yakın
        // [ProLimits.freeReminders] hatırlatma yaşıyor; geri kalanı, yeniden Pro
        // alınca sessizce geri gelmesin diye siliniyor.
        //
        // Seçim tarihe göre: çalma anı geçmiş bir istek zaten geri gelmeyecek,
        // ücretsiz katmanın sayılı slotunu ona harcamak kullanıcıya hiçbir şey
        // vermezdi.
        final used = {
          for (final id in (row?.freeReminderNotes ?? '').split(','))
            if (int.tryParse(id.trim()) case final parsed?)
              if (parsed > 0) parsed,
        };
        final freshSlots = ProLimits.remainingReminders(
          used,
          burnedFloor: effectiveFloor,
        );
        final keep = <int>{};
        if (ProLimits.freeRemindersEnabled) {
          final moment = now ?? DateTime.now();

          // Daha önce hakkı yanmış bir notu yeniden kurmak ikinci hak değildir;
          // Pro sırasında ileri alınmış olsa da downgrade'de yaşamaya devam eder.
          if (used.isNotEmpty) {
            final alreadyPaid =
                await (_db.select(_db.notes)..where(
                      (note) =>
                          note.id.isIn(used) &
                          note.remindAt.isBiggerThanValue(moment),
                    ))
                    .get();
            keep.addAll(alreadyPaid.map((note) => note.id));
          }

          // Yalnız gerçekten boş kalan Free slotlara en yakın yeni Pro
          // hatırlatmaları yerleşir. Keychain tabanı DB kimliklerinden büyükse
          // yeniden kurulumla geri gelmiş sahte boşluk da burada kapanır.
          if (freshSlots > 0) {
            final fresh =
                await (_db.select(_db.notes)
                      ..where(
                        (note) =>
                            note.remindAt.isBiggerThanValue(moment) &
                            (used.isEmpty
                                ? const Constant(true)
                                : note.id.isNotIn(used)),
                      )
                      ..orderBy([(note) => OrderingTerm.asc(note.remindAt)])
                      ..limit(freshSlots))
                    .get();
            keep.addAll(fresh.map((note) => note.id));
          }
        }

        // Tek SQL yazımı, not akışına downgrade transaction'ı tamamlandığında
        // yayın yapar.
        await (_db.update(_db.notes)..where(
              (note) => keep.isEmpty
                  ? note.remindAt.isNotNull()
                  : note.id.isNotIn(keep),
            ))
            .write(
              const NotesCompanion(
                remindAt: Value(null),
                remindEveryDays: Value(0),
              ),
            );

        // Kalanlarda ritim yok: ücretsiz katmanda tekrar Pro'ya ait. Tek hakla
        // sınırsız bildirim üreten bir kayıt, sayının anlamını bitirirdi.
        if (keep.isNotEmpty) {
          await (_db.update(_db.notes)..where((note) => note.id.isIn(keep)))
              .write(const NotesCompanion(remindEveryDays: Value(0)));
        }

        await _write(
          SettingsTableCompanion(
            proUnlocked: const Value(false),
            // Ana şalter, ücretsiz katmanda hatırlatma diye bir şey **yoksa**
            // kapanıyor. Varsa kullanıcının niyeti duruyor: sağ kalan
            // hatırlatmaları kapalı bir şalterin arkasında bırakmak, onları
            // silmenin sessiz hâli olurdu.
            reminderEnabled: ProLimits.freeRemindersEnabled
                ? const Value.absent()
                : const Value(false),
            defaultRetention: Value(fallback.retention),
            defaultCustomMinutes: Value(fallback.customMinutes),
          ),
        );

        // Uzun bir arşivin normalizasyonu sırasında daha yeni bir hak kararı
        // geldiyse transaction geri alınır. Yeni karar kuyrukta hemen arkasından
        // uygulanacak; eski iade fotoğrafı Pro verisini kalıcı silemez.
        if (revision != _proWriteRevision) {
          throw const _SupersededEntitlementWrite();
        }
      });
    } on _SupersededEntitlementWrite {
      // Beklenen yarış sonucu; transaction rollback'i düzeltmenin kendisidir.
    }
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
      accentHue: row.accentHue,
      density: row.density,
      reminderEnabled:
          ProLimits.remindersAvailable(isPro: row.proUnlocked) &&
          row.reminderEnabled,
      locationEnabled: row.locationEnabled,
      defaultRetention: effectiveRetention.retention,
      defaultCustomMinutes: effectiveRetention.customMinutes,
      locale: row.locale,
      shareSignature: row.shareSignature,
      alwaysHighContrast: row.alwaysHighContrast,
      alwaysReduceMotion: row.alwaysReduceMotion,
      collapsedGroups: {
        for (final name in row.collapsedGroups.split(','))
          if (name.trim().isNotEmpty) name.trim(),
      },
      // Bozuk ya da elle düzenlenmiş bir değer açılışı düşürmemeli; sayıya
      // çevrilemeyen parça sessizce atılıyor.
      freeReminderNotes: {
        for (final id in row.freeReminderNotes.split(','))
          if (int.tryParse(id.trim()) case final parsed?)
            if (parsed > 0) parsed,
      },
      proUnlocked: row.proUnlocked,
    );
  }
}

final class _SupersededEntitlementWrite implements Exception {
  const _SupersededEntitlementWrite();
}
