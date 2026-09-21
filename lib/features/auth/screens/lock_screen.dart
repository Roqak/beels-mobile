import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router.dart' show resumeLocationFrom;
import '../../../core/theme.dart';
import '../../../core/widgets/adire_pattern.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/session_lock_controller.dart';

/// Gate screen shown when a session is locked behind biometrics.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, this.from});

  /// Location to resume after unlocking (set by the router on auto-lock).
  final String? from;

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
      context.go(resumeLocationFrom(widget.from));
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
    final onDark = Colors.white.withOpacity(0.75);
    return Scaffold(
      backgroundColor: BeelsColors.dye,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Opacity(opacity: 0.4, child: AdirePattern(cell: 38)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: BeelsColors.turmeric,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(Icons.fingerprint_rounded,
                          size: 52, color: BeelsColors.dye),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Beels is locked',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your fingerprint or face to sign back in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: onDark),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BeelsColors.turmeric,
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                  FilledButton(
                    onPressed: _locked && !_prompting ? _prompt : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BeelsColors.dye,
                      disabledBackgroundColor: Colors.white24,
                    ),
                    child: _prompting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: BeelsColors.dye,
                            ),
                          )
                        : const Text('Unlock'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _usePassword,
                    style: TextButton.styleFrom(foregroundColor: onDark),
                    child: const Text('Use password instead'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
