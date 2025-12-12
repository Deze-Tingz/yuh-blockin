-- Migration: Add push notification trigger for alerts
-- This trigger calls the Edge Function when a new alert is created

-- Enable the pg_net extension for HTTP requests (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION notify_alert_push()
RETURNS TRIGGER AS $$
BEGIN
  -- Call the Edge Function asynchronously via pg_net
  PERFORM net.http_post(
    url := 'https://oazxwglbvzgpehsckmfb.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.service_role_key', true)
    ),
    body := jsonb_build_object(
      'alert_id', NEW.id::text,
      'receiver_id', NEW.receiver_id,
      'message', COALESCE(NEW.message, 'Someone needs you to move your car!'),
      'sound_path', NEW.sound_path,
      'urgency_level', COALESCE(NEW.urgency_level, 'normal')
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_new_alert_send_push ON alerts;

-- Create the trigger
CREATE TRIGGER on_new_alert_send_push
AFTER INSERT ON alerts
FOR EACH ROW
EXECUTE FUNCTION notify_alert_push();
