import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/primary_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/session_lock_controller.dart';
import 'package:beels_mobile/core/theme.dart';

/// Gate screen shown when a session is locked behind biometrics.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;
  String? _error;

  bool get _locked => ref.watch(sessionLockControllerProvider).locked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_prompting || !_locked) return;
    setState(() {
      _prompting = true;
      _error = null;
    });
    await ref.read(sessionLockControllerProvider.notifier).unlock();
    if (!mounted) return;
    setState(() => _prompting = false);
    if (_locked) {
      setState(() => _error = 'We could not verify you. Try again.');
    } else {
      context.go('/');
    }
  }

  Future<void> _usePassword() async {
    final email = ref.read(authControllerProvider).valueOrNull?.email ?? '';
    ref.read(sessionLockControllerProvider.notifier).dismiss();
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login', extra: email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: BeelsColors.accentSoft,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.fingerprint_rounded,
                      size: 44, color: BeelsColors.accent),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Beels is locked',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: BeelsColors.ink0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use your fingerprint or face to sign back in.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BeelsColors.ink1,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BeelsColors.err,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Unlock',
                loading: _prompting,
                onPressed: _locked && !_prompting ? _prompt : null,
              ),
              TextButton(
                onPressed: _usePassword,
                child: const Text('Use password instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
