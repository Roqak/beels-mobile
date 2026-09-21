import '../../../core/config.dart';

// Tolerant JSON helpers. Nullable fields stay nullable, unknown keys are
// ignored and numeric fields accept int / double / String numbers.

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _nullableString(dynamic value) =>
    value?.toString();

num? _nullableNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

int? _nullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _nullableDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<T> _parseList<T>(dynamic value, T Function(dynamic) fromJson) {
  if (value is! List) return const [];
  return value.map(fromJson).toList();
}

/// A beel (contribution) as returned by the backend.
///
/// Parsing is tolerant: optional fields stay nullable, unknown JSON keys are
/// ignored and numeric fields accept int / double / String numbers.
class Contribution {
  Contribution({
    this.id,
    required this.name,
    this.unitAmount,
    this.totalAmount,
    this.status = '',
    this.recurrenceType = '',
    this.dayOfWeek,
    this.dayOfMonth,
    this.occurrences,
    this.nextOccurrence,
    this.contributionMode = 'closed',
    this.paymentLinkToken,
    this.amountPerContributor,
    this.accountNumber,
    this.cancelledAt,
    this.contributors = const [],
    this.beneficiaries = const [],
    this.createdAt,
  });

  final int? id;
  final String name;
  final num? unitAmount;
  final num? totalAmount;
  final String status;
  final String recurrenceType;
  final String? dayOfWeek;
  final int? dayOfMonth;
  final int? occurrences;
  final DateTime? nextOccurrence;
  final String contributionMode;
  final String? paymentLinkToken;
  final num? amountPerContributor;
  final String? accountNumber;
  final DateTime? cancelledAt;
  final List<ContributionContributor> contributors;
  final List<BeelBeneficiary> beneficiaries;
  final DateTime? createdAt;

  factory Contribution.fromJson(dynamic json) {
    final map = _asMap(json);
    return Contribution(
      id: _nullableInt(map['id']),
      name: _asString(map['name']),
      unitAmount: _nullableNum(map['unit_amount']),
      totalAmount: _nullableNum(map['total_amount']),
      status: _asString(map['status']),
      recurrenceType: _asString(map['recurrence_type']),
      dayOfWeek: _nullableString(map['day_of_week']),
      dayOfMonth: _nullableInt(map['day_of_month']),
      occurrences: _nullableInt(map['occurrences']),
      nextOccurrence: _nullableDate(map['next_occurrence']),
      contributionMode:
          _asString(map['contribution_mode'], fallback: 'closed'),
      paymentLinkToken: _nullableString(map['payment_link_token']),
      amountPerContributor: _nullableNum(map['amount_per_contributor']),
      accountNumber: _nullableString(map['account_number']),
      cancelledAt: _nullableDate(map['cancelled_at']),
      contributors: _parseList(
        map['contributors'],
        ContributionContributor.fromJson,
      ),
      beneficiaries: _parseList(
        map['beneficiaries'],
        BeelBeneficiary.fromJson,
      ),
      createdAt: _nullableDate(map['created_at']),
    );
  }

  bool get isOpenLink => contributionMode == 'open_link';

  /// Full shareable link for an open-link beel ('' without a token).
  String get paymentLink =>
      paymentLinkToken == null ? '' : beelPaymentLink(paymentLinkToken!);
}

/// A contributor row of a beel.
class ContributionContributor {
  ContributionContributor({
    this.id,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phoneNumber = '',
    this.unitAmount,
    this.amountPaid,
    this.status = '',
    this.bankName,
    this.paymentId,
  });

  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final num? unitAmount;
  final num? amountPaid;
  final String status;
  final String? bankName;

  /// Flutterwave payment identifier for this contributor's deposit. Present
  /// on beel detail rows; absent on participation projections.
  final String? paymentId;

  /// Contributors whose deposit can still be paid: no terminal state.
  bool get canPay => paymentId != null && !_terminalStatuses.contains(status.toLowerCase());

  static const _terminalStatuses = {'settled', 'paid', 'completed', 'cancelled', 'revoked'};

  String get fullName => '$firstName $lastName'.trim();

  factory ContributionContributor.fromJson(dynamic json) {
    final map = _asMap(json);
    return ContributionContributor(
      id: _nullableInt(map['id']),
      firstName: _asString(map['first_name']),
      lastName: _asString(map['last_name']),
      email: _asString(map['email']),
      phoneNumber: _asString(map['phone_number']),
      unitAmount: _nullableNum(map['unit_amount']),
      amountPaid: _nullableNum(map['amount_paid']),
      status: _asString(map['status']),
      bankName: _nullableString(map['bank_name']),
      paymentId: _nullableString(map['payment_id']),
    );
  }
}

