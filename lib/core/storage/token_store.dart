import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT bearer token in device secure storage.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'beels_auth_token';

  /// Reads the token, tolerating a broken Keystore / unreadable secure
  /// storage (OS update, backup restore): a missing token means re-login,
  /// a thrown one means the app is bricked before any UI exists.
  Future<String?> read() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on Object {
      return null;
    }
  }

  Future<void> write(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } on Object {
      // Corrupt or unreadable storage: nothing left to clear.
    }
  }
}
