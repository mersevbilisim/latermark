import CoreLocation
import Flutter
import Foundation

/// Tek seferlik konum okuması.
///
/// `CoreLocation` işletim sisteminin parçası — çözülecek bir bağımlılık yok ve
/// projenin Swift Package Manager kurulumuna dokunulmuyor. Aynı gerekçe OCR
/// kanalı için de geçerliydi.
///
/// Sürekli takip **yok**: `requestLocation()` bir tek sabitleme yapar ve durur.
/// Uygulamanın konuma ihtiyacı yalnızca çekim anında var; arka planda dolaşan
/// bir konum aboneliği hem pil hem güven maliyeti olurdu.
final class LocationChannel: NSObject {
  static let name = "latermark/location"

  private let manager = CLLocationManager()
  private var authorizationHandlers: [(Bool) -> Void] = []
  private var locationHandlers: [(CLLocation?) -> Void] = []

  /// Cihaz sabitleyemezse Flutter tarafı sonsuza kadar beklemesin.
  /// Kaydetme akışı konumu beklemiyor; yine de sarkan bir çağrı bırakmıyoruz.
  private static let timeout: TimeInterval = 8

  /// Son sabitlemenin taze sayıldığı süre.
  ///
  /// İki dakika içinde alınmış bir konum, bir notun nerede çekildiğini
  /// söylemek için hâlâ doğru. Daha uzunu kullanıcıyı bir önceki mahalleye
  /// yazma riski taşır.
  private static let cacheWindow: TimeInterval = 120

  /// Teşhis günlüğü — yalnızca geliştirme yapılarında.
  ///
  /// Konum sessizce gelmediğinde nerede durduğunu görmenin başka yolu yok:
  /// yetki mi, servis mi, zaman aşımı mı, yoksa sistem hata mı döndürüyor.
  static func trace(_ message: String) {
    #if DEBUG
      print("[KONUM] \(message)")
    #endif
  }

  static func register(messenger: FlutterBinaryMessenger) -> (
    FlutterMethodChannel, LocationChannel
  ) {
    let owner = LocationChannel()
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak owner] call, result in
      guard let owner else {
        result(nil)
        return
      }
      switch call.method {
      case "hasPermission":
        result(owner.isAuthorized)
      case "requestPermission":
        owner.requestPermission { result($0) }
      case "current":
        owner.currentLocation { location in
          guard let location else {
            result(nil)
            return
          }
          result([
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
          ])
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return (channel, owner)
  }

  override init() {
    super.init()
    manager.delegate = self
    // Yüz metre, "bu kare nerede çekildi" sorusu için fazlasıyla yeterli ve
    // belirleyici farkı hızda: on metrelik hedef GPS kilidi bekliyor ve kapalı
    // mekânda çoğu zaman zaman aşımına kadar gidiyordu. Yüz metre hücre ve
    // wifi ile saniyeler içinde çözülüyor.
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  private var isAuthorized: Bool {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: return true
    default: return false
    }
  }

  private func requestPermission(completion: @escaping (Bool) -> Void) {
    // Kullanıcı bir kez reddettiyse iOS istemi bir daha açmaz; sistem sessizce
    // aynı durumu döner. Bu durumda tek yol Ayarlar ve arayüz bunu söylüyor.
    guard manager.authorizationStatus == .notDetermined else {
      completion(isAuthorized)
      return
    }
    authorizationHandlers.append(completion)
    manager.requestWhenInUseAuthorization()
  }

  private func currentLocation(completion: @escaping (CLLocation?) -> Void) {
    let enabled = CLLocationManager.locationServicesEnabled()
    Self.trace(
      "istek: yetki=\(manager.authorizationStatus.rawValue) servis=\(enabled)"
    )
    guard isAuthorized, enabled else {
      completion(nil)
      return
    }

    // Sistem son sabitlemeyi zaten tutuyor. Yeterince tazeyse yeni bir istek
    // açmanın karşılığı yok: kullanıcı kaydın konumunu soruyor, metre metre
    // takip değil. Yaygın durumda bekleme tamamen ortadan kalkıyor.
    if let cached = manager.location,
      cached.horizontalAccuracy >= 0,
      -cached.timestamp.timeIntervalSinceNow <= Self.cacheWindow
    {
      Self.trace("onbellek kullanildi, yas=\(-cached.timestamp.timeIntervalSinceNow)sn")
      completion(cached)
      return
    }
    Self.trace("onbellek yok (son=\(manager.location.map { String(-$0.timestamp.timeIntervalSinceNow) } ?? "hic"))")

    locationHandlers.append(completion)
    manager.requestLocation()

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) {
      [weak self] in
      guard let self, !self.locationHandlers.isEmpty else { return }
      Self.trace("ZAMAN ASIMI (\(Self.timeout)sn)")
      self.flushLocation(nil)
    }
  }

  private func flushLocation(_ location: CLLocation?) {
    guard !locationHandlers.isEmpty else { return }
    let handlers = locationHandlers
    locationHandlers.removeAll()
    handlers.forEach { $0(location) }
  }
}

extension LocationChannel: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager.authorizationStatus != .notDetermined else { return }
    let handlers = authorizationHandlers
    authorizationHandlers.removeAll()
    let granted = isAuthorized
    handlers.forEach { $0(granted) }
  }

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    Self.trace("sabitleme geldi: \(locations.count) kayit")
    flushLocation(locations.last)
  }

  func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    // Sabitleyememek bir hata değil, "bu kayıtta konum yok" demek.
    Self.trace("HATA: \(error)")
    flushLocation(nil)
  }
}
