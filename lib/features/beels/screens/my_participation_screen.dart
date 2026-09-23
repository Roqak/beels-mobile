import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../controllers/beels_controllers.dart';
import '../models/contribution.dart';

/// Member-facing list of beels the signed-in user pays into
/// (GET /contributions/my-participation).
class MyParticipationScreen extends ConsumerWidget {
  const MyParticipationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participations = ref.watch(myParticipationProvider);

    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Beels I pay into'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myParticipationProvider),
          child: participations.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: const [
                SkeletonBox(height: 92),
                SizedBox(height: 12),
                SkeletonBox(height: 92),
                SizedBox(height: 12),
                SkeletonBox(height: 92),
              ],
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                ErrorView(
                  error: error is ApiException
                      ? error
                      : const ApiException('Could not load your beels.',
                          statusCode: 0),
                  onRetry: () => ref.invalidate(myParticipationProvider),
                ),
              ],
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: const [
                    SizedBox(height: 60),
                    EmptyState(
                      icon: Icons.savings_outlined,
                      title: 'Nothing yet',
                      message:
                          'You have not been added to any beel yet. Ask an '
                          'organizer to add you or join with a payment link.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ParticipationTile(participation: rows[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParticipationTile extends StatelessWidget {
  const _ParticipationTile({required this.participation});

  final Participation participation;

  @override
  Widget build(BuildContext context) {
    final next = participation.nextOccurrence;
    final last = participation.lastPaymentAt;
    final paid = participation.amountPaid ?? 0;
    final expected = participation.unitAmount ?? 0;
    final outstanding = participation.outstanding;
    final pending = participation.pendingCount ?? 0;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  participation.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(
                label: participation.status,
                kind: statusKind(participation.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatNaira(paid)} paid of ${formatNaira(expected)}'
            '${outstanding == null ? '' : ' · ${formatNaira(outstanding)} outstanding'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BeelsColors.ink1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (pending > 0) '$pending pending payment${pending == 1 ? '' : 's'}',
              if (next != null)
                'Next ${DateFormat('EEE, d MMM').format(next)}',
              if (last != null)
                'Last paid ${DateFormat('d MMM yyyy').format(last)}',
            ].join('  ·  '),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: BeelsColors.ink2),
          ),
        ],
      ),
    );
  }
}