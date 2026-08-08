-- Migration: Add urgency_level support to alerts
-- Run this SQL in your Supabase SQL Editor
-- Date: 2024-12-12

-- =====================================================
-- STEP 1: Add urgency_level column to alerts table (if not exists)
-- =====================================================

-- Check if column exists and add it if not
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'alerts' AND column_name = 'urgency_level'
    ) THEN
        ALTER TABLE alerts ADD COLUMN urgency_level TEXT DEFAULT 'normal';
    END IF;
END $$;

-- Add check constraint for valid urgency levels
ALTER TABLE alerts DROP CONSTRAINT IF EXISTS alerts_urgency_level_check;
ALTER TABLE alerts ADD CONSTRAINT alerts_urgency_level_check
    CHECK (urgency_level IN ('low', 'normal', 'high'));

-- Update any existing NULL values to 'normal'
UPDATE alerts SET urgency_level = 'normal' WHERE urgency_level IS NULL;

-- =====================================================
-- STEP 2: Drop old function overloads and create new one
-- =====================================================

-- Drop old overloads (3-arg and 4-arg versions)
DROP FUNCTION IF EXISTS public.send_alert(text, text, text);
DROP FUNCTION IF EXISTS public.send_alert(text, text, text, text);

-- Create the new 5-argument function
CREATE OR REPLACE FUNCTION public.send_alert(
    sender_user_id TEXT,
    target_plate_hash TEXT,
    alert_message TEXT DEFAULT NULL,
    alert_sound_path TEXT DEFAULT NULL,
    alert_urgency_level TEXT DEFAULT 'normal'
)
RETURNS JSON AS $$
DECLARE
    receiver_id TEXT;
    new_alert_id UUID;
    recipients_count INTEGER := 0;
BEGIN
    -- Find the owner of the plate
    SELECT user_id INTO receiver_id
    FROM plates
    WHERE plate_hash = target_plate_hash
    LIMIT 1;

    -- If no plate found, return error
    IF receiver_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Plate not registered',
            'recipients', 0
        );
    END IF;

    -- Don't allow sending alert to yourself
    IF receiver_id = sender_user_id THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Cannot alert your own vehicle',
            'recipients', 0
        );
    END IF;

    -- Validate urgency level
    IF alert_urgency_level NOT IN ('low', 'normal', 'high') THEN
        alert_urgency_level := 'normal';
    END IF;

    -- Insert the alert
    INSERT INTO alerts (
        sender_id,
        receiver_id,
        plate_hash,
        message,
        sound_path,
        urgency_level,
        created_at
    ) VALUES (
        sender_user_id,
        receiver_id,
        target_plate_hash,
        alert_message,
        alert_sound_path,
        alert_urgency_level,
        NOW()
    )
    RETURNING id INTO new_alert_id;

    recipients_count := 1;

    RETURN json_build_object(
        'success', true,
        'alert_id', new_alert_id,
        'recipients', recipients_count
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM,
        'recipients', 0
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission with explicit signature
GRANT EXECUTE ON FUNCTION public.send_alert(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_alert(text, text, text, text, text) TO anon;

-- =====================================================
-- STEP 3: Create index for urgency_level queries
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_alerts_urgency_level ON alerts(urgency_level);

-- =====================================================
-- VERIFICATION: Test the changes
-- =====================================================
-- Run these queries to verify:
--
-- 1. Check column exists:
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'alerts' AND column_name = 'urgency_level';
--
-- 2. Check only one function overload exists:
-- SELECT proname, pronargs, proargtypes
-- FROM pg_proc
-- WHERE proname = 'send_alert';
--
-- 3. Test the function (replace with real values):
-- SELECT send_alert('user123', 'plate_hash_here', 'Test message', null, 'high');
