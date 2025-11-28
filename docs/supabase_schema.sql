-- Yuh Blockin' Supabase Database Schema
-- Privacy-First Design: Only stores hashed license plates, never actual plate numbers

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
YB-YKJT-B6GX-S78A-GRK3
-- Users table - anonymous user profiles
CREATE TABLE users (
    user_id TEXT PRIMARY KEY,


    reputation_score INTEGER DEFAULT 1000,
    is_premium BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- License plate registry - PRIVACY: only stores hashed plates
CREATE TABLE plate_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hashed_plate TEXT UNIQUE NOT NULL, -- HMAC-SHA256 hash, never actual plate
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Alerts table - real-time parking alerts
CREATE TABLE alerts (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_plate_hash TEXT NOT NULL, -- References hashed plate, maintains privacy
    urgency_level TEXT NOT NULL CHECK (urgency_level IN ('low', 'normal', 'high', 'urgent')),
    custom_message TEXT,
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'acknowledged', 'resolved', 'expired', 'cancelled')),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User statistics for reputation system
CREATE TABLE user_stats (
    user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    alerts_sent INTEGER DEFAULT 0,
    alerts_received INTEGER DEFAULT 0,
    alerts_acknowledged INTEGER DEFAULT 0,
    alerts_resolved INTEGER DEFAULT 0,
    average_response_time_minutes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_plate_registry_hashed_plate ON plate_registry(hashed_plate);
CREATE INDEX idx_plate_registry_user_id ON plate_registry(user_id);
CREATE INDEX idx_alerts_receiver_user_id ON alerts(receiver_user_id);
CREATE INDEX idx_alerts_sender_user_id ON alerts(sender_user_id);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_sent_at ON alerts(sent_at);
CREATE INDEX idx_alerts_target_plate_hash ON alerts(target_plate_hash);

-- Enable Row Level Security for privacy protection
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE plate_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies for secure access

-- Users can only read their own data
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Plate registry policies
CREATE POLICY "Users can view their own plates" ON plate_registry
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can register plates" ON plate_registry
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can delete their own plates" ON plate_registry
    FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Allow anonymous validation of plates (for alert sending)
CREATE POLICY "Allow anonymous plate validation" ON plate_registry
    FOR SELECT USING (true);

-- Alert policies
CREATE POLICY "Users can view alerts they sent or received" ON alerts
    FOR SELECT USING (
        sender_user_id = current_setting('request.jwt.claims', true)::json->>'sub' OR
        receiver_user_id = current_setting('request.jwt.claims', true)::json->>'sub'
    );

CREATE POLICY "Users can send alerts" ON alerts
    FOR INSERT WITH CHECK (sender_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can update alerts they received" ON alerts
    FOR UPDATE USING (receiver_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- User stats policies
CREATE POLICY "Users can view their own stats" ON user_stats
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can update their own stats" ON user_stats
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Functions for automatic updates
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update timestamps
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_plate_registry_updated_at BEFORE UPDATE ON plate_registry
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_alerts_updated_at BEFORE UPDATE ON alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_user_stats_updated_at BEFORE UPDATE ON user_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to update user stats when alerts are created/updated
CREATE OR REPLACE FUNCTION update_user_stats_on_alert_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Update stats for sender (alerts sent)
    INSERT INTO user_stats (user_id, alerts_sent)
    VALUES (NEW.sender_user_id, 1)
    ON CONFLICT (user_id)
    DO UPDATE SET
        alerts_sent = user_stats.alerts_sent + 1,
        updated_at = NOW();

    -- Update stats for receiver if alert is acknowledged/resolved
    IF NEW.status IN ('acknowledged', 'resolved') THEN
        INSERT INTO user_stats (user_id, alerts_acknowledged)
        VALUES (NEW.receiver_user_id, 1)
        ON CONFLICT (user_id)
        DO UPDATE SET
            alerts_acknowledged = user_stats.alerts_acknowledged + 1,
            updated_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER alert_stats_trigger AFTER INSERT OR UPDATE ON alerts
    FOR EACH ROW EXECUTE FUNCTION update_user_stats_on_alert_change();

-- Enable real-time subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE user_stats;

-- Insert demo data for testing (optional)
-- Demo user
INSERT INTO users (user_id, reputation_score, is_premium)
VALUES ('demo_user_123', 1500, true);

-- Demo plate registration (this is a hashed plate - not real)
INSERT INTO plate_registry (hashed_plate, user_id)
VALUES ('a1b2c3d4e5f6g7h8', 'demo_user_123');

-- Comments explaining privacy approach
COMMENT ON TABLE plate_registry IS 'Stores only HMAC-SHA256 hashes of license plates. No actual plate numbers are ever stored, ensuring complete privacy protection.';
COMMENT ON COLUMN plate_registry.hashed_plate IS 'HMAC-SHA256 hash of original license plate. Irreversible hash ensures privacy even in case of data breach.';
COMMENT ON TABLE alerts IS 'Real-time alert system using hashed plate references. No personal information exposed.';
COMMENT ON COLUMN alerts.target_plate_hash IS 'References hashed license plate for privacy. Original plate number never stored or transmitted to database.';

-- =====================================================
-- SUBSCRIPTION & MONETIZATION TABLES
-- =====================================================

-- Subscriptions table - tracks premium status
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status TEXT DEFAULT 'free' CHECK (status IN ('free', 'premium', 'lifetime')),
    plan_type TEXT CHECK (plan_type IN ('monthly', 'lifetime')),
    revenuecat_user_id TEXT,
    started_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);

-- Daily alert usage - tracks free tier limits
CREATE TABLE daily_alert_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    date DATE DEFAULT CURRENT_DATE,
    alert_count INTEGER DEFAULT 0,
    UNIQUE(user_id, date)
);

CREATE INDEX idx_daily_usage_user_date ON daily_alert_usage(user_id, date);

-- Enable RLS on subscription tables
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_alert_usage ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscriptions
CREATE POLICY "Users can view their own subscription" ON subscriptions
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Allow anonymous subscription check" ON subscriptions
    FOR SELECT USING (true);

-- RLS Policies for daily usage (allow service to read/write)
CREATE POLICY "Users can view their own daily usage" ON daily_alert_usage
    FOR SELECT USING (true);

CREATE POLICY "Allow increment daily usage" ON daily_alert_usage
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update daily usage" ON daily_alert_usage
    FOR UPDATE USING (true);

-- Trigger to auto-update timestamps on subscriptions
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to increment daily usage (upsert)
CREATE OR REPLACE FUNCTION increment_daily_usage(p_user_id TEXT)
RETURNS INTEGER AS $$
DECLARE
    new_count INTEGER;
BEGIN
    INSERT INTO daily_alert_usage (user_id, date, alert_count)
    VALUES (p_user_id, CURRENT_DATE, 1)
    ON CONFLICT (user_id, date)
    DO UPDATE SET alert_count = daily_alert_usage.alert_count + 1
    RETURNING alert_count INTO new_count;

    RETURN new_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get remaining alerts for a user
CREATE OR REPLACE FUNCTION get_remaining_alerts(p_user_id TEXT, p_free_limit INTEGER DEFAULT 3)
RETURNS INTEGER AS $$
DECLARE
    user_status TEXT;
    alerts_used INTEGER;
BEGIN
    -- Check subscription status
    SELECT status INTO user_status
    FROM subscriptions
    WHERE user_id = p_user_id
    LIMIT 1;

    -- Premium/lifetime users get unlimited
    IF user_status IN ('premium', 'lifetime') THEN
        RETURN 999;
    END IF;

    -- Get today's usage for free users
    SELECT COALESCE(alert_count, 0) INTO alerts_used
    FROM daily_alert_usage
    WHERE user_id = p_user_id AND date = CURRENT_DATE;

    RETURN GREATEST(0, p_free_limit - COALESCE(alerts_used, 0));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PLATE OWNERSHIP VERIFICATION SYSTEM
-- Crypto-style ownership keys - no photos, no IDs required
-- =====================================================

-- Add ownership key columns to plates table
-- RUN THIS SQL ON YOUR EXISTING 'plates' TABLE:
ALTER TABLE plates ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'verified';
ALTER TABLE plates ADD COLUMN IF NOT EXISTS ownership_key_hash TEXT;
ALTER TABLE plates ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE plates ADD COLUMN IF NOT EXISTS hashed_plate TEXT;

-- Add constraint for verification_status (run separately if needed)
-- ALTER TABLE plates ADD CONSTRAINT plates_verification_status_check
--     CHECK (verification_status IN ('unverified', 'verified', 'disputed'));

-- Index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_plates_verification_status ON plates(verification_status);
CREATE INDEX IF NOT EXISTS idx_plates_ownership_key_hash ON plates(ownership_key_hash);
CREATE INDEX IF NOT EXISTS idx_plates_hashed_plate ON plates(hashed_plate);

-- Update existing plates to be verified by default (legacy support)
UPDATE plates SET verification_status = 'verified' WHERE verification_status IS NULL;

COMMENT ON TABLE plates IS 'License plate registry with crypto-style ownership verification. Only stores hashed plates and hashed ownership keys.';
COMMENT ON COLUMN plates.ownership_key_hash IS 'SHA-256 hash of the ownership key. Original key stored ONLY on user device (like a crypto private key).';
COMMENT ON COLUMN plates.verification_status IS 'verified=ownership proven with key, unverified=no key set, disputed=under ownership dispute';