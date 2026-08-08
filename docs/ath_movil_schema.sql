-- ============================================
-- ATH Móvil Payment Integration Schema
-- ============================================
-- Run this in your Supabase SQL Editor to create
-- the tables needed for ATH Móvil payments.
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. ATH Móvil Transactions Table
-- ============================================
-- Stores all ATH Móvil payment attempts and their status

CREATE TABLE IF NOT EXISTS ath_movil_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    -- ATH Móvil identifiers
    ecommerce_id TEXT UNIQUE NOT NULL,      -- ATH Móvil's transaction ID
    reference_number TEXT,                   -- ATH Móvil's reference after completion
    daily_transaction_id TEXT,               -- ATH Móvil's daily transaction ID

    -- Product info
    product_type TEXT NOT NULL CHECK (product_type IN ('monthly', 'lifetime')),
    amount DECIMAL(10,2) NOT NULL,

    -- Customer info
    phone_number TEXT NOT NULL,              -- Puerto Rico format: 7875551234

    -- Status tracking
    -- pending: Payment created, waiting for user to open ATH Móvil
    -- open: User has opened ATH Móvil app
    -- confirmed: User confirmed in ATH Móvil, awaiting authorization
    -- completed: Payment authorized and complete
    -- failed: Payment failed during authorization
    -- expired: Payment session expired (10 min timeout)
    -- cancelled: User or system cancelled
    -- refunded: Payment was refunded
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',
        'open',
        'confirmed',
        'completed',
        'failed',
        'expired',
        'cancelled',
        'refunded'
    )),

    -- ATH Móvil auth token (needed for authorization call)
    auth_token TEXT,

    -- Store full ATH Móvil response data
    metadata JSONB DEFAULT '{}',

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    opened_at TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_ath_transactions_user_id
    ON ath_movil_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_ath_transactions_status
    ON ath_movil_transactions(status);
CREATE INDEX IF NOT EXISTS idx_ath_transactions_ecommerce_id
    ON ath_movil_transactions(ecommerce_id);
CREATE INDEX IF NOT EXISTS idx_ath_transactions_created_at
    ON ath_movil_transactions(created_at DESC);

-- ============================================
-- 2. ATH Monthly Subscriptions Table
-- ============================================
-- Tracks monthly subscription periods for ATH Móvil users
-- (ATH Móvil doesn't support auto-recurring, so we track manually)

CREATE TABLE IF NOT EXISTS ath_monthly_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    -- Current billing period
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,

    -- Renewal status
    -- active: Subscription is active, will need renewal
    -- grace_period: Past due, in 3-day grace period (user still has access)
    -- expired: Grace period ended, access revoked
    -- cancelled: User cancelled
    renewal_status TEXT DEFAULT 'active' CHECK (renewal_status IN (
        'active',
        'grace_period',
        'expired',
        'cancelled'
    )),

    -- Payment tracking
    last_transaction_id UUID REFERENCES ath_movil_transactions(id),
    consecutive_months INTEGER DEFAULT 1,

    -- Notification tracking (to avoid duplicate reminders)
    renewal_reminder_sent_at TIMESTAMP WITH TIME ZONE,
    grace_reminder_sent_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- One subscription record per user
    UNIQUE(user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ath_monthly_user
    ON ath_monthly_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_ath_monthly_renewal_status
    ON ath_monthly_subscriptions(renewal_status);
CREATE INDEX IF NOT EXISTS idx_ath_monthly_period_end
    ON ath_monthly_subscriptions(current_period_end);

-- ============================================
-- 3. Modify Existing Subscriptions Table
-- ============================================
-- Add columns to track payment source

-- Add payment_source column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'subscriptions' AND column_name = 'payment_source'
    ) THEN
        ALTER TABLE subscriptions
        ADD COLUMN payment_source TEXT DEFAULT 'revenuecat'
        CHECK (payment_source IN ('revenuecat', 'ath_movil', 'demo_mode', 'admin_granted'));
    END IF;
END $$;

-- Add ath_transaction_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'subscriptions' AND column_name = 'ath_transaction_id'
    ) THEN
        ALTER TABLE subscriptions
        ADD COLUMN ath_transaction_id UUID REFERENCES ath_movil_transactions(id);
    END IF;
END $$;

-- ============================================
-- 4. Row Level Security (RLS)
-- ============================================

-- Enable RLS on new tables
ALTER TABLE ath_movil_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ath_monthly_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own transactions
CREATE POLICY "Users can view own ATH transactions"
    ON ath_movil_transactions
    FOR SELECT
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- Policy: Only service role can insert/update (Edge Functions)
CREATE POLICY "Service role can manage ATH transactions"
    ON ath_movil_transactions
    FOR ALL
    USING (auth.role() = 'service_role');

