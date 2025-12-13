/**
 * FCM OAuth2 Access Token Generator
 * Generates an access token for FCM HTTP v1 API
 *
 * Usage: node generate_fcm_token.js
 */

const { google } = require('googleapis');
const serviceAccount = require('C:\\Users\\Deze_Tingz\\Passes\\yuh-blockin-firebase-adminsdk-fbsvc-bb4fc2e685.json');

async function getAccessToken() {
  const jwtClient = new google.auth.JWT(
    serviceAccount.client_email,
    null,
    serviceAccount.private_key,
    ['https://www.googleapis.com/auth/firebase.messaging'],
    null
  );

  const tokens = await jwtClient.authorize();
  return tokens.access_token;
}

console.log('Generating FCM Access Token...');
console.log('Service Account:', serviceAccount.client_email);
console.log('Project ID:', serviceAccount.project_id);
console.log('');

getAccessToken()
  .then((token) => {
    console.log('✅ Access Token Generated Successfully!\n');
    console.log('Token (first 100 chars):');
    console.log(token.substring(0, 100) + '...\n');
    console.log('Full Token:');
    console.log(token);
    console.log('\n📋 Copy this token to use in Postman or curl');
    console.log('\nExample curl command:');
    console.log(`curl -X POST "https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send" \\
  -H "Authorization: Bearer ${token.substring(0, 50)}..." \\
  -H "Content-Type: application/json" \\
  -d '{"message":{"token":"DEVICE_TOKEN","notification":{"title":"Test","body":"Hello!"}}}'`);
  })
  .catch((error) => {
    console.log('❌ Failed to generate token');
    console.log('Error:', error.message);
  });
