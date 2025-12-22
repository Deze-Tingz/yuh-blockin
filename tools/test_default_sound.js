const admin = require('firebase-admin');
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-52358afc11.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const token = process.argv[2];

const message = {
  token: token,
  apns: {
    headers: { 'apns-priority': '10' },
    payload: {
      aps: {
        alert: { title: '🔔 Default Sound Test', body: 'This should play the DEFAULT iOS sound' },
        sound: 'default',
        badge: 1
      }
    }
  }
};

admin.messaging().send(message)
  .then(r => console.log('✅ Sent with DEFAULT sound:', r))
  .catch(e => console.log('❌ Error:', e.message));
