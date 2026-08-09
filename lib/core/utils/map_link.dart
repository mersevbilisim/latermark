import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bir koordinatı cihazın kendi harita uygulamasında açar.
///
/// **Ters geocoding yapılmaz.** "41,2607, 29,0421" değerini "Uludağ, Bursa"ya
/// çevirmek Apple ya da Google sunucusuna bir istek demek; uygulama bunu
/// kullanıcı adına, arka planda ve haberi olmadan yapmaz. Koordinat cihazda
/// durur, ağa yalnızca **kullanıcı dokunduğunda** ve onun harita uygulaması
/// üzerinden çıkar. Böylece "her şey telefonunda kalır" sözü, konum eklendikten
/// sonra da aynen geçerli kalıyor.
abstract final class MapLink {
  /// Koordinatın harita adresi.
  ///
  /// Bilinçli olarak `maps://` ya da `geo:` değil, **https**. Üç sebebi var:
  /// iOS bu adresi universal link olarak tanıyıp Apple Haritalar'ı kendisi
  /// açıyor, Android'de app link Google Haritalar'a yönlendiriyor, ve harita
  /// uygulaması hiç yoksa adres tarayıcıda anlamlı bir sayfa açıyor. Özel
  /// şema kullanılsaydı üçü de elle çözülmek zorunda kalır, üstelik Android'de
  /// manifest'e ayrıca `<queries>` girişi gerekirdi.
  ///
  /// Etiket olarak koordinatın kendisi geçiliyor: uydurma bir isim yazmaktansa
  /// iğnenin altında ne olduğunu tam olarak söylemek daha dürüst.
  static Uri of(double latitude, double longitude) {
    final pair = '$latitude,$longitude';
    if (!kIsWeb && Platform.isAndroid) {
      return Uri.parse('https://www.google.com/maps/search/?api=1&query=$pair');
    }
    return Uri.parse('https://maps.apple.com/?ll=$pair&q=$pair');
  }

  /// Koordinatın okunabilir hâli: `41,2607° K · 29,0421° D`.
  ///
  /// Yön harfleri arayüz dilinden gelir; eksi işaretiyle güney/batı yazmak
  /// haritaya bakmayan biri için okunmaz.
  static String format(
    double latitude,
    double longitude, {
    required String north,
    required String south,
    required String east,
    required String west,
  }) {
    final lat = latitude.abs().toStringAsFixed(4);
    final lng = longitude.abs().toStringAsFixed(4);
    return '$lat° ${latitude >= 0 ? north : south}  ·  '
        '$lng° ${longitude >= 0 ? east : west}';
  }

  /// Haritayı açar.
  ///
  /// [LaunchMode.externalApplication] ile başlanıyor — çünkü kurulu bir harita
  /// uygulaması varsa kullanıcının gitmek istediği yer orası, uygulama içi bir
  /// web görünümü değil. `inAppBrowserView` kullanılsaydı `SFSafariViewController`
  /// universal link'i başka uygulamaya devretmez ve kullanıcı haritanın web
  /// sürümüne düşerdi. Ancak dış açılış başarısız olursa gizlilik metnindeki
  /// gibi uygulama içi tarayıcıya düşülüyor: kullanıcı uygulamadan hiç
  /// çıkamamaktansa içeride bir sayfa görsün.
  static Future<bool> open(double latitude, double longitude) async {
    final url = of(latitude, longitude);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (error) {
      debugPrint('Harita dışarıda açılamadı ($url): $error');
    }

    try {
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (error) {
      debugPrint('Harita uygulama içinde de açılamadı ($url): $error');
      return false;
    }
  }
}
