import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../controllers/beels_controllers.dart';
import '../data/nfc_invite_channel.dart';
import '../data/beels_repository.dart';
import '../models/invite.dart';

/// Organizer flow that mints a beel invite and beams it to a friend's phone:
/// the Android HCE emitter acts like a physical NFC tag carrying the join
/// link, with a QR / share fallback for phones without NFC or the app.
class InviteNearbyScreen extends ConsumerStatefulWidget {
  const InviteNearbyScreen({super.key, required this.id});

  /// The beel (contribution) the invite is minted for.
  final int id;

  @override
  ConsumerState<InviteNearbyScreen> createState() =>
      _InviteNearbyScreenState();
}

class _InviteNearbyScreenState extends ConsumerState<InviteNearbyScreen> {
  static const maxUsesLimit = 20;

  int _maxUses = 5;
  bool _creating = false;
  bool _closing = false;
  Timer? _expiryTicker;
  Timer? _slotsPoll;
  BeelInvite? _invite;
  int? _slotsLeft;

  @override
  void dispose() {
    // Leaving the screen always disarms the NFC emitter so the phone stops
    // emulating a tag in someone's pocket.
    _cancelTimers();
    unawaited(
      ref.read(nfcInviteChannelProvider).clearInviteToken().catchError((_) {}),
    );
    super.dispose();
  }

  void _cancelTimers() {
    _expiryTicker?.cancel();
    _slotsPoll?.cancel();
    _expiryTicker = null;
    _slotsPoll = null;
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final invite = await ref
          .read(beelsRepositoryProvider)
          .createInvite(contributionId: widget.id, maxUses: _maxUses);
      await ref
          .read(nfcInviteChannelProvider)
          .setInviteUrl(invite.joinUrl)
          .catchError((_) {});
      setState(() {
        _invite = invite;
        _slotsLeft = invite.slotsLeft;
      });
      _startTimers();
      if (mounted) HapticFeedback.mediumImpact();
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } on Object catch (error) {
      _showSnack('$error', isError: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// Keeps the slots readout live while friends tap in, and disarms the
  /// emitter once the invite expires so taps stop answering with a link.
  void _startTimers() {
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _slotsPoll = Timer.periodic(const Duration(seconds: 5), (_) async {
      final invite = _invite;
      if (invite == null || invite.token.isEmpty) return;
      try {
        final preview = await ref
            .read(beelsRepositoryProvider)
            .previewInvite(invite.token);
        if (!mounted) return;
        final full = preview.slotsLeft != null && preview.slotsLeft! <= 0;
        if (full && invite.expiresAt?.isBefore(DateTime.now()) != true) {
          // Tag is spent: stop emulating it so further taps fail cleanly.
          await ref
              .read(nfcInviteChannelProvider)
              .clearInviteToken()
              .catchError((_) {});
        }
        setState(() => _slotsLeft = preview.slotsLeft);
      } on Object {
        // Offline moment: keep the last known readout.
      }
    });
  }

  Future<void> _closeInvite() async {
    setState(() => _closing = true);
    _cancelTimers();
    await ref
        .read(nfcInviteChannelProvider)
        .clearInviteToken()
        .catchError((_) {});
    setState(() {
      _invite = null;
      _slotsLeft = null;
      _closing = false;
    });
  }

  void _leave() {
    _cancelTimers();
    ref.read(beelDetailControllerProvider(widget.id).notifier).refresh();
    unawaited(
      ref.read(nfcInviteChannelProvider).clearInviteToken().catchError((_) {}),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _copyLink() {
    final url = _invite?.joinUrl ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    _showSnack('Invite link copied.', isError: false);
  }

  void _shareLink() {
    final url = _invite?.joinUrl ?? '';
    if (url.isEmpty) return;
    Share.share(url, subject: 'Join my beel');
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    if (isError) HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? BeelsColors.err : BeelsColors.ok,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Invite nearby'),
      body: SafeArea(
        child: invite == null
            ? _buildSetup()
            : _buildLive(invite),
      ),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmptyState(
            icon: Icons.contactless_rounded,
            title: 'Invite nearby',
            message:
                'Create an invite, then hold your phone near your friend\'s '
                'phone while their screen is unlocked and NFC is on. They '
                'land on the join page — no app or typing needed.',
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How many friends?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BeelsColors.ink2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StepperButton(
                      icon: Icons.remove_rounded,
                      enabled: _maxUses > 1,
                      onTap: () => setState(() => _maxUses--),
                    ),
                    Expanded(
                      child: Text(
                        '$_maxUses',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: BeelsColors.ink0,
                        ),
                      ),
                    ),
                    _StepperButton(
                      icon: Icons.add_rounded,
                      enabled: _maxUses < maxUsesLimit,
                      onTap: () => setState(() => _maxUses++),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1–20 taps before the invite is used up',
                  style: TextStyle(fontSize: 12, color: BeelsColors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Create invite',
            loading: _creating,
            onPressed: _creating ? null : _create,
          ),
        ],
      ),
    );
  }

  Widget _buildLive(BeelInvite invite) {
    final slotsLeft = _slotsLeft ?? invite.slotsLeft ?? _maxUses;
    final expired = _isExpired(invite);
    final full = slotsLeft <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: expired || full
                  ? BeelsColors.warnSoft
                  : BeelsColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  expired || full
                      ? Icons.timer_off_rounded
                      : Icons.contactless_rounded,
                  color: expired || full ? BeelsColors.warn : BeelsColors.accent,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  expired
                      ? 'Invite expired'
                      : full
                          ? 'All slots used'
                          : "Hold your phone near your friend's phone",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: BeelsColors.ink0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  expired || full
                      ? ''
                      : "Friend's screen unlocked · NFC on",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: BeelsColors.ink2),
                ),
                const SizedBox(height: 12),
                if (!expired && !full)
                  Text(
                    '$_slotsCounter • ${_expiryText(invite)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BeelsColors.ink1,
                    ),
                  )
                else
                  PrimaryButton(
                    label: 'Create a new invite',
                    loading: _closing,
                    onPressed: _closing ? null : _closeInvite,
                  ),
              ],
            ),
          ),
          if (!expired && !full) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BeelsColors.border),
                ),
                child: QrImageView(
                  data: invite.joinUrl,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy link'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareLink,
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share link'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'No NFC on their phone or app not responding? The QR and the '
              'link open the same join page.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: BeelsColors.ink2),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _closing ? null : _leave,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String get _slotsCounter {
    final left = _slotsLeft ?? _maxUses;
    return '$left of $_maxUses taps left';
  }

  bool _isExpired(BeelInvite invite) => invite.isExpired;

  String _expiryText(BeelInvite invite) {
    final expiresAt = invite.expiresAt;
    if (expiresAt == null) return 'no expiry set';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final hh = h == 0 ? '' : '${h}h ';
    return 'expires in $hh$m min ${s}s';
  }
}

/// Round +/- control for the slots stepper; disabled at the boundary.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: BeelsColors.fieldFill,
        foregroundColor: BeelsColors.ink0,
      ),
    );
  }
}