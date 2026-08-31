import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kaydedilen kareyi küçültür.
///
/// Kamera çıktısı olduğu gibi saklandığında kare başına ~3,5 MB tutuyordu.
/// Fiş, park yeri ve seri numarası fotoğrafları için bu gereksiz: uzun kenarı
/// sınırlamak boyutu birkaç kat düşürüyor, okunurluğu ise koruyor.
///
/// **Ayar yok, her zaman açık.** "Sıkıştırayım mı?" kullanıcının karşılığında
/// ne kaybettiğini bilemeyeceği bir soru; doğru varsayılanı bilinen bir şeyi
/// ayara çevirmek karar yükünü boşuna kullanıcıya devretmek olurdu.
///
/// Yerel kanal kullanılıyor çünkü `flutter_image_compress` iOS'ta CocoaPods
/// zorunlu kılıyor ve projenin Swift Package Manager kurulumunu bozardı.
class ImageCompressor {
  ImageCompressor({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting bool? supported,
  }) : _channel = channel ?? const MethodChannel('latermark/image'),
       _supportedOverride = supported;

  final MethodChannel _channel;

  /// Yerel kanal yalnız iOS/Android'de var. Testler bu kapıyı açıp sahte bir
  /// kanalla küçültme davranışını sınayabilsin diye ayrıldı.
  final bool? _supportedOverride;

  /// Saklanan karenin uzun kenarı için üst sınır.
  ///
  /// 2048, detay ekranındaki 4× yakınlaştırmada fiş yazısının okunur kalmasına
  /// yetiyor; bunun altına inmek küçük punto metinleri riske atardı.
  static const maxEdge = 2048;

  /// JPEG kalitesi. 88, gözle fark edilmeyen ama boyutu belirgin düşüren aralık.
  static const quality = 88;

  bool get supported =>
      _supportedOverride ?? (Platform.isIOS || Platform.isAndroid);

  /// Kareyi **yerinde** küçültür.
  ///
  /// Başarısız olursa dosyaya dokunulmaz ve `false` döner: sıkıştırma bir
  /// iyileştirme, kullanıcının karesini kaybetmektense büyük saklamak yeğdir.
  /// Kare zaten sınırın altındaysa da `false` döner — yeniden kodlamak
  /// yalnızca kalite kaybettirirdi.
  ///
  /// [edge] ve [quality] verilmezse saklama sınırları kullanılır. Izgaranın
  /// küçük kopyası aynı yolu daha küçük bir hedefle çağırıyor; iki platformun
  /// yerel tarafı da hedefi zaten parametre olarak alıyordu.
  Future<bool> compress(File image, {int? edge, int? quality}) async {
    if (!supported || !image.existsSync()) return false;

    try {
      final done = await _channel.invokeMethod<bool>('compress', {
        'path': image.path,
        'maxEdge': edge ?? ImageCompressor.maxEdge,
        'quality': quality ?? ImageCompressor.quality,
      });
      return done ?? false;
    } on PlatformException catch (error) {
      debugPrint('Kare küçültülemedi (${image.path}): $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
