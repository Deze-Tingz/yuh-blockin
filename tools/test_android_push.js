/**
 * Test Android push notification via Supabase Edge Function
 */

const https = require('https');

const SUPABASE_URL = 'oazxwglbvzgpehsckmfb.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henh3Z2xidnpncGVoc2NrbWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNzkzMjEsImV4cCI6MjA3ODc1NTMyMX0.Ia6ccZ1zp4r1mi5mgvQk9wfK5MGp0S3TDhyWngz8Z54';

// User ID from the app logs
const USER_ID = process.argv[2] || 'user_1765931820245';

const payload = JSON.stringify({
  alert_id: 'test-android-push',
  receiver_id: USER_ID,
  message: 'Test push from CLI - Android',
  urgency_level: 'high'
});

const options = {
  hostname: SUPABASE_URL,
  path: '/functions/v1/alerts-fcm',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Length': Buffer.byteLength(payload)
  }
};

console.log('📱 Testing Android push notification...');
console.log(`   User ID: ${USER_ID}`);
console.log(`   Endpoint: https://${SUPABASE_URL}/functions/v1/alerts-fcm\n`);

const req = https.request(options, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log(`Response status: ${res.statusCode}`);
    try {
      const result = JSON.parse(data);
      console.log('Response:', JSON.stringify(result, null, 2));

      if (result.ok && result.successCount > 0) {
        console.log('\n✅ Push notification sent successfully!');
        console.log('   Check your Android device for the notification.');
      } else if (result.ok && result.successCount === 0) {
        console.log('\n⚠️  No tokens found or all sends failed.');
        console.log('   Make sure the app registered a token for this user.');
      } else {
        console.log('\n❌ Push notification failed.');
      }
    } catch (e) {
      console.log('Raw response:', data);
    }
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
});

req.write(payload);
req.end();
