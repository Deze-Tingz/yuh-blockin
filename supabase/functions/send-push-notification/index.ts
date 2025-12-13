// Supabase Edge Function: send-push-notification
// Uses FCM HTTP v1 API for reliable push notifications
//
// Required secrets:
// - FIREBASE_PROJECT_ID: Your Firebase project ID
// - FIREBASE_SERVICE_ACCOUNT_KEY: Base64-encoded service account JSON

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const FIREBASE_SERVICE_ACCOUNT_KEY = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')!

// Base64URL encode (no padding, URL-safe)
function base64UrlEncode(data: string | Uint8Array): string {
  const base64 = typeof data === 'string'
    ? btoa(data)
    : btoa(String.fromCharCode(...data))
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

// Disable caching for now to debug
let cachedToken: { token: string; expiry: number } | null = null
const DISABLE_CACHE = true // Force new token each time for debugging

async function getAccessToken(): Promise<string> {
  // Return cached token if still valid (with 5 min buffer) - disabled for debugging
  if (!DISABLE_CACHE && cachedToken && Date.now() < cachedToken.expiry - 300000) {
    console.log('Using cached token')
    return cachedToken.token
  }

  try {
    console.log('Getting new access token...')

    // Decode base64 service account key
    const serviceAccountJson = atob(FIREBASE_SERVICE_ACCOUNT_KEY)
    const serviceAccount = JSON.parse(serviceAccountJson)

    console.log('Service account email:', serviceAccount.client_email)

    // Prepare the private key - handle various newline escape formats
    let privateKeyPem = serviceAccount.private_key
    // Handle double-escaped newlines (\\n -> \n)
    privateKeyPem = privateKeyPem.replace(/\\\\n/g, '\n')
    // Handle single-escaped newlines (\n literal string -> actual newline)
    privateKeyPem = privateKeyPem.replace(/\\n/g, '\n')

    console.log('Private key starts with:', privateKeyPem.substring(0, 50))
    console.log('Private key ends with:', privateKeyPem.substring(privateKeyPem.length - 50))

    // Extract the base64 content from PEM
    const pemContents = privateKeyPem
      .replace(/-----BEGIN PRIVATE KEY-----/g, '')
      .replace(/-----END PRIVATE KEY-----/g, '')
      .replace(/\s/g, '')

    // Decode the base64 key
    const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

    // Import the private key
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign']
    )

    console.log('Private key imported successfully')

    // Create JWT
    const now = Math.floor(Date.now() / 1000)
    const header = { alg: 'RS256', typ: 'JWT' }
    const payload = {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
      scope: 'https://www.googleapis.com/auth/firebase.messaging'
    }

    const encodedHeader = base64UrlEncode(JSON.stringify(header))
    const encodedPayload = base64UrlEncode(JSON.stringify(payload))
    const signatureInput = `${encodedHeader}.${encodedPayload}`

    // Sign the JWT
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      new TextEncoder().encode(signatureInput)
    )
    const encodedSignature = base64UrlEncode(new Uint8Array(signature))

    const jwt = `${signatureInput}.${encodedSignature}`
    console.log('JWT created successfully')

    // Exchange JWT for access token
    console.log('Exchanging JWT for access token...')
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
    })

    const tokenText = await tokenResponse.text()
    console.log('Token response status:', tokenResponse.status)
    console.log('Token response body:', tokenText)

    let tokenData
    try {
      tokenData = JSON.parse(tokenText)
    } catch (e) {
      throw new Error('Failed to parse token response: ' + tokenText)
    }

    if (!tokenData.access_token) {
      console.error('Token response error:', JSON.stringify(tokenData))
      throw new Error('Failed to get access token: ' + JSON.stringify(tokenData))
    }

    console.log('Access token obtained successfully, length:', tokenData.access_token.length)

    // Cache the token
    cachedToken = {
      token: tokenData.access_token,
      expiry: Date.now() + (tokenData.expires_in * 1000)
    }

    return tokenData.access_token
  } catch (error) {
    console.error('Error getting access token:', error)
    throw error
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      }
    })
  }

  try {
    const {
      alert_id,
      receiver_id,
      message,
      sound_path,
      urgency_level = 'normal'
    } = await req.json()

    console.log('Received request:', { alert_id, receiver_id, message, urgency_level })

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Get receiver's FCM tokens
    const { data: tokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('fcm_token, platform')
      .eq('user_id', receiver_id)

    if (tokenError) {
      console.error('Token query error:', tokenError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Database error: ' + tokenError.message
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    if (!tokens?.length) {
      console.log('No device tokens found for user:', receiver_id)
      return new Response(JSON.stringify({
        success: false,
        error: 'No device tokens found'
      }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log('Found tokens:', tokens.length)

    // Get OAuth2 access token
    const accessToken = await getAccessToken()

    // Determine sound file based on urgency
    const soundMap: Record<string, string> = {
      'low': 'low_alert_1.wav',
      'normal': 'normal_alert.wav',
      'high': 'high_alert_1.wav'
    }
    const soundFile = sound_path?.split('/').pop() || soundMap[urgency_level] || 'normal_alert.wav'
    const androidSound = soundFile.replace('.wav', '')

    // Send to each device using FCM v1 API
    const results = await Promise.all(tokens.map(async (token: { fcm_token: string, platform: string }) => {
      // Build FCM v1 message
      const fcmMessage: Record<string, unknown> = {
        token: token.fcm_token,
        notification: {
          title: "Yuh Blockin'",
          body: message || "Someone needs you to move your car!"
        },
        data: {
          alert_id: alert_id?.toString() || '',
          urgency_level: urgency_level,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      }

      // iOS-specific configuration
      if (token.platform === 'ios') {
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
              sound: soundFile,
              badge: 1,
              'mutable-content': 1
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
            notification_priority: 'PRIORITY_MAX'
          }
        }
      }

      console.log(`Sending to ${token.platform}:`, JSON.stringify(fcmMessage, null, 2))

      // Log token info for debugging
      console.log('Access token first 50 chars:', accessToken.substring(0, 50))
      console.log('Access token last 20 chars:', accessToken.substring(accessToken.length - 20))
      console.log('FCM URL:', `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`)

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
      console.log('FCM response:', response.status, JSON.stringify(result))

      return {
        platform: token.platform,
        success: response.ok,
        status: response.status,
        result
      }
    }))

    // Mark alert as push sent
    if (alert_id && alert_id !== 'test-123') {
      const { error: updateError } = await supabase
        .from('alerts')
        .update({
          push_sent: true,
          push_sent_at: new Date().toISOString()
        })
        .eq('id', alert_id)

      if (updateError) {
        console.log('Failed to update push_sent:', updateError)
      }
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
      error: error.message || String(error)
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
