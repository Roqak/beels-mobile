import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../controllers/beels_controllers.dart';
import '../models/contribution.dart';

const _kModes = <String, String>{'closed': 'Closed', 'open': 'Open link'};
const _kRecurrences = <String, String>{
  'one_time': 'One-time',
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
};
const _kWeekdays = <String, String>{
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};
const _kBeneficiaryTypes = <String, String>{
  'bank_transfer': 'Bank transfer',
  'airtime': 'Airtime',
  'data': 'Data',
  'cable': 'Cable TV',
  'electricity': 'Electricity',
};

final RegExp _emailRegExp =
    RegExp(r'^\S+@\S+\.\S+$', caseSensitive: false);

num? _parseAmount(String text) =>
    num.tryParse(text.trim().replaceAll(',', ''));

/// Create a new beel: closed mode (contributors) or open-link mode.
class CreateBeelScreen extends ConsumerStatefulWidget {
  const CreateBeelScreen({super.key});

  @override
  ConsumerState<CreateBeelScreen> createState() => _CreateBeelScreenState();
}

class _CreateBeelScreenState extends ConsumerState<CreateBeelScreen> {
  String _mode = 'closed';
  bool _review = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _amountPerContributorController =
      TextEditingController();
  final TextEditingController _expectedContributorsController =
      TextEditingController();

  String _recurrenceType = 'one_time';
  String _dayOfWeek = 'monday';
  int _dayOfMonth = 1;

  final List<_ContributorRow> _contributors = [_ContributorRow()];
  final List<_BeneficiaryRow> _beneficiaries = [_BeneficiaryRow()];

