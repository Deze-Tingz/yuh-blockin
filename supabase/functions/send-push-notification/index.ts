// Supabase Edge Function: send-push-notification
// Uses FCM HTTP v1 API for reliable iOS and Android push notifications
//
// Required secrets (set via `supabase secrets set`):
// - FIREBASE_PROJECT_ID: Your Firebase project ID
// - FIREBASE_SERVICE_ACCOUNT_KEY: Your Firebase service account JSON key (base64 encoded)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const FIREBASE_SERVICE_ACCOUNT_KEY = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')!

interface ServiceAccountKey {
  client_email: string
  private_key: string
}

// Get OAuth2 access token for FCM v1 API
async function getAccessToken(): Promise<string> {
  const serviceAccount: ServiceAccountKey = JSON.parse(
    atob(FIREBASE_SERVICE_ACCOUNT_KEY)
  )

  const now = Math.floor(Date.now() / 1000)
  const exp = now + 3600 // 1 hour expiry

  // Create JWT header and claims
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: exp,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }

  // Encode header and claims
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const encodedClaims = btoa(JSON.stringify(claims)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  // Sign with private key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBinary(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signatureInput = new TextEncoder().encode(`${encodedHeader}.${encodedClaims}`)
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, signatureInput)
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const jwt = `${encodedHeader}.${encodedClaims}.${encodedSignature}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

// Convert PEM private key to binary
function pemToBinary(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

serve(async (req) => {
  try {
    const {
      alert_id,
      receiver_id,
      message,
      sound_path,
      urgency_level = 'normal'
    } = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Get receiver's FCM tokens
    const { data: tokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('fcm_token, platform')
      .eq('user_id', receiver_id)

    if (tokenError || !tokens?.length) {
      console.log('No device tokens found for user:', receiver_id)
      return new Response(JSON.stringify({
        success: false,
        error: 'No device tokens found'
      }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Get OAuth2 access token
    const accessToken = await getAccessToken()

    // Determine sound file based on urgency
    // Map urgency level to default sound files
    const soundMap: Record<string, string> = {
      'low': 'low_alert_1.wav',
      'normal': 'normal_alert.wav',
      'high': 'high_alert_1.wav'
    }
    const soundFile = sound_path?.split('/').pop() || soundMap[urgency_level] || 'normal_alert.wav'
    const androidSound = soundFile.replace('.wav', '')

    // Send to each device using FCM v1 API
    const results = await Promise.all(tokens.map(async (token: { fcm_token: string, platform: string }) => {
      // Build platform-specific message
      const fcmMessage: Record<string, unknown> = {
        token: token.fcm_token,
        notification: {
          title: "Yuh Blockin'",
          body: message || "Someone needs you to move your car!"
        },
        data: {
          alert_id: alert_id || '',
          urgency_level: urgency_level,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      }

      // iOS-specific configuration - CRITICAL for background/terminated delivery
      if (token.platform === 'ios') {
        fcmMessage.apns = {
          headers: {
            // push-type MUST be 'alert' for visible notifications
            'apns-push-type': 'alert',
            // Priority 10 = immediate delivery
            'apns-priority': '10',
            // Expiry - 1 hour from now
            'apns-expiration': String(Math.floor(Date.now() / 1000) + 3600)
          },
          payload: {
            aps: {
              alert: {
                title: "Yuh Blockin'",
                body: message || "Someone needs you to move your car!"
              },
              sound: soundFile,
              badge: 1,
              // mutable-content allows Notification Service Extension to modify
              'mutable-content': 1,
              // content-available for background wake (but alert is primary)
              'content-available': 1
            }
          }
        }
      }

      // Android-specific configuration
      if (token.platform === 'android') {
        fcmMessage.android = {
          priority: 'high',
          notification: {
            sound: androidSound,
            channel_id: `yuh_blockin_alert_${androidSound}`,
            default_sound: false,
            default_vibrate_timings: false,
            vibrate_timings: ['0.1s', '0.2s', '0.1s', '0.2s'],
            visibility: 'PUBLIC',
            notification_priority: 'PRIORITY_MAX'
          }
        }
      }

      console.log(`Sending to ${token.platform}:`, JSON.stringify(fcmMessage, null, 2))

      // Send via FCM v1 API
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`
          },
          body: JSON.stringify({ message: fcmMessage })
        }
      )

      const result = await response.json()
      console.log('FCM response:', JSON.stringify(result))

      return {
        platform: token.platform,
        success: response.ok,
        result
      }
    }))

    // Mark alert as push sent
    if (alert_id) {
      await supabase
        .from('alerts')
        .update({
          push_sent: true,
          push_sent_at: new Date().toISOString()
        })
        .eq('id', alert_id)
    }

    const allSuccessful = results.every(r => r.success)

    return new Response(JSON.stringify({
      success: allSuccessful,
      results
    }), {
      status: allSuccessful ? 200 : 207,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Push notification error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
