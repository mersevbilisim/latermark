import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/theme/accent_tone.dart';
import '../../../core/theme/app_accent.dart';
import '../../notes/domain/retention.dart';
import 'app_locale.dart';

/// Tema tercihi.
///
/// UYARI: Veritabanında `index` olarak saklanır; sırayı değiştirmeyin.
enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get flutterMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// Akışın sıkılığı: tek sütun büyük kartlar mı, iki sütun ızgara mı.
///
/// UYARI: Veritabanında `index` olarak saklanır; sırayı değiştirmeyin.
enum FeedDensity {
  /// Kareler bütün genişliği alır, en yeni kayıt daha da uzundur.
  single,

  /// İki sütun; daha çok kayıt tek bakışta.
  grid;

  FeedDensity get other =>
      this == FeedDensity.single ? FeedDensity.grid : FeedDensity.single;
}

/// Tüm tercihler tek bir değer nesnesinde.
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.accent = AppAccent.orange,
    this.accentHue = AccentTone.defaultHue,
    this.density = FeedDensity.grid,
    this.reminderEnabled = false,
    this.locationEnabled = false,
    this.defaultRetention = Retention.off,
    this.defaultCustomMinutes = 0,
    this.locale = AppLocale.system,
    this.shareSignature = true,
    this.alwaysHighContrast = false,
    this.alwaysReduceMotion = false,
    this.proUnlocked = false,
    this.collapsedGroups = const {},
    this.freeReminderNotes = const {},
  });

  final AppThemeMode themeMode;

  /// Kontroller, seçimler ve fotoğraf üstü etkileşimlerin vurgu rengi.
  final AppAccent accent;

  /// [AppAccent.custom] seçiliyken kullanıcının tonu (0–359). Diğer
  /// seçimlerde okunmuyor ama korunuyor: kullanıcı küratörlü bir renge geçip
  /// geri döndüğünde kendi tonunu yeniden ayarlamak zorunda kalmasın.
  final int accentHue;

  final FeedDensity density;

  /// Hatırlatmaların ana şalteri. Kapalıysa hiçbir not bildirim göndermez;
  /// açıkken yalnızca kullanıcının açıkça süre verdiği notlar gönderir.
  ///
  /// Bildirim izni verilmemişse bu yine `true` olabilir; izin ayrı bir konudur
  /// ve her planlamada yeniden denenir.
  final bool reminderEnabled;

  /// Yeni kayıtlara çekim yeri iliştirilsin mi.
  ///
  /// Compose ekranındaki anahtarın varsayılanı. Kullanıcı bir kez açtığında
  /// her çekimde yeniden açmak zorunda kalmaz; kapattığında da öyle.
  final bool locationEnabled;

  /// Yeni kayıtların açılacağı saklama süresi.
  final Retention defaultRetention;

  /// [Retention.custom] seçiliyse varsayılan özel süre (dakika).
  final int defaultCustomMinutes;

  /// Arayüz dili. [AppLocale.system] ise telefonun dili izlenir.
  final AppLocale locale;

  /// Paylaşılan notun sonuna Latermark satırı eklensin mi. Varsayılan açık.
  final bool shareSignature;

  /// Sistem tercihi kapalı olsa da Latermark içinde yüksek kontrast kullan.
  /// Sistem yüksek kontrastı açıksa uygulama bunu geri kapatamaz.
  final bool alwaysHighContrast;

  /// Sistem tercihi kapalı olsa da Latermark içindeki hareketi azalt.
  /// Sistem hareketi azaltmışsa uygulama bunu geri açamaz.
  final bool alwaysReduceMotion;

  /// Ana akışta kapatılmış zaman bölümlerinin adları.
  ///
  /// Ad taşınıyor, `enum` değil: `NoteAgeGroup` bu katmanın altında ve
  /// tanımadığı bir ad geldiğinde ayarların tamamının okunamaz hâle gelmesi
  /// kabul edilemez. Çözümleme akışın kendi işi.
  final Set<String> collapsedGroups;

  /// Ücretsiz hatırlatma hakkını harcamış kayıtların kimlikleri.
  ///
  /// Pro açıkken hiç okunmaz. Bkz. `ProLimits.allowsReminder`.
  final Set<int> freeReminderNotes;

  /// Pro hakkının son bilinen durumu (önbellek; kaynağı mağaza).
  final bool proUnlocked;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppAccent? accent,
    int? accentHue,
    FeedDensity? density,
    bool? reminderEnabled,
    Retention? defaultRetention,
    int? defaultCustomMinutes,
    AppLocale? locale,
    bool? shareSignature,
    bool? alwaysHighContrast,
    bool? alwaysReduceMotion,
    Set<String>? collapsedGroups,
    Set<int>? freeReminderNotes,
    bool? proUnlocked,
    bool? locationEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    accentHue: accentHue ?? this.accentHue,
    density: density ?? this.density,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    locationEnabled: locationEnabled ?? this.locationEnabled,
    defaultRetention: defaultRetention ?? this.defaultRetention,
    defaultCustomMinutes: defaultCustomMinutes ?? this.defaultCustomMinutes,
    locale: locale ?? this.locale,
    shareSignature: shareSignature ?? this.shareSignature,
    alwaysHighContrast: alwaysHighContrast ?? this.alwaysHighContrast,
    alwaysReduceMotion: alwaysReduceMotion ?? this.alwaysReduceMotion,
    collapsedGroups: collapsedGroups ?? this.collapsedGroups,
    freeReminderNotes: freeReminderNotes ?? this.freeReminderNotes,
    proUnlocked: proUnlocked ?? this.proUnlocked,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.accent == accent &&
      other.accentHue == accentHue &&
      other.density == density &&
      other.reminderEnabled == reminderEnabled &&
      other.defaultRetention == defaultRetention &&
      other.defaultCustomMinutes == defaultCustomMinutes &&
      other.locale == locale &&
      other.shareSignature == shareSignature &&
      other.alwaysHighContrast == alwaysHighContrast &&
      other.alwaysReduceMotion == alwaysReduceMotion &&
      // Küme eşitliği Dart'ta kimlik üzerinden: içerik karşılaştırılmazsa
      // her ayar yayını "değişti" sayılır ve ana ekran boşuna yeniden kurulur.
      setEquals(other.collapsedGroups, collapsedGroups) &&
      setEquals(other.freeReminderNotes, freeReminderNotes) &&
      other.proUnlocked == proUnlocked;

  @override
  int get hashCode => Object.hash(
    themeMode,
    accent,
    accentHue,
    density,
    reminderEnabled,
    defaultRetention,
    defaultCustomMinutes,
    locale,
    shareSignature,
    alwaysHighContrast,
    alwaysReduceMotion,
    Object.hashAllUnordered(collapsedGroups),
    Object.hashAllUnordered(freeReminderNotes),
    proUnlocked,
  );
}
