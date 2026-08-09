import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around secure storage for the JWT bearer token.
/// Kept separate from AuthProvider so the Dio interceptor (which has no
/// widget-tree access) can read the token without depending on Riverpod.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  final _storage = const FlutterSecureStorage();
  static const _key = 'auth_token';

  String? _cached;

  Future<String?> read() async {
    _cached ??= await _storage.read(key: _key);
    return _cached;
  }

  String? get cached => _cached;

  Future<void> write(String token) async {
    _cached = token;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}
