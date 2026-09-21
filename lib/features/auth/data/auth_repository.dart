import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/envelope.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_store.dart';
import '../models/profile.dart';

/// Auth + profile endpoints of the NestJS backend.
///
/// Field names verified against:
/// - beels/src/auth/dto/login-auth.dto.ts / create-auth.dto.ts
/// - beels/src/auth/dto/password/change-password.dto.ts
/// - beels/src/auth/dto/update-profile.dto.ts
/// - beels/src/auth/auth.controller.ts (routes)
class AuthRepository {
  AuthRepository({required ApiClient apiClient, required TokenStore tokenStore})
      : _api = apiClient,
        _tokenStore = tokenStore;

  final ApiClient _api;
  final TokenStore _tokenStore;

  /// POST /auth/login — the JWT lives at the TOP level (`access_token`),
  /// profile fields under `data`. Token is persisted before returning.
  Future<Profile> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post('/auth/login', body: {
      'email': email,
      'method': 'password',
      'password': password,
    });
    final token = response is Map<dynamic, dynamic>
        ? response['access_token']?.toString()
        : null;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Login failed. Please try again.',
        statusCode: 0,
      );
    }
    await _tokenStore.write(token);
    return envelope<Profile>(response, Profile.fromJson);
  }

  /// POST /auth/register — backend returns no token; the caller logs in after.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    return _api.post('/auth/register', body: {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'method': 'password',
      'password': password,
    });
  }

  /// POST /auth/password/reset/email.
  Future<void> requestPasswordReset(String email) {
    return _api.post('/auth/password/reset/email', body: {'email': email});
  }

  /// GET /auth/profile.
  Future<Profile> fetchProfile() async {
    final response = await _api.get('/auth/profile');
    return envelope<Profile>(response, Profile.fromJson);
  }

  /// PATCH /auth/profile — sends only the provided fields.
  Future<Profile> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final response = await _api.patch('/auth/profile', body: {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
    });
    return envelope<Profile>(response, Profile.fromJson);
  }

  /// POST /auth/password/change — DTO requires old, new and a matching
  /// confirmation, so the new password is sent as both `new_password` and
  /// `confirm_new_password`.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _api.post('/auth/password/change', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
      'confirm_new_password': newPassword,
    });
  }

  /// POST /auth/logout, then always clear the local token: blacklisting is
  /// best-effort on the server and a failed request must not trap the user
  /// in a signed-in UI.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Ignore: local sign-out proceeds regardless.
    }
    await _tokenStore.clear();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});