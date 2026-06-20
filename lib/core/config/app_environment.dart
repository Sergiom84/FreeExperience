abstract final class AppEnvironment {
  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get supabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.startsWith('sb_');

  static bool get sentryConfigured => sentryDsn.startsWith('https://');
  static bool get isProduction => name == 'production';
}
