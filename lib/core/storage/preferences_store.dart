import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small on-device preferences that are not part of the session lock itself.
/// Every call is failure-tolerant: a storage problem must never break UI.
class PreferencesStore {
  PreferencesStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _hideBalancesKey = 'beels_hide_balances';
  static const _declinesKey = 'beels_biometric_offer_declines';
  static const _autoLockKey = 'beels_auto_lock_seconds';

  Future<bool> hideBalances() async {
    try {
      return await _storage.read(key: _hideBalancesKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setHideBalances(bool value) async {
    try {
      await _storage.write(
          key: _hideBalancesKey, value: value ? 'true' : 'false');
    } catch (_) {}
  }

  /// How many times the user tapped "Not now" on the biometric offer.
  Future<int> biometricOfferDeclines() async {
    try {
      return int.tryParse(await _storage.read(key: _declinesKey) ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setBiometricOfferDeclines(int value) async {
    try {
      await _storage.write(key: _declinesKey, value: '$value');
    } catch (_) {}
  }

  /// Saved auto-lock delay in seconds, or `null` when never chosen.
  Future<int?> autoLockSeconds() async {
    try {
      return int.tryParse(await _storage.read(key: _autoLockKey) ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> setAutoLockSeconds(int value) async {
    try {
      await _storage.write(key: _autoLockKey, value: '$value');
    } catch (_) {}
  }
}
