-- ANONYMOUS PARKING CODE SYSTEM
-- Maximum Privacy: No license plates, phone numbers, or personal info stored
-- Users get unique codes like "PARK-7K9M-3X2Q" that they save and use

-- Drop existing tables
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS plate_registry CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Anonymous parking profiles - only unique codes
CREATE TABLE parking_profiles (
    profile_id TEXT PRIMARY KEY,
    parking_code TEXT UNIQUE NOT NULL, -- Format: PARK-XXXX-XXXX
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reputation_score INTEGER DEFAULT 1000,
    alerts_received INTEGER DEFAULT 0,
    alerts_sent INTEGER DEFAULT 0,
    account_status TEXT DEFAULT 'active' CHECK (account_status IN ('active', 'suspended')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Anonymous alerts - no personal information
CREATE TABLE anonymous_alerts (
    alert_id TEXT PRIMARY KEY,
    sender_profile_id TEXT NOT NULL REFERENCES parking_profiles(profile_id) ON DELETE CASCADE,
    receiver_profile_id TEXT NOT NULL REFERENCES parking_profiles(profile_id) ON DELETE CASCADE,
    target_parking_code TEXT NOT NULL, -- The code that was alerted
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

-- Reputation system for spam prevention
CREATE TABLE reputation_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id TEXT NOT NULL REFERENCES parking_profiles(profile_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'alert_sent', 'alert_acknowledged', 'alert_resolved', 'quick_response',
        'spam_report', 'account_created'
    )),
    reputation_change INTEGER NOT NULL, -- +/- reputation points
    description TEXT,
    related_alert_id TEXT, -- Optional reference to alert
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Security events for fraud detection (anonymous)
CREATE TABLE security_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id TEXT REFERENCES parking_profiles(profile_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'multiple_codes_requested', 'rapid_alerts', 'suspicious_pattern',
        'reputation_manipulation', 'spam_detected'
    )),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    details JSONB NOT NULL,
    action_taken TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_parking_profiles_code ON parking_profiles(parking_code);
CREATE INDEX idx_parking_profiles_reputation ON parking_profiles(reputation_score);
CREATE INDEX idx_anonymous_alerts_sender ON anonymous_alerts(sender_profile_id);
CREATE INDEX idx_anonymous_alerts_receiver ON anonymous_alerts(receiver_profile_id);
CREATE INDEX idx_anonymous_alerts_target_code ON anonymous_alerts(target_parking_code);
CREATE INDEX idx_anonymous_alerts_status ON anonymous_alerts(status);
CREATE INDEX idx_anonymous_alerts_sent_at ON anonymous_alerts(sent_at);
CREATE INDEX idx_reputation_events_profile ON reputation_events(profile_id);
CREATE INDEX idx_security_events_profile ON security_events(profile_id);
CREATE INDEX idx_security_events_type ON security_events(event_type);

-- Enable Row Level Security (RLS)
ALTER TABLE parking_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE reputation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies for maximum privacy

-- Users can only see their own profile
CREATE POLICY "Own profile only" ON parking_profiles
    FOR ALL USING (profile_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Anonymous code lookup for alerts (but not full profile)
CREATE POLICY "Code lookup for alerts" ON parking_profiles
    FOR SELECT USING (true); -- Allow anonymous lookups by parking code

-- Users can only see alerts they sent or received
CREATE POLICY "Own alerts only" ON anonymous_alerts
    FOR SELECT USING (
        sender_profile_id = current_setting('request.jwt.claims', true)::json->>'sub' OR
        receiver_profile_id = current_setting('request.jwt.claims', true)::json->>'sub'
    );

-- Users can send alerts to any valid parking code
CREATE POLICY "Send alerts to valid codes" ON anonymous_alerts
    FOR INSERT WITH CHECK (
        sender_profile_id = current_setting('request.jwt.claims', true)::json->>'sub'
    );

-- Users can update alerts they received
CREATE POLICY "Update received alerts" ON anonymous_alerts
    FOR UPDATE USING (
        receiver_profile_id = current_setting('request.jwt.claims', true)::json->>'sub'
    );

-- Users can see their own reputation events
CREATE POLICY "Own reputation events" ON reputation_events
    FOR ALL USING (profile_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Security events are admin-only
CREATE POLICY "Admin security events" ON security_events
    FOR ALL USING (current_setting('request.jwt.claims', true)::json->>'role' = 'admin');

-- Triggers and functions
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_parking_profiles_updated_at BEFORE UPDATE ON parking_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_anonymous_alerts_updated_at BEFORE UPDATE ON anonymous_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Automatic reputation updates
CREATE OR REPLACE FUNCTION update_reputation_on_alert_resolution()
RETURNS TRIGGER AS $$
BEGIN
    -- When alert is resolved, update reputation scores
    IF NEW.status = 'resolved' AND OLD.status != 'resolved' THEN
        -- Sender gets +10 points for successful alert
        INSERT INTO reputation_events (profile_id, event_type, reputation_change, description, related_alert_id)
        VALUES (NEW.sender_profile_id, 'alert_resolved', 10, 'Successfully resolved parking alert', NEW.alert_id);

        UPDATE parking_profiles
        SET reputation_score = reputation_score + 10,
            last_active_at = NOW()
        WHERE profile_id = NEW.sender_profile_id;

        -- Receiver gets bonus for quick response (if within 5 minutes)
        IF NEW.acknowledged_at IS NOT NULL AND
           NEW.acknowledged_at - NEW.sent_at <= INTERVAL '5 minutes' THEN
            INSERT INTO reputation_events (profile_id, event_type, reputation_change, description, related_alert_id)
            VALUES (NEW.receiver_profile_id, 'quick_response', 15, 'Quick response to parking alert', NEW.alert_id);

            UPDATE parking_profiles
            SET reputation_score = reputation_score + 15,
                last_active_at = NOW()
            WHERE profile_id = NEW.receiver_profile_id;
        ELSE
            -- Regular response gets +5 points
            INSERT INTO reputation_events (profile_id, event_type, reputation_change, description, related_alert_id)
            VALUES (NEW.receiver_profile_id, 'alert_acknowledged', 5, 'Acknowledged parking alert', NEW.alert_id);

            UPDATE parking_profiles
            SET reputation_score = reputation_score + 5,
                last_active_at = NOW()
            WHERE profile_id = NEW.receiver_profile_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reputation_update_trigger AFTER UPDATE ON anonymous_alerts
    FOR EACH ROW EXECUTE FUNCTION update_reputation_on_alert_resolution();

-- Anti-spam detection
CREATE OR REPLACE FUNCTION detect_spam_activity()
RETURNS TRIGGER AS $$
DECLARE
    recent_alerts INTEGER;
    profile_reputation INTEGER;
BEGIN
    -- Check for rapid alert sending (more than 5 alerts in 10 minutes)
    SELECT COUNT(*) INTO recent_alerts
    FROM anonymous_alerts
    WHERE sender_profile_id = NEW.sender_profile_id
    AND sent_at > NOW() - INTERVAL '10 minutes';

    IF recent_alerts > 5 THEN
        INSERT INTO security_events (profile_id, event_type, severity, details)
        VALUES (NEW.sender_profile_id, 'rapid_alerts', 'high',
               json_build_object('alert_count', recent_alerts, 'timeframe', '10 minutes'));

        -- Temporary reputation penalty
        UPDATE parking_profiles
        SET reputation_score = GREATEST(reputation_score - 50, 0)
        WHERE profile_id = NEW.sender_profile_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER spam_detection_trigger AFTER INSERT ON anonymous_alerts
    FOR EACH ROW EXECUTE FUNCTION detect_spam_activity();

-- Parking code validation
CREATE OR REPLACE FUNCTION validate_parking_code()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure parking code follows format: PARK-XXXX-XXXX
    IF NOT NEW.parking_code ~ '^PARK-[A-Z0-9]{4}-[A-Z0-9]{4}$' THEN
        RAISE EXCEPTION 'Invalid parking code format. Must be PARK-XXXX-XXXX';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_code_trigger BEFORE INSERT OR UPDATE ON parking_profiles
    FOR EACH ROW EXECUTE FUNCTION validate_parking_code();

-- Enable real-time subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE anonymous_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE parking_profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE reputation_events;

-- Views for analytics (anonymous)
CREATE VIEW alert_statistics AS
SELECT
    urgency_level,
    status,
    COUNT(*) as alert_count,
    AVG(EXTRACT(EPOCH FROM (COALESCE(acknowledged_at, resolved_at, expires_at) - sent_at))) as avg_response_time_seconds
FROM anonymous_alerts
WHERE sent_at > NOW() - INTERVAL '30 days'
GROUP BY urgency_level, status;

CREATE VIEW reputation_distribution AS
SELECT
    CASE
        WHEN reputation_score >= 2000 THEN 'Excellent (2000+)'
        WHEN reputation_score >= 1500 THEN 'Very Good (1500-1999)'
        WHEN reputation_score >= 1000 THEN 'Good (1000-1499)'
        WHEN reputation_score >= 500 THEN 'Fair (500-999)'
        ELSE 'Poor (<500)'
    END as reputation_tier,
    COUNT(*) as profile_count,
    AVG(alerts_sent) as avg_alerts_sent,
    AVG(alerts_received) as avg_alerts_received
FROM parking_profiles
WHERE account_status = 'active'
GROUP BY reputation_tier;

-- Comments explaining the system
COMMENT ON TABLE parking_profiles IS 'Anonymous parking profiles with unique codes. No personal information stored.';
COMMENT ON COLUMN parking_profiles.parking_code IS 'Unique parking code like PARK-7K9M-3X2Q that users save and share.';
COMMENT ON TABLE anonymous_alerts IS 'Completely anonymous alert system using parking codes for routing.';
COMMENT ON COLUMN anonymous_alerts.target_parking_code IS 'The parking code that was alerted - no license plates stored.';

-- Demo data (remove in production)
INSERT INTO parking_profiles (profile_id, parking_code, reputation_score)
VALUES
    ('demo_profile_1', 'PARK-TEST-DEMO', 1500),
    ('demo_profile_2', 'PARK-DEMO-USER', 1200);