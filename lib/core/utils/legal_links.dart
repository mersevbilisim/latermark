import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Gizlilik ve kullanım koşulları bağlantıları.
abstract final class LegalLinks {
  static const _privacyBase = 'https://www.mersev.com/latermark-app/privacy';

  /// Apple'ın standart lisans sözleşmesi.
  ///
  /// Kendi koşullarımızı yazmadığımız sürece App Store'un beklediği bağlantı
  /// budur; ayrıca Apple bunu kendi dillerinde sunuyor.
  static final terms = Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  /// Yürürlükteki arayüz diline göre gizlilik bağlantısı.
  ///
  /// Dil kodu [Localizations] üzerinden okunuyor — yani kullanıcının Ayarlar'da
  /// seçtiği dil değil, ekranda **gerçekten çizilen** dil. İkisi "Sistem"
  /// seçiliyken ayrışıyor ve doğru olan ikincisi. Bölge kodu düşürülüyor:
  /// hem `pt_PT` hem de `pt_BR` için `privacy-pt` açılır.
  static Uri privacy(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Uri.parse('$_privacyBase-$language');
  }

  /// Bağlantıyı uygulama içi tarayıcıda açar. Açılamazsa `false` döner.
  ///
  /// [LaunchMode.inAppBrowserView] iOS'ta `SFSafariViewController`, Android'de
  /// Custom Tabs açıyor: kullanıcı uygulamadan çıkmıyor ama adres çubuğu ve
  /// paylaşma yine duruyor. `inAppWebView` tercih edilmedi — o, adresi
  /// gizleyen ham bir web görünümü ve yasal metinde kullanıcının hangi siteye
  /// baktığını görebilmesi gerekir.
  ///
  /// Cihazda uygun bir tarayıcı yoksa harici uygulamaya düşer.
  static Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (error) {
      debugPrint('Uygulama içi tarayıcı açılamadı ($url): $error');
      try {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (fallbackError) {
        debugPrint('Bağlantı açılamadı ($url): $fallbackError');
        return false;
      }
    }
  }
}
