import 'package:flutter/material.dart' show ThemeMode;

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
    this.density = FeedDensity.grid,
    this.reminderEnabled = false,
    this.defaultRetention = Retention.off,
    this.defaultCustomMinutes = 0,
    this.locale = AppLocale.system,
    this.proUnlocked = false,
  });

  final AppThemeMode themeMode;
  final FeedDensity density;

  /// Hatırlatmaların ana şalteri. Kapalıysa hiçbir not bildirim göndermez;
  /// açıkken yalnızca kullanıcının açıkça süre verdiği notlar gönderir.
  ///
  /// Bildirim izni verilmemişse bu yine `true` olabilir; izin ayrı bir konudur
  /// ve her planlamada yeniden denenir.
  final bool reminderEnabled;

  /// Yeni kayıtların açılacağı saklama süresi.
  final Retention defaultRetention;

  /// [Retention.custom] seçiliyse varsayılan özel süre (dakika).
  final int defaultCustomMinutes;

  /// Arayüz dili. [AppLocale.system] ise telefonun dili izlenir.
  final AppLocale locale;

  /// Pro hakkının son bilinen durumu (önbellek; kaynağı mağaza).
  final bool proUnlocked;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    FeedDensity? density,
    bool? reminderEnabled,
    Retention? defaultRetention,
    int? defaultCustomMinutes,
    AppLocale? locale,
    bool? proUnlocked,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    density: density ?? this.density,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    defaultRetention: defaultRetention ?? this.defaultRetention,
    defaultCustomMinutes: defaultCustomMinutes ?? this.defaultCustomMinutes,
    locale: locale ?? this.locale,
    proUnlocked: proUnlocked ?? this.proUnlocked,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.density == density &&
      other.reminderEnabled == reminderEnabled &&
      other.defaultRetention == defaultRetention &&
      other.defaultCustomMinutes == defaultCustomMinutes &&
      other.locale == locale &&
      other.proUnlocked == proUnlocked;

  @override
  int get hashCode =>
      Object.hash(
        themeMode,
        density,
        reminderEnabled,
        defaultRetention,
        defaultCustomMinutes,
        locale,
        proUnlocked,
      );
}
