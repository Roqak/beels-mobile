import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';
import '../validation.dart';
import '../widgets/error_banner.dart';
import '../widgets/fields.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.prefilledEmail});

  /// Email remembered from a biometric session, offered as a default.
  final String? prefilledEmail;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.prefilledEmail ?? '');
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      context.go('/');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BeelsColors.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'b',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome back',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: BeelsColors.ink0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to manage your savings.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: BeelsColors.ink1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    EmailField(
                      controller: _email,
                      validator: validateEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _password,
                      validator: validatePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      label: 'Log in',
                      loading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New to Beels?'),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