  final Map<String, String> _errors = {};

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _amountPerContributorController.dispose();
    _expectedContributorsController.dispose();
    for (final row in _contributors) {
      row.dispose();
    }
    for (final row in _beneficiaries) {
      row.dispose();
    }
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors.remove(key) != null) {
      setState(() {});
    }
  }

  void _setMode(String mode) {
    setState(() {
      _mode = mode;
      _errors.clear();
    });
  }

  void _setRecurrence(String recurrence) {
    setState(() => _recurrenceType = recurrence);
  }

  void _addContributor() => setState(() => _contributors.add(_ContributorRow()));

  void _removeContributor(int index) {
    setState(() {
      _contributors.removeAt(index).dispose();
      if (_contributors.isEmpty) _contributors.add(_ContributorRow());
    });
  }

  void _addBeneficiary() =>
      setState(() => _beneficiaries.add(_BeneficiaryRow()));

  num? _parsePerContributor() =>
      _parseAmount(_amountPerContributorController.text);

  int? _expectedContributors() =>
      int.tryParse(_expectedContributorsController.text.trim());

  void _removeBeneficiary(int index) {
    setState(() {
      _beneficiaries.removeAt(index).dispose();
      if (_beneficiaries.isEmpty) _beneficiaries.add(_BeneficiaryRow());
    });
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(
      createBeelControllerProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFE),
      appBar: BeelsAppBar(_review ? 'Review' : 'New Beel'),
      body: _review
          ? _ReviewPane(
              screen: this,
              submitting: submitting,
            )
          : _buildForm(),
      bottomNavigationBar: _buildBottomBar(submitting),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeSelector(),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Beel name',
            error: _errors['name'],
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _clearError('name'),
              decoration: const InputDecoration(hintText: 'e.g. Family Savings'),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: _mode == 'closed'
                ? 'Target amount'
                : 'Target amount (total)',
            error: _errors['amount'],
            child: MoneyField(
              controller: _amountController,
              hint: '0',
              onChanged: (_) => _clearError('amount'),
            ),
          ),
          if (_mode == 'open') ...[
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Amount per contributor (optional)',
              error: _errors['amount_per_contributor'],
              child: MoneyField(
                controller: _amountPerContributorController,
                hint: 'Leave empty to split by number of people',
                onChanged: (_) => setState(() {
                  _errors.remove('amount_per_contributor');
                }),
              ),
            ),
            if (_amountPerContributorController.text.trim().isEmpty) ...[
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Expected contributors',
                error: _errors['expected_contributors'],
                child: TextField(
                  controller: _expectedContributorsController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _clearError('expected_contributors'),
                  decoration:
                      const InputDecoration(hintText: 'e.g. 4 people'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Recurrence',
            error: _errors['recurrence'],
            child: DropdownButtonFormField<String>(
              value: _recurrenceType,
              items: [
                for (final entry in _kRecurrences.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => _setRecurrence(value ?? 'one_time'),
              decoration: const InputDecoration(),
            ),
          ),
          if (_recurrenceType == 'weekly') ...[
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Day of week',
              error: _errors['day_of_week'],
              child: DropdownButtonFormField<String>(
                value: _dayOfWeek,
                items: [
                  for (final entry in _kWeekdays.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => _dayOfWeek = value ?? 'monday'),
                decoration: const InputDecoration(),
              ),
            ),
          ],
          if (_recurrenceType == 'monthly') ...[
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Day of month',
              error: _errors['day_of_month'],
              child: DropdownButtonFormField<int>(
                value: _dayOfMonth,
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('Day $day')),
                ],
                onChanged: (value) => setState(() => _dayOfMonth = value ?? 1),
                decoration: const InputDecoration(),
              ),
            ),
          ],
          if (_mode == 'closed') ...[
            const SizedBox(height: 20),
            SectionHeader(
              'Contributors',
              action: TextButton.icon(
                onPressed: _addContributor,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ),
            ..._buildContributorRows(),
          ],
          const SizedBox(height: 20),
          SectionHeader(
            'Beneficiaries',
            action: TextButton.icon(
              onPressed: _addBeneficiary,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ),
          ..._buildBeneficiaryRows(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<String>(
      segments: [
        for (final entry in _kModes.entries)
          ButtonSegment(value: entry.key, label: Text(entry.value)),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) => _setMode(selection.first),
    );
  }

  List<Widget> _buildContributorRows() {
    return [
      for (var i = 0; i < _contributors.length; i++)
        _ContributorEditorRow(
          key: ValueKey(_contributors[i]),
          row: _contributors[i],
          index: i,
          removable: _contributors.length > 1,
          errors: _errors,
          onClearError: _clearError,
          onRemove: () => _removeContributor(i),
        ),
    ];
  }

  List<Widget> _buildBeneficiaryRows() {
    return [
      for (var i = 0; i < _beneficiaries.length; i++)
        _BeneficiaryEditorRow(
          key: ValueKey(_beneficiaries[i]),
          row: _beneficiaries[i],
          index: i,
          removable: _beneficiaries.length > 1,
          errors: _errors,
          onClearError: _clearError,
          onRemove: () => _removeBeneficiary(i),
          onTypeChanged: () {
            setState(() {});
          },
        ),
    ];
  }

  Widget _buildBottomBar(bool submitting) {
    final children = _review
        ? <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: submitting
                    ? null
                    : () => setState(() => _review = false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Submit',
                loading: submitting,
                onPressed: submitting ? null : () => _onPrimaryPressed(),
              ),
            ),
          ]
        : <Widget>[
            Expanded(
              child: PrimaryButton(
                label: 'Review',
                loading: submitting,
                onPressed: submitting ? null : () => _onPrimaryPressed(),
              ),
            ),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(children: children),
    );
  }

  Future<void> _onPrimaryPressed() async {
    if (!_review) {
      final errors = _validateForm();
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      if (errors.isEmpty) {
        setState(() => _review = true);
      } else {
        _showSnack('Fix the highlighted fields', isError: true);
      }
      return;
    }

    final errors = _validateReview();
    setState(() => _errors
      ..clear()
      ..addAll(errors));
    if (errors['review'] != null) {
      _showSnack(errors['review']!, isError: true);
      return;
    }
    await _submit();
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB23A3A) : const Color(0xFF1F7A4D),
      ),
    );
  }

  Map<String, String> _validateForm() {
    final errors = <String, String>{};

    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'Enter a name for the beel';
    }

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      errors['amount'] = 'Enter a target amount';
    }

    if (_mode == 'open') {
      final perContributor = _parseAmount(_amountPerContributorController.text);
      if (perContributor != null) {
        if (perContributor <= 0) {
          errors['amount_per_contributor'] = 'Enter an amount above zero';
        }
      } else {
        final expected =
            int.tryParse(_expectedContributorsController.text.trim());
        if (expected == null || expected < 1) {
          errors['expected_contributors'] =
              'Enter how many people will split this beel';
        }
      }
      for (var i = 0; i < _beneficiaries.length; i++) {
        _validateBeneficiary(i, _beneficiaries[i], errors);
      }
      if (_beneficiaries.isEmpty) {
        errors['review'] = 'Add at least one beneficiary';
      }
      return errors;
    }

    if (_contributors.isEmpty) {
      errors['review'] = 'Add at least one contributor';
    }
    for (var i = 0; i < _contributors.length; i++) {
      final row = _contributors[i];
      final prefix = 'contributor_$i';
      if (row.firstName.text.trim().isEmpty) {
        errors['${prefix}_first'] = 'Required';
      }
      if (row.lastName.text.trim().isEmpty) {
        errors['${prefix}_last'] = 'Required';
      }
      if (!_emailRegExp.hasMatch(row.email.text.trim())) {
        errors['${prefix}_email'] = 'Enter a valid email';
      }
      final digits = row.phone.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 11) {
        errors['${prefix}_phone'] = 'At least 11 digits';
      }
      final rowAmount = _parseAmount(row.amount.text);
      if (rowAmount == null || rowAmount <= 0) {
        errors['${prefix}_amount'] = 'Enter an amount';
      }
    }
    for (var i = 0; i < _beneficiaries.length; i++) {
      _validateBeneficiary(i, _beneficiaries[i], errors);
    }
    if (_beneficiaries.isEmpty) {
      errors['review'] = 'Add at least one beneficiary';
    }
    return errors;
  }

  void _validateBeneficiary(
    int i,
    _BeneficiaryRow row,
    Map<String, String> errors,
  ) {
    final prefix = 'beneficiary_$i';
    if (row.name.text.trim().isEmpty) {
      errors['${prefix}_name'] = 'Required';
    }
    if (row.type == 'bank_transfer') {
      if (row.accountNumber.text.trim().isEmpty) {
        errors['${prefix}_account'] = 'Required';
      }
      if (row.bankCode.text.trim().isEmpty) {
        errors['${prefix}_bank_code'] = 'Required';
      }
    } else {
      if (row.serviceNumber.text.trim().isEmpty) {
        errors['${prefix}_service_number'] = 'Required';
      }
      if (row.serviceIdentifier.text.trim().isEmpty) {
        errors['${prefix}_service_identifier'] = 'Required';
      }
    }
    if (row.type == 'bank_transfer' || row.type == 'airtime') {
      final amount = _parseAmount(row.amount.text);
      if (amount == null || amount <= 0) {
        errors['${prefix}_amount'] = 'Enter an amount';
      }
    }
  }

  Map<String, String> _validateReview() {
    final errors = <String, String>{};
    final amount = _parseAmount(_amountController.text) ?? 0;

    if (_mode == 'closed') {
      final contributorSum = _contributors.fold<num>(
          0, (sum, row) => sum + (_parseAmount(row.amount.text) ?? 0));
      if (contributorSum != amount) {
        errors['review'] =
            'Contributor amounts (${formatNaira(contributorSum)}) must total ${formatNaira(amount)}';
      }
    }

    final rowsWithAmount =
        _beneficiaries.where((row) => _parseAmount(row.amount.text) != null);
    if (rowsWithAmount.length == _beneficiaries.length) {
      final beneficiarySum = _beneficiaries.fold<num>(
          0, (sum, row) => sum + (_parseAmount(row.amount.text) ?? 0));
      if (beneficiarySum != amount) {
        errors['review'] =
            'Beneficiary allocation (${formatNaira(beneficiarySum)}) must total ${formatNaira(amount)}';
      }
    } else {
      errors['review_warning'] =
          'Some beneficiaries have no amount, so the allocation cannot be verified here.';
    }
    return errors;
  }

  Future<void> _submit() async {
    final controller = ref.read(createBeelControllerProvider.notifier);
    final amount = _parseAmount(_amountController.text)!;
    final recurrence = _recurrenceType;
    final dayOfWeek = recurrence == 'weekly' ? _dayOfWeek : null;
    final dayOfMonth = recurrence == 'monthly' ? _dayOfMonth : null;
    final beneficiaries = [
      for (final row in _beneficiaries) row.toInput(),
    ];

    try {
      if (_mode == 'closed') {
        await controller.submitClosed(
          name: _nameController.text.trim(),
          amount: amount,
          recurrenceType: recurrence,
          dayOfWeek: dayOfWeek,
          dayOfMonth: dayOfMonth,
          contributors: [for (final row in _contributors) row.toInput()],
          beneficiaries: beneficiaries,
        );
        if (!mounted) return;
        _showSnack('Beel created', isError: false);
        context.pop();
      } else {
        final perContributor =
            _parseAmount(_amountPerContributorController.text);
        final created = await controller.submitOpen(
          name: _nameController.text.trim(),
          amount: amount,
          amountPerContributor: perContributor,
          expectedContributors: perContributor == null
              ? int.tryParse(_expectedContributorsController.text.trim())
              : null,
          recurrenceType: recurrence,
          dayOfWeek: dayOfWeek,
          dayOfMonth: dayOfMonth,
          beneficiaries: beneficiaries,
        );
        if (!mounted) return;
        if (created.paymentLink.isNotEmpty) {
          await _showPaymentLinkDialog(created);
          if (!mounted) return;
        }
        if (created.id != null) {
          context.pushReplacement('/beels/${created.id}');
        } else {
          context.pop();
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _review = false);
      _showSnack(error.message, isError: true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _review = false);
      _showSnack('$error', isError: true);
    }
  }

  Future<void> _showPaymentLinkDialog(Contribution created) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Beel created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this payment link so people can join:'),
            const SizedBox(height: 8),
            SelectableText(created.paymentLink),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Share.share(created.paymentLink, subject: 'Join my beel'),
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: '₦ ',
        prefixStyle: const TextStyle(
          color: Color(0xFF21222D),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.error,
  });

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF5B5D6B),
              ),
        ),
        const SizedBox(height: 6),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFB23A3A), fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _ContributorRow {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController amount = TextEditingController();

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    amount.dispose();
  }

  ContributorInput toInput() => ContributorInput(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        email: email.text.trim(),
        phoneNumber: phone.text.trim(),
        amount: _parseAmount(amount.text) ?? 0,
      );
}

