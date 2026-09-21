import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/money_input.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/filter_chip_bar.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../payments/data/payments_repository.dart';
import '../../../payments/models/bank.dart';
import '../../../payments/widgets/bank_picker.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';
import 'create_widgets.dart';
import 'text_sync.dart';

/// Step 4: where the money goes.
class PayoutStep extends ConsumerWidget {
  const PayoutStep({super.key, required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    final many = draft.beneficiaries.length > 1;
    final total = draft.payoutTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (many && total != null) ...[
          KeyedSubtree(
            key: scroller.keyFor('payout'),
            child: AllocationBar(
              assigned: total,
              total: draft.target ?? 0,
              noun: 'paid out',
            ),
          ),
          if (errors['payout'] != null) ...[
            const SizedBox(height: 8),
            Row(
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
          ],
          const SizedBox(height: 14),
        ] else if (errors['payout'] != null) ...[
          KeyedSubtree(
            key: scroller.keyFor('payout'),
            child: Text(
              errors['payout']!,
              style: TextStyle(fontSize: 13, color: BeelsColors.err),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < draft.beneficiaries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BeneficiaryCard(
              key: ValueKey(draft.beneficiaries[i].id),
              index: i,
              beneficiary: draft.beneficiaries[i],
              showAmount: many,
              canRemove: many,
              errors: errors,
              scroller: scroller,
            ),
          ),
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.addBeneficiary();
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Split between another account'),
        ),
      ],
    );
  }
}

enum _Verify { idle, checking, verified, failed }

class _BeneficiaryCard extends ConsumerStatefulWidget {
  const _BeneficiaryCard({
    super.key,
    required this.index,
    required this.beneficiary,
    required this.showAmount,
    required this.canRemove,
    required this.errors,
    required this.scroller,
  });

  final int index;
  final DraftBeneficiary beneficiary;
  final bool showAmount;
  final bool canRemove;
  final Map<String, String> errors;
  final ErrorScroller scroller;

  @override
  ConsumerState<_BeneficiaryCard> createState() => _BeneficiaryCardState();
}

class _BeneficiaryCardState extends ConsumerState<_BeneficiaryCard> {
  late final _name = TextEditingController(text: widget.beneficiary.name);
  late final _account =
      TextEditingController(text: widget.beneficiary.accountNumber);
  late final _serviceNumber =
      TextEditingController(text: widget.beneficiary.serviceNumber);
  late final _serviceId =
      TextEditingController(text: widget.beneficiary.serviceIdentifier);
  late final _amount = TextEditingController(text: widget.beneficiary.amount);

  _Verify _verify = _Verify.idle;
  String? _verifiedName;
  String? _autoFilledName;
  int _verifyToken = 0;

