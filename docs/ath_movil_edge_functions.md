# ATH Móvil Edge Functions for Supabase

These Edge Functions handle ATH Móvil Business payments securely. The private key never leaves the server.

## Setup Instructions

1. Go to **Supabase Dashboard** → **Edge Functions**
2. Click **Create a new function** for each function below
3. Copy-paste the code
4. Go to **Edge Functions** → **Secrets** and add:
   - `ATH_MOVIL_PUBLIC_TOKEN` - Your public token from ATH Business app
   - `ATH_MOVIL_PRIVATE_KEY` - Your private key from ATH Business app

---

## Function 1: `ath-create-payment`

Creates a new payment request with ATH Móvil.

```typescript
// ath-create-payment/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ATH_API_BASE = 'https://payments.athmovil.com/api/business-transaction/ecommerce'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreatePaymentRequest {
  user_id: string
  product_type: 'monthly' | 'lifetime'
  phone_number: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get secrets
    const ATH_PUBLIC_TOKEN = Deno.env.get('ATH_MOVIL_PUBLIC_TOKEN')
    const ATH_PRIVATE_KEY = Deno.env.get('ATH_MOVIL_PRIVATE_KEY')

    if (!ATH_PUBLIC_TOKEN || !ATH_PRIVATE_KEY) {
      console.error('Missing ATH Móvil credentials')
      return new Response(
        JSON.stringify({ error: 'Payment system not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with service role
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Parse request
    const { user_id, product_type, phone_number }: CreatePaymentRequest = await req.json()

    // Validate phone number (Puerto Rico format)
    const cleanPhone = phone_number.replace(/\D/g, '')
    if (cleanPhone.length !== 10) {
      return new Response(
        JSON.stringify({ error: 'Invalid phone number format' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!cleanPhone.startsWith('787') && !cleanPhone.startsWith('939')) {
      return new Response(
        JSON.stringify({ error: 'Phone must be a Puerto Rico number (787 or 939)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Determine amount based on product type
    const amount = product_type === 'monthly' ? 2.99 : 19.99
    const productName = product_type === 'monthly'
      ? 'Yuh Blockin Premium - Monthly'
      : 'Yuh Blockin Premium - Lifetime'

    console.log(`Creating ATH Móvil payment: ${productName} for $${amount}`)

    // Create ATH Móvil payment
    const athResponse = await fetch(`${ATH_API_BASE}/payment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        publicToken: ATH_PUBLIC_TOKEN,
        privateToken: ATH_PRIVATE_KEY,
        timeout: 600,  // 10 minutes
        total: amount,
        tax: 0,
        subtotal: amount,
        phoneNumber: cleanPhone,
        metadata1: user_id.substring(0, 40),  // Max 40 chars
        metadata2: product_type,
        items: [
          {
            name: productName,
            description: `${productName} subscription`,
            quantity: 1,
            price: amount,
            metadata: product_type
          }
        ]
      })
    })

    const athData = await athResponse.json()
    console.log('ATH Móvil response:', JSON.stringify(athData))

    if (!athData.ecommerceId) {
      console.error('ATH Móvil error - no ecommerceId:', athData)
      return new Response(
        JSON.stringify({
          error: 'Failed to create payment with ATH Móvil',
          details: athData.errorMessage || athData.message || 'Unknown error'
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Store transaction in database
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString()  // 10 min

    const { data: transaction, error: dbError } = await supabase
      .from('ath_movil_transactions')
      .insert({
        user_id,
        ecommerce_id: athData.ecommerceId,
        product_type,
        amount,
        phone_number: cleanPhone,
        status: 'pending',
        auth_token: athData.auth_token,
        expires_at: expiresAt,
        metadata: {
          ath_response: athData,
          created_via: 'edge_function'
        }
      })
      .select()
      .single()

    if (dbError) {
      console.error('Database error:', dbError)
      return new Response(
        JSON.stringify({ error: 'Failed to store transaction' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Transaction created: ${transaction.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        transaction_id: transaction.id,
        ecommerce_id: athData.ecommerceId,
        amount,
        product_type,
        expires_at: expiresAt
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## Function 2: `ath-check-payment`

Polls ATH Móvil for payment status.

```typescript
// ath-check-payment/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ATH_API_BASE = 'https://payments.athmovil.com/api/business-transaction/ecommerce'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const ATH_PUBLIC_TOKEN = Deno.env.get('ATH_MOVIL_PUBLIC_TOKEN')
    const ATH_PRIVATE_KEY = Deno.env.get('ATH_MOVIL_PRIVATE_KEY')

    if (!ATH_PUBLIC_TOKEN || !ATH_PRIVATE_KEY) {
      return new Response(
        JSON.stringify({ error: 'Payment system not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { transaction_id } = await req.json()

    if (!transaction_id) {
      return new Response(
        JSON.stringify({ error: 'transaction_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get transaction from database
    const { data: transaction, error: fetchError } = await supabase
      .from('ath_movil_transactions')
      .select('*')
      .eq('id', transaction_id)
      .single()

    if (fetchError || !transaction) {
      return new Response(
        JSON.stringify({ error: 'Transaction not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if already in terminal state
    const terminalStates = ['completed', 'failed', 'expired', 'cancelled', 'refunded']
    if (terminalStates.includes(transaction.status)) {
      return new Response(
        JSON.stringify({
          status: transaction.status,
          reference_number: transaction.reference_number,
          transaction
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Query ATH Móvil for current status
    const athResponse = await fetch(`${ATH_API_BASE}/findPayment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        publicToken: ATH_PUBLIC_TOKEN,
        privateToken: ATH_PRIVATE_KEY,
        ecommerceId: transaction.ecommerce_id
      })
    })

    const athData = await athResponse.json()
    console.log('ATH findPayment response:', JSON.stringify(athData))

    let newStatus = transaction.status
    const updates: Record<string, any> = {
      updated_at: new Date().toISOString(),
      metadata: {
        ...transaction.metadata,
        last_ath_response: athData
      }
    }

    // Map ATH Móvil status to our status
    // ATH Móvil statuses: OPEN, CONFIRM, CANCELLED, EXPIRED
    const athStatus = athData.status || athData.ecommerceStatus

    switch (athStatus) {
      case 'OPEN':
        newStatus = 'open'
        if (!transaction.opened_at) {
          updates.opened_at = new Date().toISOString()
        }
        break
      case 'CONFIRM':
        newStatus = 'confirmed'
        if (!transaction.confirmed_at) {
          updates.confirmed_at = new Date().toISOString()
        }
        updates.reference_number = athData.referenceNumber
        updates.daily_transaction_id = athData.dailyTransactionId
        break
      case 'CANCELLED':
        newStatus = 'cancelled'
        break
      case 'EXPIRED':
        newStatus = 'expired'
        break
    }

    updates.status = newStatus

    // Update transaction in database
    await supabase
      .from('ath_movil_transactions')
      .update(updates)
      .eq('id', transaction_id)

    return new Response(
      JSON.stringify({
        status: newStatus,
        ready_for_authorization: newStatus === 'confirmed',
        reference_number: athData.referenceNumber,
        transaction: { ...transaction, ...updates }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## Function 3: `ath-authorize-payment`

Completes the payment after user confirmation.

```typescript
// ath-authorize-payment/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ATH_API_BASE = 'https://payments.athmovil.com/api/business-transaction/ecommerce'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const ATH_PUBLIC_TOKEN = Deno.env.get('ATH_MOVIL_PUBLIC_TOKEN')
    const ATH_PRIVATE_KEY = Deno.env.get('ATH_MOVIL_PRIVATE_KEY')

    if (!ATH_PUBLIC_TOKEN || !ATH_PRIVATE_KEY) {
      return new Response(
        JSON.stringify({ error: 'Payment system not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { transaction_id } = await req.json()

    if (!transaction_id) {
      return new Response(
        JSON.stringify({ error: 'transaction_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get transaction
    const { data: transaction, error: fetchError } = await supabase
      .from('ath_movil_transactions')
      .select('*')
      .eq('id', transaction_id)
      .single()

    if (fetchError || !transaction) {
      return new Response(
        JSON.stringify({ error: 'Transaction not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify transaction is in confirmed state
    if (transaction.status !== 'confirmed') {
      return new Response(
        JSON.stringify({
          error: 'Transaction not ready for authorization',
          status: transaction.status
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Authorizing transaction ${transaction_id}`)

    // Authorize payment with ATH Móvil
    const athResponse = await fetch(`${ATH_API_BASE}/authorization`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        publicToken: ATH_PUBLIC_TOKEN,
        privateToken: ATH_PRIVATE_KEY,
        ecommerceId: transaction.ecommerce_id,
        auth_token: transaction.auth_token
      })
    })

    const athData = await athResponse.json()
    console.log('ATH authorization response:', JSON.stringify(athData))

    // Check for success - ATH Móvil returns status: "COMPLETED" or similar
    const isSuccess = athData.status === 'COMPLETED' ||
                      athData.completed === true ||
                      athData.ecommerceStatus === 'COMPLETED'

    if (isSuccess) {
      // Update transaction to completed
      await supabase
        .from('ath_movil_transactions')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          reference_number: athData.referenceNumber || transaction.reference_number,
          metadata: {
            ...transaction.metadata,
            authorization_response: athData
          }
        })
        .eq('id', transaction_id)

      // Calculate subscription dates
      const now = new Date()
      const isLifetime = transaction.product_type === 'lifetime'
      const expiresAt = isLifetime
        ? null
        : new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString()

      // Grant subscription access
      const { error: subError } = await supabase
        .from('subscriptions')
        .upsert({
          user_id: transaction.user_id,
          status: isLifetime ? 'lifetime' : 'premium',
          plan_type: transaction.product_type,
          started_at: now.toISOString(),
          expires_at: expiresAt,
          payment_source: 'ath_movil',
          ath_transaction_id: transaction_id,
          updated_at: now.toISOString()
        }, {
          onConflict: 'user_id'
        })

      if (subError) {
        console.error('Error updating subscription:', subError)
        // Don't fail - payment was successful, subscription update is secondary
      }

      // If monthly, create/update monthly subscription tracker
      if (!isLifetime) {
        const periodEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000)

        await supabase
          .from('ath_monthly_subscriptions')
          .upsert({
            user_id: transaction.user_id,
            current_period_start: now.toISOString(),
            current_period_end: periodEnd.toISOString(),
            renewal_status: 'active',
            last_transaction_id: transaction_id,
            consecutive_months: 1,  // Will be incremented on renewals
            updated_at: now.toISOString()
          }, {
            onConflict: 'user_id'
          })
      }

      console.log(`Payment completed for user ${transaction.user_id}`)

      return new Response(
        JSON.stringify({
          success: true,
          status: 'completed',
          subscription_type: transaction.product_type,
          reference_number: athData.referenceNumber || transaction.reference_number,
          message: 'Payment completed successfully!'
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } else {
      // Authorization failed
      await supabase
        .from('ath_movil_transactions')
        .update({
          status: 'failed',
          metadata: {
            ...transaction.metadata,
            authorization_response: athData
          }
        })
        .eq('id', transaction_id)

      console.error('Authorization failed:', athData)

      return new Response(
        JSON.stringify({
          success: false,
          status: 'failed',
          error: athData.errorMessage || athData.message || 'Authorization failed',
          details: athData
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## Required Secrets

In **Supabase Dashboard → Edge Functions → Secrets**, add:

| Secret Name | Description |
|-------------|-------------|
| `ATH_MOVIL_PUBLIC_TOKEN` | Your public token from ATH Business app settings |
| `ATH_MOVIL_PRIVATE_KEY` | Your private key (NEVER share this publicly) |

The `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available in Edge Functions.

---

## Testing

After deploying, test with:

```bash
# Test create payment
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/ath-create-payment' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "test-user-123", "product_type": "monthly", "phone_number": "7875551234"}'
```

Note: ATH Móvil has no sandbox environment. All payments are real.

---

## Payment Flow

```
1. App calls ath-create-payment
   → Creates ATH Móvil payment
   → Returns transaction_id

2. App polls ath-check-payment every 3 seconds
   → Returns status: pending → open → confirmed

3. When status = confirmed, app calls ath-authorize-payment
   → Completes the payment
   → Updates subscriptions table
   → Returns success

4. App shows success message
```
