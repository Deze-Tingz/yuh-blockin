import { initializeApp, cert, getApps } from 'npm:firebase-admin@11.10.0/app';
import { getMessaging } from 'npm:firebase-admin@11.10.0/messaging';
import { createClient } from 'npm:@supabase/supabase-js@2.28.0';

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json();
    const { alert_id, receiver_id, message, sound_path, urgency_level = 'normal' } = body;

    console.log('Received request:', { alert_id, receiver_id, message, urgency_level });

    if (!receiver_id) {
      return new Response(JSON.stringify({ error: 'missing receiver_id' }), { status: 400 });
    }

    const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID');
    const firebaseClientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL');
    const firebasePrivateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');

    console.log('Firebase config:', {
      hasProjectId: !!firebaseProjectId,
      hasClientEmail: !!firebaseClientEmail,
      hasPrivateKey: !!firebasePrivateKey
    });

    if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKey) {
      return new Response(JSON.stringify({ error: 'missing firebase service account env vars' }), { status: 500 });
    }

    if (!getApps().length) {
      const serviceAccount = {
        projectId: firebaseProjectId,
        clientEmail: firebaseClientEmail,
        // Handle escaped newlines in private key
        privateKey: firebasePrivateKey.replace(/\\n/g, '\n'),
      };
      console.log('Initializing Firebase app...');
      initializeApp({ credential: cert(serviceAccount) });
    }
    const messaging = getMessaging();

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: 'missing supabase env vars' }), { status: 500 });
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // Query device tokens by user_id
    const { data, error } = await supabase
      .from('device_tokens')
      .select('fcm_token, platform')
      .eq('user_id', receiver_id);

    if (error) {
      console.error('Supabase query failed:', error);
      return new Response(JSON.stringify({ error: 'supabase query failed', details: error.message }), { status: 500 });
    }

    console.log('Found tokens:', data?.length || 0);

    const tokens = (data || []).map((r: any) => r.fcm_token).filter(Boolean);
    if (!tokens.length) {
      return new Response(JSON.stringify({ ok: true, message: 'no tokens' }));
    }

    // Determine sound file based on urgency
    const soundMap: Record<string, string> = {
      'low': 'low_alert_1.wav',
      'normal': 'normal_alert.wav',
      'high': 'high_alert_1.wav'
    };
    const soundFile = sound_path?.split('/').pop() || soundMap[urgency_level] || 'normal_alert.wav';
    const androidSound = soundFile.replace('.wav', '');

    const messagePayload = {
      notification: {
        title: "Yuh Blockin'",
        body: message || "Someone needs you to move your car!"
      },
      tokens,
      android: {
        priority: 'high' as const,
        notification: {
          sound: androidSound,
          channelId: `yuh_blockin_alert_${androidSound}`,
        }
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert'
        },
        payload: {
          aps: {
            sound: soundFile,
            badge: 1,
            'mutable-content': 1
          }
        }
      },
      data: {
        alert_id: String(alert_id || ''),
        urgency_level: urgency_level,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
    };

    console.log('Sending multicast message to', tokens.length, 'devices');
    const response = await messaging.sendEachForMulticast(messagePayload as any);
    console.log('FCM response:', JSON.stringify(response));

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
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses
    }), { status: 200 });
  } catch (err) {
    console.error('Error:', err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
