import Flutter
import Foundation

/// Bildirim düğmelerini işleyen arka plan motoru ile uygulamanın kendi motoru
/// arasındaki tek yönlü haber hattı.
///
/// `flutter_local_notifications`, uygulamayı açmayan bir düğmeye basıldığında
/// cevabı **ayrı ve başsız bir `FlutterEngine`'e** teslim ediyor. Ayrı motor
/// demek ayrı bir isolate, ayrı bir Dart yığını ve ayrı bir SQLite bağlantısı
/// demek — Drift'in akış geçersizleştirmesi ise süreç içi çalışıyor.
///
/// Sonuç: kullanıcı uygulama önündeyken bir bildirimi "Yarın"a ertelerse
/// veritabanı doğru tarihi alır ama ekrandaki kart eskisini göstermeye devam
/// ederdi. Bu köprü, arka plan motoru işini bitirdiğinde ana motora haber
/// veriyor ve sorgular yeniden koşuyor. Uygulama kapalıysa alan olmaz, haber
/// sessizce düşer — zaten açılışta her şey diskten okunuyor.
enum ReminderActionBridge {
  static let name = "latermark/reminder_actions"

  /// Ana motorun kanalı. Uygulama kapalıyken `nil`.
  private static weak var mainChannel: FlutterMethodChannel?

  /// Arka plan motorunun kanalı.
  ///
  /// Güçlü tutuluyor: `FlutterMethodChannel` çağrı işleyicisinin tek sahibi
  /// ve bırakılırsa haber hiç gelmez.
  private static var backgroundChannel: FlutterMethodChannel?

  static func attachMain(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "timeZoneIdentifier" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(TimeZone.current.identifier)
    }
    mainChannel = channel
    return channel
  }

  static func attachBackground(to registry: FlutterPluginRegistry) {
    guard
      let registrar = registry.registrar(forPlugin: "LatermarkReminderActionBridge")
    else {
      return
    }

    let channel = FlutterMethodChannel(
      name: name,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reminderActionApplied":
        mainChannel?.invokeMethod(call.method, arguments: nil)
        result(nil)
      case "timeZoneIdentifier":
        result(TimeZone.current.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    backgroundChannel = channel
  }
}
