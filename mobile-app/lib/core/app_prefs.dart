import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small persisted key-value store for lightweight local preferences
/// (theme mode, etc). Reuses secure storage so we don't need a second
/// persistence dependency just for a couple of string values.
class AppPrefs {
  static final _storage = const FlutterSecureStorage();

  static Future<String?> getString(String key) => _storage.read(key: key);

  static Future<void> setString(String key, String value) => _storage.write(key: key, value: value);
}
