import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/widgets/error_banner.dart';
import '../../auth/widgets/fields.dart';
import '../controllers/mandate_setup_controller.dart';
import '../controllers/mandates_controller.dart';
import '../models/bank.dart';

/// Three-step direct-debit setup: bank + account verification, personal
/// details with BVN, then review and submit.
class MandateSetupScreen extends ConsumerStatefulWidget {
  const MandateSetupScreen({super.key});

  @override
  ConsumerState<MandateSetupScreen> createState() => _MandateSetupScreenState();
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
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Set up direct debit'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            _StepIndicator(step: state.step),
            const SizedBox(height: 16),
            if (state.error != null) ...[
              ErrorBanner(message: state.error!),
              const SizedBox(height: 12),
            ],
            if (state.step == MandateSetupStep.details) ...[
              const SectionHeader('Bank account'),
              const SizedBox(height: 10),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) => (value ?? '').trim().length >= 10
                    ? null
                    : 'Enter a 10-digit account number',
              ),
              const SizedBox(height: 12),
              if (state.accountName != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BeelsColors.okSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: BeelsColors.ok),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified: ${state.accountName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: BeelsColors.ok,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
              const SizedBox(height: 10),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                obscureText: true,
                validator: (value) =>
                    RegExp(r'^\d{11}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'BVN must be 11 digits',
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                color: BeelsColors.surfaceAlt,
                child: Row(
                  children: [
                    Icon(Icons.account_balance_outlined,
                        size: 20, color: BeelsColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${state.selectedBank?.name ?? ''} •••• ${_last4(state.accountNumber)}'
                        '${state.accountName != null ? ' — ${state.accountName}' : ''}',
                        style: TextStyle(color: BeelsColors.ink0),
                      ),
                    ),
                  ],
                ),
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
      HapticFeedback.mediumImpact();
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
    const labels = ['Bank account', 'Your details'];
    final currentIndex = step == MandateSetupStep.details ? 0 : 1;
    return Semantics(
      label: 'Step ${currentIndex + 1} of ${labels.length}: '
          '${labels[currentIndex]}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutQuart,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= currentIndex
                          ? BeelsColors.accent
                          : BeelsColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (i < labels.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${currentIndex + 1}. ${labels[currentIndex]}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BeelsColors.ink1,
            ),
          ),
        ],
      ),
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
      loading: () => const SkeletonScope(
        child: SkeletonBox(height: 52, radius: 10),
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
      isScrollControlled: true,
      builder: (sheetContext) => _BankSheet(banks: banks),
    );
    if (picked != null) onChanged(picked);
  }
}

class _BankSheet extends StatefulWidget {
  const _BankSheet({required this.banks});

  final List<Bank> banks;

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? widget.banks
        : widget.banks.where((b) => b.name.toLowerCase().contains(q)).toList();
    final height = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search banks',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'No bank matches that search.',
                        style: TextStyle(color: BeelsColors.ink2),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: rows.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(rows[i].name),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(rows[i]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
