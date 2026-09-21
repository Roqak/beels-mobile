import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the biometric quick-unlock preference and the remembered email.
class SessionLockStore {
  SessionLockStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _enabledKey = 'beels_biometric_enabled';

  Future<bool> enabled() async =>
      await _storage.read(key: _enabledKey) == 'true';

  Future<void> setEnabled(bool value) =>
      _storage.write(key: _enabledKey, value: value ? 'true' : 'false');
}
