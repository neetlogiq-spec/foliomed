import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerAccessibilityChannel(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private var accessibilityChannel: FlutterMethodChannel?

  /// Exposes "Reduce Transparency" to Flutter (MediaQuery doesn't).
  private func registerAccessibilityChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.foliomed.app/accessibility",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "reduceTransparency" {
        result(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak channel] _ in
      channel?.invokeMethod(
        "reduceTransparencyChanged",
        arguments: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
      )
    }
    accessibilityChannel = channel
  }
}
