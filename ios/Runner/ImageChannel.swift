import Flutter
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

      DispatchQueue.global(qos: .utility).async {
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
  private static func compress(path: String, maxEdge: CGFloat, quality: CGFloat) -> Bool {
    guard let image = UIImage(contentsOfFile: path) else { return false }

    let longest = max(image.size.width, image.size.height)
    // Zaten küçükse yeniden kodlamak yalnızca kalite kaybettirir.
    guard longest > maxEdge else { return false }

    let ratio = maxEdge / longest
    let target = CGSize(
      width: (image.size.width * ratio).rounded(),
      height: (image.size.height * ratio).rounded()
    )

    // Ölçek 1: `UIGraphicsImageRenderer` varsayılan olarak ekran ölçeğini
    // kullanıyor ve 3x cihazda hedefin üç katı piksel üretirdi.
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: target, format: format)
    // `draw` EXIF yönünü uyguluyor; sonuç dik ve etiketsiz oluyor.
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }

    guard let data = resized.jpegData(compressionQuality: quality) else { return false }

    do {
      try data.write(to: URL(fileURLWithPath: path), options: .atomic)
      return true
    } catch {
      return false
    }
  }
}
