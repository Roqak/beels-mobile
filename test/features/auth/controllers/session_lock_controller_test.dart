import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/biometrics/biometric_authenticator.dart';
import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/core/storage/session_lock_store.dart';
import 'package:beels_mobile/core/storage/token_store.dart';
import 'package:beels_mobile/features/auth/controllers/session_lock_controller.dart';

class _FakeTokenStore implements TokenStore {
  String? token = 'stored-token';

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

class _FakeSessionLockStore implements SessionLockStore {
  bool enabledValue = false;
  int writes = 0;

  @override
  Future<bool> enabled() async => enabledValue;

  @override
  Future<void> setEnabled(bool value) async {
    enabledValue = value;
    writes++;
  }
}

class _FakeAuthenticator implements BiometricAuthenticator {
  bool available = true;
  bool promptResult = true;
  int prompts = 0;
  String? lastReason;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    lastReason = reason;
    return promptResult;
  }
}

SessionLockController _controller(ProviderContainer container) =>
    container.read(sessionLockControllerProvider.notifier);

void main() {
  late _FakeTokenStore tokens;
  late _FakeSessionLockStore store;
  late _FakeAuthenticator authenticator;

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        sessionLockStoreProvider.overrideWithValue(store),
        biometricAuthenticatorProvider.overrideWithValue(authenticator),
      ]);

  setUp(() {
    tokens = _FakeTokenStore();
    store = _FakeSessionLockStore();
    authenticator = _FakeAuthenticator();
  });

  test('no stored token leaves the session open and the toggle off',
      () async {
    tokens.token = null;
    store.enabledValue = true;
    final container = makeContainer();
    addTearDown(container.dispose);

    await _controller(container).evaluate();

    final state = container.read(sessionLockControllerProvider);
    expect(state.locked, isFalse);
    // Without a session there is nothing to unlock, so the preference is
    // treated as off even if a stale 'true' lingers in storage.
    expect(state.enabled, isFalse);
  });

  test('token plus opt-in plus device support locks the session', () async {
    store.enabledValue = true;
    final container = makeContainer();
    addTearDown(container.dispose);

    await _controller(container).evaluate();

    final state = container.read(sessionLockControllerProvider);
    expect(state.locked, isTrue);
    expect(state.enabled, isTrue);
    expect(state.supported, isTrue);
  });

  test('opt-in on a device without usable biometrics never locks',
      () async {
    store.enabledValue = true;
    authenticator.available = false;
    final container = makeContainer();
    addTearDown(container.dispose);

    await _controller(container).evaluate();

    final state = container.read(sessionLockControllerProvider);
    expect(state.locked, isFalse);
  });

  test('unlock success opens the session; failure keeps it locked',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await _controller(container).evaluate();
    expect(container.read(sessionLockControllerProvider).locked, isFalse);

    // Re-evaluate as a locked session (evaluate() ran with default prefs).
    store.enabledValue = true;
    await _controller(container).evaluate();
    expect(container.read(sessionLockControllerProvider).locked, isTrue);

    authenticator.promptResult = false;
    expect(await _controller(container).unlock(), isFalse);
    expect(container.read(sessionLockControllerProvider).locked, isTrue);

    authenticator.promptResult = true;
    expect(await _controller(container).unlock(), isTrue);
    expect(container.read(sessionLockControllerProvider).locked, isFalse);
  });

  test('dismiss opens the session without touching the preference',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    store.enabledValue = true;
    await _controller(container).evaluate();
    expect(container.read(sessionLockControllerProvider).locked, isTrue);

    _controller(container).dismiss();

    final state = container.read(sessionLockControllerProvider);
    expect(state.locked, isFalse);
    expect(state.enabled, isTrue);
    expect(store.writes, 0);
  });

  test('setEnabled requires a passing biometric prompt', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await _controller(container).evaluate();

    authenticator.promptResult = false;
    expect(await _controller(container).setEnabled(true), isFalse);
    expect(container.read(sessionLockControllerProvider).enabled, isFalse);
    expect(store.writes, 0);

    authenticator.promptResult = true;
    expect(await _controller(container).setEnabled(true), isTrue);
    expect(container.read(sessionLockControllerProvider).enabled, isTrue);
    expect(store.writes, 1);

    // Disabling never prompts.
    final promptsBefore = authenticator.prompts;
    expect(await _controller(container).setEnabled(false), isTrue);
    expect(authenticator.prompts, promptsBefore);
    expect(container.read(sessionLockControllerProvider).enabled, isFalse);
  });

  test('setEnabled on an unsupported device is a no-op', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await _controller(container).evaluate();
    authenticator.available = false;
    await _controller(container).evaluate();

    expect(await _controller(container).setEnabled(true), isFalse);
    expect(store.writes, 0);
  });
}