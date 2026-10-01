class AppConfig {
  static const authRedirect = 'nossapatota://login-callback';
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get isConfigured =>
      Uri.tryParse(supabaseUrl)?.scheme == 'https' && supabaseKey.isNotEmpty;
}
