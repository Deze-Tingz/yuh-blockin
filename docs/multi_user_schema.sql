-- MULTI-USER LICENSE PLATE SYSTEM
-- Multiple people can register the same license plate
-- Alerts are sent to ALL registered users for that plate
-- No ownership verification required - maximum simplicity

-- Drop and recreate tables to remove unique constraints
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS plate_registry CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table - simple anonymous profiles
CREATE TABLE users (
    user_id TEXT PRIMARY KEY,
    reputation_score INTEGER DEFAULT 1000,
    is_premium BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Plate registry - REMOVED UNIQUE constraint to allow multiple registrations
CREATE TABLE plate_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hashed_plate TEXT NOT NULL, -- NO LONGER UNIQUE - multiple users can register same plate
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT true, -- Always true - no verification needed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Real-time alerts (multiple recipients possible)
CREATE TABLE alerts (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_plate_hash TEXT NOT NULL, -- The hashed plate that was alerted
    urgency_level TEXT NOT NULL CHECK (urgency_level IN ('low', 'normal', 'high', 'urgent')),
    custom_message TEXT,
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'acknowledged', 'resolved', 'expired', 'cancelled')),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Alert recipients - tracks which users received each alert
CREATE TABLE alert_recipients (
    recipient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_id UUID NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'acknowledged', 'resolved', 'ignored')),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User statistics
