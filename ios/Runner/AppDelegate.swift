import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var accessibilityChannel: FlutterMethodChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerAccessibilityChannel(engineBridge.pluginRegistry)
  }

  /// Exposes "Reduce Transparency" to Flutter (MediaQuery doesn't), so the
  /// frosted tab bar can fall back to a solid surface.
  private func registerAccessibilityChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "FolioMedAccessibility") else { return }
    let channel = FlutterMethodChannel(
      name: "com.foliomed.app/accessibility",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "reduceTransparency" {
        result(UIAccessibility.isReduceTransparencyEnabled)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak channel] _ in
      channel?.invokeMethod(
        "reduceTransparencyChanged",
        arguments: UIAccessibility.isReduceTransparencyEnabled
      )
    }
    accessibilityChannel = channel
  }
}
