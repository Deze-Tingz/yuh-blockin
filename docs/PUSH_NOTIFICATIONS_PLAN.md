# Push Notifications Implementation Plan

## Goal
Enable users to receive alert notifications with custom sounds even when the app is completely closed (terminated).

---

## Current Problem
- App uses Supabase real-time subscriptions to listen for alerts
- Real-time only works when app is open/in foreground
- When user swipes up to close app, they receive NO notifications
- Custom alert sounds cannot play

---

## Solution Overview

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  User A     │ ──►  │  Supabase   │ ──►  │  FCM/APNs   │ ──►  │  User B     │
│  Sends      │      │  Database   │      │  Push       │      │  Receives   │
│  Alert      │      │  + Edge Fn  │      │  Service    │      │  Notification│
└─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
```

---

## Implementation Steps

### Phase 1: Firebase Setup

#### 1.1 Create Firebase Project
- Go to https://console.firebase.google.com
- Create new project: "Yuh Blockin"
- Enable Cloud Messaging

#### 1.2 iOS Configuration (APNs)
- Apple Developer Account → Certificates, Identifiers & Profiles
- Create APNs Key (recommended over certificate):
  - Keys → Create Key → Enable "Apple Push Notifications service (APNs)"
  - Download .p8 file (save securely - only downloadable once)
  - Note: Key ID and Team ID
- In Firebase Console → Project Settings → Cloud Messaging:
  - Upload APNs Authentication Key (.p8)
  - Enter Key ID and Team ID

#### 1.3 Android Configuration
- Firebase Console → Add Android app
- Package name: `com.dezetingz.yuhBlockin` (verify in android/app/build.gradle.kts)
- Download `google-services.json`
- Place in `android/app/google-services.json`

#### 1.4 iOS Configuration Files
- Firebase Console → Add iOS app
- Bundle ID: `com.dezetingz.yuhBlockin` (verify in Xcode)
- Download `GoogleService-Info.plist`
- Add to `ios/Runner/` via Xcode (important: must be added through Xcode)

---

### Phase 2: Flutter Dependencies

#### 2.1 Add packages to pubspec.yaml
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10
```

#### 2.2 Android Setup (android/build.gradle)
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

#### 2.3 Android Setup (android/app/build.gradle)
```gradle
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        minSdkVersion 21  // FCM requires 21+
    }
}
```

#### 2.4 iOS Setup (ios/Runner/Info.plist)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

#### 2.5 iOS AppDelegate.swift
```swift
import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Request notification permissions
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

### Phase 3: Database Schema

#### 3.1 Create device_tokens table in Supabase
```sql
CREATE TABLE device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- Index for fast lookups
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

-- RLS Policy
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own tokens"
ON device_tokens FOR ALL
USING (true)
WITH CHECK (true);
```

#### 3.2 Update alerts table (if needed)
```sql
-- Add column to track if push was sent
ALTER TABLE alerts ADD COLUMN push_sent BOOLEAN DEFAULT FALSE;
ALTER TABLE alerts ADD COLUMN push_sent_at TIMESTAMP WITH TIME ZONE;
```

---

### Phase 4: Supabase Edge Function

#### 4.1 Create Edge Function: `send-push-notification`

File: `supabase/functions/send-push-notification/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!

serve(async (req) => {
  try {
    const { alert_id, receiver_id, message, sound_path } = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Get receiver's FCM tokens
    const { data: tokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('fcm_token, platform')
      .eq('user_id', receiver_id)

    if (tokenError || !tokens?.length) {
      return new Response(JSON.stringify({
        success: false,
        error: 'No device tokens found'
      }), { status: 404 })
    }

    // Send to each device
    const results = await Promise.all(tokens.map(async (token) => {
      const payload = {
        to: token.fcm_token,
        notification: {
          title: "Yuh Blockin'",
          body: message || "Someone needs you to move your car!",
          sound: token.platform === 'ios'
            ? (sound_path || 'default')
            : 'default',
        },
        data: {
          alert_id: alert_id,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        // iOS specific
        apns: {
          payload: {
            aps: {
              sound: sound_path || 'default',
              'mutable-content': 1,
            }
          }
        },
        // Android specific
        android: {
          notification: {
            sound: 'default',
            channel_id: 'yuh_blockin_alerts',
          }
        }
      }

      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `key=${FCM_SERVER_KEY}`,
        },
        body: JSON.stringify(payload),
      })

      return response.json()
    }))

    // Mark alert as push sent
    await supabase
      .from('alerts')
      .update({
        push_sent: true,
        push_sent_at: new Date().toISOString()
      })
      .eq('id', alert_id)

    return new Response(JSON.stringify({
      success: true,
      results
    }), { status: 200 })

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), { status: 500 })
  }
})
```

#### 4.2 Database Trigger for Auto-Push

```sql
-- Trigger function to call edge function on new alert
CREATE OR REPLACE FUNCTION notify_alert_push()
RETURNS TRIGGER AS $$
BEGIN
  -- Call edge function via pg_net (async HTTP)
  PERFORM net.http_post(
    url := 'https://oazxwglbvzgpehsckmfb.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object(
      'alert_id', NEW.id,
      'receiver_id', NEW.receiver_id,
      'message', NEW.message,
      'sound_path', NEW.sound_path
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER on_new_alert_send_push
AFTER INSERT ON alerts
FOR EACH ROW
EXECUTE FUNCTION notify_alert_push();
```

---

### Phase 5: Flutter Implementation

#### 5.1 Create PushNotificationService

File: `lib/core/services/push_notification_service.dart`

```dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
  // Handle background message (e.g., show local notification)
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Initialize Firebase and request permissions
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize Firebase
    await Firebase.initializeApp();

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      debugPrint('Push permission status: ${settings.authorizationStatus}');
    }

    // Get and save FCM token
    await _saveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _initialized = true;
  }

  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final platform = Platform.isIOS ? 'ios' : 'android';

      // Save to Supabase
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, fcm_token');

      if (kDebugMode) {
        debugPrint('FCM Token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save FCM token: $e');
      }
    }
  }

  void _onTokenRefresh(String token) {
    _saveToken();
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message: ${message.notification?.title}');
    }
    // App is open - real-time subscription handles this
    // Optionally show in-app banner
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${message.data}');
    }
    // Navigate to alert screen
    // You can use a global navigator key or callback
  }

  /// Remove token on logout
  Future<void> removeToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('fcm_token', token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to remove FCM token: $e');
      }
    }
  }
}
```

#### 5.2 Update main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize push notifications
  await PushNotificationService().initialize();

  runApp(const PremiumYuhBlockinApp());
}
```