-- Policy: Users can view their own monthly subscription
CREATE POLICY "Users can view own ATH monthly sub"
    ON ath_monthly_subscriptions
    FOR SELECT
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- Policy: Only service role can manage monthly subscriptions
CREATE POLICY "Service role can manage ATH monthly subs"
    ON ath_monthly_subscriptions
    FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- 5. Helper Functions
-- ============================================

-- Function to check if user has active ATH Móvil subscription
CREATE OR REPLACE FUNCTION check_ath_subscription_status(p_user_id TEXT)
RETURNS JSON AS $$
DECLARE
    sub_record RECORD;
    monthly_record RECORD;
BEGIN
    -- Check subscriptions table for ATH Móvil payment source
    SELECT status, plan_type, expires_at, payment_source
    INTO sub_record
    FROM subscriptions
    WHERE user_id = p_user_id AND payment_source = 'ath_movil'
    LIMIT 1;

    -- If lifetime, always active
    IF sub_record.plan_type = 'lifetime' THEN
        RETURN json_build_object(
            'has_subscription', true,
            'type', 'lifetime',
            'status', 'active',
            'expires_at', null,
            'needs_renewal', false
        );
    END IF;

    -- Check monthly subscription status
    SELECT * INTO monthly_record
    FROM ath_monthly_subscriptions
    WHERE user_id = p_user_id;

    IF monthly_record IS NULL THEN
        RETURN json_build_object(
            'has_subscription', false,
            'type', null,
            'status', null,
            'expires_at', null,
            'needs_renewal', false
        );
    END IF;

    -- Calculate if renewal is needed (within 3 days of expiry)
    RETURN json_build_object(
        'has_subscription', monthly_record.renewal_status IN ('active', 'grace_period'),
        'type', 'monthly',
        'status', monthly_record.renewal_status,
        'expires_at', monthly_record.current_period_end,
        'needs_renewal', monthly_record.current_period_end <= NOW() + INTERVAL '3 days',
        'consecutive_months', monthly_record.consecutive_months
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update transaction status (called by Edge Functions)
CREATE OR REPLACE FUNCTION update_ath_transaction_status(
    p_transaction_id UUID,
    p_status TEXT,
    p_reference_number TEXT DEFAULT NULL,
    p_daily_transaction_id TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    updated_record RECORD;
BEGIN
    UPDATE ath_movil_transactions
    SET
        status = p_status,
        reference_number = COALESCE(p_reference_number, reference_number),
        daily_transaction_id = COALESCE(p_daily_transaction_id, daily_transaction_id),
        opened_at = CASE WHEN p_status = 'open' AND opened_at IS NULL THEN NOW() ELSE opened_at END,
        confirmed_at = CASE WHEN p_status = 'confirmed' AND confirmed_at IS NULL THEN NOW() ELSE confirmed_at END,
        completed_at = CASE WHEN p_status = 'completed' AND completed_at IS NULL THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = p_transaction_id
    RETURNING * INTO updated_record;

    IF updated_record IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Transaction not found');
    END IF;

    RETURN json_build_object(
        'success', true,
        'transaction_id', updated_record.id,
        'status', updated_record.status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. Trigger for updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to ath_movil_transactions
DROP TRIGGER IF EXISTS update_ath_transactions_modtime ON ath_movil_transactions;
CREATE TRIGGER update_ath_transactions_modtime
    BEFORE UPDATE ON ath_movil_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- Apply trigger to ath_monthly_subscriptions
DROP TRIGGER IF EXISTS update_ath_monthly_modtime ON ath_monthly_subscriptions;
CREATE TRIGGER update_ath_monthly_modtime
    BEFORE UPDATE ON ath_monthly_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- ============================================
-- Done! Tables are ready for ATH Móvil integration
-- ============================================

-- NEXT STEPS:
-- 1. Go to Supabase Dashboard -> Edge Functions
-- 2. Create the following functions:
--    - ath-create-payment
--    - ath-check-payment
--    - ath-authorize-payment
-- 3. Add secrets in Edge Functions settings:
--    - ATH_MOVIL_PUBLIC_TOKEN
--    - ATH_MOVIL_PRIVATE_KEY
I/flutter (27396): ❌ Failed to ensure user exists: AuthApiException(message: Anonymous sign-ins are disabled, statusCode: 422, code: anonymous_provider_disabled)
I/flutter (27396): ❌ Alert system initialization failed: No user ID available
I/flutter (27396): Background service: Anonymous sign-in failed: AuthApiException(message: Anonymous sign-ins are disabled, statusCode: 422, code: anonymous_provider_disabled)