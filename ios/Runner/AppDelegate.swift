import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase FIRST
    FirebaseApp.configure()

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

  // Handle successful APNs registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("✅ APNs: Registration SUCCESS!")
    print("✅ APNs: Device token (first 20 chars): \(String(tokenString.prefix(20)))...")
    // Pass device token to Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
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