/// A beneficiary row of a beel.
class BeelBeneficiary {
  BeelBeneficiary({
    this.id,
    this.name = '',
    this.type = '',
    this.status = '',
    this.amount,
    this.accountNumber,
    this.bankCode,
    this.serviceNumber,
    this.serviceIdentifier,
  });

  final int? id;
  final String name;
  final String type;
  final String status;
  final num? amount;
  final String? accountNumber;
  final String? bankCode;
  final String? serviceNumber;
  final String? serviceIdentifier;

  String get typeLabel {
    switch (type) {
      case 'bank_transfer':
        return 'Bank transfer';
      case 'airtime':
        return 'Airtime';
      case 'data':
        return 'Data';
      case 'cable':
        return 'Cable TV';
      case 'electricity':
        return 'Electricity';
      default:
        return type.isEmpty ? 'Beneficiary' : type;
    }
  }

  factory BeelBeneficiary.fromJson(dynamic json) {
    final map = _asMap(json);
    return BeelBeneficiary(
      id: _nullableInt(map['id']),
      name: _asString(map['name']),
      type: _asString(map['type']),
      status: _asString(map['status']),
      amount: _nullableNum(map['amount']),
      accountNumber: _nullableString(map['account_number']),
      bankCode: _nullableString(map['bank_code']),
      serviceNumber: _nullableString(map['service_number']),
      serviceIdentifier: _nullableString(map['service_identifier']),
    );
  }
}

/// A beel the signed-in user has paid into (as contributor, not organizer).
class Participation {
  Participation({
    this.id,
    this.name = '',
    this.unitAmount,
    this.amountPaid,
    this.status = '',
    this.nextOccurrence,
  });

  final int? id;
  final String name;
  final num? unitAmount;
  final num? amountPaid;
  final String status;
  final DateTime? nextOccurrence;

  factory Participation.fromJson(dynamic json) {
    final map = _asMap(json);
    final contribution = _asMap(map['contribution']);
    return Participation(
      id: _nullableInt(map['contributor_id']) ??
          _nullableInt(contribution['id']),
      name: _asString(contribution['name']),
      unitAmount: _nullableNum(map['expected_amount']) ??
          _nullableNum(map['unit_amount']),
      amountPaid: _nullableNum(map['amount_paid']),
      status: _asString(map['status']),
      nextOccurrence: _nullableDate(
        map['next_occurrence'] ?? contribution['next_occurrence'],
      ),
    );
  }
}

/// Contributor row submitted when creating a closed beel.
class ContributorInput {
  ContributorInput({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.amount,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final num amount;

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'amount': amount,
      };
}

/// Beneficiary row submitted when creating a beel. Null fields are omitted.
class BeneficiaryInput {
  BeneficiaryInput({
    required this.name,
    required this.type,
    this.accountNumber,
    this.bankCode,
    this.serviceNumber,
    this.serviceIdentifier,
    this.amount,
  });

  final String name;
  final String type;
  final String? accountNumber;
  final String? bankCode;
  final String? serviceNumber;
  final String? serviceIdentifier;
  final num? amount;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'type': type,
      'account_number': accountNumber,
      'bank_code': bankCode,
      'service_number': serviceNumber,
      'service_identifier': serviceIdentifier,
      'amount': amount,
    };
    map.removeWhere((_, value) => value == null);
    return map;
  }
}

/// Full payment link for an open-link beel.
String beelPaymentLink(String paymentLinkToken) =>
    '${AppConfig.frontendBaseUrl}/pay/join/$paymentLinkToken';

/// Human label for a recurrence, e.g. "Weekly · Monday", "Monthly · Day 15".
String recurrenceLabel(Contribution beel) {
  switch (beel.recurrenceType) {
    case 'weekly':
      final day = beel.dayOfWeek;
      if (day == null || day.isEmpty) return 'Weekly';
      return 'Weekly · ${_capitalize(day)}';
    case 'monthly':
      final day = beel.dayOfMonth;
      if (day == null) return 'Monthly';
      return 'Monthly · Day $day';
    case 'daily':
      return 'Daily';
    case 'one_time':
      return 'One-time';
    default:
      return beel.recurrenceType.isEmpty ? 'Recurring' : beel.recurrenceType;
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';