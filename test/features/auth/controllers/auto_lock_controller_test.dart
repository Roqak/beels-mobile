import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/core/storage/preferences_store.dart';
import 'package:beels_mobile/features/auth/controllers/auto_lock_controller.dart';

class _Prefs implements PreferencesStore {
  _Prefs({this.saved});

  int? saved;
  int writes = 0;

  @override
  Future<int?> autoLockSeconds() async => saved;

  @override
  Future<String?> beelDraft() async => null;

  @override
  Future<void> setBeelDraft(String? json) async {}

  @override
  Future<void> setAutoLockSeconds(int value) async {
    saved = value;
    writes++;
  }

  @override
  Future<int> biometricOfferDeclines() async => 0;

  @override
  Future<void> setBiometricOfferDeclines(int value) async {}

  @override
  Future<bool> hideBalances() async => false;

  @override
  Future<void> setHideBalances(bool value) async {}
}

ProviderContainer _container(_Prefs prefs) {
  final container = ProviderContainer(
    overrides: [preferencesStoreProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to one minute before anything is saved', () async {
    final container = _container(_Prefs());
    expect(container.read(autoLockDelayProvider), kDefaultAutoLock);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(autoLockDelayProvider), const Duration(minutes: 1));
  });

  test('loads a saved choice', () async {
    final container = _container(_Prefs(saved: 300));
    container.read(autoLockDelayProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(autoLockDelayProvider), const Duration(minutes: 5));
  });

  test('ignores a saved value that is not one of the choices', () async {
    final container = _container(_Prefs(saved: 7));
    container.read(autoLockDelayProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(autoLockDelayProvider), kDefaultAutoLock);
  });

  test('set updates state and persists', () async {
    final prefs = _Prefs();
    final container = _container(prefs);
    container.read(autoLockDelayProvider);

    container
        .read(autoLockDelayProvider.notifier)
        .set(const Duration(seconds: 30));

    expect(container.read(autoLockDelayProvider), const Duration(seconds: 30));
    expect(prefs.saved, 30);
    expect(prefs.writes, 1);
  });

  test('labels read naturally', () {
    expect(autoLockLabel(const Duration(seconds: 3)), 'Right away');
    expect(autoLockLabel(const Duration(seconds: 30)), '30 seconds');
    expect(autoLockLabel(const Duration(minutes: 1)), '1 minute');
    expect(autoLockLabel(const Duration(minutes: 5)), '5 minutes');
  });
}
