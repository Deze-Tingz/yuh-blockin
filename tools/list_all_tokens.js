/**
 * List all device tokens via Supabase Edge Function
 * This calls a simple query endpoint
 */

const https = require('https');

const SUPABASE_URL = 'oazxwglbvzgpehsckmfb.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henh3Z2xidnpncGVoc2NrbWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNzkzMjEsImV4cCI6MjA3ODc1NTMyMX0.Ia6ccZ1zp4r1mi5mgvQk9wfK5MGp0S3TDhyWngz8Z54';

// Query device_tokens table directly via REST API
const options = {
  hostname: SUPABASE_URL,
  path: '/rest/v1/device_tokens?select=user_id,platform,created_at&order=created_at.desc&limit=20',
  method: 'GET',
  headers: {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
  }
};

console.log('📱 Querying device tokens from Supabase...\n');

const req = https.request(options, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    if (res.statusCode === 200) {
      try {
        const tokens = JSON.parse(data);
        if (tokens.length === 0) {
          console.log('No device tokens found.');
        } else {
          console.log(`Found ${tokens.length} device token(s):\n`);

          const iosTokens = tokens.filter(t => t.platform === 'ios');
          const androidTokens = tokens.filter(t => t.platform === 'android');

          console.log(`iOS: ${iosTokens.length}, Android: ${androidTokens.length}\n`);

          tokens.forEach((t, i) => {
            console.log(`[${i + 1}] Platform: ${t.platform}`);
            console.log(`    User: ${t.user_id}`);
            console.log(`    Created: ${t.created_at}\n`);
          });

          if (iosTokens.length > 0) {
            console.log('\n✅ iOS tokens found! Run:');
            console.log(`   node test_android_push.js ${iosTokens[0].user_id}`);
            console.log('   (The script works for both platforms)');
          }
        }
      } catch (e) {
        console.log('Parse error:', e.message);
        console.log('Raw:', data);
      }
    } else {
      console.log('Error:', res.statusCode);
      console.log(data);
    }
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
});

req.end();
