import '../features/notes/domain/retention.dart';
import '../features/settings/domain/app_locale.dart';
import '../features/settings/domain/app_settings.dart';
import 'app_localizations.dart';

/// Alan enum'larının ekranda görünen adları.
///
/// Etiketler enum'ların içinde sabit metin olarak duruyordu; çok dilli bir
/// uygulamada oraya yazılamazlar çünkü metin yürürlükteki dile bağlı. Enum'lar
/// yalnızca *anlamı* taşır, adlandırma bu dosyada.
extension RetentionLabels on Retention {
  String label(L10n l10n) => switch (this) {
    Retention.off => l10n.retentionOff,
    Retention.threeDays => l10n.retentionThreeDays,
    Retention.oneWeek => l10n.retentionOneWeek,
    Retention.custom => l10n.retentionCustom,
  };

  String description(L10n l10n) => switch (this) {
    Retention.off => l10n.retentionOffDescription,
    Retention.threeDays => l10n.retentionThreeDaysDescription,
    Retention.oneWeek => l10n.retentionOneWeekDescription,
    Retention.custom => l10n.retentionCustomDescription,
  };
}

extension RetentionChoiceLabels on RetentionChoice {
  /// Seçimin okunur hâli. Özel sürede sayının kendisi yazılır.
  String label(L10n l10n) =>
      retention.isCustom ? formatMinutes(l10n, customMinutes) : retention.label(l10n);
}

/// Dakikayı en büyük tam birime yuvarlayarak yazar: `6 saat`, `3 gün`,
/// `2 hafta`. Kullanıcı "72 saat" değil "3 gün" okumak ister.
String formatMinutes(L10n l10n, int minutes) {
  if (minutes <= 0) return l10n.retentionOff;
  if (minutes % 10080 == 0) return l10n.retentionCustomWeeks(minutes ~/ 10080);
  if (minutes % 1440 == 0) return l10n.retentionCustomDays(minutes ~/ 1440);
  return l10n.retentionCustomHours((minutes / 60).round());
}

extension ThemeModeLabels on AppThemeMode {
  String label(L10n l10n) => switch (this) {
    AppThemeMode.system => l10n.themeSystem,
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
  };
}

extension DensityLabels on FeedDensity {
  String label(L10n l10n) => switch (this) {
    FeedDensity.single => l10n.densityLarge,
    FeedDensity.grid => l10n.densityGrid,
  };
}

extension LocaleLabels on AppLocale {
  /// Dil adları çevrilmez; yalnızca "Sistem" seçeneği yürürlükteki dile döner.
  String label(L10n l10n) =>
      this == AppLocale.system ? l10n.languageSystem : nativeName;
}
