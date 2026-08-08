-- Create Subscriptions Table
-- This table syncs with RevenueCat status to provide cross-platform parity (Web/Android/iOS)

CREATE TABLE IF NOT EXISTS public.subscriptions (
    user_id TEXT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'free', -- 'free', 'premium', 'lifetime'
    plan_type TEXT, -- 'monthly', 'lifetime'
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE, -- NULL for lifetime
    is_demo BOOLEAN DEFAULT FALSE,
    source TEXT DEFAULT 'revenuecat', -- 'revenuecat', 'ath_movil', 'manual'
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own subscription"
ON public.subscriptions FOR SELECT
TO anon, authenticated
USING (auth.uid()::text = user_id);

CREATE POLICY "Service role can manage all subscriptions"
ON public.subscriptions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
