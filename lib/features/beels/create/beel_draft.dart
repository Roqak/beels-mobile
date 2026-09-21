import '../models/contribution.dart';

/// Who is paying: people you choose, or anyone holding the link.
enum BeelMode { closed, open }

/// How an open-link beel prices each person.
enum OpenSplit { fixed, even }

/// How a chosen-people beel works out what each person pays: shared evenly
/// (derived from the target) or typed per person.
enum ContributorSplit { even, custom }

/// Beneficiary kinds the backend accepts, in display order.
const kBeneficiaryTypes = <String, String>{
  'bank_transfer': 'Bank transfer',
  'airtime': 'Airtime',
  'data': 'Data',
  'cable': 'Cable TV',
  'electricity': 'Electricity',
};

const kRecurrences = <String, String>{
  'one_time': 'One-time',
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
};

const kWeekdays = <String, String>{
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};

final RegExp _emailRegExp = RegExp(r'^\S+@\S+\.\S+$', caseSensitive: false);

/// `"1,250.50"` -> 1250.5; null when it is not a number.
num? parseMoney(String text) {
  final n = num.tryParse(text.trim().replaceAll(',', ''));
  if (n == null) return null;
  return n;
}

class DraftContributor {
  const DraftContributor({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.amount = '',
  });

  /// Stable identity for widget keys (indexes shift when rows are removed).
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String amount;

  String get fullName => '$firstName $lastName'.trim();

  DraftContributor copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? amount,
  }) =>
      DraftContributor(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        amount: amount ?? this.amount,
      );
}

class DraftBeneficiary {
  const DraftBeneficiary({
    required this.id,
    this.type = 'bank_transfer',
    this.name = '',
    this.accountNumber = '',
    this.bankCode = '',
    this.bankName = '',
    this.serviceNumber = '',
    this.serviceIdentifier = '',
    this.amount = '',
  });

  final int id;
  final String type;
  final String name;
  final String accountNumber;
  final String bankCode;
  final String bankName;
  final String serviceNumber;
  final String serviceIdentifier;
  final String amount;

  bool get isBank => type == 'bank_transfer';

  /// Only bank transfers and airtime carry an amount.
  bool get wantsAmount => type == 'bank_transfer' || type == 'airtime';

  DraftBeneficiary copyWith({
    String? type,
    String? name,
    String? accountNumber,
    String? bankCode,
    String? bankName,
    String? serviceNumber,
    String? serviceIdentifier,
    String? amount,
  }) =>
      DraftBeneficiary(
        id: id,
        type: type ?? this.type,
        name: name ?? this.name,
        accountNumber: accountNumber ?? this.accountNumber,
        bankCode: bankCode ?? this.bankCode,
        bankName: bankName ?? this.bankName,
        serviceNumber: serviceNumber ?? this.serviceNumber,
        serviceIdentifier: serviceIdentifier ?? this.serviceIdentifier,
        amount: amount ?? this.amount,
      );
}

/// Everything the user has entered so far. Immutable; the notifier swaps it.
class BeelDraft {
  const BeelDraft({
    this.mode = BeelMode.closed,
    this.name = '',
    this.amount = '',
    this.recurrenceType = 'one_time',
    this.dayOfWeek = 'monday',
    this.dayOfMonth = 1,
    this.contributors = const [],
    this.beneficiaries = const [],
    this.contributorSplit = ContributorSplit.even,
    this.openSplit = OpenSplit.even,
    this.perContributor = '',
    this.expectedContributors = '',
    this.nextId = 1,
  });

  final BeelMode mode;
  final String name;
  final String amount;
  final String recurrenceType;
  final String dayOfWeek;
  final int dayOfMonth;
  final List<DraftContributor> contributors;
  final List<DraftBeneficiary> beneficiaries;
  final ContributorSplit contributorSplit;
  final OpenSplit openSplit;
  final String perContributor;
  final String expectedContributors;
  final int nextId;

