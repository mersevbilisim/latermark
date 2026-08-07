import Flutter
import ImageIO
import UIKit
import Vision

/// Karedeki yazıyı okuyup Flutter'a döndürür.
///
/// Apple'ın `Vision` çatısı **işletim sisteminin parçası** — çözülecek bir
/// bağımlılık yok. Bu yüzden projenin Swift Package Manager kurulumuna hiç
/// dokunmuyor; ML Kit'in Flutter eklentisi ise iOS tarafında CocoaPods
/// zorunlu kılıyordu ve kurulumu bozuyordu.
///
/// Okuma arka planda yapılır; sonuç ana kuyrukta döner.
enum TextRecognitionChannel {
  static let name = "latermark/ocr"
  private static let queue = DispatchQueue(
    label: "com.mersev.latermark.ocr",
    qos: .utility
  )
  private static let maximumImageDimension = 2560

  static func register(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result("")
        return
      }
      read(path: path, result: result)
    }
    return channel
  }

  private static func read(path: String, result: @escaping FlutterResult) {
    // `nil` ile `""` ayrı anlamlar taşıyor: `nil` "okuma yapılamadı, sonra
    // yeniden dene", `""` ise "okundu, yazı yok". İkisini karıştırmak
    // okunamayan kareleri kalıcı olarak taranmış saymak olurdu.
    queue.async {
      autoreleasepool {
        guard let cgImage = downsampledImage(path: path) else {
          DispatchQueue.main.async { result(nil) }
          return
        }

        let request = VNRecognizeTextRequest { request, error in
          guard
            error == nil,
            let observations = request.results as? [VNRecognizedTextObservation]
          else {
            DispatchQueue.main.async { result(nil) }
            return
          }

          let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
          DispatchQueue.main.async { result(text) }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Dil ipucu yalnızca Vision o dili gerçekten destekliyorsa veriliyor.
        // Desteklenmeyen bir kod göndermek isteği tümden başarısız kılıyor;
        // ipucu olmadan da Latin betiği okunur, sadece düzeltme zayıflar.
        if
          let language = Locale.preferredLanguages.first?
            .components(separatedBy: "-").first,
          let supported = try? request.supportedRecognitionLanguages(),
          supported.contains(where: { $0.hasPrefix(language) })
        {
          request.recognitionLanguages = [language]
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
          try handler.perform([request])
        } catch {
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  /// ImageIO yalnızca OCR'a gidecek piksel boyutunu decode eder ve EXIF
  /// dönüşümünü uygular. Böylece 24/48 MP kamera kareleri ana thread'i ve
  /// belleği gereksiz yere zorlamaz.
  private static func downsampledImage(path: String) -> CGImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard
      let source = CGImageSourceCreateWithURL(
        URL(fileURLWithPath: path) as CFURL,
        sourceOptions
      )
    else {
      return nil
    }

    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maximumImageDimension,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(
      source,
      0,
      thumbnailOptions as CFDictionary
    )
  }
}
