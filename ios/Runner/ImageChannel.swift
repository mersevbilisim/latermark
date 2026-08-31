import Flutter
import ImageIO
import UIKit

/// Kaydedilen kareyi küçültüp yeniden kodlar.
///
/// Kamera çıktısı olduğu gibi saklandığında kare başına ~3,5 MB tutuyordu;
/// fiş ve park yeri fotoğrafları için bu gereksiz. Uzun kenarı sınırlamak
/// boyutu birkaç kat düşürüyor, okunurluğu ise koruyor.
///
/// `flutter_image_compress` kullanılmadı: iOS tarafında CocoaPods zorunlu
/// kılıyor ve projenin Swift Package Manager kurulumunu bozardı.
enum ImageChannel {
  static let name = "latermark/image"

  /// Küçültme **tek sıra** üzerinde koşuyor.
  ///
  /// Eskiden `DispatchQueue.global()` kullanılıyordu ve o kuyruk eşzamanlı:
  /// arka arkaya gelen çağrılar paralel başlıyor ve her biri kendi karesini
  /// belleğe alıyordu. Arşiv geçişi gibi yüzlerce kareyi peş peşe küçülten bir
  /// iş sırasında süreç iOS'un bellek tavanını (~2 GB) aşıp öldürülüyordu.
  /// Android tarafı en baştan tek iş parçacığı kullanıyordu; burası artık aynı
  /// garantiyi veriyor.
  private static let queue = DispatchQueue(label: "latermark.image", qos: .utility)

  static func register(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "compress" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String,
        let maxEdge = arguments["maxEdge"] as? Int,
        let quality = arguments["quality"] as? Int
      else {
        result(false)
        return
      }

      queue.async {
        let done = compress(
          path: path,
          maxEdge: CGFloat(maxEdge),
          quality: CGFloat(quality) / 100
        )
        DispatchQueue.main.async { result(done) }
      }
    }
    return channel
  }

  /// Kareyi yerinde küçültür. Başarısız olursa dosyaya **dokunmaz**.
  ///
  /// Sıkıştırma bir iyileştirme; kullanıcının karesini kaybetmektense
  /// büyük saklamak yeğdir.
  /// Kare **hedef boyutunda çözülüyor**, tam boyda değil.
  ///
  /// Önce `UIImage(contentsOfFile:)` kullanılıyordu ve o, kareyi olduğu gibi
  /// belleğe açıyor: 2048×1536 bir kare için 12 MB. Küçük kopya üretmek için
  /// tam çözünürlüğü belleğe almanın hiçbir karşılığı yok. ImageIO doğrudan
  /// istenen boyutta çözüyor, yani bellek **çıktıyla** orantılı kalıyor —
  /// 600 piksellik bir kopya için 12 MB yerine ~1 MB.
  private static func compress(path: String, maxEdge: CGFloat, quality: CGFloat) -> Bool {
    autoreleasepool {
      let url = URL(fileURLWithPath: path)
      guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
          as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
        let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
      else { return false }

      // Zaten küçükse yeniden kodlamak yalnızca kalite kaybettirir.
      guard max(width, height) > maxEdge else { return false }

      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        // EXIF yönünü kareye işliyor; eskiden `draw` bunu yapıyordu.
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxEdge,
      ]
      guard
        let scaled = CGImageSourceCreateThumbnailAtIndex(
          source,
          0,
          options as CFDictionary
        ),
        let data = UIImage(cgImage: scaled).jpegData(compressionQuality: quality)
      else { return false }

      do {
        try data.write(to: url, options: .atomic)
        return true
      } catch {
        return false
      }
    }
  }
}
