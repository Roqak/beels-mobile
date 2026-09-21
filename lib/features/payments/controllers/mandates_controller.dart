import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/payments_repository.dart';
import '../models/bank.dart';
import '../models/payment_mandate.dart';

/// Mandates registered by the signed-in organizer, with revocation.
class MandatesController extends AsyncNotifier<List<PaymentMandate>> {
  @override
  FutureOr<List<PaymentMandate>> build() {
    return ref.watch(paymentsRepositoryProvider).listMandates();
  }

  /// Revokes a mandate, then reloads. Throws on failure.
  Future<void> revoke(PaymentMandate mandate) async {
    final id = mandate.id;
    if (id == null) {
      throw const ApiException('This mandate cannot be revoked.', statusCode: 0);
    }
    await ref.read(paymentsRepositoryProvider).revokeMandate(id);
    await ref.read(mandatesControllerProvider.notifier).refresh();
  }

  /// Reloads the list, keeping current data visible while refreshing.
  Future<void> refresh() async {
    state = const AsyncLoading<List<PaymentMandate>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(paymentsRepositoryProvider).listMandates(),
    );
  }
}

final mandatesControllerProvider =
    AsyncNotifierProvider<MandatesController, List<PaymentMandate>>(
  MandatesController.new,
);

/// Nigerian banks for the mandate setup bank picker.
final banksProvider =
    FutureProvider<List<Bank>>((ref) async {
  return ref.watch(paymentsRepositoryProvider).getBanks();
});