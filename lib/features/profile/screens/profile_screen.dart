import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/session_lock_controller.dart';
import '../../auth/models/profile.dart';
import '../../auth/validation.dart';
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
  late final TextEditingController _firstName =
      TextEditingController(text: widget.profile.firstName);
  late final TextEditingController _lastName =
      TextEditingController(text: widget.profile.lastName ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.profile.phoneNumber ?? '');
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _editFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _changing = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    error ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfile() async {
    if (!(_editFormKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phoneNumber: _phone.text.trim(),
          );
      _showSnack('Profile updated');
    } on ApiException catch (error) {
      _showSnack(error.message, error: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _changing = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            oldPassword: _oldPassword.text,
            newPassword: _newPassword.text,
          );
      _oldPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _showSnack('Password changed');
    } on ApiException catch (error) {
      _showSnack(error.message, error: true);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
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
            style: TextButton.styleFrom(
              foregroundColor: BeelsColors.err,
            ),
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
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BeelsColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  widget.profile.initials,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: BeelsColors.accent,
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: BeelsColors.ink0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BeelsColors.ink1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(label: status, kind: statusKind(status)),
            ),
          ],
          const SizedBox(height: 28),
          const SectionHeader('Edit profile'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _editFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BeelsTextField(
                      controller: _firstName,
                      label: 'First name',
                      validator: (value) =>
                          validateRequired(value, 'first name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    BeelsTextField(
                      controller: _lastName,
                      label: 'Last name',
                      validator: (value) =>
                          validateRequired(value, 'last name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    PhoneField(
                      controller: _phone,
                      validator: validatePhone,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save changes',
                      loading: _saving,
                      onPressed: _saving ? null : _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Change password'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordField(
                      controller: _oldPassword,
                      label: 'Current password',
                      validator: validatePassword,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _newPassword,
                      label: 'New password',
                      validator: validatePassword,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _confirmPassword,
                      label: 'Confirm new password',
                      validator: (value) =>
                          validateConfirmPassword(value, _newPassword.text),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _changePassword(),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Change password',
                      loading: _changing,
                      onPressed: _changing ? null : _changePassword,
                    ),
                  ],
                ),
              ),
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
            onTap: () => context.push('/mandates'),
            child: const ListTile(
              leading: Icon(Icons.account_balance_outlined,
                  color: BeelsColors.accent),
              title: Text('Mandates'),
              subtitle: Text('Manage automatic collections.'),
              trailing: Icon(Icons.chevron_right, color: BeelsColors.ink3),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: BeelsColors.err,
              side: const BorderSide(color: BeelsColors.err),
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

class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await ref
          .read(sessionLockControllerProvider.notifier)
          .setEnabled(value);
      if (!mounted) return;
      if (!ok) {
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SwitchListTile(
          title: const Text('Biometric login'),
          subtitle: Text(
            lock.supported
                ? 'Unlock Beels with your fingerprint or face.'
                : 'Not available on this device.',
            style: theme.textTheme.bodySmall?.copyWith(color: BeelsColors.ink2),
          ),
          value: lock.enabled,
          onChanged: lock.canEnable && !_saving ? _toggle : null,
        ),
      ),
    );
  }
}
