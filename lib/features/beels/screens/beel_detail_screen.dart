import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../payments/data/payments_repository.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/controllers/session_lock_controller.dart';
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
      HapticFeedback.mediumImpact();
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

  /// Starts a Flutterwave checkout for the contributor's deposit and hands
  /// the hosted link to the system share sheet (opens in any browser).
  Future<void> _pay(ContributionContributor contributor) async {
    final paymentId = contributor.paymentId;
    if (paymentId == null) return;
    await _runAction('pay_$paymentId', () async {
      final url = await ref
          .read(paymentsRepositoryProvider)
          .initializePayment(paymentId);
      if (url.isEmpty) {
        throw const ApiException('Payment link unavailable. Try again.',
            statusCode: 0);
      }
      await Share.share(url, subject: 'Complete your Beels payment');
      await ref
          .read(beelDetailControllerProvider(widget.id).notifier)
          .refresh();
    });
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
              foregroundColor: BeelsColors.err,
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
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Beel'),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<Contribution> state) {
    if (!state.hasValue) {
      if (state.isLoading) {
        return const _DetailSkeleton();
      }
      return ErrorView(
        error: _toApiException(state.error!),
        onRetry: () => ref.invalidate(beelDetailControllerProvider(widget.id)),
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
            const SizedBox(height: 24),
            SectionHeader('Contributors',
                action: _CountBadge(beel.contributors.length)),
            if (beel.contributors.isEmpty)
              const _SectionEmpty('No contributors yet.'),
            ...beel.contributors.map(
              (contributor) => _ContributorTile(
                contributor: contributor,
                busy: _isBusy('remove_${contributor.id}'),
                payBusy: contributor.paymentId == null
                    ? false
                    : _isBusy('pay_${contributor.paymentId}'),
                onPay: contributor.canPay ? () => _pay(contributor) : null,
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
                              .read(beelDetailControllerProvider(widget.id)
                                  .notifier)
                              .removeContributor(contributor.id!),
                        );
                      },
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader('Beneficiaries',
                action: _CountBadge(beel.beneficiaries.length)),
            if (beel.beneficiaries.isEmpty)
              const _SectionEmpty('No beneficiaries.'),
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
                        final verified = await ref
                            .read(sessionLockControllerProvider.notifier)
                            .confirmSensitive('Confirm to disburse funds');
                        if (!verified) {
                          _showSnack('Verification cancelled.', isError: true);
                          return;
                        }
                        await _runAction(
                          'disburse_${beneficiary.id}',
                          () => ref
                              .read(beelDetailControllerProvider(widget.id)
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
                          .read(
                              beelDetailControllerProvider(widget.id).notifier)
                          .cancelBeel(),
                    );
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: BeelsColors.err,
              side: BorderSide(color: BeelsColors.err),
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

    final collected =
        beel.contributors.fold<num>(0, (sum, c) => sum + (c.amountPaid ?? 0));
    final expected =
        beel.contributors.fold<num>(0, (sum, c) => sum + (c.unitAmount ?? 0));
    final slots = [
      for (final c in beel.contributors)
        RotaSlot((c.unitAmount ?? 0) <= 0
            ? 0
            : ((c.amountPaid ?? 0) / c.unitAmount!).clamp(0.0, 1.0).toDouble()),
    ];
    final paidCount = slots.where((s) => s.fraction >= 1).length;
    final onDark = Colors.white.withOpacity(0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
          const Positioned.fill(child: AdirePattern()),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        beel.name,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        beel.isOpenLink ? 'Open link' : 'Closed',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    StatusChip(
                        label: beel.status, kind: statusKind(beel.status)),
                    if (cancelledAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Cancelled $cancelledAt',
                        style: TextStyle(fontSize: 12, color: onDark),
                      ),
                    ],
                  ],
                ),
                if (expected > 0) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      RotaRing(
                        slots: slots,
                        size: 132,
                        stroke: 11,
                        trackColor: Colors.white.withOpacity(0.16),
                        paidColor: BeelsColors.turmeric,
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$paidCount/${slots.length}',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'paid',
                              style: TextStyle(fontSize: 12, color: onDark),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Collected',
                              style: TextStyle(fontSize: 13, color: onDark),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: AnimatedNaira(
                                collected,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                  color: Colors.white,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'of ${formatNaira(expected)}',
                              style: TextStyle(fontSize: 13, color: onDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.14)),
                const SizedBox(height: 14),
                Text(
                  _amountsLine(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recurrenceLabel(beel) +
                      (nextOccurrence == null
                          ? ''
                          : '  ·  Next: $nextOccurrence'),
                  style: TextStyle(fontSize: 13, color: onDark),
                ),
                if (beel.isOpenLink && beel.amountPerContributor != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${formatNaira(beel.amountPerContributor!)} per contributor',
                    style: TextStyle(fontSize: 13, color: onDark),
                  ),
                ],
              ],
            ),
          ),
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
    required this.payBusy,
    required this.onPay,
    required this.onRemove,
  });

  final ContributionContributor contributor;
  final bool busy;
  final bool payBusy;
  final VoidCallback? onPay;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final unit = contributor.unitAmount ?? 0;
    final paid = contributor.amountPaid ?? 0;
    final progress = unit <= 0 ? 0.0 : (paid / unit).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BeelsColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(contributor.fullName),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BeelsColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contributor.fullName,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: BeelsColors.ink0,
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
                          ?.copyWith(color: BeelsColors.ink2),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: BeelsColors.fieldFill,
                      valueColor: AlwaysStoppedAnimation(BeelsColors.accent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatNaira(paid)} paid of ${formatNaira(unit)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BeelsColors.ink1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (onPay != null)
                        TextButton(
                          onPressed: payBusy ? null : onPay,
                          child: payBusy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Pay now'),
                        ),
                    ],
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
                  : const Icon(Icons.person_remove_outlined, size: 22),
              color: BeelsColors.err,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: busy ? null : onRemove,
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
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

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
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
                          color: BeelsColors.ink0,
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
                        ?.copyWith(color: BeelsColors.ink2),
                  ),
                ],
              ),
            ),
            if (beneficiary.amount != null) ...[
              Text(
                formatNaira(beneficiary.amount!),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: BeelsColors.ink0,
                    ),
              ),
              const SizedBox(width: 12),
            ],
            if (beneficiary.status != 'settled' && onDisburse != null)
              OutlinedButton(
                onPressed: busy ? null : onDisburse,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BeelsColors.accent,
                  side: BorderSide(color: BeelsColors.accent),
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
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: BeelsColors.fieldFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: BeelsColors.ink1,
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SurfaceCard(
        color: BeelsColors.surfaceAlt,
        child: Text(
          message,
          style: TextStyle(fontSize: 14, color: BeelsColors.ink2),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonScope(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 190, radius: 16),
            SizedBox(height: 24),
            SkeletonBox(width: 120, height: 18),
            SizedBox(height: 12),
            SkeletonBox(height: 96, radius: 16),
            SizedBox(height: 10),
            SkeletonBox(height: 96, radius: 16),
          ],
        ),
      ),
    );
  }
}
