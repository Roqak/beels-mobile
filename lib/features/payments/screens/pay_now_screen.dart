import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../data/payments_repository.dart';
import '../models/payment_options.dart';

/// Native pay-now flow for a contributor payment link:
/// bank transfer details, or an instant debit against a linked
/// (mandate) account. Mirrors the web pay page.
class PayNowScreen extends ConsumerStatefulWidget {
  const PayNowScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PayNowScreen> createState() => _PayNowScreenState();
}

enum _PaymentMethod { transfer, debit }

class _PayNowScreenState extends ConsumerState<PayNowScreen> {
  _LoadState _state = _LoadState.loading;
  PaymentOptions? _options;
  ApiException? _error;
  _PaymentMethod _method = _PaymentMethod.transfer;
  int? _selectedAccountId;
  bool _submitting = false;
  String? _payError;
  DebitRequest? _receipt;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _state = _LoadState.loading;
      _error = null;
    });

    try {
      final options = await ref
          .read(paymentsRepositoryProvider)
          .getPaymentOptions(widget.paymentId);
      if (!mounted) return;
      setState(() {
        _options = options;
        _state = _LoadState.ready;
        if (options.directDebitAvailable && options.debitAccounts.isNotEmpty) {
          _method = _PaymentMethod.debit;
          _selectedAccountId = options.debitAccounts.first.id;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _state = _LoadState.failed;
      });
    }
  }

  Future<void> _payNow() async {
    final accountId = _selectedAccountId;
    if (accountId == null || _submitting) return;

    setState(() {
      _submitting = true;
      _payError = null;
    });
    try {
      final receipt = await ref
          .read(paymentsRepositoryProvider)
          .payByDirectDebit(widget.paymentId, accountId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _submitting = false;
      });
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _payError = e.message;
        _submitting = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: BeelsAppBar(_options?.beelName == null || _state == _LoadState.loading
          ? 'Pay'
          : _options!.beelName),
      body: SafeArea(
        child: switch (_state) {
          _LoadState.loading => _buildSkeleton(),
          _LoadState.failed => _buildLoadError(),
          _LoadState.ready when _receipt != null => _buildReceipt(),
          _LoadState.ready => _buildForm(),
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        SkeletonScope(child: _SkeletonContent()),
      ],
    );
  }

  Widget _buildLoadError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        ErrorView(
          error: _error ?? const ApiException('Payment reference not found.', statusCode: 404),
          onRetry: _loadOptions,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final options = _options!;

    if (options.settlesEverything) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const EmptyState(
            icon: Icons.verified_outlined,
            title: 'You are all settled',
            message: 'Nothing outstanding on this beel. Thank you!',
          ),
        ],
      );
    }

    final canDebit = options.directDebitAvailable && options.debitAccounts.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pay your contribution',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: BeelsColors.ink0,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Hi ${options.contributorFirstName}, you owe '
          '${options.outstandingLabel} on this beel.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BeelsColors.ink1,
              ),
        ),
        const SizedBox(height: 20),
        if (canDebit) ...[
          Row(
            children: [
              Expanded(
                child: _MethodTab(
                  label: 'Bank transfer',
                  selected: _method == _PaymentMethod.transfer,
                  onTap: () => setState(() => _method = _PaymentMethod.transfer),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodTab(
                  label: 'Direct debit',
                  selected: _method == _PaymentMethod.debit,
                  onTap: () => setState(() => _method = _PaymentMethod.debit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (!canDebit || _method == _PaymentMethod.transfer)
          _TransferPanel(options: options)
        else
          _DebitPanel(
            key: ValueKey(_selectedAccountId),
            options: options,
            selectedAccountId: _selectedAccountId,
            onSelect: (id) => setState(() => _selectedAccountId = id),
            submitting: _submitting,
            error: _payError,
            onPay: _payNow,
          ),
      ],
    );
  }

  Widget _buildReceipt() {
    final receipt = _receipt!;
    final reference = receipt.reference;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: BeelsColors.okSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: BeelsColors.ok, size: 34),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Payment received',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: BeelsColors.ink0,
                ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'The account was debited and this beel is updated.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BeelsColors.ink1,
                ),
          ),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (reference.isNotEmpty)
                _FactRow(label: 'Reference', value: reference),
              _FactRow(
                label: 'Amount',
                value: formatNaira(receipt.amount > 0 ? receipt.amount : 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

enum _LoadState { loading, ready, failed }

class _SkeletonContent extends StatelessWidget {
  const _SkeletonContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skel(context, width: 180, height: 22),
        const SizedBox(height: 10),
        _skel(context, width: 260, height: 16),
        const SizedBox(height: 24),
        _skel(context, fullWidth: true, height: 120),
      ],
    );
  }

  Widget _skel(BuildContext context, {double? width, bool fullWidth = false, required double height}) {
    return Container(
      width: fullWidth ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        color: BeelsColors.panel,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? BeelsColors.accentSoft : BeelsColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? BeelsColors.accent : BeelsColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? BeelsColors.accent : BeelsColors.ink1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

class _TransferPanel extends StatelessWidget {
  const _TransferPanel({required this.options});

  final PaymentOptions options;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FactRow(label: 'Bank', value: options.transferBankName),
          _FactRow(label: 'Account number', value: options.transferAccountNumber),
          _FactRow(label: 'Reference', value: options.transferReference),
          const SizedBox(height: 8),
          Text(
            'Transfer the exact amount to the account above. We match it to '
            'this beel automatically.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BeelsColors.ink2,
                ),
          ),
        ],
      ),
    );
  }
}

class _DebitPanel extends StatelessWidget {
  const _DebitPanel({
    super.key,
    required this.options,
    required this.selectedAccountId,
    required this.onSelect,
    required this.submitting,
    required this.error,
    required this.onPay,
  });

  final PaymentOptions options;
  final int? selectedAccountId;
  final ValueChanged<int> onSelect;
  final bool submitting;
  final String? error;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Debit which account?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: BeelsColors.ink0,
              ),
        ),
        const SizedBox(height: 10),
        ...options.debitAccounts.map((account) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DebitAccountTile(
                account: account,
                selected: selectedAccountId == account.id,
                onTap: account.id == null ? null : () => onSelect(account.id!),
              ),
            )),
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BeelsColors.err,
                ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        PrimaryButton(
          label: 'Debit ${options.outstandingLabel}',
          loading: submitting,
          onPressed: selectedAccountId == null ? null : onPay,
        ),
        const SizedBox(height: 10),
        Text(
          'We debit the account once. This beel updates the moment the debit clears.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BeelsColors.ink2,
              ),
        ),
      ],
    );
  }
}

class DebitAccountTile extends StatelessWidget {
  const DebitAccountTile({
    super.key,
    required this.account,
    required this.selected,
    this.onTap,
  });

  final DebitAccount account;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? BeelsColors.accentSoft : BeelsColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? BeelsColors.accent : BeelsColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 20,
                color: selected ? BeelsColors.accent : BeelsColors.ink2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.bankName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: BeelsColors.ink0,
                      ),
                    ),
                    Text(
                      account.accountNumberMasked,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BeelsColors.ink2,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 20, color: BeelsColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BeelsColors.ink2,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BeelsColors.ink0,
                    letterSpacing: label == 'Reference' || label == 'Account number'
                        ? 0.5
                        : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}