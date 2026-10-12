import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var accessibilityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setUpAccessibilityChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// «Понижение прозрачности» и «Увеличение контраста» из Настроек iOS → Flutter
  /// (lib/ui/system_prefs.dart). Flutter сам эти флаги не передаёт.
  private func setUpAccessibilityChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "anteyko/accessibility", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "get" {
        result(AppDelegate.accessibilityState())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    accessibilityChannel = channel

    let center = NotificationCenter.default
    for name in [
      UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
    ] {
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.accessibilityChannel?.invokeMethod("changed", arguments: AppDelegate.accessibilityState())
      }
    }
  }

  private static func accessibilityState() -> [String: Bool] {
    return [
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "increaseContrast": UIAccessibility.isDarkerSystemColorsEnabled,
    ]
  }
}
