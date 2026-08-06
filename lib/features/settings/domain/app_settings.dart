import 'package:flutter/material.dart' show ThemeMode;

/// Tema tercihi.
///
/// UYARI: Veritabanında `index` olarak saklanır; sırayı değiştirmeyin.
enum AppThemeMode {
  system('Sistem'),
  light('Aydınlık'),
  dark('Karanlık');

  const AppThemeMode(this.label);
  final String label;

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
  single('Büyük'),

  /// İki sütun; daha çok kayıt tek bakışta.
  grid('Izgara');

  const FeedDensity(this.label);
  final String label;

  FeedDensity get other =>
      this == FeedDensity.single ? FeedDensity.grid : FeedDensity.single;
}

/// "Bu nota şu kadar gün bakmazsam hatırlat."
///
/// UYARI: Veritabanında `index` olarak saklanır; sırayı değiştirmeyin.
enum ReminderDelay {
  threeDays(Duration(days: 3), '3 Gün'),
  oneWeek(Duration(days: 7), '1 Hafta'),
  twoWeeks(Duration(days: 14), '2 Hafta');

  const ReminderDelay(this.duration, this.label);

  final Duration duration;
  final String label;
}

/// Tüm tercihler tek bir değer nesnesinde.
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.density = FeedDensity.single,
    this.reminderEnabled = false,
    this.reminderDelay = ReminderDelay.oneWeek,
  });

  final AppThemeMode themeMode;
  final FeedDensity density;

  /// Bildirim izni verilmemişse bu yine `true` olabilir; izin ayrı bir konudur
  /// ve her planlamada yeniden denenir.
  final bool reminderEnabled;

  final ReminderDelay reminderDelay;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    FeedDensity? density,
    bool? reminderEnabled,
    ReminderDelay? reminderDelay,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    density: density ?? this.density,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderDelay: reminderDelay ?? this.reminderDelay,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.density == density &&
      other.reminderEnabled == reminderEnabled &&
      other.reminderDelay == reminderDelay;

  @override
  int get hashCode =>
      Object.hash(themeMode, density, reminderEnabled, reminderDelay);
}
