import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/beels_repository.dart';
import '../models/invite.dart';

/// Public preview of an invite token for the friend's phone.
final invitePreviewProvider =
    FutureProvider.autoDispose.family<InvitePreview, String>((ref, token) {
  return ref.watch(beelsRepositoryProvider).previewInvite(token);
});

/// Landing screen for a join link (NFC tap or web link):
/// `https://<frontend>/join/<token>`. Works signed in or not — without a
/// session it shows the preview plus a sign-in prompt that carries the user
/// straight back here.
class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  bool _joining = false;
  InviteAcceptResult? _result;

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(authControllerProvider).valueOrNull != null;
    final preview = ref.watch(invitePreviewProvider(widget.token));

    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Join'),
      body: SafeArea(
        child: _result != null
            ? _buildSuccess(_result!)
            : preview.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(invitePreviewProvider(widget.token)),
                ),
                data: (data) => _buildPreview(data, authed),
              ),
      ),
    );
  }

  Widget _buildPreview(InvitePreview preview, bool authed) {
    if (widget.token.isEmpty) {
      return const ErrorView(
        error: ApiException('This invite link is invalid.', statusCode: 404),
      );
    }
    if (preview.slotsLeft != null && preview.slotsLeft! <= 0) {
      return EmptyState(
        icon: Icons.group_off_rounded,
        title: 'Invite full',
        message:
            'All the slots for ${preview.beelName.isEmpty ? 'this beel' : preview.beelName} '
            'have been used. Ask ${preview.organizerLabel} for a new invite.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmptyState(
            icon: Icons.celebration_rounded,
            title: 'Join ${preview.beelName.isEmpty ? 'a beel' : preview.beelName}',
            message: '${preview.organizerLabel} invited you to contribute.',
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.shareAmount != null) ...[
                  Text(
                    'Your share',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BeelsColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatNaira(preview.shareAmount!),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: BeelsColors.ink0,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _PreviewRow(
                  label: 'Beel',
                  value: preview.beelName,
                ),
                if (preview.nextOccurrence != null)
                  _PreviewRow(
                    label: 'Next contribution',
                    value: DateFormat('EEE, d MMM y').format(
                      preview.nextOccurrence!,
                    ),
                  ),
                if (preview.recurrenceType != null)
                  _PreviewRow(
                    label: 'Recurs',
                    value: _capitalize(preview.recurrenceType!),
                  ),
                if (preview.slotsLeft != null)
                  _PreviewRow(
                    label: 'Slots left',
                    value: '${preview.slotsLeft}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (authed)
            PrimaryButton(
              label: 'Join beel',
              loading: _joining,
              onPressed: _joining ? null : _accept,
            )
          else ...[
            PrimaryButton(
              label: 'Sign in to join',
              icon: Icons.login_rounded,
              onPressed: () =>
                  context.push('/login?next=/join/${widget.token}'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/register?next=/join/${widget.token}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Create an account'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _joining = true);
    try {
      final result = await ref
          .read(beelsRepositoryProvider)
          .acceptInvite(widget.token);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) _showSnack(error.message, isError: true);
    } on Object catch (_) {
      if (mounted) {
        _showSnack('Something went wrong. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Widget _buildSuccess(InviteAcceptResult result) {
    final name =
        result.beelName.isEmpty ? 'the beel' : result.beelName;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: BeelsColors.okSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.check_rounded, color: BeelsColors.ok, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              "You're in!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: BeelsColors.ink0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have joined $name.'
              '${result.unitAmount == null ? '' : ' Your share: ${formatNaira(result.unitAmount!)}.'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: BeelsColors.ink1,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Go to Beels',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
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
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: BeelsColors.ink2,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BeelsColors.ink0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}