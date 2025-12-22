/**
 * iOS Push Notification Test Script
 * Sends a test push notification to an iOS device via FCM
 *
 * Usage: node test_ios_push.js <device_token>
 */

const admin = require('firebase-admin');
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-52358afc11.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const token = process.argv[2];

if (!token) {
  console.log('Usage: node test_ios_push.js <fcm_token> [emoji] [urgency]');
  console.log('');
  console.log('Examples:');
  console.log('  node test_ios_push.js <token>              # Default: 🚗 emoji, normal urgency');
  console.log('  node test_ios_push.js <token> 🚨 high      # High urgency with 🚨 emoji');
  console.log('  node test_ios_push.js <token> 🙏 low       # Low urgency with 🙏 emoji');
  console.log('');
  console.log('Urgency levels: low, normal, high');
  process.exit(1);
}

console.log('🍎 Sending iOS Push Notification Test');
console.log('Token:', token.substring(0, 30) + '...');
console.log('');

// Get optional emoji from args (default: 🚗)
const emoji = process.argv[3] || '🚗';
const urgencyLevel = process.argv[4] || 'normal';

// Map urgency to sound file
const soundMap = {
  'low': 'low_alert_1.wav',
  'normal': 'normal_alert.wav',
  'high': 'high_alert_1.wav'
};
const soundFile = soundMap[urgencyLevel] || 'normal_alert.wav';

console.log('Emoji:', emoji);
console.log('Urgency:', urgencyLevel);
console.log('Sound:', soundFile);
console.log('');

// For iOS: Use APNs-only payload (no FCM notification block) to ensure custom sound works
// For Android: Use FCM notification block with channel
const message = {
  token: token,
  // Data payload - available on both platforms
  data: {
    alert_id: 'test_123',
    type: 'alert',
    emoji: emoji,
    urgency_level: urgencyLevel,
    title: `${emoji} Yuh Blockin'!`,
    body: "Someone needs you to move your vehicle!",
    click_action: 'FLUTTER_NOTIFICATION_CLICK'
  },
  // Android-specific: Use notification with channel for custom sound
  android: {
    priority: 'high',
    notification: {
      title: `${emoji} Yuh Blockin'!`,
      body: "Someone needs you to move your vehicle!",
      channelId: `yuh_blockin_alert_${soundFile.replace('.wav', '')}`,
      sound: soundFile.replace('.wav', ''),
      defaultSound: false,
      priority: 'max',
      visibility: 'public'
    }
  },
  // iOS-specific: Direct APNs payload for custom sound on lock screen
  apns: {
    headers: {
      'apns-priority': '10',
      'apns-push-type': 'alert'
    },
    payload: {
      aps: {
        alert: {
          title: `${emoji} Yuh Blockin'!`,
          body: "Someone needs you to move your vehicle!"
        },
        sound: soundFile,
        badge: 1,
        'mutable-content': 1,
        'content-available': 1,
        'interruption-level': 'time-sensitive'
      }
    }
  }
};

admin.messaging().send(message)
  .then((response) => {
    console.log('✅ PUSH SENT SUCCESSFULLY');
    console.log('Message ID:', response);
    console.log('');
    console.log('Check your iOS device for the notification!');
  })
  .catch((error) => {
    console.log('❌ PUSH FAILED');
    console.log('Error Code:', error.code);
    console.log('Error Message:', error.message);
    console.log('');

    if (error.code === 'messaging/registration-token-not-registered') {
      console.log('⚠️  Token not registered - app may be uninstalled or token expired');
    } else if (error.code === 'messaging/invalid-registration-token') {
      console.log('⚠️  Invalid token format');
    } else if (error.code === 'messaging/third-party-auth-error') {
      console.log('⚠️  APNs auth failed - check APNs key in Firebase Console');
    } else if (error.code === 'messaging/invalid-argument') {
      console.log('⚠️  Invalid message format');
      console.log('Full error:', JSON.stringify(error, null, 2));
    }
  });
