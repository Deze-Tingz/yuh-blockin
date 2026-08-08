/**
 * Query iOS device tokens from Supabase
 */

const https = require('https');

const SUPABASE_URL = 'https://oazxwglbvzgpehsckmfb.supabase.co';
// Using service role key from environment or you can paste it here temporarily
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.argv[2];

if (!SUPABASE_KEY) {
  console.log('Usage: node query_ios_tokens.js <SUPABASE_SERVICE_ROLE_KEY>');
  console.log('Or set SUPABASE_SERVICE_ROLE_KEY environment variable');
  process.exit(1);
}

const options = {
  hostname: 'oazxwglbvzgpehsckmfb.supabase.co',
  path: '/rest/v1/device_tokens?select=user_id,fcm_token,platform,created_at&order=created_at.desc&limit=10',
  method: 'GET',
  headers: {
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${SUPABASE_KEY}`,
    'Content-Type': 'application/json'
  }
};

console.log('🔍 Querying iOS device tokens from Supabase...\n');

const req = https.request(options, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    if (res.statusCode === 200) {
      const tokens = JSON.parse(data);
      if (tokens.length === 0) {
        console.log('No iOS device tokens found.');
        console.log('Run the app on an iOS device to register a token.');
      } else {
        console.log(`Found ${tokens.length} iOS token(s):\n`);
        tokens.forEach((t, i) => {
          console.log(`[${i + 1}] User: ${t.user_id}`);
          console.log(`    Token: ${t.fcm_token}`);
          console.log(`    Created: ${t.created_at}\n`);
        });

        console.log('\n📋 To test push, copy a token and run:');
        console.log('node test_ios_push.js <token>');
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
