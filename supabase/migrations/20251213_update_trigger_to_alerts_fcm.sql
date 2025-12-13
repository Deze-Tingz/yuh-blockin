-- Migration: Update push notification trigger to use alerts-fcm function
-- This uses the Firebase Admin SDK which has better authentication handling

-- Update the trigger function to call alerts-fcm instead of send-push-notification
CREATE OR REPLACE FUNCTION notify_alert_push()
RETURNS TRIGGER AS $$
BEGIN
  -- Call the alerts-fcm Edge Function asynchronously via pg_net
  PERFORM net.http_post(
    url := 'https://oazxwglbvzgpehsckmfb.supabase.co/functions/v1/alerts-fcm',
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
