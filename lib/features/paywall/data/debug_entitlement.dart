import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Geliştirme sırasında Pro hakkını mağazayı hiç aramadan açan anahtar.
///
/// Simülatörde StoreKit kum havuzu yok, gerçek cihazda da her denemede sandbox
/// hesabıyla yeniden satın almak gerekiyor. Oysa Pro'ya bağlı davranışların
/// (özel süre, hatırlatma, kare sınırının kalkması) her gün elle denenmesi
/// gerekiyor. Bu anahtar o yolu kısaltır: açıkken [PurchaseService] mağazaya
/// hiç sormadan "sahip" cevabını verir.
///
/// Yayınlanan uygulamada **hiç var olmaz**: [kDebugMode] false olduğunda hem
/// okuma hem yazma no-op'a düşer, dolayısıyla işaretçi dosyası da yazılmaz.
abstract final class DebugEntitlement {
  /// Uygulama destek klasöründe duran boş işaretçi. Varlığı "açık" demek.
  ///
  /// Ayrı bir tercih sütunu açmak yerine dosya: şema yalnızca ürünün gerçek
  /// alanlarını taşısın, geliştirme kolaylığı üretim veritabanına sızmasın.
  static const _fileName = 'debug_pro';

  /// Anahtar arayüzde görünsün mü.
  ///
  /// Testler de debug modda koşuyor; anahtarın orada da çizilmesi Ayarlar'ın
  /// yerleşim testlerine gerçekte olmayan bir satır eklerdi.
  static final bool available =
      kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST');

  static bool _forced = false;
  static File? _marker;

  /// Pro, mağaza sorulmadan elle açılmış mı.
  static bool get forced => available && _forced;

  /// Açılışta bir kez, `runApp`'ten önce çağrılır: ilk kare zaten doğru hakla
  /// çizilsin, uygulama gözün önünde free'den Pro'ya atlamasın.
  static Future<void> load() async {
    if (!available) return;
    try {
      _forced = (await _resolve()).existsSync();
    } catch (error) {
      debugPrint('[DEBUG PRO] İşaretçi okunamadı: $error');
    }
  }

  static Future<void> set(bool value) async {
    if (!available) return;
    _forced = value;
    try {
      final marker = await _resolve();
      if (value) {
        await marker.create(recursive: true);
      } else if (marker.existsSync()) {
        await marker.delete();
      }
    } catch (error) {
      debugPrint('[DEBUG PRO] İşaretçi yazılamadı: $error');
    }
  }

  static Future<File> _resolve() async {
    final cached = _marker;
    if (cached != null) return cached;
    final directory = await getApplicationSupportDirectory();
    return _marker = File(p.join(directory.path, _fileName));
  }
}