#### 5.3 Android Notification Channel

File: `android/app/src/main/kotlin/.../MainActivity.kt`

```kotlin
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "yuh_blockin_alerts",
                "Yuh Blockin Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when someone needs you to move your car"
                enableVibration(true)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
```

---

### Phase 6: Custom Sounds

#### 6.1 iOS Custom Sounds
- Sound files must be in app bundle
- Supported formats: .aiff, .caf, .wav (linear PCM, MA4, uLaw, aLaw)
- Max duration: 30 seconds
- Place in `ios/Runner/` and add to Xcode target

#### 6.2 Android Custom Sounds
- Place in `android/app/src/main/res/raw/`
- Reference by filename without extension
- Supported formats: .mp3, .ogg, .wav

#### 6.3 Sound Mapping
```dart
// Map your app's sound paths to notification sounds
String getNotificationSound(String? appSoundPath) {
  if (appSoundPath == null) return 'default';

  // Map internal paths to bundle sounds
  final soundMap = {
    'assets/sounds/alert1.mp3': 'alert1',
    'assets/sounds/alert2.mp3': 'alert2',
    'assets/sounds/horn.mp3': 'horn',
  };

  return soundMap[appSoundPath] ?? 'default';
}
```

---

### Phase 7: Testing

#### 7.1 Test Push Delivery
1. Install app on physical device (push doesn't work on simulator)
2. Register plate and get FCM token
3. Close app completely (swipe up)
4. Send alert from another device/user
5. Verify notification appears with sound

#### 7.2 Test Scenarios
- [ ] App in foreground - should use in-app notification
- [ ] App in background - should show system notification
- [ ] App terminated - should show system notification
- [ ] Custom sounds play correctly
- [ ] Tapping notification opens app to alert

#### 7.3 Debug Tools
- Firebase Console → Cloud Messaging → Send test message
- Use FCM token from debug logs

---

### Phase 8: Environment Variables

#### Supabase Edge Function Secrets
```bash
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key
```

Get FCM Server Key from:
Firebase Console → Project Settings → Cloud Messaging → Server Key

---

## File Changes Summary

| File | Action |
|------|--------|
| `pubspec.yaml` | Add firebase_core, firebase_messaging |
| `android/build.gradle` | Add google-services classpath |
| `android/app/build.gradle` | Apply google-services plugin |
| `android/app/google-services.json` | Add (from Firebase) |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Create notification channel |
| `ios/Runner/GoogleService-Info.plist` | Add (from Firebase) |
| `ios/Runner/Info.plist` | Add background modes |
| `ios/Runner/AppDelegate.swift` | Configure Firebase |
| `lib/core/services/push_notification_service.dart` | Create new |
| `lib/main.dart` | Initialize push service |
| `supabase/functions/send-push-notification/index.ts` | Create new |
| Supabase SQL | Create device_tokens table, trigger |

---

## Cost Considerations

- **Firebase Cloud Messaging**: FREE (unlimited notifications)
- **Supabase Edge Functions**: Free tier includes 500K invocations/month
- **APNs**: FREE (included with Apple Developer account)

---

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Phase 1: Firebase Setup | 1-2 hours |
| Phase 2: Flutter Dependencies | 30 min |
| Phase 3: Database Schema | 15 min |
| Phase 4: Edge Function | 1-2 hours |
| Phase 5: Flutter Implementation | 2-3 hours |
| Phase 6: Custom Sounds | 1 hour |
| Phase 7: Testing | 2-3 hours |

**Total: ~8-12 hours**

---

## Alternative: OneSignal

If Firebase setup is too complex, consider OneSignal:
- Easier setup
- Built-in dashboard
- Free tier: 10K subscribers
- Package: `onesignal_flutter`

However, Firebase is recommended for:
- Better integration with Supabase
- No subscriber limits
- More control over payload
