-- FINAL SECURE SUBSCRIPTION LOGIC
-- Handles daily limits for free users and bypasses for premium users
-- Uses auth.uid() to prevent ID spoofing

-- 1. Usage tracking table
CREATE TABLE IF NOT EXISTS public.daily_usage (
    user_id TEXT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    alerts_sent INTEGER DEFAULT 0,
    last_alert_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.daily_usage ENABLE ROW LEVEL SECURITY;

-- Secure Policy: Only the owner can manage their usage
DROP POLICY IF EXISTS "Users can manage their own usage" ON public.daily_usage;
CREATE POLICY "Users can manage their own usage"
ON public.daily_usage FOR ALL
TO authenticated
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- 2. SECURE function to validate alert permission
-- Returns JSON with 'allowed' status and details
CREATE OR REPLACE FUNCTION public.validate_alert_permission()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT := auth.uid()::text;
    v_is_premium BOOLEAN := FALSE;
    v_alerts_sent INTEGER := 0;
    v_last_alert_at TIMESTAMP WITH TIME ZONE;
    v_limit INTEGER := 1; -- Matches PaymentConfig.freeDailyAlertLimit
BEGIN
    -- Check for premium status in both RevenueCat and ATH tables
    SELECT EXISTS (
        SELECT 1 FROM public.subscriptions
        WHERE user_id = v_user_id AND status IN ('premium', 'lifetime')
        AND (expires_at IS NULL OR expires_at > NOW())
        UNION
        SELECT 1 FROM public.ath_monthly_subscriptions
        WHERE user_id = v_user_id AND renewal_status = 'active'
        AND current_period_end > NOW()
    ) INTO v_is_premium;

    -- Premium users get unlimited access
    IF v_is_premium THEN
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'is_premium', TRUE,
            'remaining', 999,
            'reason', NULL
        );
    END IF;

    -- Get current usage for free user
    SELECT alerts_sent, last_alert_at INTO v_alerts_sent, v_last_alert_at
    FROM public.daily_usage
    WHERE user_id = v_user_id;

    -- Reset usage if it's a new day
    IF v_last_alert_at IS NULL OR v_last_alert_at::date < NOW()::date THEN
        v_alerts_sent := 0;
    END IF;

    -- Final permission check
    IF v_alerts_sent < v_limit THEN
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'is_premium', FALSE,
            'remaining', v_limit - v_alerts_sent,
            'reason', NULL
        );
    ELSE
        RETURN jsonb_build_object(
            'allowed', FALSE,
            'is_premium', FALSE,
            'remaining', 0,
            'reason', 'Daily limit of ' || v_limit || ' alerts reached. Upgrade to Premium for unlimited access!'
        );
    END IF;
END;
$$;

-- 3. SECURE function to increment usage
CREATE OR REPLACE FUNCTION public.increment_daily_usage()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT := auth.uid()::text;
BEGIN
    INSERT INTO public.daily_usage (user_id, alerts_sent, last_alert_at, updated_at)
    VALUES (v_user_id, 1, NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        alerts_sent = CASE
            WHEN public.daily_usage.last_alert_at::date < NOW()::date THEN 1
            ELSE public.daily_usage.alerts_sent + 1
        END,
        last_alert_at = NOW(),
        updated_at = NOW();
END;
$$;
