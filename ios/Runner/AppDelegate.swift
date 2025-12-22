import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("📱 AppDelegate: Starting initialization...")

    // Initialize Firebase with error handling
    do {
      if FirebaseApp.app() == nil {
        FirebaseApp.configure()
        print("✅ Firebase configured in Swift")
      } else {
        print("⚠️ Firebase already configured")
      }
    } catch {
      print("❌ Firebase config error: \(error)")
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()
    print("📱 Registered for remote notifications")

    GeneratedPluginRegistrant.register(with: self)
    print("📱 Plugins registered")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs token received - pass to Firebase Messaging
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("✅ APNs token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs registration failed
  override func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ APNs registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
