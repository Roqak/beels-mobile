/// Compile-time configuration supplied via `--dart-define`.
class AppConfig {
  AppConfig._();

  /// API base URL, e.g. --dart-define=BEELS_BASE_URL=https://api.example.com
  static const baseUrl = String.fromEnvironment(
    'BEELS_BASE_URL',
    defaultValue: 'https://dev-production-80a4.up.railway.app',
  );

  /// Web frontend base URL used to build shareable links (payment pages).
  static const frontendBaseUrl = String.fromEnvironment(
    'BEELS_FRONTEND_URL',
    defaultValue: 'https://beels-frontend-production.up.railway.app',
  );
}
