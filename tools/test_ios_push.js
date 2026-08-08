/**
 * iOS Push Notification Test Script
 * Sends a test push notification to an iOS device via FCM
 *
 * Usage: node test_ios_push.js <device_token>
 */

const admin = require('firebase-admin');
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-bb4fc2e685.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const token = process.argv[2];

if (!token) {
  console.log('Usage: node test_ios_push.js <ios_fcm_token>');
  console.log('');
  console.log('Get the token from the app debug console when running on iOS device.');
  process.exit(1);
}

console.log('🍎 Sending iOS Push Notification Test');
console.log('Token:', token.substring(0, 30) + '...');
console.log('');

const message = {
  token: token,
  notification: {
    title: "Yuh Blockin' Test",
    body: "iOS push notification working! 🏝️"
  },
  data: {
    alert_id: 'test_123',
    type: 'test',
    click_action: 'FLUTTER_NOTIFICATION_CLICK'
  },
  apns: {
    headers: {
      'apns-priority': '10',
      'apns-push-type': 'alert'
    },
    payload: {
      aps: {
        alert: {
          title: "Yuh Blockin' Test",
          body: "iOS push notification working! 🏝️"
        },
        sound: 'default',
        badge: 1,
        'mutable-content': 1,
        'content-available': 1
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