  num? get target => parseMoney(amount);

  bool get isOpen => mode == BeelMode.open;

  /// True once the user has typed anything worth protecting from a back-tap.
  bool get isDirty =>
      name.trim().isNotEmpty ||
      amount.trim().isNotEmpty ||
      contributors.any((c) =>
          c.firstName.isNotEmpty ||
          c.phone.isNotEmpty ||
          c.amount.isNotEmpty) ||
      beneficiaries.any((b) =>
          b.name.isNotEmpty ||
          b.accountNumber.isNotEmpty ||
          b.amount.isNotEmpty);

  bool get sharesEvenly => contributorSplit == ContributorSplit.even;

  /// Each person's even share of the target (empty until there is a positive
  /// target and at least one person). The parts add up exactly.
  List<num> get evenShares {
    final t = target;
    if (t == null || t <= 0 || contributors.isEmpty) return const [];
    return splitEvenly(t, contributors.length);
  }

  /// What the person at [index] pays: their even share, or what was typed.
  num? effectiveContributorAmount(int index) {
    if (index < 0 || index >= contributors.length) return null;
    if (sharesEvenly) {
      final shares = evenShares;
      return index < shares.length ? shares[index] : null;
    }
    return parseMoney(contributors[index].amount);
  }

  num get contributorTotal {
    var sum = 0.0;
    for (var i = 0; i < contributors.length; i++) {
      sum += effectiveContributorAmount(i) ?? 0;
    }
    return sum;
  }

  /// Target minus what contributors are assigned (negative = over-assigned).
  num get contributorRemaining => (target ?? 0) - contributorTotal;

  /// A beneficiary's amount: what was typed, or the whole target when there
  /// is a single bank/airtime beneficiary (nothing to split).
  num? effectiveBeneficiaryAmount(DraftBeneficiary b) {
    if (!b.wantsAmount) return null;
    final typed = parseMoney(b.amount);
    if (typed != null) return typed;
    if (beneficiaries.length == 1) return target;
    return null;
  }

  /// Sum of beneficiary amounts, or null when some row has none (services
  /// carry no amount, so the total cannot be checked).
  num? get payoutTotal {
    var sum = 0.0;
    for (final b in beneficiaries) {
      final a = effectiveBeneficiaryAmount(b);
      if (a == null) return null;
      sum += a;
    }
    return sum;
  }

  /// What one person pays on an open-link beel, when it can be worked out.
  num? get perPersonPreview {
    if (openSplit == OpenSplit.fixed) {
      final p = parseMoney(perContributor);
      return (p != null && p > 0) ? p : null;
    }
    final n = int.tryParse(expectedContributors.trim());
    final t = target;
    if (n == null || n < 1 || t == null || t <= 0) return null;
    return t / n;
  }

  BeelDraft copyWith({
    BeelMode? mode,
    String? name,
    String? amount,
    String? recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    List<DraftContributor>? contributors,
    List<DraftBeneficiary>? beneficiaries,
    ContributorSplit? contributorSplit,
    OpenSplit? openSplit,
    String? perContributor,
    String? expectedContributors,
    int? nextId,
  }) =>
      BeelDraft(
        mode: mode ?? this.mode,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        recurrenceType: recurrenceType ?? this.recurrenceType,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        contributors: contributors ?? this.contributors,
        beneficiaries: beneficiaries ?? this.beneficiaries,
        contributorSplit: contributorSplit ?? this.contributorSplit,
        openSplit: openSplit ?? this.openSplit,
        perContributor: perContributor ?? this.perContributor,
        expectedContributors: expectedContributors ?? this.expectedContributors,
        nextId: nextId ?? this.nextId,
      );

  /// Submission payload pieces.
  List<ContributorInput> toContributorInputs() => [
        for (var i = 0; i < contributors.length; i++)
          ContributorInput(
            firstName: contributors[i].firstName.trim(),
            lastName: contributors[i].lastName.trim(),
            email: contributors[i].email.trim(),
            phoneNumber: contributors[i].phone.trim(),
            amount: effectiveContributorAmount(i) ?? 0,
          ),
      ];

