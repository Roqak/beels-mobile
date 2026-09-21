import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/biometrics/biometric_authenticator.dart';
import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/core/storage/preferences_store.dart';
import 'package:beels_mobile/core/storage/session_lock_store.dart';
import 'package:beels_mobile/features/auth/widgets/biometric_offer.dart';

class _LockStore implements SessionLockStore {
  bool value = false;

  @override
  Future<bool> enabled() async => value;

  @override
  Future<void> setEnabled(bool v) async => value = v;
}

class _Prefs implements PreferencesStore {
  _Prefs({this.declines = 0});

  int declines;
  bool hidden = false;

  @override
  Future<int> biometricOfferDeclines() async => declines;

  @override
  Future<void> setBiometricOfferDeclines(int value) async => declines = value;

  @override
  Future<bool> hideBalances() async => hidden;

  @override
  Future<void> setHideBalances(bool value) async => hidden = value;
}

class _Bio implements BiometricAuthenticator {
  _Bio({this.available = true, this.result = true});

  bool available;
  bool result;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return result;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _LockStore lock,
  required _Prefs prefs,
  required _Bio bio,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionLockStoreProvider.overrideWithValue(lock),
        preferencesStoreProvider.overrideWithValue(prefs),
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BiometricOfferTrigger()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetBiometricOfferForTests);

  testWidgets('offers biometrics when supported, off and not asked enough',
      (tester) async {
    await _pump(tester, lock: _LockStore(), prefs: _Prefs(), bio: _Bio());

    expect(find.text('Unlock Beels with your fingerprint or face'),
        findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Turn on enables biometrics after the system prompt',
      (tester) async {
    final lock = _LockStore();
    final bio = _Bio();
    final prefs = _Prefs();
    await _pump(tester, lock: lock, prefs: prefs, bio: bio);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(bio.prompts, 1);
    expect(lock.value, isTrue);
    expect(find.text('Turn on'), findsNothing);
    expect(prefs.declines, 0);
  });

  testWidgets('a failed prompt keeps the sheet open with a hint',
      (tester) async {
    final lock = _LockStore();
    final bio = _Bio(result: false);
    await _pump(tester, lock: lock, prefs: _Prefs(), bio: bio);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(lock.value, isFalse);
    expect(find.textContaining('could not verify you'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('Not now is remembered and counted', (tester) async {
    final prefs = _Prefs();
    await _pump(tester, lock: _LockStore(), prefs: prefs, bio: _Bio());

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on'), findsNothing);
    expect(prefs.declines, 1);
  });

  testWidgets('never asks after the limit, when already on, or unsupported',
      (tester) async {
    await _pump(
      tester,
      lock: _LockStore(),
      prefs: _Prefs(declines: kBiometricOfferLimit),
      bio: _Bio(),
    );
    expect(find.text('Turn on'), findsNothing);

    resetBiometricOfferForTests();
    await _pump(
      tester,
      lock: _LockStore()..value = true,
      prefs: _Prefs(),
      bio: _Bio(),
    );
    expect(find.text('Turn on'), findsNothing);

    resetBiometricOfferForTests();
    await _pump(
      tester,
      lock: _LockStore(),
      prefs: _Prefs(),
      bio: _Bio(available: false),
    );
    expect(find.text('Turn on'), findsNothing);
  });
}
