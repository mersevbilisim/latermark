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
  ImageCompressor({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('latermark/image');

  final MethodChannel _channel;

  /// Saklanan karenin uzun kenarı için üst sınır.
  ///
  /// 2048, detay ekranındaki 4× yakınlaştırmada fiş yazısının okunur kalmasına
  /// yetiyor; bunun altına inmek küçük punto metinleri riske atardı.
  static const maxEdge = 2048;

  /// JPEG kalitesi. 88, gözle fark edilmeyen ama boyutu belirgin düşüren aralık.
  static const quality = 88;

  bool get supported => Platform.isIOS || Platform.isAndroid;

  /// Kareyi **yerinde** küçültür.
  ///
  /// Başarısız olursa dosyaya dokunulmaz ve `false` döner: sıkıştırma bir
  /// iyileştirme, kullanıcının karesini kaybetmektense büyük saklamak yeğdir.
  /// Kare zaten sınırın altındaysa da `false` döner — yeniden kodlamak
  /// yalnızca kalite kaybettirirdi.
  Future<bool> compress(File image) async {
    if (!supported || !image.existsSync()) return false;

    try {
      final done = await _channel.invokeMethod<bool>('compress', {
        'path': image.path,
        'maxEdge': maxEdge,
        'quality': quality,
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
