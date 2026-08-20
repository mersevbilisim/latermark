import CoreServices
import CoreSpotlight
import Flutter
import Foundation
import UniformTypeIdentifiers

/// Kayıtları iPhone'un Spotlight aramasına taşır.
///
/// Bilinçli olarak akılsız: neyin indeksleneceğine, neyin değiştiğine ve
/// hangisinin kaldırılacağına Dart karar veriyor. Burada yalnızca Apple'ın
/// API'sine çeviri var — kural iki dile bölünürse ikisi zamanla ayrışır.
///
/// İndeks **cihazda** kalıyor: `CSSearchableIndex` yerel bir dizin ve buraya
/// yalnızca notun yazısı, karedeki metin ve kaydın tarihi giriyor. Fotoğrafın
/// kendisi, konum ve saklama süresi hiç çıkmıyor.
enum SpotlightChannel {
  static let name = "latermark/spotlight"

  /// Uygulamanın kendi kayıtlarını topluca tanımasını sağlayan alan adı.
  private static let domain = "com.mersev.latermark.note"
  private static let indexDelegate = SpotlightIndexDelegate()

  static func register(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    indexDelegate.channel = channel
    CSSearchableIndex.default().indexDelegate = indexDelegate
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "index":
        index(arguments?["items"] as? [[String: Any]] ?? [], result: result)
      case "remove":
        remove(arguments?["ids"] as? [Int] ?? [], result: result)
      case "reset":
        reset(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return channel
  }

  /// Bir kaydın indeksteki kararlı kimliği.
  ///
  /// Kimlik veritabanı satırına bağlı: kayıt silinip kimliği yeniden
  /// kullanılmadıkça aynı kalır. Spotlight sonucuna dokunulduğunda aranan not
  /// bu kimlikten çözülüyor.
  static func identifier(noteId: Int) -> String { "\(domain).\(noteId)" }

  /// Kimlikten not numarasını geri okur. Bize ait olmayan bir kimlik `nil`.
  static func noteId(from identifier: String) -> Int? {
    let prefix = "\(domain)."
    guard identifier.hasPrefix(prefix) else { return nil }
    return Int(identifier.dropFirst(prefix.count))
  }

  private static func index(_ items: [[String: Any]], result: @escaping FlutterResult) {
    let searchable: [CSSearchableItem] = items.compactMap { item in
      guard let noteId = item["id"] as? Int else { return nil }

      let attributes = CSSearchableItemAttributeSet(contentType: UTType.content)
      attributes.title = item["title"] as? String

      // Karedeki yazı ayrı metin alanına giriyor. Sonuç başlığı yalnız
      // kullanıcının notudur; sistemin gelecekte eşleşme bağlamını nasıl
      // sunacağına dair "asla görünmez" varsayımı yapılmaz.
      if let text = item["text"] as? String, !text.isEmpty {
        attributes.textContent = text
      }

      if let milliseconds = item["createdAtMilliseconds"] as? Int {
        attributes.contentCreationDate = Date(
          timeIntervalSince1970: Double(milliseconds) / 1000
        )
      }

      let searchableItem = CSSearchableItem(
        uniqueIdentifier: identifier(noteId: noteId),
        domainIdentifier: domain,
        attributeSet: attributes
      )
      // Varsayılan ömür **bir ay**. Belirtilmezse aylar önce kaydedilmiş bir
      // garanti belgesi tam da arandığı gün indeksten düşmüş olurdu; oysa
      // kaydın ömrünü uygulamanın kendi saklama kuralı belirliyor ve süresi
      // dolan kayıt zaten açıkça kaldırılıyor.
      searchableItem.expirationDate = .distantFuture
      return searchableItem
    }

    guard !searchable.isEmpty else {
      result(nil)
      return
    }

    CSSearchableIndex.default().indexSearchableItems(searchable) { error in
      // Hata yutuluyor ama Dart'a bildiriliyor: indeksleme bir kolaylık,
      // başarısızlığı uygulamanın hiçbir işini durdurmamalı.
      DispatchQueue.main.async { result(failure(error)) }
    }
  }

  private static func remove(_ ids: [Int], result: @escaping FlutterResult) {
    guard !ids.isEmpty else {
      result(nil)
      return
    }

    CSSearchableIndex.default().deleteSearchableItems(
      withIdentifiers: ids.map { identifier(noteId: $0) }
    ) { error in
      DispatchQueue.main.async { result(failure(error)) }
    }
  }

  private static func reset(result: @escaping FlutterResult) {
    CSSearchableIndex.default().deleteSearchableItems(
      withDomainIdentifiers: [domain]
    ) { error in
      DispatchQueue.main.async { result(failure(error)) }
    }
  }

  private static func failure(_ error: Error?) -> Any? {
    guard let error else { return nil }
    return FlutterError(
      code: "spotlight_failed",
      message: error.localizedDescription,
      details: nil
    )
  }
}

/// iOS kendi indeksini kaybettiğinde veya belirli kayıtları yeniden istediğinde
/// Dart tarafındaki doğruluk kaynağından tam, acknowledgement'lı rebuild ister.
/// İstek uygulama çalışırken gelir; tamamlanma callback'i Flutter'ın reset ve
/// batch indekslemesi bitmeden Apple'a dönmez.
private final class SpotlightIndexDelegate: NSObject, CSSearchableIndexDelegate {
  weak var channel: FlutterMethodChannel?

  func searchableIndex(
    _ searchableIndex: CSSearchableIndex,
    reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler:
      @escaping () -> Void
  ) {
    requestReindex(acknowledgementHandler)
  }

  func searchableIndex(
    _ searchableIndex: CSSearchableIndex,
    reindexSearchableItemsWithIdentifiers identifiers: [String],
    acknowledgementHandler: @escaping () -> Void
  ) {
    // Dart diff'i küçük arşivlerde ucuz ve tek doğruluk kaynağıdır. Kısmi
    // isteği tam rebuild'e yükseltmek, native tarafta DB mantığı çoğaltmaz.
    requestReindex(acknowledgementHandler)
  }

  private func requestReindex(_ acknowledgement: @escaping () -> Void) {
    guard let channel else {
      acknowledgement()
      return
    }
    DispatchQueue.main.async {
      channel.invokeMethod("reindexAll", arguments: nil) { _ in
        acknowledgement()
      }
    }
  }
}
