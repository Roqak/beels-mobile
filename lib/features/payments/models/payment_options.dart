import '../../../core/money.dart';

class _Json {
  static String asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  static num? asNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static int? asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

/// One bank account the contributor has already linked for direct debit.
class DebitAccount {
  const DebitAccount({
    this.id,
    this.bankName = '',
    this.accountNumberMasked = '',
  });

  final int? id;
  final String bankName;
  final String accountNumberMasked;

  factory DebitAccount.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    return DebitAccount(
      id: _Json.asInt(map['id']),
      bankName: _Json.asString(map['bank_name'], fallback: 'Linked account'),
      accountNumberMasked: _Json.asString(map['account_number_masked']),
    );
  }
}

/// Payment alternatives for a contributor payment link:
/// bank transfer details and, when enabled, linked debit accounts.
class PaymentOptions {
  const PaymentOptions({
    this.contributorFirstName = '',
    this.beelName = '',
    this.amountDue = 0,
    this.amountPaid = 0,
    this.transferBankName = '',
    this.transferAccountNumber = '',
    this.transferReference = '',
    this.directDebitAvailable = false,
    this.debitAccounts = const <DebitAccount>[],
  });

  final String contributorFirstName;
  final String beelName;
  final num amountDue;
  final num amountPaid;
  final String transferBankName;
  final String transferAccountNumber;
  final String transferReference;
  final bool directDebitAvailable;
  final List<DebitAccount> debitAccounts;

  num get outstanding {
    final left = amountDue - amountPaid;
    return left > 0 ? left : 0;
  }

  bool get settlesEverything => outstanding <= 0;

  /// Parsed naira values for direct display.
  String get outstandingLabel => formatNaira(outstanding);

  factory PaymentOptions.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    final transfer = json is Map ? json['transfer'] : null;
    final transferMap = transfer is Map ? transfer : const {};
    final directDebit = json is Map ? json['direct_debit'] : null;
    final directDebitMap = directDebit is Map ? directDebit : const {};
    final accounts = directDebitMap['accounts'];
    final contributor = json is Map ? json['contributor'] : null;
    final contributorMap = contributor is Map ? contributor : const {};
    final beel = json is Map ? json['beel'] : null;
    final beelMap = beel is Map ? beel : const {};

    return PaymentOptions(
      contributorFirstName: _Json.asString(contributorMap['first_name']),
      beelName: _Json.asString(beelMap['name']),
      amountDue: _Json.asNum(map['amount_due']) ?? 0,
      amountPaid: _Json.asNum(map['amount_paid']) ?? 0,
      transferBankName: _Json.asString(transferMap['bank_name']),
      transferAccountNumber: _Json.asString(transferMap['account_number']),
      transferReference: _Json.asString(transferMap['reference']),
      directDebitAvailable: directDebitMap['available'] == true,
      debitAccounts: accounts is List
          ? accounts.map(DebitAccount.fromJson).toList()
          : const <DebitAccount>[],
    );
  }
}

/// Result of an instant mandate debit (POST .../direct-debit).
class DebitRequest {
  const DebitRequest({this.reference = '', this.amount = 0, this.message = ''});

  final String reference;
  final num amount;
  final String message;

  factory DebitRequest.fromJson(dynamic envelope) {
    final data = envelope is Map ? envelope['data'] : null;
    final dataMap = data is Map ? data : const {};
    return DebitRequest(
      reference: _Json.asString(dataMap['reference']),
      amount: _Json.asNum(dataMap['amount']) ?? 0,
      message: _Json.asString(envelope is Map ? envelope['message'] : null),
    );
  }
}