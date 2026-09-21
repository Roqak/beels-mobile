import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/surface_card.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';
import 'create_widgets.dart';
import 'sheets.dart';

/// Step 4: where the money goes. Accounts are compact rows; adding or editing
/// one opens a focused sheet, so nothing needs scrolling to reach.
class PayoutStep extends ConsumerWidget {
  const PayoutStep({super.key, required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  static const _labels = {
    'name': 'name',
    'bank': 'bank',
    'account': 'account number',
    'service_number': 'number',
    'service_identifier': 'provider',
    'amount': 'amount',
  };

  static bool _isBlank(DraftBeneficiary b) =>
      b.name.isEmpty &&
      b.accountNumber.isEmpty &&
      b.bankCode.isEmpty &&
      b.serviceNumber.isEmpty &&
      b.serviceIdentifier.isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    final accounts = draft.beneficiaries;
    final onlyBlank = accounts.length == 1 && _isBlank(accounts.first);
    final many = accounts.length > 1;
    final amountRows = accounts.where((b) => b.wantsAmount).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onlyBlank)
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add the account that should receive the money.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: BeelsColors.ink1,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      showAccountSheet(context, editing: accounts.first),
                  icon: const Icon(Icons.account_balance_rounded, size: 20),
                  label: const Text('Add payout account'),
                ),
              ],
            ),
          )
        else ...[
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < accounts.length; i++) ...[
                  if (i > 0) Divider(indent: 64, color: BeelsColors.border),
                  _AccountRow(
                    account: accounts[i],
                    showAmount: many,
                    amount: draft.effectiveBeneficiaryAmount(accounts[i]),
                    errorFields: [
                      for (final k in errors.keys)
                        if (k.startsWith('beneficiary_${i}_'))
                          _labels[k.substring('beneficiary_${i}_'.length)] ??
                              '',
                    ],
                    rowKey: errors.keys
                        .where((k) => k.startsWith('beneficiary_${i}_'))
                        .map(scroller.keyFor)
                        .firstOrNull,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    showAccountSheet(context);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Split to another account'),
                ),
              ),
            ],
          ),
          if (many && amountRows >= 2 && (draft.target ?? 0) > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  notifier.splitBeneficiariesEvenly();
                },
                icon: const Icon(Icons.balance_rounded, size: 18),
                label: Text(
                    'Split ${formatNaira(draft.target!)} equally between $amountRows'),
              ),
            ),
        ],
        if (errors['payout'] != null) ...[
          const SizedBox(height: 10),
          KeyedSubtree(
            key: scroller.keyFor('payout'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 15, color: BeelsColors.err),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    errors['payout']!,
                    style: TextStyle(fontSize: 12.5, color: BeelsColors.err),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.showAmount,
    required this.amount,
    required this.errorFields,
    this.rowKey,
  });

  final DraftBeneficiary account;
  final bool showAmount;
  final num? amount;
  final List<String> errorFields;
  final GlobalKey? rowKey;

  @override
  Widget build(BuildContext context) {
    final hasErrors = errorFields.isNotEmpty;
    final subtitle = account.isBank
        ? '${account.bankName.isEmpty ? 'Bank' : account.bankName}'
            '${account.accountNumber.length >= 4 ? ' · •••• ${account.accountNumber.substring(account.accountNumber.length - 4)}' : ''}'
        : '${kBeneficiaryTypes[account.type]} · ${account.serviceIdentifier}';
    return KeyedSubtree(
      key: rowKey ?? ValueKey('account-${account.id}'),
      child: Pressable(
        onTap: () =>
            showAccountSheet(context, editing: account, showErrors: hasErrors),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      hasErrors ? BeelsColors.errSoft : BeelsColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasErrors
                      ? Icons.priority_high_rounded
                      : (account.isBank
                          ? Icons.account_balance_rounded
                          : Icons.bolt_rounded),
                  size: 20,
                  color: hasErrors ? BeelsColors.err : BeelsColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name.isEmpty ? 'New account' : account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BeelsColors.ink0,
                      ),
                    ),
                    Text(
                      hasErrors
                          ? 'Needs ${errorFields.where((f) => f.isNotEmpty).join(', ')}'
                          : subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: hasErrors ? BeelsColors.err : BeelsColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (showAmount && amount != null)
                Text(
                  formatNaira(amount!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BeelsColors.ink1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: BeelsColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
