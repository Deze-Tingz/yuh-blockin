-- SIMPLE SECURE ALERT SYSTEM
-- Only 3 tables, minimal data, maximum security

-- Clean slate
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS plates CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Simple users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Simple plates table (hashed for privacy)
CREATE TABLE plates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plate_hash TEXT NOT NULL, -- SHA256 hash of license plate
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Simple alerts table
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plate_hash TEXT NOT NULL,
    message TEXT,
    response TEXT, -- receiver response: moving_now, 5_minutes, cant_move, wrong_car
    response_message TEXT, -- optional custom response message
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE,
    response_at TIMESTAMP WITH TIME ZONE
);

-- Basic indexes for performance
CREATE INDEX idx_plates_user_id ON plates(user_id);
CREATE INDEX idx_plates_hash ON plates(plate_hash);
CREATE INDEX idx_alerts_receiver ON alerts(receiver_id);
CREATE INDEX idx_alerts_created ON alerts(created_at);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE plates ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

-- Simple RLS policies (allow anonymous access)
CREATE POLICY "Allow all" ON users FOR ALL USING (true);
CREATE POLICY "Allow all" ON plates FOR ALL USING (true);
CREATE POLICY "Allow all" ON alerts FOR ALL USING (true);

-- Simple function to send alerts
CREATE OR REPLACE FUNCTION send_alert(
    sender_user_id TEXT,
    target_plate_hash TEXT,
    alert_message TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    target_users TEXT[];
    alert_id UUID;
    result JSON;
BEGIN
    -- Find all users who registered this plate
    SELECT ARRAY_AGG(DISTINCT user_id) INTO target_users
    FROM plates
    WHERE plate_hash = target_plate_hash;

    -- Return error if plate not registered
    IF target_users IS NULL OR array_length(target_users, 1) = 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'License plate not registered'
        );
    END IF;

    -- Send alert to each registered user
    FOR i IN 1..array_length(target_users, 1) LOOP
        INSERT INTO alerts (sender_id, receiver_id, plate_hash, message)
        VALUES (sender_user_id, target_users[i], target_plate_hash, alert_message)
        RETURNING id INTO alert_id;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'recipients', array_length(target_users, 1),
        'alert_id', alert_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable real-time for alerts
ALTER PUBLICATION supabase_realtime ADD TABLE alerts;

-- Comments
COMMENT ON TABLE plates IS 'Stores hashed license plates for privacy';
COMMENT ON TABLE alerts IS 'Real-time alerts between users';
COMMENT ON FUNCTION send_alert IS 'Sends alert to all users registered for a license plate';