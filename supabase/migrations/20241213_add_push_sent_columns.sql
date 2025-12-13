-- Add push_sent tracking columns to alerts table
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS push_sent BOOLEAN DEFAULT FALSE;
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS push_sent_at TIMESTAMP WITH TIME ZONE;
