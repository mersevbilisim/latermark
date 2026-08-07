import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Karedeki yazıyı okur. Sonuç yalnızca aramayı besler.
///
/// **Flutter paketi kullanılmıyor**, her platform kendi yerel çözümüyle:
///
/// * iOS → Apple `Vision`. İşletim sisteminin parçası, çözülecek bağımlılık
///   yok, paket boyutu artmıyor.
/// * Android → ML Kit, doğrudan Gradle bağımlılığı olarak.
///
/// Sebebi mimari: `google_mlkit_text_recognition` eklentisi iOS tarafında
/// CocoaPods zorunlu kılıyor ve projenin Swift Package Manager kurulumunu
/// bozuyordu. İki ince kanal, o kurulumu bozmadan aynı işi yapıyor.
///
/// Her iki tarafta da işlem cihaz üstünde — fotoğraf hiçbir yere gitmiyor.
/// Uygulamanın "her şey telefonunda kalır" duruşu bulut OCR'ı zaten eliyordu.
class OcrService {
  OcrService({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('latermark/ocr');

  final MethodChannel _channel;

  bool get supported => Platform.isIOS || Platform.isAndroid;

  /// Karedeki metni döner.
  ///
  /// Dönüş değerinin üç hâli var ve üçü de anlamlı:
  ///
  /// * metin → okundu, bulunan yazı bu
  /// * `''`  → okundu, karede yazı yok
  /// * `null` → **okunamadı**, sonra yeniden denenmeli
  ///
  /// Son ikisini karıştırmamak Android'de kritik: ML Kit modeli APK'da gömülü
  /// değil, ilk kullanımda Play Services'ten iniyor. O aralıktaki başarısızlığı
  /// "yazı yok" saymak, kareyi kalıcı olarak taranmış işaretler ve model
  /// indikten sonra bir daha hiç denenmezdi.
  Future<String?> read(File image) async {
    if (!supported || !image.existsSync()) return null;

    try {
      return await _channel.invokeMethod<String>('read', {'path': image.path});
    } on PlatformException catch (error) {
      debugPrint('Kare okunamadı (${image.path}): $error');
      return null;
    } on MissingPluginException {
      // Kanal yoksa (test, masaüstü) sessizce geç.
      return null;
    }
  }
}
