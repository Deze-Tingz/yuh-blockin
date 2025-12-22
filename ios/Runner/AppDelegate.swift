import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is initialized in Dart (main.dart)
    // FirebaseAppDelegateProxyEnabled=true in Info.plist handles APNs token forwarding

    GeneratedPluginRegistrant.register(with: self)

    // Register for remote notifications with APNs
    // This is required by Apple - must be called at launch
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    print("📱 APNs: Calling registerForRemoteNotifications()")
    application.registerForRemoteNotifications()
    print("📱 APNs: isRegisteredForRemoteNotifications = \(application.isRegisteredForRemoteNotifications)")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle successful APNs registration - logged for debugging
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("✅ APNs: Registration SUCCESS!")
    print("✅ APNs: Device token (first 20 chars): \(String(tokenString.prefix(20)))...")
    // Firebase proxy (enabled in Info.plist) automatically forwards token to FCM
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Handle failed APNs registration
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs: Registration FAILED!")
    print("❌ APNs: Error: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
