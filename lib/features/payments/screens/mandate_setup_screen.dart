import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/widgets/fields.dart';
import '../controllers/mandate_setup_controller.dart';
import '../controllers/mandates_controller.dart';
import '../models/bank.dart';

/// Three-step direct-debit setup: bank + account verification, personal
/// details with BVN, then review and submit.
class MandateSetupScreen extends ConsumerStatefulWidget {
  const MandateSetupScreen({super.key});

  @override
  ConsumerState<MandateSetupScreen> createState() =>
      _MandateSetupScreenState();
}

class _MandateSetupScreenState extends ConsumerState<MandateSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bvnController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authControllerProvider).value;
    _firstNameController.text = profile?.firstName ?? '';
    _lastNameController.text = profile?.lastName ?? '';
    _emailController.text = profile?.email ?? '';
    _phoneController.text = profile?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _accountController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bvnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mandateSetupControllerProvider);

    return Scaffold(
      appBar: const BeelsAppBar('Set up direct debit'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StepIndicator(step: state.step),
            const SizedBox(height: 16),
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (state.step == MandateSetupStep.details) ...[
              const SectionHeader('Bank account'),
              _BankPicker(
                selected: state.selectedBank,
                onChanged: (bank) => ref
                    .read(mandateSetupControllerProvider.notifier)
                    .selectBank(bank),
              ),
              const SizedBox(height: 12),
              BeelsTextField(
                controller: _accountController,
                label: 'Account number',
                keyboardType: TextInputType.number,
                validator: (value) => (value ?? '').trim().length >= 10
                    ? null
                    : 'Enter a 10-digit account number',
              ),
              const SizedBox(height: 12),
              if (state.accountName != null)
                Text('Verified: ${state.accountName}'),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Verify account',
                loading: state.verifying,
                onPressed: () => ref
                    .read(mandateSetupControllerProvider.notifier)
                    .verifyAccount(accountNumber: _accountController.text),
              ),
            ] else ...[
              const SectionHeader('Your details'),
              BeelsTextField(
                controller: _firstNameController,
                label: 'First name',
                validator: (value) => (value ?? '').trim().isNotEmpty
                    ? null
                    : 'First name is required',
              ),
              const SizedBox(height: 12),
              BeelsTextField(
                controller: _lastNameController,
                label: 'Last name',
                validator: (value) => (value ?? '').trim().isNotEmpty
                    ? null
                    : 'Last name is required',
              ),
              const SizedBox(height: 12),
              BeelsTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value ?? '').trim().contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              BeelsTextField(
                controller: _phoneController,
                label: 'Phone number',
                keyboardType: TextInputType.phone,
                validator: (value) => (value ?? '').trim().length >= 10
                    ? null
                    : 'Enter a valid phone number',
              ),
              const SizedBox(height: 12),
              BeelsTextField(
                controller: _bvnController,
                label: 'Bank Verification Number (BVN)',
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) =>
                    RegExp(r'^\d{11}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'BVN must be 11 digits',
              ),
              const SizedBox(height: 12),
              Text(
                '${state.selectedBank?.name ?? ''} •••• ${_last4(state.accountNumber)}'
                '${state.accountName != null ? ' — ${state.accountName}' : ''}',
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Set up mandate',
                loading: state.submitting,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => ref
                    .read(mandateSetupControllerProvider.notifier)
                    .backToAccount(),
                child: const Text('Change account'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _last4(String value) =>
      value.length > 4 ? value.substring(value.length - 4) : value;

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    try {
      await ref.read(mandateSetupControllerProvider.notifier).submit(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            email: _emailController.text,
            phoneNumber: _phoneController.text,
            bvn: _bvnController.text,
          );
      if (!mounted) return;
      ref.invalidate(mandatesControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Direct debit mandate set up.')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not set up the mandate. Try again.'),
        ),
      );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final MandateSetupStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['Bank account', 'Your details'];
    final currentIndex = step == MandateSetupStep.details ? 0 : 1;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: i <= currentIndex
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${i + 1}. ${labels[i]}',
              style: TextStyle(
                color: i <= currentIndex
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _BankPicker extends ConsumerWidget {
  const _BankPicker({required this.selected, required this.onChanged});

  final Bank? selected;
  final ValueChanged<Bank> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(banksProvider);
    return banks.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        error: error as ApiException,
        onRetry: () => ref.invalidate(banksProvider),
      ),
      data: (rows) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pick(context, rows),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Bank',
            suffixIcon: Icon(Icons.expand_more),
          ),
          child: Text(selected?.name ?? 'Choose your bank'),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, List<Bank> banks) async {
    final picked = await showModalBottomSheet<Bank>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final bank in banks)
              ListTile(
                title: Text(bank.name),
                onTap: () => Navigator.of(sheetContext).pop(bank),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }
}