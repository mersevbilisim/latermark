import 'dart:ui';

import 'app_localizations.dart';

/// Cihazın dilini uygulamanın desteklediği bir yerele indirger.
///
/// Widget ağacının dışında metin kuran her yer (bildirimler, ana ekran
/// widget'ı) buradan geçmeli. Flutter'ın kendi çözümleyicisi eşleşme
/// bulamazsa `supportedLocales` listesinin **ilk** öğesine düşer — yani
/// sonuç, listeye hangi dilin önce yazıldığına bağlı bir rastlantı olur.
/// Geri düşülecek dil burada açıkça söyleniyor.
///
/// Önce tam eşleşme (dil + ülke), sonra yalnızca dil denenir; böylece `pt_PT`
/// konuşan bir telefon `pt_BR` çevirisini alır.
Locale resolveSupportedLocale(Locale device) {
  for (final locale in L10n.supportedLocales) {
    if (locale.languageCode == device.languageCode &&
        locale.countryCode == device.countryCode) {
      return locale;
    }
  }
  for (final locale in L10n.supportedLocales) {
    if (locale.languageCode == device.languageCode) return locale;
  }
  return const Locale('en');
}
