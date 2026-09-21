import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../controllers/beels_controllers.dart';
import '../models/contribution.dart';

/// Detail screen for a single beel: header, contributors, beneficiaries,
/// and organizer actions (cancel / retry / share payment link).
class BeelDetailScreen extends ConsumerStatefulWidget {
  const BeelDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<BeelDetailScreen> createState() => _BeelDetailScreenState();
}

class _BeelDetailScreenState extends ConsumerState<BeelDetailScreen> {
  final Set<String> _busyActions = {};

  bool _isBusy(String key) => _busyActions.contains(key);

  Future<void> _runAction(String key, Future<void> Function() action) async {
    if (_isBusy(key)) return;
    setState(() => _busyActions.add(key));
    try {
      await action();
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } on Object catch (error) {
      _showSnack('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyActions.remove(key));
      }
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB23A3A) : const Color(0xFF1F7A4D),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB23A3A),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(beelDetailControllerProvider(widget.id));

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFE),
      appBar: const BeelsAppBar('Beel'),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<Contribution> state) {
    if (!state.hasValue) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ErrorView(
        error: _toApiException(state.error!),
        onRetry: () =>
            ref.invalidate(beelDetailControllerProvider(widget.id)),
      );
    }

    final beel = state.requireValue;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(beelDetailControllerProvider(widget.id).notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(beel: beel),
            const SizedBox(height: 16),
            _buildActionsBar(beel),
            const SizedBox(height: 16),
            SectionHeader('Contributors',
                action: Text('${beel.contributors.length}')),
            ...beel.contributors.map(
              (contributor) => _ContributorTile(
                contributor: contributor,
                busy: _isBusy('remove_${contributor.id}'),
                onRemove: contributor.id == null
                    ? null
                    : () async {
                        final confirmed = await _confirm(
                          title: 'Remove contributor',
                          message:
                              'Remove ${contributor.fullName} from this beel?',
                          confirmLabel: 'Remove',
                        );
                        if (!confirmed) return;
                        await _runAction(
                          'remove_${contributor.id}',
                          () => ref
                              .read(
                                  beelDetailControllerProvider(widget.id)
                                      .notifier)
                              .removeContributor(contributor.id!),
                        );
                      },
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader('Beneficiaries',
                action: Text('${beel.beneficiaries.length}')),
            ...beel.beneficiaries.map(
              (beneficiary) => _BeneficiaryTile(
                beneficiary: beneficiary,
                busy: _isBusy('disburse_${beneficiary.id}'),
                onDisburse: beneficiary.id == null
                    ? null
                    : () async {
                        final confirmed = await _confirm(
                          title: 'Disburse',
                          message:
                              'Disburse to ${beneficiary.name}? This transfers the funds out of the beel.',
                          confirmLabel: 'Disburse',
                        );
                        if (!confirmed) return;
                        await _runAction(
                          'disburse_${beneficiary.id}',
                          () => ref
                              .read(
                                  beelDetailControllerProvider(widget.id)
                                      .notifier)
                              .disburse(beneficiary.id!),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsBar(Contribution beel) {
    final canCancel = beel.status == 'active';
    final canRetry = beel.status == 'failed';
    final canShare = beel.isOpenLink && beel.paymentLinkToken != null;
    if (!canCancel && !canRetry && !canShare) return const SizedBox.shrink();

    final actions = <Widget>[
      if (canCancel)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBusy('cancel')
                ? null
                : () async {
                    final confirmed = await _confirm(
                      title: 'Cancel beel',
                      message:
                          'Cancel "${beel.name}"? Future contributions will stop.',
                      confirmLabel: 'Cancel beel',
                    );
                    if (!confirmed) return;
                    await _runAction(
                      'cancel',
                      () => ref
                          .read(beelDetailControllerProvider(widget.id)
                              .notifier)
                          .cancelBeel(),
                    );
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB23A3A),
              side: const BorderSide(color: Color(0xFFB23A3A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancel Beel'),
          ),
        ),
      if (canRetry)
        Expanded(
          child: PrimaryButton(
            label: 'Retry',
            loading: _isBusy('retry'),
            onPressed: () => _runAction(
              'retry',
              () => ref
                  .read(beelDetailControllerProvider(widget.id).notifier)
                  .retry(),
            ),
          ),
        ),
      if (canShare) ...[
        if (canCancel || canRetry) const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton(
            label: 'Share link',
            icon: Icons.ios_share,
            onPressed: () =>
                Share.share(beel.paymentLink, subject: 'Join my beel'),
          ),
        ),
      ],
    ];

    return Row(children: actions);
  }
}

ApiException _toApiException(Object error) =>
    error is ApiException ? error : ApiException('$error', statusCode: 0);

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.beel});

  final Contribution beel;

  @override
  Widget build(BuildContext context) {
    final nextOccurrence = beel.nextOccurrence == null
        ? null
        : DateFormat('d MMM, yyyy').format(beel.nextOccurrence!);
    final cancelledAt = beel.cancelledAt == null
        ? null
        : DateFormat('d MMM, yyyy').format(beel.cancelledAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  beel.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF21222D),
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: beel.isOpenLink
                      ? const Color(0xFFEEEDFB)
                      : const Color(0xFFF4F4F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  beel.isOpenLink ? 'Open link' : 'Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: beel.isOpenLink
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF5B5D6B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusChip(label: beel.status, kind: statusKind(beel.status)),
              if (cancelledAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Cancelled $cancelledAt',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFFB23A3A)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _amountsLine(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF21222D),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            recurrenceLabel(beel) +
                (nextOccurrence == null ? '' : '  ·  Next: $nextOccurrence'),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF5B5D6B)),
          ),
          if (beel.isOpenLink && beel.amountPerContributor != null) ...[
            const SizedBox(height: 4),
            Text(
              '${formatNaira(beel.amountPerContributor!)} per contributor',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF5B5D6B)),
            ),
          ],
        ],
      ),
    );
  }

  String _amountsLine() {
    final unit = beel.unitAmount;
    final total = beel.totalAmount;
    if (unit != null && total != null && unit != total) {
      return '${formatNaira(unit)} per unit  ·  ${formatNaira(total)} total';
    }
    if (total != null) return '${formatNaira(total)} total';
    if (unit != null) return '${formatNaira(unit)} per unit';
    return '';
  }
}

