import 'package:flutter/widgets.dart';

/// Uygulama dili tercihi.
///
/// Varsayılan [system]: uygulama telefonun dilini izler ve desteklenmeyen bir
/// dilde açılırsa İngilizce'ye düşer (bkz. `LatermarkApp.localeResolution`).
/// Kullanıcı buradan açıkça bir dil seçerse sistem yok sayılır.
///
/// UYARI: Veritabanında `index` olarak saklanır; sırayı değiştirmeyin, yeni
/// diller **sona** eklenir.
enum AppLocale {
  system(null, 'Sistem'),
  turkish(Locale('tr'), 'Türkçe'),
  english(Locale('en'), 'English'),
  german(Locale('de'), 'Deutsch'),
  french(Locale('fr'), 'Français'),
  spanish(Locale('es'), 'Español'),
  portugueseBrazil(Locale('pt', 'BR'), 'Português (Brasil)'),
  japanese(Locale('ja'), '日本語'),
  korean(Locale('ko'), '한국어'),
  italian(Locale('it'), 'Italiano');

  const AppLocale(this.locale, this.nativeName);

  /// `null` ise sistem dili kullanılır.
  final Locale? locale;

  /// Seçim listesinde görünen ad.
  ///
  /// Dil adları **çevrilmez**: her dil kendi adıyla yazılır. Almanca bilmeyen
  /// biri "Almanca" yazısını arar, Almanca bilen "Deutsch" arar — ikincisi
  /// listeyi herkes için okunur kılıyor. Yalnızca [system] çevrilir.
  final String nativeName;
}