class _ContributorEditorRow extends StatelessWidget {
  const _ContributorEditorRow({
    super.key,
    required this.row,
    required this.index,
    required this.removable,
    required this.errors,
    required this.onClearError,
    required this.onRemove,
  });

  final _ContributorRow row;
  final int index;
  final bool removable;
  final Map<String, String> errors;
  final void Function(String key) onClearError;
  final VoidCallback onRemove;

  String? _errorOf(String suffix) => errors['contributor_$index$suffix'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contributor ${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF21222D),
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Remove contributor',
                icon: const Icon(Icons.close, size: 20),
                color: const Color(0xFFB23A3A),
                onPressed: removable ? onRemove : null,
              ),
            ],
          ),
          TextField(
            controller: row.firstName,
            onChanged: (_) => onClearError('contributor_${index}_first'),
            decoration: InputDecoration(
              hintText: 'First name',
              errorText: _errorOf('_first'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.lastName,
            onChanged: (_) => onClearError('contributor_${index}_last'),
            decoration: InputDecoration(
              hintText: 'Last name',
              errorText: _errorOf('_last'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => onClearError('contributor_${index}_email'),
            decoration: InputDecoration(
              hintText: 'Email',
              errorText: _errorOf('_email'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => onClearError('contributor_${index}_phone'),
            decoration: InputDecoration(
              hintText: 'Phone number',
              errorText: _errorOf('_phone'),
            ),
          ),
          const SizedBox(height: 8),
          MoneyField(
            controller: row.amount,
            hint: 'Amount',
            onChanged: (_) => onClearError('contributor_${index}_amount'),
          ),
          if (_errorOf('_amount') != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                _errorOf('_amount')!,
                style: const TextStyle(
                    color: Color(0xFFB23A3A), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _BeneficiaryRow {
  _BeneficiaryRow();

  String type = 'bank_transfer';
  final TextEditingController name = TextEditingController();
  final TextEditingController accountNumber = TextEditingController();
  final TextEditingController bankCode = TextEditingController();
  final TextEditingController serviceNumber = TextEditingController();
  final TextEditingController serviceIdentifier = TextEditingController();
  final TextEditingController amount = TextEditingController();

  void dispose() {
    name.dispose();
    accountNumber.dispose();
    bankCode.dispose();
    serviceNumber.dispose();
    serviceIdentifier.dispose();
    amount.dispose();
  }

  bool get wantsAmount => type == 'bank_transfer' || type == 'airtime';

  BeneficiaryInput toInput() => BeneficiaryInput(
        name: name.text.trim(),
        type: type,
        accountNumber:
            type == 'bank_transfer' ? accountNumber.text.trim() : null,
        bankCode: type == 'bank_transfer' ? bankCode.text.trim() : null,
        serviceNumber:
            type == 'bank_transfer' ? null : serviceNumber.text.trim(),
        serviceIdentifier:
            type == 'bank_transfer' ? null : serviceIdentifier.text.trim(),
        amount: wantsAmount ? _parseAmount(amount.text) : null,
      );
}

class _BeneficiaryEditorRow extends StatelessWidget {
  const _BeneficiaryEditorRow({
    super.key,
    required this.row,
    required this.index,
    required this.removable,
    required this.errors,
    required this.onClearError,
    required this.onRemove,
    required this.onTypeChanged,
  });

  final _BeneficiaryRow row;
  final int index;
  final bool removable;
  final Map<String, String> errors;
  final void Function(String key) onClearError;
  final VoidCallback onRemove;
  final VoidCallback onTypeChanged;

  String? _errorOf(String suffix) => errors['beneficiary_$index$suffix'];

  @override
  Widget build(BuildContext context) {
    final isBank = row.type == 'bank_transfer';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: row.type,
                  items: [
                    for (final entry in _kBeneficiaryTypes.entries)
                      DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) {
                    if (value == null || value == row.type) return;
                    row.type = value;
                    onTypeChanged();
                  },
                  decoration: const InputDecoration(hintText: 'Type'),
                ),
              ),
              IconButton(
                tooltip: 'Remove beneficiary',
                icon: const Icon(Icons.close, size: 20),
                color: const Color(0xFFB23A3A),
                onPressed: removable ? onRemove : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.name,
            onChanged: (_) => onClearError('beneficiary_${index}_name'),
            decoration: InputDecoration(
              hintText: 'Beneficiary name',
              errorText: _errorOf('_name'),
            ),
          ),
          const SizedBox(height: 8),
          if (isBank) ...[
            TextField(
              controller: row.accountNumber,
              keyboardType: TextInputType.number,
              onChanged: (_) =>
                  onClearError('beneficiary_${index}_account'),
              decoration: InputDecoration(
                hintText: 'Account number',
                errorText: _errorOf('_account'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.bankCode,
              onChanged: (_) =>
                  onClearError('beneficiary_${index}_bank_code'),
              decoration: InputDecoration(
                hintText: 'Bank code (e.g. 058)',
                errorText: _errorOf('_bank_code'),
              ),
            ),
          ] else ...[
            TextField(
              controller: row.serviceNumber,
              onChanged: (_) =>
                  onClearError('beneficiary_${index}_service_number'),
              decoration: InputDecoration(
                hintText: row.type == 'electricity'
                    ? 'Meter number'
                    : 'Service number (e.g. 08012345678)',
                errorText: _errorOf('_service_number'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.serviceIdentifier,
              onChanged: (_) =>
                  onClearError('beneficiary_${index}_service_identifier'),
              decoration: InputDecoration(
                hintText: row.type == 'electricity'
                    ? 'Disco identifier (e.g. EKEDC)'
                    : 'Service identifier (e.g. MTN)',
                errorText: _errorOf('_service_identifier'),
              ),
            ),
          ],
          if (row.wantsAmount) ...[
            const SizedBox(height: 8),
            MoneyField(
              controller: row.amount,
              hint: 'Amount',
              onChanged: (_) => onClearError('beneficiary_${index}_amount'),
            ),
            if (_errorOf('_amount') != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  _errorOf('_amount')!,
                  style:
                      const TextStyle(color: Color(0xFFB23A3A), fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewPane extends StatelessWidget {
  const _ReviewPane({required this.screen, required this.submitting});

  final _CreateBeelScreenState screen;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final amount = _parseAmount(screen._amountController.text) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewCard(
            context,
            title: 'Beel',
            rows: [
              ('Mode', _kModes[screen._mode] ?? screen._mode),
              ('Name', screen._nameController.text.trim()),
              ('Target', formatNaira(amount)),
              (
                'Recurrence',
                _recurrenceSummary(screen),
              ),
              if (screen._mode == 'open')
                (
                  'Per contributor',
                  screen._parsePerContributor() == null
                      ? '${screen._expectedContributors() ?? '?'} people split'
                      : formatNaira(screen._parsePerContributor()!)
                ),
            ],
          ),
          if (screen._mode == 'closed') ...[
            const SizedBox(height: 12),
            _reviewCard(
              context,
              title: 'Contributors',
              rows: [
                for (var i = 0; i < screen._contributors.length; i++)
                  (
                    '${screen._contributors[i].firstName.text.trim()} '
                        '${screen._contributors[i].lastName.text.trim()}'
                        .trim(),
                    formatNaira(
                        _parseAmount(screen._contributors[i].amount.text) ?? 0),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _reviewCard(
            context,
            title: 'Beneficiaries',
            rows: [
              for (var i = 0; i < screen._beneficiaries.length; i++)
                (
                  screen._beneficiaries[i].name.text.trim(),
                  [
                    _kBeneficiaryTypes[screen._beneficiaries[i].type] ??
                        screen._beneficiaries[i].type,
                    if (screen._beneficiaries[i].wantsAmount)
                      formatNaira(
                          _parseAmount(screen._beneficiaries[i].amount.text) ??
                              0),
                  ].join(' · '),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (screen._errors['review'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEDED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                screen._errors['review']!,
                style: const TextStyle(color: Color(0xFFB23A3A)),
              ),
            )
          else if (screen._errors['review_warning'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF3E4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                screen._errors['review_warning']!,
                style: const TextStyle(color: Color(0xFFB0700F)),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Everything looks good. Submit to create the beel.',
                style: TextStyle(color: Color(0xFF1F7A4D)),
              ),
            ),
        ],
      ),
    );
  }

  String _recurrenceSummary(_CreateBeelScreenState screen) {
    final base = _kRecurrences[screen._recurrenceType] ??
        screen._recurrenceType;
    if (screen._recurrenceType == 'weekly') {
      return 'Weekly · ${_kWeekdays[screen._dayOfWeek] ?? screen._dayOfWeek}';
    }
    if (screen._recurrenceType == 'monthly') {
      return 'Monthly · Day ${screen._dayOfMonth}';
    }
    return base;
  }

  Widget _reviewCard(
    BuildContext context, {
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF21222D),
                ),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: const Color(0xFF7B7D8C)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF21222D),
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