  List<BeneficiaryInput> toBeneficiaryInputs() => [
        for (final b in beneficiaries)
          BeneficiaryInput(
            name: b.name.trim(),
            type: b.type,
            accountNumber: b.isBank ? b.accountNumber.trim() : null,
            bankCode: b.isBank ? b.bankCode.trim() : null,
            serviceNumber: b.isBank ? null : b.serviceNumber.trim(),
            serviceIdentifier: b.isBank ? null : b.serviceIdentifier.trim(),
            amount: effectiveBeneficiaryAmount(b),
          ),
      ];
}

/// Step 1: name and target.
Map<String, String> validateBasics(BeelDraft d) {
  final errors = <String, String>{};
  if (d.name.trim().isEmpty) errors['name'] = 'Give your beel a name';
  final t = d.target;
  if (t == null || t <= 0) errors['amount'] = 'Enter the target amount';
  return errors;
}

/// Step 3: who pays.
Map<String, String> validatePeople(BeelDraft d) {
  final errors = <String, String>{};
  if (d.isOpen) {
    if (d.openSplit == OpenSplit.fixed) {
      final p = parseMoney(d.perContributor);
      if (p == null || p <= 0) {
        errors['per_person'] = 'Enter how much each person pays';
      }
    } else {
      final n = int.tryParse(d.expectedContributors.trim());
      if (n == null || n < 1) {
        errors['expected'] = 'Enter how many people will split this';
      }
    }
    return errors;
  }

  if (d.contributors.isEmpty) {
    errors['people'] = 'Add at least one person';
    return errors;
  }
  for (var i = 0; i < d.contributors.length; i++) {
    validateContributor(d.contributors[i], amountRequired: !d.sharesEvenly)
        .forEach(
            (field, message) => errors['contributor_${i}_$field'] = message);
  }
  if (errors.isEmpty &&
      !d.sharesEvenly &&
      d.contributorTotal != (d.target ?? 0)) {
    errors['people'] =
        'Amounts add up to ${_naira(d.contributorTotal)}, but the target is ${_naira(d.target ?? 0)}';
  }
  return errors;
}

/// Field errors for one person (keys: first, last, email, phone, amount).
Map<String, String> validateContributor(
  DraftContributor c, {
  bool amountRequired = true,
}) {
  final errors = <String, String>{};
  if (c.firstName.trim().isEmpty) errors['first'] = 'Required';
  if (c.lastName.trim().isEmpty) errors['last'] = 'Required';
  if (!_emailRegExp.hasMatch(c.email.trim())) {
    errors['email'] = 'Enter a valid email';
  }
  if (c.phone.replaceAll(RegExp(r'\D'), '').length < 11) {
    errors['phone'] = 'At least 11 digits';
  }
  if (amountRequired) {
    final a = parseMoney(c.amount);
    if (a == null || a <= 0) errors['amount'] = 'Enter an amount';
  }
  return errors;
}

/// Field errors for one payout account (keys: name, bank, account,
/// service_number, service_identifier, amount). [amountRequired] is true when
/// the amount is a real choice (several accounts), false when a single
/// account implicitly receives the whole target.
Map<String, String> validateBeneficiary(
  DraftBeneficiary b, {
  required bool amountRequired,
}) {
  final errors = <String, String>{};
  if (b.name.trim().isEmpty) errors['name'] = 'Required';
  if (b.isBank) {
    if (b.bankCode.trim().isEmpty) errors['bank'] = 'Choose a bank';
    if (b.accountNumber.trim().length < 10) {
      errors['account'] = 'Enter the 10-digit account number';
    }
  } else {
    if (b.serviceNumber.trim().isEmpty) errors['service_number'] = 'Required';
    if (b.serviceIdentifier.trim().isEmpty) {
      errors['service_identifier'] = 'Required';
    }
  }
  if (b.wantsAmount && amountRequired) {
    final a = parseMoney(b.amount);
    if (a == null || a <= 0) errors['amount'] = 'Enter an amount';
  }
  return errors;
}