CREATE TABLE user_stats (
    user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    plates_registered INTEGER DEFAULT 0,
    alerts_sent INTEGER DEFAULT 0,
    alerts_received INTEGER DEFAULT 0,
    alerts_acknowledged INTEGER DEFAULT 0,
    alerts_resolved INTEGER DEFAULT 0,
    average_response_time_minutes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_plate_registry_hashed_plate ON plate_registry(hashed_plate); -- Non-unique index
CREATE INDEX idx_plate_registry_user_id ON plate_registry(user_id);
CREATE INDEX idx_alerts_target_plate_hash ON alerts(target_plate_hash);
CREATE INDEX idx_alerts_sender_user_id ON alerts(sender_user_id);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_sent_at ON alerts(sent_at);
CREATE INDEX idx_alert_recipients_alert_id ON alert_recipients(alert_id);
CREATE INDEX idx_alert_recipients_user_id ON alert_recipients(user_id);
CREATE INDEX idx_alert_recipients_status ON alert_recipients(status);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE plate_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can only see their own data
CREATE POLICY "Own user data" ON users
    FOR ALL USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Users can register any plate (no ownership verification)
CREATE POLICY "Anyone can register plates" ON plate_registry
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users see own registered plates" ON plate_registry
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can delete own registrations" ON plate_registry
    FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Allow anonymous plate lookup for alert routing
CREATE POLICY "Anonymous plate lookup" ON plate_registry
    FOR SELECT USING (true);

-- Alert policies
CREATE POLICY "Users can send alerts" ON alerts
    FOR INSERT WITH CHECK (sender_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users see alerts they sent" ON alerts
    FOR SELECT USING (sender_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Alert recipient policies
CREATE POLICY "Users see alerts they received" ON alert_recipients
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can respond to their alerts" ON alert_recipients
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- User stats policies
CREATE POLICY "Own stats only" ON user_stats
    FOR ALL USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Triggers and functions
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_plate_registry_updated_at BEFORE UPDATE ON plate_registry
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_alerts_updated_at BEFORE UPDATE ON alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_alert_recipients_updated_at BEFORE UPDATE ON alert_recipients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to create alert recipients when alert is sent
CREATE OR REPLACE FUNCTION create_alert_recipients()
RETURNS TRIGGER AS $$
BEGIN
    -- Find all users who registered this plate and create recipient records
    INSERT INTO alert_recipients (alert_id, user_id)
    SELECT NEW.alert_id, user_id
    FROM plate_registry
    WHERE hashed_plate = NEW.target_plate_hash;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_recipients_trigger AFTER INSERT ON alerts
    FOR EACH ROW EXECUTE FUNCTION create_alert_recipients();

-- Function to update user stats when plates are registered
CREATE OR REPLACE FUNCTION update_user_stats_on_plate_registration()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_stats (user_id, plates_registered)
    VALUES (NEW.user_id, 1)
    ON CONFLICT (user_id)
    DO UPDATE SET
        plates_registered = user_stats.plates_registered + 1,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER plate_registration_stats_trigger AFTER INSERT ON plate_registry
    FOR EACH ROW EXECUTE FUNCTION update_user_stats_on_plate_registration();

-- Function to update reputation when alerts are resolved
CREATE OR REPLACE FUNCTION update_reputation_on_alert_resolution()
RETURNS TRIGGER AS $$
BEGIN
    -- When recipient resolves alert, update reputation
    IF NEW.status = 'resolved' AND OLD.status != 'resolved' THEN
        -- Receiver gets +15 points for resolving
        UPDATE users
        SET reputation_score = reputation_score + 15,
            last_active_at = NOW()
        WHERE user_id = NEW.user_id;

        -- Sender gets +10 points for successful alert
        UPDATE users
        SET reputation_score = reputation_score + 10,
            last_active_at = NOW()
        WHERE user_id = (
            SELECT sender_user_id FROM alerts WHERE alert_id = NEW.alert_id
        );

        -- Update stats
        INSERT INTO user_stats (user_id, alerts_resolved)
        VALUES (NEW.user_id, 1)
        ON CONFLICT (user_id)
        DO UPDATE SET
            alerts_resolved = user_stats.alerts_resolved + 1,
            updated_at = NOW();

    ELSIF NEW.status = 'acknowledged' AND OLD.status != 'acknowledged' THEN
        -- Receiver gets +5 points for acknowledging
        UPDATE users
        SET reputation_score = reputation_score + 5,
            last_active_at = NOW()
        WHERE user_id = NEW.user_id;

        -- Update stats
        INSERT INTO user_stats (user_id, alerts_acknowledged)
        VALUES (NEW.user_id, 1)
        ON CONFLICT (user_id)
        DO UPDATE SET
            alerts_acknowledged = user_stats.alerts_acknowledged + 1,
            updated_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reputation_update_trigger AFTER UPDATE ON alert_recipients
    FOR EACH ROW EXECUTE FUNCTION update_reputation_on_alert_resolution();

-- Enable real-time subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE alert_recipients;
ALTER PUBLICATION supabase_realtime ADD TABLE user_stats;

-- Views for analytics
CREATE VIEW plate_registration_stats AS
SELECT
    hashed_plate,
    COUNT(*) as registration_count,
    COUNT(DISTINCT user_id) as unique_users,
    MIN(registered_at) as first_registered,
    MAX(registered_at) as last_registered
FROM plate_registry
GROUP BY hashed_plate
ORDER BY registration_count DESC;

CREATE VIEW alert_effectiveness AS
SELECT
    urgency_level,
    COUNT(*) as total_alerts,
    COUNT(DISTINCT ar.user_id) as recipients_reached,
    COUNT(CASE WHEN ar.status IN ('acknowledged', 'resolved') THEN 1 END) as responses,
    COUNT(CASE WHEN ar.status = 'resolved' THEN 1 END) as resolutions,
    ROUND(
        COUNT(CASE WHEN ar.status IN ('acknowledged', 'resolved') THEN 1 END)::numeric /
        COUNT(*)::numeric * 100, 2
    ) as response_rate_percent
FROM alerts a
LEFT JOIN alert_recipients ar ON a.alert_id = ar.alert_id
WHERE a.sent_at > NOW() - INTERVAL '30 days'
GROUP BY urgency_level;

-- Comments
COMMENT ON TABLE plate_registry IS 'Multiple users can register the same license plate. No ownership verification required.';
COMMENT ON COLUMN plate_registry.hashed_plate IS 'HMAC-SHA256 hash of license plate. Multiple registrations allowed for same plate.';
COMMENT ON TABLE alert_recipients IS 'Tracks all users who received each alert. Multiple recipients per alert supported.';
COMMENT ON TABLE alerts IS 'Alert broadcasts to all users registered for a license plate.';

-- Demo data (multiple users registering same plate)
INSERT INTO users (user_id, reputation_score)
VALUES
    ('user_owner_123', 1500),
    ('user_spouse_456', 1200),
    ('user_teen_789', 800);

-- Same plate registered by multiple family members
INSERT INTO plate_registry (hashed_plate, user_id)
VALUES
    ('demo_plate_hash_abc123', 'user_owner_123'),
    ('demo_plate_hash_abc123', 'user_spouse_456'),
    ('demo_plate_hash_abc123', 'user_teen_789');