class _ContributorTile extends StatelessWidget {
  const _ContributorTile({
    required this.contributor,
    required this.busy,
    required this.onRemove,
  });

  final ContributionContributor contributor;
  final bool busy;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final unit = contributor.unitAmount ?? 0;
    final paid = contributor.amountPaid ?? 0;
    final progress = unit <= 0 ? 0.0 : (paid / unit).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contributor.fullName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF21222D),
                            ),
                      ),
                    ),
                    StatusChip(
                      label: contributor.status,
                      kind: statusKind(contributor.status),
                    ),
                  ],
                ),
                if (contributor.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    contributor.email,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFF7B7D8C)),
                  ),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF4F4F8),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatNaira(paid)} paid of ${formatNaira(unit)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF5B5D6B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove contributor',
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_remove_outlined, size: 20),
            color: const Color(0xFFB23A3A),
            onPressed: busy ? null : onRemove,
          ),
        ],
      ),
    );
  }
}

class _BeneficiaryTile extends StatelessWidget {
  const _BeneficiaryTile({
    required this.beneficiary,
    required this.busy,
    required this.onDisburse,
  });

  final BeelBeneficiary beneficiary;
  final bool busy;
  final VoidCallback? onDisburse;

  @override
  Widget build(BuildContext context) {
    final detail = beneficiary.accountNumber != null
        ? '${beneficiary.accountNumber}'
            '${beneficiary.bankCode == null ? '' : ' · ${beneficiary.bankCode}'}'
        : beneficiary.serviceNumber ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beneficiary.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF21222D),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.isEmpty
                      ? beneficiary.typeLabel
                      : '${beneficiary.typeLabel}${detail.isEmpty ? '' : '  ·  $detail'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF7B7D8C)),
                ),
              ],
            ),
          ),
          if (beneficiary.amount != null) ...[
            Text(
              formatNaira(beneficiary.amount!),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF21222D),
                  ),
            ),
            const SizedBox(width: 12),
          ],
          if (beneficiary.status != 'settled' && onDisburse != null)
            OutlinedButton(
              onPressed: busy ? null : onDisburse,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Disburse'),
            )
          else
            StatusChip(
              label: beneficiary.status,
              kind: statusKind(beneficiary.status),
            ),
        ],
      ),
    );
  }
}