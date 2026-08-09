import Flutter
import StoreKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let proProductID = "latermarkpro"

  private var sharedImportChannel: FlutterMethodChannel?
  private var appSettingsChannel: FlutterMethodChannel?
  private var entitlementChannel: FlutterMethodChannel?
  private var ocrChannel: FlutterMethodChannel?
  private var imageChannel: FlutterMethodChannel?
  private var locationChannel: FlutterMethodChannel?
  private var locationHandler: LocationChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
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
          SharedImportStore.complete(id: id)
        }
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
      guard call.method == "currentProEntitlement" else {
        result(FlutterMethodNotImplemented)
        return
      }

      // StoreKit 2 imzayı cihazda doğrular. Yalnızca doğrulanmış, hâlen
      // yürürlükte ve geri alınmamış `latermarkpro` işlemi hak verir. Boş
      // dizi kesin `false`; hedef ürüne ait doğrulanamayan bir işlem ise
      // mağaza hatası sayılır ve Dart tarafındaki son doğrulanmış önbelleği
      // ezmemek için hata olarak döner.
      Task { @MainActor in
        var foundUnverifiedTarget = false

        for await verification in Transaction.currentEntitlements {
          switch verification {
          case .verified(let transaction):
            guard transaction.productID == AppDelegate.proProductID else {
              continue
            }
            if transaction.revocationDate == nil {
              result(true)
              return
            }
          case .unverified(let transaction, _):
            if transaction.productID == AppDelegate.proProductID {
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
    }
    self.entitlementChannel = entitlementChannel

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
