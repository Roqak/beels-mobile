import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// How long Beels may sit in the background before biometrics are required.
/// "Right away" keeps a few seconds of grace so the system biometric dialog
/// (which briefly backgrounds the app) never re-locks a session it just
/// unlocked.
const kAutoLockChoices = <Duration>[
  Duration(seconds: 3),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
];

const kDefaultAutoLock = Duration(minutes: 1);

String autoLockLabel(Duration delay) {
  if (delay.inSeconds <= 3) return 'Right away';
  if (delay.inSeconds < 60) return '${delay.inSeconds} seconds';
  final minutes = delay.inMinutes;
  return minutes == 1 ? '1 minute' : '$minutes minutes';
}

/// The user's chosen auto-lock delay, remembered on the device.
class AutoLockDelayController extends Notifier<Duration> {
  @override
  Duration build() {
    _load();
    return kDefaultAutoLock;
  }

  Future<void> _load() async {
    final seconds = await ref.read(preferencesStoreProvider).autoLockSeconds();
    final saved = seconds == null ? null : Duration(seconds: seconds);
    if (saved != null && kAutoLockChoices.contains(saved) && saved != state) {
      state = saved;
    }
  }

  void set(Duration delay) {
    state = delay;
    ref.read(preferencesStoreProvider).setAutoLockSeconds(delay.inSeconds);
  }
}

final autoLockDelayProvider =
    NotifierProvider<AutoLockDelayController, Duration>(
  AutoLockDelayController.new,
);
