import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/payments_repository.dart';
import '../models/bank.dart';

enum MandateSetupStep { details, personal, submitting }

/// State for the mandate setup wizard.
class MandateSetupState {
  const MandateSetupState({
    this.step = MandateSetupStep.details,
    this.selectedBank,
    this.accountNumber = '',
    this.accountName,
    this.verifying = false,
    this.submitting = false,
    this.error,
  });

  final MandateSetupStep step;
  final Bank? selectedBank;
  final String accountNumber;

  /// Name returned by the backend's name enquiry; null until verified.
  final String? accountName;
  final bool verifying;
  final bool submitting;
  final String? error;

  bool canVerify(String accountNumber) =>
      selectedBank != null &&
      selectedBank!.cbnCode.isNotEmpty &&
      accountNumber.trim().length >= 10;

  bool canSubmitPersonal(
    String firstName,
    String lastName,
    String email,
    String phoneNumber,
    String bvn,
  ) =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      email.trim().contains('@') &&
      phoneNumber.trim().length >= 10 &&
      RegExp(r'^\d{11}$').hasMatch(bvn.trim());

  MandateSetupState copyWith({
    MandateSetupStep? step,
    Bank? selectedBank,
    String? accountNumber,
    String? accountName,
    bool clearAccountName = false,
    bool? verifying,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return MandateSetupState(
      step: step ?? this.step,
      selectedBank: selectedBank ?? this.selectedBank,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: clearAccountName ? null : (accountName ?? this.accountName),
      verifying: verifying ?? this.verifying,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the three-step mandate setup wizard: bank + account verification,
/// personal details with BVN, then submission.
class MandateSetupController extends AutoDisposeNotifier<MandateSetupState> {
  @override
  MandateSetupState build() {
    // Personal fields are prefilled by the screen from the profile at mount;
    // the wizard keeps its own state while open.
    return const MandateSetupState();
  }

  void selectBank(Bank bank) {
    state = state.copyWith(
      selectedBank: bank,
      clearAccountName: true,
      clearError: true,
    );
  }

  /// Returns to the account step without discarding the verified details.
  void backToAccount() {
    state = state.copyWith(step: MandateSetupStep.details, clearError: true);
  }

  /// Resolves the account holder name for the entered account.
  Future<void> verifyAccount({required String accountNumber}) async {
    if (!state.canVerify(accountNumber) || state.verifying) return;
    state = state.copyWith(
      accountNumber: accountNumber.trim(),
      verifying: true,
      clearError: true,
      clearAccountName: true,
    );
    try {
      final name = await ref.read(paymentsRepositoryProvider).nameEnquiry(
            accountNumber: accountNumber.trim(),
            bankCode: state.selectedBank!.cbnCode,
          );
      if (name.isEmpty) {
        state = state.copyWith(
          verifying: false,
          error: 'We could not confirm that account. Check the details.',
        );
        return;
      }
      state = state.copyWith(
        verifying: false,
        accountName: name,
        step: MandateSetupStep.personal,
      );
    } on ApiException catch (e) {
      state = state.copyWith(verifying: false, error: e.message);
    }
  }

  /// Submits the mandate setup request. Throws on failure.
  Future<void> submit({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String bvn,
  }) async {
    if (!state.canSubmitPersonal(firstName, lastName, email, phoneNumber, bvn) ||
        state.submitting) {
      return;
    }
    state = state.copyWith(
      submitting: true,
      step: MandateSetupStep.submitting,
      clearError: true,
    );
    try {
      await ref.read(paymentsRepositoryProvider).setupMandate(
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            email: email.trim(),
            phoneNumber: phoneNumber.trim(),
            accountNumber: state.accountNumber.trim(),
            bankName: state.selectedBank!.name,
            bankCode: state.selectedBank!.cbnCode,
            bvn: bvn.trim(),
          );
    } finally {
      if (ref.exists(mandateSetupControllerProvider)) {
        state = state.copyWith(submitting: false);
      }
    }
  }
}

final mandateSetupControllerProvider = NotifierProvider.autoDispose<
    MandateSetupController, MandateSetupState>(
  MandateSetupController.new,
);