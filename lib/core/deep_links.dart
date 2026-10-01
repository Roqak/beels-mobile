import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/beels/models/invite.dart';

/// Access to the platform link stream. [AppLinks] is a singleton, so this
/// provider is only a seam for tests.
final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());

/// Cold-start join link, resolved in main() before the router builds so the
/// very first navigation lands on `/join/:token`.
final initialJoinUriProvider = Provider<Uri?>((ref) => null);

/// Where to resume after signing in from the join screen. Only join
/// locations are honoured, so a crafted `next` can never send a user
/// anywhere else.
String? joinReturnLocation(String? next) =>
    next != null && next.startsWith('/join/') ? next : null;

/// Resolves the cold-start join token, or null when the app was not opened
/// through a join link.
String? coldStartJoinToken(Ref ref) =>
    joinTokenFromUri(ref.read(initialJoinUriProvider) ?? Uri());

/// Subscribes to warm-start links while the router lives; cold start is
/// handled via [initialJoinUriProvider].
StreamSubscription<Uri> listenForJoinLinks(Ref ref, void Function(String) onToken) {
  if (kIsWeb) {
    return const Stream<Uri>.empty().listen(null);
  }
  return ref.read(appLinksProvider).uriLinkStream.listen((uri) {
    final token = joinTokenFromUri(uri);
    if (token != null) onToken(token);
  }, onError: (_) {});
}