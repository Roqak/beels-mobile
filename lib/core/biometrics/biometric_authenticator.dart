import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contract for device biometric authentication, faked in tests.
abstract class BiometricAuthenticator {
  /// `true` when the device has biometric hardware, is set up with at least
  /// one enrolled credential, and can show the system prompt.
  Future<bool> isAvailable();

  /// Shows the system biometric prompt. Resolves `true` on success.
  Future<bool> authenticate({required String reason});
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({LocalAuthentication? localAuthentication})
      : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) return false;
      final biometrics = await _localAuthentication.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      // Missing platform wiring (e.g. desktop/test hosts) means unavailable.
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometricAuthenticator(),
);