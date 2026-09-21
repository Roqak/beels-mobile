import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../validation.dart';
import '../widgets/error_banner.dart';
import '../widgets/fields.dart';
import 'package:beels_mobile/core/theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.push('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const BeelsAppBar('Forgot password'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _sent ? _buildSent(theme) : _buildForm(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset your password',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: BeelsColors.ink0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the email on your account and we will send you a reset link.',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: BeelsColors.ink1),
          ),
          const SizedBox(height: 24),
          EmailField(
            controller: _email,
            validator: validateEmail,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          PrimaryButton(
            label: 'Send reset link',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _openLogin,
              child: const Text('Back to log in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: BeelsColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: BeelsColors.accent,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your inbox',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a password reset link to ${_email.text.trim()}. The link expires in 10 minutes.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: BeelsColors.ink1),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _openLogin,
          child: const Text('Back to log in'),
        ),
      ],
    );
  }
}
