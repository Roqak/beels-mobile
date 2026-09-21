/// A direct-debit mandate registered for the signed-in organizer.
class PaymentMandate {
  PaymentMandate({
    this.id,
    this.accountNumber = '',
    this.bankCode = '',
    this.bankName,
    this.status = '',
    this.transactionRef,
    this.revokedAt,
    this.createdAt,
  });

  final int? id;
  final String accountNumber;
  final String bankCode;
  final String? bankName;
  final String status;
  final String? transactionRef;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  bool get isActive => status.toLowerCase() == 'active';

  factory PaymentMandate.fromJson(dynamic json) {
    if (json is! Map) return PaymentMandate();
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return PaymentMandate(
      id: json['id'] is num ? (json['id'] as num).toInt() : null,
      accountNumber: (json['account_number'] ?? '') as String,
      bankCode: (json['bank_code'] ?? '') as String,
      bankName:
          json['bank_name'] is String ? json['bank_name'] as String : null,
      status: (json['status'] ?? '') as String,
      transactionRef: json['transaction_ref'] is String
          ? json['transaction_ref'] as String
          : null,
      revokedAt: date(json['revoked_at']),
      createdAt: date(json['created_at']),
    );
  }
}
