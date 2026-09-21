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

/// One entry of the user's transaction history (deposit or withdrawal).
///
/// The backend nests the payment payload: `deposit.contributor.contribution`
/// for deposits and `withdrawal.contribution` for withdrawals.
class Transaction {
  Transaction({
    this.id,
    this.type = '',
    this.amount,
    this.status = '',
    this.createdAt,
    this.reference,
    this.beelName,
    this.unitAmount,
    this.totalAmount,
  });

  final int? id;
  final String type;
  final num? amount;
  final String status;
  final DateTime? createdAt;
  final String? reference;
  final String? beelName;
  final num? unitAmount;
  final num? totalAmount;

  bool get isDeposit => type == 'deposit';

  factory Transaction.fromJson(dynamic json) {
    final map = _asMap(json);
    final deposit = _asMap(map['deposit']);
    final withdrawal = _asMap(map['withdrawal']);
    final depositContributor = _asMap(deposit['contributor']);
    final depositContribution = _asMap(depositContributor['contribution']);
    final withdrawalContribution = _asMap(withdrawal['contribution']);

    return Transaction(
      id: _nullableInt(map['id']),
      type: _asString(map['type']),
      amount: _nullableNum(map['amount']) ??
          _nullableNum(deposit['amount']) ??
          _nullableNum(withdrawal['amount']),
      status: _asString(map['status']),
      createdAt: _nullableDate(map['created_at']),
      reference: _nullableStringOrNull(deposit['transaction_reference']) ??
          _nullableStringOrNull(withdrawal['transaction_reference']),
      beelName: _nullableStringOrNull(depositContribution['name']) ??
          _nullableStringOrNull(withdrawalContribution['name']),
      unitAmount: _nullableNum(depositContributor['unit_amount']) ??
          _nullableNum(withdrawalContribution['unit_amount']),
      totalAmount: _nullableNum(depositContribution['total_amount']) ??
          _nullableNum(withdrawalContribution['total_amount']),
    );
  }
}

String? _nullableStringOrNull(dynamic value) => value?.toString();
