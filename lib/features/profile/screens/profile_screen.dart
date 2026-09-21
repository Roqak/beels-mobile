import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/profile.dart';
import '../../auth/validation.dart';
import '../../auth/widgets/fields.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: const BeelsAppBar('Profile'),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

  void _showSnack(String message) {
    if (!mounted) return;
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
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
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
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
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
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  widget.profile.initials,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.fullName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
          const SizedBox(height: 24),
          const SectionHeader('Edit profile'),
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
          const SizedBox(height: 24),
          const SectionHeader('Change password'),
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
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
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