import Flutter
import StoreKit
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let proProductID = "latermarkpro"

  /// StoreKit 2 imzayı cihazda doğrular. Yalnızca doğrulanmış, hâlen yürürlükte
  /// ve geri alınmamış `latermarkpro` işlemi hak verir. Boş dizi kesin `false`;
  /// hedef ürüne ait doğrulanamayan işlem ise yerel önbelleği ezmemek için
  /// Flutter hatası olarak döner.
  @MainActor
  private static func resolveProEntitlement(_ result: @escaping FlutterResult) async {
    var foundUnverifiedTarget = false

    for await verification in Transaction.currentEntitlements {
      switch verification {
      case .verified(let transaction):
        guard transaction.productID == proProductID else {
          continue
        }
        if transaction.revocationDate == nil {
          result(true)
          return
        }
      case .unverified(let transaction, _):
        if transaction.productID == proProductID {
          foundUnverifiedTarget = true
        }
      }
    }

    if foundUnverifiedTarget {
      result(
        FlutterError(
          code: "unverified_entitlement",
          message: "StoreKit could not verify the Pro entitlement.",
          details: nil
        )
      )
    } else {
      result(false)
    }
  }

  private var sharedImportChannel: FlutterMethodChannel?
  private var appSettingsChannel: FlutterMethodChannel?
  private var entitlementChannel: FlutterMethodChannel?
  private var ocrChannel: FlutterMethodChannel?
  private var imageChannel: FlutterMethodChannel?
  private var locationChannel: FlutterMethodChannel?
  private var locationHandler: LocationChannel?
  private var spotlightChannel: FlutterMethodChannel?
  private var appLinkChannel: FlutterMethodChannel?
  private var reminderActionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Uygulamayı açmayan bir bildirim düğmesine basıldığında eklenti başsız
    // bir `FlutterEngine` başlatıyor. O motorun eklentileri bu geri çağrıyla
    // kaydediliyor ve kaydedilmesi şart: hatırlatmayı erteleyen kod
    // veritabanına path_provider üzerinden ulaşıyor. Ayarlanmadan bırakılırsa
    // eklenti `registerPlugins` nil'ken motoru kuruyor ve çöküyor.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      ReminderActionBridge.attachBackground(to: registry)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "latermark/shared_import",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "takePendingSharedImport":
        result(SharedImportStore.nextPending())
      case "completeSharedImport":
        if
          let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String
        {
          result(SharedImportStore.complete(id: id))
        } else {
          result(false)
        }
      case "setShareEntitlement":
        guard
          let arguments = call.arguments as? [String: Any],
          let unlocked = arguments["unlocked"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing Share entitlement value.",
              details: nil
            )
          )
          return
        }
        SharedImportStore.setProUnlocked(unlocked)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    sharedImportChannel = channel

    let settingsChannel = FlutterMethodChannel(
      name: "latermark/app_settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    settingsChannel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
    appSettingsChannel = settingsChannel

    let entitlementChannel = FlutterMethodChannel(
      name: "latermark/purchases",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    entitlementChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "currentProEntitlement":
        Task { @MainActor in
          await AppDelegate.resolveProEntitlement(result)
        }

      case "restoreProEntitlement":
        // Bu çağrı yalnız kullanıcının açık "Satın alımları geri yükle"
        // dokunuşundan gelir. `AppStore.sync()` Apple hesabı istemi
        // gösterebildiği için açılışta veya arka planda çağrılmamalı.
        Task { @MainActor in
          do {
            try await AppStore.sync()
          } catch {
            result(
              FlutterError(
                code: "app_store_sync_failed",
                message: "StoreKit could not sync purchases with the App Store.",
                details: String(describing: error)
              )
            )
            return
          }
          await AppDelegate.resolveProEntitlement(result)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.entitlementChannel = entitlementChannel

    spotlightChannel = SpotlightChannel.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    // Sahne olaylarına ancak tam bir eklenti kaydı üzerinden abone olunuyor;
    // `applicationRegistrar` `addSceneDelegate:` taşımıyor.
    if let linkRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LatermarkAppLink"
    ) {
      appLinkChannel = AppLinkChannel.register(registrar: linkRegistrar)
    }
    reminderActionChannel = ReminderActionBridge.attachMain(
      messenger: engineBridge.applicationRegistrar.messenger()
    )

    ocrChannel = TextRecognitionChannel.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    imageChannel = ImageChannel.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    let location = LocationChannel.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    locationChannel = location.0
    // Delegate'i tutan sahibi burada saklanıyor: `CLLocationManager` yalnızca
    // zayıf referansla delegate'e bakar, sahip serbest bırakılırsa yetki ve
    // konum geri çağrıları hiç gelmez.
    locationHandler = location.1
  }
}
