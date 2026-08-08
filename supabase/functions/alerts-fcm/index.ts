import { createClient } from 'npm:@supabase/supabase-js@2.28.0';
import { SignJWT, importPKCS8 } from 'npm:jose@5.2.0';

// FCM error codes that indicate invalid/expired tokens
const INVALID_TOKEN_ERRORS = [
  'UNREGISTERED',
  'INVALID_ARGUMENT',
];

// Generate OAuth2 access token from service account
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const privateKey = await importPKCS8(serviceAccount.private_key, 'RS256');

  const jwt = await new SignJWT({
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging'
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .sign(privateKey);

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to get access token: ${error}`);
  }

  const data = await response.json();
  return data.access_token;
}

// Send FCM message using HTTP v1 API
async function sendFcmMessage(accessToken: string, projectId: string, message: any): Promise<any> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const body = JSON.stringify({ message });

  console.log('FCM URL:', url);
  console.log('Access token (first 50 chars):', accessToken.substring(0, 50) + '...');
  console.log('Request body:', body.substring(0, 200));

  const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body
    }
  );

  const responseText = await response.text();
  console.log('FCM response status:', response.status);
  console.log('FCM response body:', responseText);

  let data;
  try {
    data = JSON.parse(responseText);
  } catch {
    return { success: false, error: { message: responseText } };
  }

  if (!response.ok) {
    return { success: false, error: data.error };
  }

  return { success: true, messageId: data.name };
}

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json();
    const { alert_id, receiver_id, message, sound_path, urgency_level = 'normal' } = body;

    console.log('Received request:', { alert_id, receiver_id, message, urgency_level });

    if (!receiver_id) {
      return new Response(JSON.stringify({ error: 'missing receiver_id' }), { status: 400 });
    }

    // Get service account from base64-encoded secret
    const serviceAccountBase64 = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');

    if (!serviceAccountBase64) {
      console.error('Missing FIREBASE_SERVICE_ACCOUNT_JSON');
      return new Response(JSON.stringify({ error: 'missing firebase service account' }), { status: 500 });
    }

    let serviceAccount: any;
    try {
      const serviceAccountJson = atob(serviceAccountBase64);
      serviceAccount = JSON.parse(serviceAccountJson);
      console.log('Service account project:', serviceAccount.project_id);
      console.log('Service account email:', serviceAccount.client_email);
    } catch (e) {
      console.error('Failed to parse service account:', e);
      return new Response(JSON.stringify({ error: 'invalid service account', details: e.message }), { status: 500 });
    }

    // Get OAuth2 access token
    let accessToken: string;
    try {
      accessToken = await getAccessToken(serviceAccount);
      console.log('Got access token successfully');
    } catch (e) {
      console.error('Failed to get access token:', e);
      return new Response(JSON.stringify({ error: 'auth failed', details: e.message }), { status: 500 });
    }

    // Initialize Supabase client
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: 'missing supabase env vars' }), { status: 500 });
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // Query device tokens by user_id
    const { data: tokenData, error: tokenError } = await supabase
      .from('device_tokens')
      .select('fcm_token, platform')
      .eq('user_id', receiver_id);

    if (tokenError) {
      console.error('Supabase query failed:', tokenError);
      return new Response(JSON.stringify({ error: 'supabase query failed', details: tokenError.message }), { status: 500 });
    }

    const tokenRecords = tokenData || [];
    console.log('Found tokens:', tokenRecords.length);
    // Log tokens by platform for debugging
    console.log('Tokens by platform:', tokenRecords.map((r: any) => ({
      platform: r.platform,
      tokenLength: (r.fcm_token || '').length
    })));

    if (!tokenRecords.length) {
      return new Response(JSON.stringify({ ok: true, message: 'no tokens registered' }));
    }

    // Determine sound file based on urgency
    const soundMap: Record<string, string> = {
      'low': 'low_alert_1.wav',
      'normal': 'normal_alert.wav',
      'high': 'high_alert_1.wav'
    };
    const soundFile = sound_path?.split('/').pop() || soundMap[urgency_level] || 'normal_alert.wav';
    const androidSound = soundFile.replace('.wav', '');

    // Send to each token
    const tokens = tokenRecords.map((r: any) => r.fcm_token).filter(Boolean);
    const platforms = tokenRecords.map((r: any) => String(r.platform || '').toLowerCase());

    console.log('Sending to', tokens.length, 'devices');

    let successCount = 0;
    let failureCount = 0;
    const invalidTokens: string[] = [];
    const errorDetails: any[] = [];

    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i];
      const platform = platforms[i];

      // Build platform-specific message
      const fcmMessage: any = {
        token,
        notification: {
          title: "Yuh Blockin'",
          body: message || "Someone needs you to move your car!"
        },
        data: {
          alert_id: String(alert_id || ''),
          urgency_level: urgency_level,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      };

      // Add Android-specific config
      if (platform === 'android') {
        fcmMessage.android = {
          priority: 'high',
          notification: {
            sound: androidSound,
            channel_id: `yuh_blockin_alert_${androidSound}`,
          }
        };
      }

      // Add iOS-specific config with explicit aps.alert
      if (platform === 'ios') {
        fcmMessage.apns = {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert'
          },
          payload: {
            aps: {
              alert: {
                title: "Yuh Blockin'",
                body: message || "Someone needs you to move your car!"
              },
              sound: "default",
              badge: 1
            }
          }
        };
      }

      const result = await sendFcmMessage(accessToken, serviceAccount.project_id, fcmMessage);

      if (result.success) {
        successCount++;
        console.log(`Token ${i} (${platform}) sent successfully:`, result.messageId);
      } else {
        failureCount++;
        // Improved error code extraction
        const details = result.error?.details || [];
        const errorCode =
          details.find((d: any) => d.errorCode)?.errorCode ||
          result.error?.status ||
          'UNKNOWN';
        console.log(`Token ${i} (${platform}) failed:`, errorCode, result.error?.message);
        console.log(`Token ${i} full error:`, JSON.stringify(result.error));
        errorDetails.push({ platform, errorCode, message: result.error?.message, details: result.error?.details });

        if (INVALID_TOKEN_ERRORS.includes(errorCode)) {
          invalidTokens.push(token);
        }
      }
    }

    console.log('FCM result:', { success: successCount, failure: failureCount });

    // Delete invalid tokens from database
    if (invalidTokens.length > 0) {
      console.log('Removing', invalidTokens.length, 'invalid tokens');
      const { error: deleteError } = await supabase
        .from('device_tokens')
        .delete()
        .in('fcm_token', invalidTokens);

      if (deleteError) {
        console.error('Failed to delete invalid tokens:', deleteError);
      } else {
        console.log('Invalid tokens removed successfully');
      }
    }

    // Update push_sent in alerts table
    if (alert_id && alert_id !== 'test-123') {
      await supabase
        .from('alerts')
        .update({
          push_sent: true,
          push_sent_at: new Date().toISOString()
        })
        .eq('id', alert_id);
    }

    return new Response(JSON.stringify({
      ok: true,
      successCount,
      failureCount,
      invalidTokensRemoved: invalidTokens.length,
      errors: errorDetails.length > 0 ? errorDetails : undefined
    }), { status: 200 });

  } catch (err) {
    console.error('Error:', err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
