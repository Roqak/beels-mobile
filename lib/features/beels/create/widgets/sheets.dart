import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/contacts/contact_picker.dart';
import '../../../../core/money.dart';
import '../../../../core/money_input.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/contact_pick_button.dart';
import '../../../../core/widgets/filter_chip_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../payments/data/payments_repository.dart';
import '../../../payments/models/bank.dart';
import '../../../payments/widgets/bank_picker.dart';
import '../../controllers/beels_controllers.dart';
import '../../models/bill_provider.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';
import 'bill_pickers.dart';

const _sheetPadding = EdgeInsets.fromLTRB(20, 4, 20, 20);

String _plain(num n) =>
    n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(2);

/// Opens the add/edit sheet for one person. [prefill] seeds it from a picked
/// contact.
Future<void> showPersonSheet(
  BuildContext context, {
  DraftContributor? editing,
  PickedContact? prefill,
  bool showErrors = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PersonSheet(
      editing: editing,
      prefill: prefill,
      showErrors: showErrors,
    ),
  );
}

/// Opens the add/edit sheet for one payout account.
Future<void> showAccountSheet(
  BuildContext context, {
  DraftBeneficiary? editing,
  bool showErrors = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AccountSheet(editing: editing, showErrors: showErrors),
  );
}

// ------------------------------------------------------------------- person

class PersonSheet extends ConsumerStatefulWidget {
  const PersonSheet({
    super.key,
    this.editing,
    this.prefill,
    this.showErrors = false,
  });

  final DraftContributor? editing;
  final PickedContact? prefill;

  /// Show what is missing straight away (opened from a flagged row).
  final bool showErrors;

  @override
  ConsumerState<PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<PersonSheet> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _amount = TextEditingController();
  final _firstFocus = FocusNode();
  Map<String, String> _errors = const {};
  String? _justAdded;

  bool get _editing => widget.editing != null;

  /// Even mode: the app works out the amount, so it is not asked for.
  bool get _even => ref.read(beelDraftProvider).sharesEvenly;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _first.text = e.firstName;
      _last.text = e.lastName;
      _phone.text = e.phone;
      _email.text = e.email;
      _amount.text = e.amount;
      if (widget.showErrors) {
        _errors = validateContributor(e, amountRequired: !_even);
      }
    } else {
      widget.prefill?.fillInto(
        firstName: _first,
        lastName: _last,
        email: _email,
        phone: _phone,
      );
      _amount.text = _even ? '' : _remainingDefault();
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    _amount.dispose();
    _firstFocus.dispose();
    super.dispose();
  }

  /// What is still unassigned, formatted for the amount box (blank if none).
  String _remainingDefault() {
    final left = ref.read(beelDraftProvider).contributorRemaining;
    return left > 0
        ? const ThousandsFormatter()
            .formatEditUpdate(
                TextEditingValue.empty, TextEditingValue(text: _plain(left)))
            .text
        : '';
  }

  DraftContributor _value() => DraftContributor(
        id: widget.editing?.id ?? -1,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        amount: _even ? '' : _amount.text.trim(),
      );

  void _save({required bool another}) {
    final person = _value();
    final errors = validateContributor(person, amountRequired: !_even);
    if (errors.isNotEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _errors = errors);
      return;
    }
    ref.read(beelDraftProvider.notifier).upsertContributor(person);
    HapticFeedback.mediumImpact();
    if (!another) {
      Navigator.of(context).pop();
      return;
    }
    // Ready for the next person, amount pre-filled with what is left.
    setState(() {
      _justAdded = person.fullName;
      _errors = const {};
      _first.clear();
      _last.clear();
      _phone.clear();
      _email.clear();
      _amount.text = _even ? '' : _remainingDefault();
    });
    _firstFocus.requestFocus();
  }

  InputDecoration _deco(String label, String key) =>
      InputDecoration(labelText: label, errorText: _errors[key]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: _sheetPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit person' : 'Add person',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: BeelsColors.ink0,
                    ),
                  ),
                ),
                ContactPickButton(
                  onPicked: (c) => setState(() {
                    c.fillInto(
                      firstName: _first,
                      lastName: _last,
                      email: _email,
                      phone: _phone,
                    );
                    _errors = const {};
                  }),
                ),
              ],
            ),
            if (_justAdded != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: BeelsColors.ok),
                  const SizedBox(width: 6),
                  Text(
                    'Added $_justAdded',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BeelsColors.ok,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    focusNode: _firstFocus,
                    autofocus: !_editing && widget.prefill == null,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _deco('First name', 'first'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _deco('Last name', 'last'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _deco('Phone number', 'phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _deco('Email', 'email'),
            ),
            const SizedBox(height: 12),
            if (_even)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeelsColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.balance_rounded,
                        size: 18, color: BeelsColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The amount is worked out for you: everyone pays an equal share.',
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: BeelsColors.ink1),
                      ),
                    ),
                  ],
                ),
              )
            else
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: const [ThousandsFormatter()],
                onSubmitted: (_) => _save(another: false),
                decoration: InputDecoration(
                  labelText: 'Amount this person pays',
                  errorText: _errors['amount'],
                  prefixText: '₦ ',
                ),
              ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _editing ? 'Save' : 'Add person',
              onPressed: () => _save(another: false),
            ),
            if (!_editing)
              TextButton(
                onPressed: () => _save(another: true),
                child: const Text('Save and add another'),
              )
            else
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: BeelsColors.err),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(beelDraftProvider.notifier)
                      .removeContributor(widget.editing!.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove person'),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ account

class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key, this.editing, this.showErrors = false});

  final DraftBeneficiary? editing;
  final bool showErrors;

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

