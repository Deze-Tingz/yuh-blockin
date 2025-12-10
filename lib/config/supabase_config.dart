/// Supabase Configuration for Yuh Blockin'
///
/// IMPORTANT: For production, set these values via environment variables:
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co
///   flutter run --dart-define=SUPABASE_ANON_KEY=eyJxxx...
///
/// For development, you can use the default values below.
class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase Project URL
  ///
  /// Set via environment variable for production:
  /// --dart-define=SUPABASE_URL=https://your-project.supabase.co
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oazxwglbvzgpehsckmfb.supabase.co',
  );

  /// Supabase Anonymous Key
  ///
  /// This is the public anon key - safe to include in app but should
  /// still be provided via environment variable for production.
  ///
  /// Set via environment variable:
  /// --dart-define=SUPABASE_ANON_KEY=eyJxxx...
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henh3Z2xidnpncGVoc2NrbWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNzkzMjEsImV4cCI6MjA3ODc1NTMyMX0.Ia6ccZ1zp4r1mi5mgvQk9wfK5MGp0S3TDhyWngz8Z54',
  );

  /// Check if using environment-provided credentials (more secure)
  static bool get isConfiguredViaEnvironment {
    // Check if URL was overridden from default
    const defaultUrl = 'https://oazxwglbvzgpehsckmfb.supabase.co';
    return url != defaultUrl ||
           const bool.hasEnvironment('SUPABASE_URL') ||
           const bool.hasEnvironment('SUPABASE_ANON_KEY');
  }

  /// Validate configuration
  static bool get isValid {
    return url.isNotEmpty &&
           anonKey.isNotEmpty &&
           url.startsWith('https://') &&
           url.contains('supabase.co');
  }
}
