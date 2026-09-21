import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/controllers/auth_controller.dart';
import 'api/api_client.dart';
import 'storage/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: () => ref.invalidate(authControllerProvider),
  );
});

/// Bridges riverpod auth state into a [Listenable] so go_router can refresh
/// its redirects when authentication changes.
class AuthListenable extends ChangeNotifier {
  AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

final authListenableProvider = Provider<AuthListenable>((ref) {
  final listenable = AuthListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
});