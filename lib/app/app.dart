import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_palette.dart';
import '../l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/backup/data/backup_service.dart';
import '../features/review/review_prompt_service.dart';
import '../features/notes/presentation/home/home_page.dart';
import '../features/settings/data/settings_repository.dart';
import 'app_scope.dart';
import '../l10n/l10n_context.dart';

/// Uygulamanın kökü: tema, dil ve depo bağlaması. Ekranlara ait hiçbir mantık
/// burada durmaz.
class LatermarkApp extends StatelessWidget {
  const LatermarkApp({
    super.key,
    required this.notes,
    required this.settings,
    this.backups,
    this.reviewPrompts,
    this.countRecoverableFrames,
    this.onRepairArchive,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final BackupService? backups;
  final ReviewPromptService? reviewPrompts;

  /// Arşiv okunamadığında diskte kaç karenin kurtarılabileceği.
  final Future<int> Function()? countRecoverableFrames;

  /// Onarımı yürütür ve kurtarılan kare sayısını döner. Yığını tazelemek
  /// gerektiği için sahibi [LatermarkBoot]; buradan yalnızca geçiyor.
  final Future<int> Function()? onRepairArchive;

  @override
  Widget build(BuildContext context) {
    // AppScope, MaterialApp'in ÜSTÜNDE durmalı. `home:` içine konursa
    // Navigator'ın altında kalır ve sonradan push edilen sayfalar (kamera,
    // yazma, detay) onu bulamaz. Ayrıca tema tercihini de o taşıyor.
    return AppScope(
      notes: notes,
      settings: settings,
      backups: backups,
      reviewPrompts: reviewPrompts,
      countRecoverableFrames: countRecoverableFrames,
      onRepairArchive: onRepairArchive,
      child: Builder(
        builder: (context) {
          final preferences = AppScope.preferences(context);

          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(preferences.accent, preferences.accentHue),
            darkTheme: AppTheme.dark(preferences.accent, preferences.accentHue),
            themeMode: preferences.themeMode.flutterMode,
            // `null` ise Flutter telefonun dilini kullanır ve eşleşme yoksa
            // aşağıdaki çözümleyici devreye girer.
            locale: preferences.locale.locale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: L10n.localizationsDelegates,
            localeResolutionCallback: _resolveLocale,
            builder: (context, child) {
              // Durum çubuğu ikonları temaya göre; ayrıca sistem yazı ölçeği
              // aşırı büyüdüğünde düzenin dağılmaması için makul bir tavan.
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.overlayFor(context.palette.brightness),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const HomePage(),
          );
        },
      ),
    );
  }

  /// Telefonun dili desteklenmiyorsa İngilizce'ye düşer.
  ///
  /// Flutter'ın varsayılanı, eşleşme bulamazsa `supportedLocales` listesinin
  /// *ilk* öğesini seçer — bu, listeye hangi dilin önce yazıldığına bağlı
  /// rastgele bir sonuç demek. Geri düşülecek dili burada açıkça söylüyoruz.
  ///
  /// Önce tam eşleşme (dil + ülke), sonra yalnızca dil denenir; böylece
  /// `pt_PT` konuşan bir telefon `pt_BR` çevirisini alır.
  static Locale? _resolveLocale(Locale? device, Iterable<Locale> supported) {
    if (device == null) return const Locale('en');

    for (final locale in supported) {
      if (locale.languageCode == device.languageCode &&
          locale.countryCode == device.countryCode) {
        return locale;
      }
    }
    for (final locale in supported) {
      if (locale.languageCode == device.languageCode) return locale;
    }
    return const Locale('en');
  }
}
