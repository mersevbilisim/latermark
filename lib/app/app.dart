import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/presentation/home/home_page.dart';
import '../features/settings/data/settings_repository.dart';
import 'app_scope.dart';

/// Uygulamanın kökü: tema, dil ve depo bağlaması. Ekranlara ait hiçbir mantık
/// burada durmaz.
class LatermarkApp extends StatelessWidget {
  const LatermarkApp({
    super.key,
    required this.notes,
    required this.settings,
  });

  final NotesRepository notes;
  final SettingsRepository settings;

  @override
  Widget build(BuildContext context) {
    // AppScope, MaterialApp'in ÜSTÜNDE durmalı. `home:` içine konursa
    // Navigator'ın altında kalır ve sonradan push edilen sayfalar (kamera,
    // yazma, detay) onu bulamaz. Ayrıca tema tercihini de o taşıyor.
    return AppScope(
      notes: notes,
      settings: settings,
      child: Builder(
        builder: (context) {
          final preferences = AppScope.preferences(context);

          return MaterialApp(
            title: 'Latermark',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: preferences.themeMode.flutterMode,
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
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
}