enum _Verify { idle, checking, verified, failed }

class _AccountSheetState extends ConsumerState<AccountSheet> {
  late DraftBeneficiary _b = widget.editing ?? const DraftBeneficiary(id: -1);
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _serviceNumber = TextEditingController();
  final _amount = TextEditingController();
  Map<String, String> _errors = const {};
  _Verify _verify = _Verify.idle;
  String? _verifiedName;
  String? _autoName;
  int _token = 0;

  /// True for an account that already has details (not the blank starter).
  bool get _editing {
    final e = widget.editing;
    if (e == null) return false;
    return e.name.isNotEmpty ||
        e.accountNumber.isNotEmpty ||
        e.bankCode.isNotEmpty ||
        e.serviceNumber.isNotEmpty;
  }

  /// Itemised beels: every account is an item with a label and its own
  /// amount, and together they set the target.
  bool get _itemised => ref.read(beelDraftProvider).isItemised;

  /// Whether the amount must be typed (it is implicit for a lone account).
  bool get _needsAmount => _itemised || _others > 0;

  /// Other accounts already in the draft (so the amount is a real choice).
  int get _others => ref
      .read(beelDraftProvider)
      .beneficiaries
      .where((x) => x.id != _b.id)
      .length;

  @override
  void initState() {
    super.initState();
    _name.text = _b.name;
    _account.text = _b.accountNumber;
    _serviceNumber.text = _b.serviceNumber;
    _amount.text = _b.amount.isNotEmpty ? _b.amount : _defaultAmount();
    if (widget.showErrors && widget.editing != null) {
      _errors = validateBeneficiary(_b, amountRequired: _needsAmount);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _account.dispose();
    _serviceNumber.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// A sensible starting amount when this account joins others.
  String _defaultAmount() {
    if (_editing || _itemised) return '';
    final d = ref.read(beelDraftProvider);
    final target = d.target;
    if (target == null || target <= 0 || d.beneficiaries.isEmpty) return '';
    final rows = d.beneficiaries.where((b) => !b.hasPlanPrice).toList();
    final implicit = rows.where((b) => b.amount.trim().isEmpty).length;
    num? suggest;
    if (implicit > 0) {
      suggest = splitEvenly(target, rows.length + 1).last;
    } else {
      final taken =
          rows.fold<num>(0, (s, b) => s + (parseMoney(b.amount) ?? 0));
      if (target - taken > 0) suggest = target - taken;
    }
    if (suggest == null) return '';
    return const ThousandsFormatter()
        .formatEditUpdate(
            TextEditingValue.empty, TextEditingValue(text: _plain(suggest)))
        .text;
  }

  Future<void> _maybeVerify() async {
    final digits = _b.accountNumber.trim();
    if (!_b.isBank || _b.bankCode.isEmpty || digits.length < 10) {
      if (_verify != _Verify.idle) setState(() => _verify = _Verify.idle);
      return;
    }
    final token = ++_token;
    setState(() => _verify = _Verify.checking);
    try {
      final name = await ref
          .read(paymentsRepositoryProvider)
          .nameEnquiry(accountNumber: digits, bankCode: _b.bankCode);
      if (!mounted || token != _token) return;
      if (name.isEmpty) {
        setState(() => _verify = _Verify.failed);
        return;
      }
      setState(() {
        _verify = _Verify.verified;
        _verifiedName = name;
        final current = _name.text.trim();
        // An item's name is its label ("Cleaner"); the verified name only
        // shows in the check row.
        if (!_itemised && (current.isEmpty || current == _autoName)) {
          _autoName = name;
          _name.text = name;
          _b = _b.copyWith(name: name);
        }
      });
      HapticFeedback.selectionClick();
    } on ApiException {
      if (mounted && token == _token) setState(() => _verify = _Verify.failed);
    } on Object {
      if (mounted && token == _token) setState(() => _verify = _Verify.failed);
    }
  }

  void _save() {
    final value = _b.copyWith(
      name: _name.text.trim(),
      accountNumber: _account.text.trim(),
      serviceNumber: _serviceNumber.text.trim(),
      // A plan's price was set when the plan was picked.
      amount: _b.hasPlanPrice ? _b.amount : _amount.text.trim(),
    );
    final needsAmount = _needsAmount;
    final errors = validateBeneficiary(value, amountRequired: needsAmount);
    if (errors.isNotEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _errors = errors);
      return;
    }
    // Keep a single account's amount implicit so it always equals the target.
    final stored = (needsAmount || value.hasPlanPrice)
        ? value
        : value.copyWith(amount: '');
    ref.read(beelDraftProvider.notifier).upsertBeneficiary(stored);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final itemised = _itemised;
    final showAmount = !_b.hasPlanPrice && _needsAmount;
    final plans = _b.hasPlanPrice && _b.providerId.isNotEmpty
        ? ref
                .watch(billProvidersProvider(_b.type))
                .valueOrNull
                ?.where((p) => p.id == _b.providerId)
                .firstOrNull
                ?.plans ??
            const <BillPlan>[]
        : const <BillPlan>[];
    final nameField = TextField(
      controller: _name,
      textCapitalization:
          itemised ? TextCapitalization.sentences : TextCapitalization.words,
      textInputAction:
          itemised || showAmount ? TextInputAction.next : TextInputAction.done,
      onSubmitted: itemised || showAmount ? null : (_) => _save(),
      decoration: InputDecoration(
        labelText: itemised
            ? 'What is it for?'
            : (_b.isBank ? 'Account name' : 'Name'),
        hintText: itemised ? 'e.g. Cleaner, Light for pumping' : null,
        errorText: _errors['name'],
      ),
    );
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: _sheetPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              itemised
                  ? (_editing ? 'Edit item' : 'Add item')
                  : (_editing ? 'Edit account' : 'Add account'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: BeelsColors.ink0,
              ),
            ),
            if (itemised) ...[
              const SizedBox(height: 14),
              nameField,
            ],
            const SizedBox(height: 10),
            FilterChipBar<String>(
              padding: EdgeInsets.zero,
              value: _b.type,
              options: [
                for (final e in kBeneficiaryTypes.entries)
                  FilterOption(e.key, e.value),
              ],
              onChanged: (type) => setState(() {
                // Providers and plans belong to one type; a plan's price
                // goes with its plan.
                _b = _b.copyWith(
                  type: type,
                  providerId: '',
                  providerName: '',
                  planName: '',
                  serviceIdentifier: '',
                  amount: _b.hasPlanPrice ? '' : null,
                );
                _verify = _Verify.idle;
                _errors = const {};
              }),
            ),
            const SizedBox(height: 12),
            if (_b.isBank) ...[
              BankPickerField(
                selected: _b.bankCode.isEmpty
                    ? null
                    : Bank(name: _b.bankName, cbnCode: _b.bankCode),
                errorText: _errors['bank'],
                hint: 'Choose a bank',
                onChanged: (bank) {
                  setState(() => _b =
                      _b.copyWith(bankCode: bank.cbnCode, bankName: bank.name));
                  _maybeVerify();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _account,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (v) {
                  _b = _b.copyWith(accountNumber: v);
                  _maybeVerify();
                },
                decoration: InputDecoration(
                  labelText: 'Account number',
                  errorText: _errors['account'],
                ),
              ),
              _verifyRow(),
            ] else ...[
              TextField(
                controller: _serviceNumber,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _b.type == 'electricity'
                      ? 'Meter number'
                      : 'Phone or account number',
                  errorText: _errors['service_number'],
                ),
              ),
              const SizedBox(height: 12),
              BillProviderField(
                type: _b.type,
                selectedName: _b.providerName,
                errorText: _b.hasPlanPrice
                    ? _errors['provider']
                    : _errors['service_identifier'],
                onChanged: (provider) => setState(() {
                  _errors = const {};
                  _b = _b.copyWith(
                    providerId: provider.id,
                    providerName: provider.name,
                    // Airtime and electricity are paid against the
                    // provider; data and cable against a plan, chosen next.
                    serviceIdentifier: _b.hasPlanPrice ? '' : provider.id,
                    planName: '',
                    amount: _b.hasPlanPrice ? '' : null,
                  );
                }),
              ),
              if (_b.hasPlanPrice && _b.providerId.isNotEmpty) ...[
                const SizedBox(height: 12),
                BillPlanField(
                  plans: plans,
                  selectedName: _b.planName,
                  errorText: _errors['service_identifier'],
                  onChanged: (plan) => setState(() {
                    _errors = const {};
                    _b = _b.copyWith(
                      serviceIdentifier: plan.id,
                      planName: plan.name,
                      amount: _plain(plan.amount),
                    );
                    if (_name.text.trim().isEmpty) _name.text = plan.name;
                  }),
                ),
                if (_b.planName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Costs ${formatNaira(parseMoney(_b.amount) ?? 0)}. The plan sets the amount.',
                    style: TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
                  ),
                ],
              ],
            ],
            if (!itemised) ...[
              const SizedBox(height: 12),
              nameField,
            ],
            if (showAmount) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: const [ThousandsFormatter()],
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: itemised
                      ? 'How much it costs'
                      : 'Amount for this account',
                  errorText: _errors['amount'],
                  prefixText: '₦ ',
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label:
                  _editing ? 'Save' : (itemised ? 'Add item' : 'Add account'),
              onPressed: _save,
            ),
            if (_editing &&
                ref.read(beelDraftProvider).beneficiaries.length > 1)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: BeelsColors.err),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(beelDraftProvider.notifier)
                      .removeBeneficiary(widget.editing!.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(itemised ? 'Remove item' : 'Remove account'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _verifyRow() {
    switch (_verify) {
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
                    'Verified: $_verifiedName',
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
            _itemised
                ? 'We could not verify this account. Check the number and bank.'
                : 'We could not verify this account. Check the number, or type the name yourself.',
            style: TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
          ),
        );
    }
  }
}
