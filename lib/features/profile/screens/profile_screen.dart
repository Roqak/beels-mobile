import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/session_lock_controller.dart';
import '../../auth/models/profile.dart';
import '../../auth/validation.dart';
import '../../auth/widgets/error_banner.dart';
import '../../auth/widgets/fields.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Profile'),
      body: auth.when(
        loading: () => const SkeletonScope(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(height: 64, circle: true),
                    SizedBox(width: 16),
                    SkeletonBox(width: 160, height: 18),
                  ],
                ),
                SizedBox(height: 32),
                SkeletonBox(height: 220, radius: 16),
              ],
            ),
          ),
        ),
        error: (error, _) {
          final apiError = error is ApiException
              ? error
              : const ApiException(
                  'Something went wrong. Please try again.',
                  statusCode: 0,
                );
          return ErrorView(
            error: apiError,
            onRetry: () => ref.invalidate(authControllerProvider),
          );
        },
        data: (profile) {
          if (profile == null) {
            return EmptyState(
              icon: Icons.person_outline,
              title: 'Not signed in',
              message: 'Log in to view and manage your profile.',
              actionLabel: 'Log in',
              onAction: () => context.go('/login'),
            );
          }
          return _ProfileContent(key: ValueKey(profile), profile: profile);
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  const _ProfileContent({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    error ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEdit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(profile: widget.profile),
    );
    if (saved == true) _showSnack('Profile updated');
  }

  Future<void> _openPassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true) _showSnack('Password changed');
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text(
          'You will need your email and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: BeelsColors.err),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.profile.status;
    final phone = widget.profile.phoneNumber;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
                const Positioned.fill(child: AdirePattern()),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: BeelsColors.turmeric,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              widget.profile.initials,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: BeelsColors.dye,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile.fullName,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 24,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.profile.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                                if (phone != null && phone.isNotEmpty)
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (status != null && status.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        StatusChip(label: status, kind: statusKind(status)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Account'),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit profile',
                  subtitle: 'Name and phone number',
                  onTap: _openEdit,
                ),
                const Divider(indent: 64),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  subtitle: 'Use a strong, unique password',
                  onTap: _openPassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Security'),
          const SizedBox(height: 10),
          const _BiometricTile(),
          const SizedBox(height: 28),
          const SectionHeader('Direct debit'),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: _SettingsRow(
              icon: Icons.account_balance_outlined,
              title: 'Mandates',
              subtitle: 'Manage automatic collections.',
              onTap: () => context.push('/mandates'),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: BeelsColors.err,
              side: BorderSide(color: BeelsColors.err),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BeelsColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: BeelsColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BeelsColors.ink0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: BeelsColors.ink2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: BeelsColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet scaffold: keyboard-aware, scrollable, titled.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: BeelsColors.ink0,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _firstName = TextEditingController(text: widget.profile.firstName);
  late final _lastName =
      TextEditingController(text: widget.profile.lastName ?? '');
  late final _phone =
      TextEditingController(text: widget.profile.phoneNumber ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phoneNumber: _phone.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Edit profile',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            BeelsTextField(
              controller: _firstName,
              label: 'First name',
              validator: (value) => validateRequired(value, 'first name'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            BeelsTextField(
              controller: _lastName,
              label: 'Last name',
              validator: (value) => validateRequired(value, 'last name'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            PhoneField(
              controller: _phone,
              validator: validatePhone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save changes',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _changing = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _changing = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            oldPassword: _old.text,
            newPassword: _new.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Change password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            PasswordField(
              controller: _old,
              label: 'Current password',
              validator: validatePassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _new,
              label: 'New password',
              validator: validatePassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              validator: (value) => validateConfirmPassword(value, _new.text),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _change(),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Change password',
              loading: _changing,
              onPressed: _changing ? null : _change,
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Support is only probed at boot when a session already existed, so a
    // fresh sign-in must re-check before showing "not available".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(sessionLockControllerProvider.notifier).refreshSupport();
      }
    });
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await ref
          .read(sessionLockControllerProvider.notifier)
          .setEnabled(value);
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Biometric verification failed. Try again.'),
          ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lock = ref.watch(sessionLockControllerProvider);
    final hint = !lock.supported
        ? 'To use this, add a fingerprint or face in your phone settings, then come back.'
        : (lock.enabled
            ? 'Beels also locks itself after you have been away for a while.'
            : 'Turn on to skip your password next time.');
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BeelsColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fingerprint_rounded,
                    size: 22, color: BeelsColors.accent),
              ),
              title: const Text('Biometric login'),
              subtitle: Text(
                lock.supported
                    ? 'Unlock Beels with your fingerprint or face.'
                    : 'Not available on this device.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BeelsColors.ink2),
              ),
              value: lock.enabled,
              onChanged: lock.canEnable && !_saving ? _toggle : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              hint,
              style:
                  TextStyle(fontSize: 12, height: 1.4, color: BeelsColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
