import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/biometrics/biometric_authenticator.dart';
import '../../../core/providers.dart';
import '../../../core/storage/session_lock_store.dart';

/// State of the biometric quick-unlock gate.
class SessionLockState {
  const SessionLockState({
    this.supported = false,
    this.enabled = false,
    this.locked = false,
  });

  /// The device can show biometric prompts (hardware + enrolled credential).
  final bool supported;

  /// The user opted in to biometric unlock.
  final bool enabled;

  /// The running session is waiting on a biometric confirmation.
  final bool locked;

  bool get canEnable => supported;

  SessionLockState copyWith({
    bool? supported,
    bool? enabled,
    bool? locked,
  }) {
    return SessionLockState(
      supported: supported ?? this.supported,
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
    );
  }
}

/// Coordinates the biometric quick-unlock: evaluated once at startup, then
/// toggled from the profile screen and satisfied by the lock screen.
class SessionLockController extends Notifier<SessionLockState> {
  BiometricAuthenticator get _authenticator =>
      ref.read(biometricAuthenticatorProvider);
  SessionLockStore get _store => ref.read(sessionLockStoreProvider);

  @override
  SessionLockState build() => const SessionLockState();

  /// Runs during app bootstrap, before the router settles. A lock applies
  /// only when a stored token exists, the user enabled the feature, and the
  /// device still has usable biometrics.
  Future<void> evaluate() async {
    final token = await ref.read(tokenStoreProvider).read();
    if (token == null) {
      state = const SessionLockState();
      return;
    }
    final supported = await _authenticator.isAvailable();
    final enabled = await _store.enabled();
    state = SessionLockState(
      supported: supported,
      enabled: enabled,
      locked: supported && enabled,
    );
  }

  /// Shows the biometric prompt. `true` when the session opened.
  Future<bool> unlock() async {
    final ok = await _authenticator.authenticate(
      reason: 'Unlock Beels with your fingerprint or face',
    );
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  /// Password fallback: the stored session is discarded (logout happens in
  /// [AuthController]); the preference stays on for future boots.
  void dismiss() {
    state = state.copyWith(locked: false);
  }

  /// Profile-screen toggle. Enabling requires a fresh biometric confirmation;
  /// returns `false` when that prompt fails or was cancelled.
  Future<bool> setEnabled(bool value) async {
    if (value && !state.supported) return false;
    if (value) {
      final ok = await _authenticator.authenticate(
        reason: 'Confirm to enable biometric login',
      );
      if (!ok) return false;
    }
    await _store.setEnabled(value);
    state = state.copyWith(enabled: value, locked: false);
    return true;
  }
}

final sessionLockControllerProvider =
    NotifierProvider<SessionLockController, SessionLockState>(
  SessionLockController.new,
);