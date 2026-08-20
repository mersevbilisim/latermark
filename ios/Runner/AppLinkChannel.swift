import CoreSpotlight
import Flutter
import Foundation
import UIKit

/// Uygulamanın dışından gelen yönlendirmelerin tek kapısı.
///
/// Bugün tek kaynağı Spotlight sonuçları, ama sözleşme kaynaktan bağımsız:
/// bir App Intent ya da bir kısayol da aynı `latermark://note/12` adresini
/// buraya bırakabilir. Ana ekran widget'ının kendi yolu var (`home_widget`
/// paketinin URL akışı) ve ona dokunulmadı.
///
/// Teslim `SharedImportStore` ile aynı biçimde çalışıyor: native taraf
/// yönlendirmeyi **bekletir** ve yalnızca "bir şey var" der; Dart hazır
/// olduğunda gelip alır. Soğuk açılışta bu şart — kullanıcı sonuca
/// dokunduğunda Flutter motoru henüz ayakta olmayabiliyor — ve tek teslim
/// yolu bıraktığı için aynı yönlendirmenin iki kez işlenmesi de imkânsız.
enum AppLinkChannel {
  static let name = "latermark/app_link"

  private static var channel: FlutterMethodChannel?
  private static var pending: String?

  /// Sahne olaylarını dinleyen nesne.
  ///
  /// Güçlü tutuluyor: `addSceneDelegate:` zayıf referansla bakıyor ve sahip
  /// serbest bırakılırsa Spotlight devirleri hiç gelmez.
  private static var sceneDelegate: AppLinkSceneDelegate?

  static func register(
    registrar: any FlutterPluginRegistrar
  ) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(
      name: name,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "takePendingLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let link = pending
      pending = nil
      result(link)
    }
    self.channel = channel

    if #available(iOS 13.0, *) {
      let delegate = AppLinkSceneDelegate()
      registrar.addSceneDelegate(delegate)
      sceneDelegate = delegate
    }

    // Motor, bekleyen bir yönlendirme varken kurulmuş olabilir.
    notifyIfPending()
    return channel
  }

  /// Bir Spotlight sonucundan gelen kullanıcı etkinliğini çözer.
  ///
  /// Bize ait olmayan bir etkinlik için `false` döner; çağıran taraf onu
  /// zincirdeki diğer eklentilere bırakır.
  @discardableResult
  static func handle(userActivity: NSUserActivity) -> Bool {
    guard
      userActivity.activityType == CSSearchableItemActionType,
      let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier]
        as? String,
      let noteId = SpotlightChannel.noteId(from: identifier)
    else {
      return false
    }

    deliver("latermark://note/\(noteId)")
    return true
  }

  static func deliver(_ link: String) {
    pending = link
    notifyIfPending()
  }

  private static func notifyIfPending() {
    guard pending != nil, let channel else { return }
    // Kanal çağrıları platform thread'inde yapılmalı.
    DispatchQueue.main.async {
      channel.invokeMethod("linkAvailable", arguments: nil)
    }
  }
}

/// Spotlight devirlerini karşılayan sahne dinleyicisi.
///
/// `Info.plist` sahne (scene) desteğini açtığı için `NSUserActivity` devirleri
/// artık `UIApplicationDelegate`'e hiç uğramıyor. `FlutterSceneDelegate`'i
/// türetip yöntemlerini ezmek yerine Flutter'ın kendi eklenti kaydı
/// kullanılıyor: `FlutterSceneDelegate` bu geri çağrıları başlıkta
/// bildirmiyor, dolayısıyla `override` yazmak derlenmez ve `override`suz
/// yazmak üst sınıfın uygulamasını sessizce devre dışı bırakırdı — yani
/// eklentilerin (ör. ana ekran widget'ı) sahne olayları kesilirdi.
///
/// Seçiciler açıkça sabitleniyor: bunlar **isteğe bağlı** protokol
/// yöntemleri, adı bir harf tutmazsa derleyici uyarmaz, yöntem yalnızca hiç
/// çağrılmaz.
@available(iOS 13.0, *)
final class AppLinkSceneDelegate: NSObject, FlutterSceneLifeCycleDelegate {
  /// Uygulama kapalıyken bir Spotlight sonucu açtı.
  @objc(scene:willConnectToSession:options:)
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    for activity in connectionOptions?.userActivities ?? [] {
      if AppLinkChannel.handle(userActivity: activity) { break }
    }

    // Bilinçli olarak `false`: zincir ilk `true`da duruyor ve bağlantı
    // olayını sahiplenmek, aynı açılışta gelen bir widget URL'ini diğer
    // eklentilerin hiç görmemesi demek olurdu. Yönlendirme zaten alındı.
    return false
  }

  /// Uygulama çalışırken bir Spotlight sonucuna dokunuldu.
  @objc(scene:continueUserActivity:)
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    AppLinkChannel.handle(userActivity: userActivity)
  }
}
