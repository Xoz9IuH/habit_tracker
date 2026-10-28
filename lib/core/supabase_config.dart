class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static String restUrl(String base) => '$base/rest/v1';

  static String authUrl(String base) => '$base/auth/v1';

  static String get rest => restUrl(url);

  static String get auth => authUrl(url);
}
