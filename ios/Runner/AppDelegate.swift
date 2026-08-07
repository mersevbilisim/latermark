import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var sharedImportChannel: FlutterMethodChannel?
  private var appSettingsChannel: FlutterMethodChannel?
  private var ocrChannel: FlutterMethodChannel?
  private var imageChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

    ocrChannel = TextRecognitionChannel.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    imageChannel = ImageChannel.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}
