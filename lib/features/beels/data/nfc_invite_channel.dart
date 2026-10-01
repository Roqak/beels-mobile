import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge to the native Android HCE emitter. While an invite URL is set the
/// host phone emulates an NFC tag broadcasting the join link, so a friend's
/// phone joins by tapping — no app or typing required on their side.
class NfcInviteChannel {
  static const _channel = MethodChannel('beels/nfc');

  /// Arms the NFC emitter with the invite join URL. Pass `null` (or call
  /// [clearInviteToken]) to disarm: every SELECT then answers `6D00` and the
  /// phone stops emulating a tag.
  Future<void> setInviteUrl(String? url) => _invoke('setInviteUrl', url);

  /// Disarms the NFC emitter.
  Future<void> clearInviteToken() => _invoke('clearInviteToken', null);

  /// Missing-plugin and platform errors degrade to no-op: without the native
  /// emitter (e.g. non-Android, or unit tests) invites still work via QR /
  /// link share.
  Future<void> _invoke(String method, String? argument) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method, argument);
    } on MissingPluginException catch (_) {
      // No native handler registered.
    } on PlatformException catch (_) {
      // Native side present but HCE setup failed locally.
    }
  }
}

final nfcInviteChannelProvider =
    Provider<NfcInviteChannel>((ref) => NfcInviteChannel());