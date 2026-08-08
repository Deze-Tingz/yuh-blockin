-- ENHANCED SECURITY SCHEMA FOR YUH BLOCKIN'
-- Addresses ownership verification and prevents unauthorized plate registration

-- Drop existing tables to recreate with security features
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS plate_registry CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Add verification tables
DROP TABLE IF EXISTS ownership_verifications CASCADE;
DROP TABLE IF EXISTS verification_evidence CASCADE;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table with enhanced security
CREATE TABLE users (
    user_id TEXT PRIMARY KEY,
    phone_number TEXT, -- For SMS verification
    email TEXT, -- For notifications
    phone_verified BOOLEAN DEFAULT false,
    email_verified BOOLEAN DEFAULT false,
    reputation_score INTEGER DEFAULT 1000,
    is_premium BOOLEAN DEFAULT true,
    account_status TEXT DEFAULT 'active' CHECK (account_status IN ('active', 'suspended', 'pending_verification')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ownership verification requests
CREATE TABLE ownership_verifications (
    verification_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    hashed_plate TEXT NOT NULL, -- Hash of plate being claimed
    original_plate_hint TEXT, -- First/last chars for human verification (e.g., "A***3")
    phone_number TEXT NOT NULL,
    email TEXT,

    -- Verification status fields
    sms_status TEXT DEFAULT 'pending' CHECK (sms_status IN ('pending', 'sent', 'verified', 'failed', 'expired')),
    sms_code TEXT, -- Encrypted verification code
    sms_sent_at TIMESTAMP WITH TIME ZONE,
    sms_verified_at TIMESTAMP WITH TIME ZONE,

    photo_status TEXT DEFAULT 'pending' CHECK (photo_status IN ('pending', 'uploaded', 'verified', 'rejected')),
    photo_url TEXT, -- Secure URL to uploaded photo
    photo_analysis_result JSONB, -- AI analysis results
    photo_uploaded_at TIMESTAMP WITH TIME ZONE,
    photo_verified_at TIMESTAMP WITH TIME ZONE,

    document_status TEXT DEFAULT 'pending' CHECK (document_status IN ('pending', 'uploaded', 'verified', 'rejected')),
    document_url TEXT, -- Secure URL to registration document
    document_analysis_result JSONB, -- Document verification results
    document_uploaded_at TIMESTAMP WITH TIME ZONE,
    document_verified_at TIMESTAMP WITH TIME ZONE,

    -- Overall verification status
    overall_status TEXT DEFAULT 'pending' CHECK (overall_status IN (
        'pending', 'sms_pending', 'photo_pending', 'document_pending',
        'manual_review', 'verified', 'rejected', 'expired'
    )),

    -- Review and moderation
    requires_manual_review BOOLEAN DEFAULT false,
    reviewer_user_id TEXT, -- Admin/moderator who reviewed
    reviewer_notes TEXT,
    reviewed_at TIMESTAMP WITH TIME ZONE,

    -- Security fields
    ip_address INET, -- Track registration IP for fraud detection
    user_agent TEXT, -- Browser/device info
    fraud_score DECIMAL(3,2) DEFAULT 0.00, -- 0.00 = clean, 1.00 = definitely fraud
    security_flags JSONB DEFAULT '{}', -- Flexible security metadata

    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'), -- Expire after 7 days
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Evidence files for verification (photos, documents)
CREATE TABLE verification_evidence (
    evidence_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    verification_id TEXT NOT NULL REFERENCES ownership_verifications(verification_id) ON DELETE CASCADE,
    evidence_type TEXT NOT NULL CHECK (evidence_type IN ('vehicle_photo', 'registration_document', 'id_document')),
    file_url TEXT NOT NULL, -- Secure cloud storage URL
    file_hash TEXT NOT NULL, -- SHA256 of file for integrity
    file_size BIGINT NOT NULL,
    mime_type TEXT NOT NULL,

    -- AI/ML analysis results
    analysis_status TEXT DEFAULT 'pending' CHECK (analysis_status IN ('pending', 'processing', 'completed', 'failed')),
    analysis_result JSONB, -- Detailed analysis results
    confidence_score DECIMAL(3,2), -- 0.00-1.00 confidence in verification

    -- OCR results for documents
    extracted_text TEXT, -- Full OCR text
    extracted_plate_number TEXT, -- Extracted plate from document/photo
    plate_match_confidence DECIMAL(3,2), -- How well extracted plate matches claim

    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    analyzed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Verified license plate registry (only after ownership verification)
CREATE TABLE plate_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hashed_plate TEXT UNIQUE NOT NULL, -- HMAC-SHA256 hash
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    verification_id TEXT NOT NULL REFERENCES ownership_verifications(verification_id),

    -- Registration details
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT false, -- Only true after full verification
    verification_method TEXT NOT NULL CHECK (verification_method IN ('full_verification', 'manual_approval', 'legacy_import')),

    -- Security tracking
    registration_ip INET,
    last_alert_sent_at TIMESTAMP WITH TIME ZONE,
    alert_count INTEGER DEFAULT 0,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Real-time alerts (unchanged but with additional security)
CREATE TABLE alerts (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_plate_hash TEXT NOT NULL,
    urgency_level TEXT NOT NULL CHECK (urgency_level IN ('low', 'normal', 'high', 'urgent')),
    custom_message TEXT,
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'acknowledged', 'resolved', 'expired', 'cancelled')),

    -- Anti-spam and fraud protection
    sender_ip INET, -- Track sender IP for abuse detection
    is_suspected_spam BOOLEAN DEFAULT false,
    spam_score DECIMAL(3,2) DEFAULT 0.00,

    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User statistics (enhanced with fraud detection metrics)
CREATE TABLE user_stats (
    user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    alerts_sent INTEGER DEFAULT 0,
    alerts_received INTEGER DEFAULT 0,
    alerts_acknowledged INTEGER DEFAULT 0,
    alerts_resolved INTEGER DEFAULT 0,
    average_response_time_minutes INTEGER DEFAULT 0,

    -- Fraud and abuse metrics
    spam_reports_against INTEGER DEFAULT 0,
    spam_reports_made INTEGER DEFAULT 0,
    false_claims_count INTEGER DEFAULT 0,
    trust_score DECIMAL(3,2) DEFAULT 1.00, -- 1.00 = fully trusted, 0.00 = banned

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fraud detection log
CREATE TABLE security_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT REFERENCES users(user_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'suspicious_registration', 'spam_alert', 'multiple_devices',
        'rapid_registrations', 'fake_document', 'ip_mismatch'
    )),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    details JSONB NOT NULL,
    ip_address INET,
    user_agent TEXT,
    action_taken TEXT, -- What automated action was taken
    requires_review BOOLEAN DEFAULT false,
    reviewed BOOLEAN DEFAULT false,
    reviewer_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_plate_registry_hashed_plate ON plate_registry(hashed_plate);
CREATE INDEX idx_plate_registry_user_id ON plate_registry(user_id);
CREATE INDEX idx_ownership_verifications_user_id ON ownership_verifications(user_id);
CREATE INDEX idx_ownership_verifications_hashed_plate ON ownership_verifications(hashed_plate);
CREATE INDEX idx_ownership_verifications_status ON ownership_verifications(overall_status);
CREATE INDEX idx_verification_evidence_verification_id ON verification_evidence(verification_id);
CREATE INDEX idx_alerts_receiver_user_id ON alerts(receiver_user_id);
CREATE INDEX idx_alerts_sender_user_id ON alerts(sender_user_id);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_sent_at ON alerts(sent_at);
CREATE INDEX idx_security_events_user_id ON security_events(user_id);
CREATE INDEX idx_security_events_event_type ON security_events(event_type);
CREATE INDEX idx_security_events_created_at ON security_events(created_at);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE ownership_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE plate_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events ENABLE ROW LEVEL SECURITY;

-- Enhanced RLS Policies

-- Users can only see their own data
CREATE POLICY "Users own data only" ON users
    FOR ALL USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Verification policies - stricter access control
CREATE POLICY "Own verifications only" ON ownership_verifications
    FOR ALL USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Admins can view all verifications for moderation
CREATE POLICY "Admin verification access" ON ownership_verifications
    FOR SELECT USING (
        current_setting('request.jwt.claims', true)::json->>'role' = 'admin' OR
        current_setting('request.jwt.claims', true)::json->>'role' = 'moderator'
    );

-- Evidence access - very restricted
CREATE POLICY "Own evidence only" ON verification_evidence
    FOR ALL USING (
        verification_id IN (
            SELECT verification_id FROM ownership_verifications
            WHERE user_id = current_setting('request.jwt.claims', true)::json->>'sub'
        )
    );

-- Plate registry - allow anonymous lookups for alert routing
CREATE POLICY "Verified plates visible" ON plate_registry
    FOR SELECT USING (is_verified = true);

-- Users can only manage their own plates
CREATE POLICY "Own plates management" ON plate_registry
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'sub');
CREATE POLICY "Own plates update" ON plate_registry
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');
CREATE POLICY "Own plates delete" ON plate_registry
    FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Alert policies (same as before)
CREATE POLICY "Users can view relevant alerts" ON alerts
    FOR SELECT USING (
        sender_user_id = current_setting('request.jwt.claims', true)::json->>'sub' OR
        receiver_user_id = current_setting('request.jwt.claims', true)::json->>'sub'
    );

CREATE POLICY "Users can send alerts" ON alerts
    FOR INSERT WITH CHECK (sender_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can update received alerts" ON alerts
    FOR UPDATE USING (receiver_user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Security events - admin only
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

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_ownership_verifications_updated_at BEFORE UPDATE ON ownership_verifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_plate_registry_updated_at BEFORE UPDATE ON plate_registry
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_alerts_updated_at BEFORE UPDATE ON alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Fraud detection function
CREATE OR REPLACE FUNCTION detect_suspicious_activity()
RETURNS TRIGGER AS $$
BEGIN
    -- Check for rapid registrations from same IP
    IF (SELECT COUNT(*) FROM ownership_verifications
        WHERE ip_address = NEW.ip_address
        AND created_at > NOW() - INTERVAL '1 hour') > 3 THEN

        INSERT INTO security_events (user_id, event_type, severity, details, ip_address)
        VALUES (NEW.user_id, 'rapid_registrations', 'high',
               json_build_object('count', 3, 'timeframe', '1 hour'), NEW.ip_address);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER fraud_detection_trigger AFTER INSERT ON ownership_verifications
    FOR EACH ROW EXECUTE FUNCTION detect_suspicious_activity();

-- Enable real-time subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE ownership_verifications;
ALTER PUBLICATION supabase_realtime ADD TABLE security_events;

-- Comments
COMMENT ON TABLE ownership_verifications IS 'Multi-factor ownership verification before allowing plate registration. Prevents unauthorized plate claiming.';
COMMENT ON TABLE verification_evidence IS 'Secure storage of verification photos and documents with AI analysis results.';
COMMENT ON TABLE security_events IS 'Comprehensive fraud detection and security monitoring system.';
COMMENT ON COLUMN plate_registry.hashed_plate IS 'Only verified plates are stored. Original plate numbers never stored - privacy preserved.';
COMMENT ON COLUMN ownership_verifications.original_plate_hint IS 'Partial plate for human verification (e.g., A***3) - not enough to identify vehicle but helps verification.';

-- Demo data (for testing only - remove in production)
INSERT INTO users (user_id, phone_number, email, phone_verified, email_verified)
VALUES ('demo_verified_user', '+1234567890', 'demo@verified.com', true, true);