/// Step 4: who gets paid.
Map<String, String> validatePayout(BeelDraft d) {
  final errors = <String, String>{};
  if (d.beneficiaries.isEmpty) {
    errors['payout'] = 'Add at least one beneficiary';
    return errors;
  }
  for (var i = 0; i < d.beneficiaries.length; i++) {
    final b = d.beneficiaries[i];
    // A single account receives the whole target without typing it.
    final needsAmount =
        d.beneficiaries.length > 1 || d.effectiveBeneficiaryAmount(b) == null;
    validateBeneficiary(b, amountRequired: b.wantsAmount && needsAmount)
        .forEach(
            (field, message) => errors['beneficiary_${i}_$field'] = message);
    if (b.wantsAmount && !errors.containsKey('beneficiary_${i}_amount')) {
      final a = d.effectiveBeneficiaryAmount(b);
      if (a == null || a <= 0) {
        errors['beneficiary_${i}_amount'] = 'Enter an amount';
      }
    }
  }
  if (errors.isEmpty) {
    final total = d.payoutTotal;
    if (total != null && total != (d.target ?? 0)) {
      errors['payout'] =
          'Payouts add up to ${_naira(total)}, but the target is ${_naira(d.target ?? 0)}';
    }
  }
  return errors;
}

String _naira(num n) {
  final whole = n == n.roundToDouble();
  final text = whole ? n.round().toString() : n.toStringAsFixed(2);
  final buf = StringBuffer();
  final parts = text.split('.');
  final digits = parts.first;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₦$buf${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Splits [total] across [count] people to the kobo; any remainder goes to
/// the first people one kobo at a time so the parts always add up exactly.
List<num> splitEvenly(num total, int count) {
  if (count <= 0) return const [];
  final kobo = (total * 100).round();
  final base = kobo ~/ count;
  final extra = kobo % count;
  return [
    for (var i = 0; i < count; i++)
      () {
        final k = base + (i < extra ? 1 : 0);
        return k % 100 == 0 ? k ~/ 100 : k / 100;
      }(),
  ];
}

/// Plain-language recurrence: "Every Monday", "On day 15 of every month".
String recurrenceSentence(BeelDraft d) {
  switch (d.recurrenceType) {
    case 'daily':
      return 'Every day';
    case 'weekly':
      return 'Every ${kWeekdays[d.dayOfWeek] ?? d.dayOfWeek}';
    case 'monthly':
      return 'On day ${d.dayOfMonth} of every month';
    default:
      return 'One time only';
  }
}

const _weekdayIndex = {
  'monday': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'friday': DateTime.friday,
  'saturday': DateTime.saturday,
  'sunday': DateTime.sunday,
};

/// The next date collection would run, or null for a one-time beel (its date
/// is not chosen here).
DateTime? nextRun(BeelDraft d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (d.recurrenceType) {
    case 'daily':
      return today.add(const Duration(days: 1));
    case 'weekly':
      final target = _weekdayIndex[d.dayOfWeek] ?? DateTime.monday;
      var delta = (target - today.weekday) % 7;
      if (delta == 0) delta = 7;
      return today.add(Duration(days: delta));
    case 'monthly':
      DateTime clamp(int year, int month) {
        final last = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, d.dayOfMonth > last ? last : d.dayOfMonth);
      }

      final thisMonth = clamp(today.year, today.month);
      if (thisMonth.isAfter(today)) return thisMonth;
      final nextMonth = today.month == 12
          ? clamp(today.year + 1, 1)
          : clamp(today.year, today.month + 1);
      return nextMonth;
    default:
      return null;
  }
}
