class ApiConfig {
  /// 10.0.2.2 is the Android emulator's alias for the host machine's
  /// localhost. Point this at a real host/IP for a physical device or a
  /// deployed backend.
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  /// Base origin (no /api) — used to resolve storage/avatar URLs returned
  /// by the API as absolute paths.
  static const String origin = 'http://10.0.2.2:8000';

  /// The backend's APP_URL host differs from what the Android emulator can
  /// reach (127.0.0.1 inside the emulator is the emulator itself, not the
  /// host machine). Rewrite any absolute media URL the API returns so it
  /// resolves correctly on-device.
  static String resolveUrl(String url) {
    return url.replaceFirst('127.0.0.1:8000', '10.0.2.2:8000').replaceFirst('localhost:8000', '10.0.2.2:8000');
  }
}
