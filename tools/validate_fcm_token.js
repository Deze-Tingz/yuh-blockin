/**
 * FCM Device Token Validator
 * Tests if a device token is valid by attempting a dry-run send
 *
 * Usage: node validate_fcm_token.js <device_token>
 */

const admin = require('firebase-admin');
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-bb4fc2e685.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const token = process.argv[2];

if (!token) {
  console.log('Usage: node validate_fcm_token.js <device_token>');
  process.exit(1);
}

console.log('Validating token:', token.substring(0, 30) + '...');
console.log('');

// Dry-run validation (doesn't actually send)
admin.messaging().send({
  token: token,
  notification: {
    title: 'Validation Test',
    body: 'This is a dry-run test'
  }
}, true) // true = dry run
.then((response) => {
  console.log('✅ TOKEN IS VALID');
  console.log('Message ID (dry-run):', response);
})
.catch((error) => {
  console.log('❌ TOKEN VALIDATION FAILED');
  console.log('Error Code:', error.code);
  console.log('Error Message:', error.message);

  if (error.code === 'messaging/registration-token-not-registered') {
    console.log('\n⚠️  This token is no longer registered. The app was uninstalled or token expired.');
  } else if (error.code === 'messaging/invalid-registration-token') {
    console.log('\n⚠️  This token format is invalid.');
  } else if (error.code === 'messaging/third-party-auth-error') {
    console.log('\n⚠️  APNs authentication failed. Check your APNs key in Firebase Console.');
  }
});
