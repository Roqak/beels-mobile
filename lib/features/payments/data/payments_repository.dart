import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/envelope.dart';
import '../../../core/providers.dart';
import '../models/bank.dart';
import '../models/payment_mandate.dart';

/// Backend access for Flutterwave payments and direct-debit mandates.
class PaymentsRepository {
  PaymentsRepository(this._client);

  final ApiClient _client;

  /// GET /get-banks — Nigerian banks usable for name enquiry and mandates.
  Future<List<Bank>> getBanks() async {
    final json = await _client.get(
      '/get-banks',
      query: {'pwa_enabled_only': 'false'},
    );
    final data = json is Map ? json['data'] : null;
    final banks = data is Map ? data['banks'] : data;
    if (banks is! List) return <Bank>[];
    return banks.map(Bank.fromJson).toList();
  }

  /// GET /mandate — mandates registered by the signed-in organizer.
  Future<List<PaymentMandate>> listMandates() async {
    final json = await _client.get('/mandate');
    return envelopeList(json, PaymentMandate.fromJson);
  }

  /// POST /mandate/name-enquiry — resolves the account holder's name.
  Future<String> nameEnquiry({
    required String accountNumber,
    required String bankCode,
  }) async {
    final json = await _client.post('/mandate/name-enquiry', body: {
      'account_number': accountNumber,
      'bank_code': bankCode,
    });
    final data = json is Map ? json['data'] : null;
    if (data is Map && data['account_name'] is String) {
      return data['account_name'] as String;
    }
    return '';
  }

  /// POST /mandate/setup — registers a direct-debit mandate with the
  /// organizer's bank details and BVN.
  Future<void> setupMandate({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String accountNumber,
    required String bankName,
    required String bankCode,
    required String bvn,
  }) async {
    await _client.post('/mandate/setup', body: {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'account_number': accountNumber,
      'bank_name': bankName,
      'bank_code': bankCode,
      'bvn': bvn,
    });
  }

  /// DELETE /mandate/:id — revokes a mandate.
  Future<void> revokeMandate(int id) => _client.delete('/mandate/$id');

  /// POST /payment/initialize — starts a Flutterwave checkout for a
  /// contributor deposit and returns the hosted payment URL.
  Future<String> initializePayment(String paymentId) async {
    final json = await _client.post('/payment/initialize', body: {
      'payment_id': paymentId,
    });
    final data = json is Map ? json['data'] : null;
    if (data is Map && data['url'] is String) {
      return data['url'] as String;
    }
    return '';
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(apiClientProvider));
});