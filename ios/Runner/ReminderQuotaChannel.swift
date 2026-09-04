import Flutter
import Foundation
import Security

/// Ucretsiz hatirlatma hakkinin **silinmeyen** sayaci.
///
/// Veritabani uygulamayla birlikte gidiyor. Latermark'i yalniz hatirlatma icin
/// kullanan bir kisinin kaybedecek arsivi yok; onun icin silip yeniden kurmak
/// bedelsiz ve kota da hicbir seye baglanmamis oluyor. Keychain kayitlari ise
/// uygulama silindiginde cihazda kaliyor — bu kapinin tek yerel dayanagi o.
///
/// Burada **yalniz bir sayi** duruyor, kayit kimlikleri degil. Kimlikler
/// kuruluma ozel: yeniden kurulumdan sonra sayaç birden basliyor ve eski bir
/// kimlik yeni bir kayda denk gelip ona bedava hak verirdi.
///
/// `kSecAttrSynchronizable` **verilmiyor**: kayit cihazda kalir, iCloud ile
/// baska bir telefona gecmez. Yeni cihaza gecen durust kullanici hakkini
/// tukenmis bulmaz; yalnizca ayni cihaza yedekten donen kullanicida geri gelir
/// ki o zaten ayni kullanicinin ayni verisi.
///
/// Pro acikken bu kanala hic ugranmiyor: karar Dart tarafinda, hak kontrolu
/// baslamadan veriliyor.
enum ReminderQuotaChannel {
  static let name = "latermark/reminder_quota"

  private static let service = "com.mersev.latermark.reminder_quota"
  private static let account = "free_reminders_burned"

  static func register(with messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "read":
        result(read())
      case "write":
        guard
          let arguments = call.arguments as? [String: Any],
          let value = arguments["value"] as? Int
        else {
          result(false)
          return
        }
        result(write(value))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return channel
  }

  /// Kayitli sayi; hic yoksa ya da okunamazsa `nil`.
  ///
  /// Okunamama **sifir degil**: sifir donmek "hic hak kullanilmamis" demek
  /// olurdu ve gecici bir Keychain hatasi kullaniciya uc hak daha verirdi.
  /// Dart tarafi `nil` gordugunde yalnizca veritabanina guveniyor.
  private static func read() -> Int? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard
      status == errSecSuccess,
      let data = item as? Data,
      let text = String(data: data, encoding: .utf8),
      let value = Int(text)
    else {
      return nil
    }
    return max(0, value)
  }

  /// Sayiyi yazar. **Asla kucultmez**: kayitli deger daha buyukse dokunmaz.
  ///
  /// Tek yonlu olmasi bilincli. Yeniden kurulumdan sonra veritabani bos
  /// basliyor ve oradan gelen sifir, silinmeyen sayaci sifirlamamali —
  /// kapinin butun anlami bu.
  private static func write(_ value: Int) -> Bool {
    let next = max(0, value)
    if let current = read() {
      if current >= next { return true }
      let attributes: [String: Any] = [
        kSecValueData as String: Data(String(next).utf8)
      ]
      let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
      return status == errSecSuccess
    }

    var query = baseQuery()
    query[kSecValueData as String] = Data(String(next).utf8)
    // Cihaz bir kez acildiktan sonra erisilebilir: arka planda calisan
    // supurme de bu sayiyi yazabilmeli.
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  private static func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
