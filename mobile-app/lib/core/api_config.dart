class ApiConfig {
  /// Overridable via env.json + `--dart-define-from-file=env.json`.
  /// Default (10.0.2.2) is the Android emulator's alias for the host
  /// machine's localhost. Point env.json at a real host/IP for a physical
  /// device or Chrome.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Base origin (no /api) — used to resolve storage/avatar URLs returned
  /// by the API as absolute paths.
  static const String origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// The backend's APP_URL host differs from what the running app can
  /// reach (127.0.0.1 inside the emulator is the emulator itself, not the
  /// host machine). Rewrite any absolute media URL the API returns so it
  /// resolves correctly against the configured origin.
  static String resolveUrl(String url) {
    final host = origin.replaceFirst(RegExp(r'^https?://'), '');
    return url.replaceFirst('127.0.0.1:8000', host).replaceFirst('localhost:8000', host);
  }
}
