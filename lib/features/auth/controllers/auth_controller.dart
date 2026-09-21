import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../models/profile.dart';

/// Single source of truth for the signed-in user.
///
/// `state.valueOrNull != null` means authenticated. Router refresh and the
/// `/auth/*` screens listen to this provider.
class AuthController extends AsyncNotifier<Profile?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStore get _tokenStore => ref.read(tokenStoreProvider);

  @override
  Future<Profile?> build() => bootstrap();

  /// Restores the session: with a stored token, fetch the profile; a 401
  /// means the token is dead — clear it silently. Other failures surface as
  /// an error state (retry via ref.invalidate).
  Future<Profile?> bootstrap() async {
    final token = await _tokenStore.read();
    if (token == null) return null;
    try {
      return await _repository.fetchProfile();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _tokenStore.clear();
        return null;
      }
      rethrow;
    }
  }

  /// `true` only when the provider holds signed-in profile data.
  ///
  /// Riverpod 2.6 attaches the previous value to loading/error states, so a
  /// plain `valueOrNull` would keep a stale profile visible right after a
  /// failed login. `unwrapPrevious` makes transitional states read as
  /// unauthenticated.
  bool get isAuthenticated => state.unwrapPrevious().valueOrNull != null;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.login(email: email, password: password);
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// POST /auth/register, then log in with the same credentials.
  Future<void> registerThenLogin({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
      final profile =
          await _repository.login(email: email, password: password);
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final updated = await _repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
    // PATCH response omits `role`; merge over the current profile so no
    // known field is lost.
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncValue.data(updated);
      return;
    }
    state = AsyncValue.data(
      Profile(
        email: updated.email.isNotEmpty ? updated.email : current.email,
        firstName: updated.firstName.isNotEmpty
            ? updated.firstName
            : current.firstName,
        lastName: updated.lastName ?? current.lastName,
        phoneNumber: updated.phoneNumber ?? current.phoneNumber,
        status: updated.status ?? current.status,
        role: updated.role ?? current.role,
      ),
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Profile?>(AuthController.new);