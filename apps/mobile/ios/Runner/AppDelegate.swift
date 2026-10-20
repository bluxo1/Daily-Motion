import Flutter
import UIKit
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let processContinuity = "process:" + UUID().uuidString
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DailyMotionDevice") else { return }
    FlutterMethodChannel(name: "daily_motion/device", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "clock":
          var timebase = mach_timebase_info_data_t()
          mach_timebase_info(&timebase)
          let microseconds = Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1000
          result(["wall_ms": Int64(Date().timeIntervalSince1970 * 1000),
                  "elapsed_us": Int64(microseconds), "continuity_id": self.processContinuity])
        case "excludeBackup":
          do {
            guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
              throw CocoaError(.fileWriteInvalidFileName)
            }
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true).resolvingSymlinksInPath()
            var directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
            guard directory.path == support.path || directory.path.hasPrefix(support.path + "/") else {
              throw CocoaError(.fileWriteNoPermission)
            }
            if FileManager.default.fileExists(atPath: directory.path),
               try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true {
              result(true)
              return
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            result(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
          } catch {
            result(FlutterError(code: "private_storage_unavailable", message: "Private storage unavailable", details: nil))
          }
        case "device":
          var system = utsname()
          uname(&system)
          let capacity = MemoryLayout.size(ofValue: system.machine)
          let model = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) { String(cString: $0) }
          }
          #if targetEnvironment(simulator)
          let physical = false
          #else
          let physical = true
          #endif
          result(["platform": "ios", "model": model,
                  "application_id": Bundle.main.bundleIdentifier ?? "",
                  "os": UIDevice.current.systemVersion, "physical": physical, "source": "ios-native"])
        default: result(FlutterMethodNotImplemented)
        }
      }
  }
}