  @override
  void dispose() {
    _name.dispose();
    _account.dispose();
    _serviceNumber.dispose();
    _serviceId.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? _err(String suffix) =>
      widget.errors['beneficiary_${widget.index}_$suffix'];

  void _update(DraftBeneficiary Function(DraftBeneficiary) f) => ref
      .read(beelDraftProvider.notifier)
      .updateBeneficiary(widget.beneficiary.id, f);

  /// Looks the account up once a bank and 10 digits are present. Never blocks:
  /// if it cannot be resolved the person can still type the name themselves.
  Future<void> _maybeVerify() async {
    final b = widget.beneficiary;
    final digits = b.accountNumber.trim();
    if (!b.isBank || b.bankCode.isEmpty || digits.length < 10) {
      if (_verify != _Verify.idle) setState(() => _verify = _Verify.idle);
      return;
    }
    final token = ++_verifyToken;
    setState(() => _verify = _Verify.checking);
    try {
      final name = await ref
          .read(paymentsRepositoryProvider)
          .nameEnquiry(accountNumber: digits, bankCode: b.bankCode);
      if (!mounted || token != _verifyToken) return;
      if (name.isEmpty) {
        setState(() => _verify = _Verify.failed);
        return;
      }
      setState(() {
        _verify = _Verify.verified;
        _verifiedName = name;
      });
      // Fill the name unless the user has typed their own.
      final current = widget.beneficiary.name.trim();
      if (current.isEmpty || current == _autoFilledName) {
        _autoFilledName = name;
        _update((x) => x.copyWith(name: name));
      }
      HapticFeedback.selectionClick();
    } on ApiException {
      if (mounted && token == _verifyToken) {
        setState(() => _verify = _Verify.failed);
      }
    } on Object {
      if (mounted && token == _verifyToken) {
        setState(() => _verify = _Verify.failed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.beneficiary;
    syncController(_name, b.name);
    syncController(_account, b.accountNumber);
    syncController(_serviceNumber, b.serviceNumber);
    syncController(_serviceId, b.serviceIdentifier);
    syncController(_amount, b.amount);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.canRemove
                      ? 'Account ${widget.index + 1}'
                      : 'Pay out to',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BeelsColors.ink0,
                  ),
                ),
              ),
              if (widget.canRemove)
                IconButton(
                  tooltip: 'Remove account',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: BeelsColors.err),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(beelDraftProvider.notifier)
                        .removeBeneficiary(b.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          FilterChipBar<String>(
            padding: EdgeInsets.zero,
            value: b.type,
            options: [
              for (final e in kBeneficiaryTypes.entries)
                FilterOption(e.key, e.value),
            ],
            onChanged: (type) {
              _verify = _Verify.idle;
              _update((x) => x.copyWith(type: type));
            },
          ),
          const SizedBox(height: 12),
          if (b.isBank) ...[
            KeyedSubtree(
              key: widget.scroller.keyFor('beneficiary_${widget.index}_bank'),
              child: BankPickerField(
                selected: b.bankCode.isEmpty
                    ? null
                    : Bank(name: b.bankName, cbnCode: b.bankCode),
                errorText: _err('bank'),
                hint: 'Choose a bank',
                onChanged: (bank) {
                  _update((x) =>
                      x.copyWith(bankCode: bank.cbnCode, bankName: bank.name));
                  // The state above updates before this reads it next frame.
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _maybeVerify());
                },
              ),
            ),
            const SizedBox(height: 12),
            FormBlock(
              label: 'Account number',
              field: 'beneficiary_${widget.index}_account',
              scroller: widget.scroller,
              error: _err('account'),
              child: TextField(
                controller: _account,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (v) {
                  _update((x) => x.copyWith(accountNumber: v));
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _maybeVerify());
                },
              ),
            ),
            _VerifyRow(state: _verify, name: _verifiedName),
          ] else ...[
            FormBlock(
              label: b.type == 'electricity'
                  ? 'Meter number'
                  : 'Phone or account number',
              field: 'beneficiary_${widget.index}_service_number',
              scroller: widget.scroller,
              error: _err('service_number'),
              child: TextField(
                controller: _serviceNumber,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (v) => _update((x) => x.copyWith(serviceNumber: v)),
              ),
            ),
            const SizedBox(height: 12),
            FormBlock(
              label:
                  b.type == 'electricity' ? 'Electricity company' : 'Provider',
              field: 'beneficiary_${widget.index}_service_identifier',
              scroller: widget.scroller,
              error: _err('service_identifier'),
              helper: b.type == 'electricity'
                  ? 'For example EKEDC'
                  : 'For example MTN, GLO or DSTV',
              child: TextField(
                controller: _serviceId,
                textInputAction: TextInputAction.next,
                onChanged: (v) =>
                    _update((x) => x.copyWith(serviceIdentifier: v)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FormBlock(
            label: b.isBank ? 'Account name' : 'Name',
            field: 'beneficiary_${widget.index}_name',
            scroller: widget.scroller,
            error: _err('name'),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (v) => _update((x) => x.copyWith(name: v)),
            ),
          ),
          if (widget.showAmount && b.wantsAmount) ...[
            const SizedBox(height: 12),
            FormBlock(
              label: 'Amount for this account',
              field: 'beneficiary_${widget.index}_amount',
              scroller: widget.scroller,
              error: _err('amount'),
              child: TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [
                  ThousandsFormatter(),
                ],
                onChanged: (v) => _update((x) => x.copyWith(amount: v)),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Text('₦',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BeelsColors.ink1)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerifyRow extends StatelessWidget {
  const _VerifyRow({required this.state, required this.name});

  final _Verify state;
  final String? name;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _Verify.idle:
        return const SizedBox.shrink();
      case _Verify.checking:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Checking the account...',
                  style: TextStyle(fontSize: 13, color: BeelsColors.ink2)),
            ],
          ),
        );
      case _Verify.verified:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BeelsColors.okSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: BeelsColors.ok),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verified: $name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BeelsColors.ok,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case _Verify.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'We could not verify this account. Check the number, or type the name yourself.',
            style: TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
          ),
        );
    }
  }
}
