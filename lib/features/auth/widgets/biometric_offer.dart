import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../controllers/session_lock_controller.dart';

/// The offer is made at most this many times ("Not now" counts one).
const kBiometricOfferLimit = 2;

/// Once per app run, so switching tabs or rebuilding never re-asks.
bool _offeredThisRun = false;

/// Test hook: forget that the offer was already made in this run.
@visibleForTesting
void resetBiometricOfferForTests() => _offeredThisRun = false;

/// Drop this into the first signed-in screen. After the first frame it checks
/// whether the phone can do biometrics, whether the user already opted in,
/// and whether they have been asked enough times; if not, it shows the offer.
class BiometricOfferTrigger extends ConsumerStatefulWidget {
  const BiometricOfferTrigger({super.key});

  @override
  ConsumerState<BiometricOfferTrigger> createState() =>
      _BiometricOfferTriggerState();
}

class _BiometricOfferTriggerState extends ConsumerState<BiometricOfferTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOffer());
  }

  Future<void> _maybeOffer() async {
    if (_offeredThisRun) return;
    final lock = ref.read(sessionLockControllerProvider.notifier);
    await lock.refreshSupport();
    if (!mounted) return;
    final state = ref.read(sessionLockControllerProvider);
    if (!state.supported || state.enabled) return;
    final prefs = ref.read(preferencesStoreProvider);
    final declines = await prefs.biometricOfferDeclines();
    if (!mounted || declines >= kBiometricOfferLimit) return;
    _offeredThisRun = true;
    final turnedOn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const BiometricOfferSheet(),
    );
    if (turnedOn != true) {
      await prefs.setBiometricOfferDeclines(declines + 1);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Bottom sheet that turns biometric login on in one tap (plus the system
/// prompt that proves it works). Pops `true` when enabled.
class BiometricOfferSheet extends ConsumerStatefulWidget {
  const BiometricOfferSheet({super.key});

  @override
  ConsumerState<BiometricOfferSheet> createState() =>
      _BiometricOfferSheetState();
}

class _BiometricOfferSheetState extends ConsumerState<BiometricOfferSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok =
        await ref.read(sessionLockControllerProvider.notifier).setEnabled(true);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _error = 'We could not verify you. Try again, or use Not now.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: BeelsColors.turmeric,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.fingerprint_rounded,
                    size: 40, color: BeelsColors.dye),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unlock Beels with your fingerprint or face',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: BeelsColors.ink0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Skip typing your password. If your phone is ever lost, your '
              'savings stay behind your fingerprint or face.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: BeelsColors.ink1,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BeelsColors.err,
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Turn on',
              icon: Icons.fingerprint_rounded,
              loading: _busy,
              onPressed: _busy ? null : _enable,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
