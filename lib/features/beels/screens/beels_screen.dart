import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../controllers/beels_controllers.dart';
import '../models/contribution.dart';

/// Filter id meaning "no status filter".
const _allStatuses = 'all';

/// Most useful first; anything else the backend adds follows alphabetically.
const _statusOrder = [
  'active',
  'pending',
  'processing',
  'completed',
  'failed',
  'cancelled',
];

String _statusLabel(String status) =>
    status.isEmpty ? 'Other' : status[0].toUpperCase() + status.substring(1);

/// Tab screen listing the organizer's beels with infinite scroll.
class BeelsScreen extends ConsumerStatefulWidget {
  const BeelsScreen({super.key});

  @override
  ConsumerState<BeelsScreen> createState() => _BeelsScreenState();
}

class _BeelsScreenState extends ConsumerState<BeelsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _statusFilter = _allStatuses;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(beelsListControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(beelsListControllerProvider);

    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Beels'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/beels/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Beel'),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<BeelsListState> state) {
    if (!state.hasValue) {
      if (state.isLoading) {
        return const _BeelsSkeleton();
      }
      return KeyedSubtree(
        key: const Key('error-view'),
        child: ErrorView(
          error: _toApiException(state.error!),
          onRetry: () => ref.invalidate(beelsListControllerProvider),
        ),
      );
    }

    final list = state.requireValue;
    if (list.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(beelsListControllerProvider.notifier).refresh(),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            KeyedSubtree(
              key: Key('empty-state'),
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No beels yet',
                message: 'Create a beel to start saving with others.',
              ),
            ),
          ],
        ),
      );
    }

    // Filters come from the statuses actually present, so there are never
    // empty chips. One status only means nothing to filter.
    final present = {for (final b in list.items) b.status.toLowerCase()};
    final ordered = [
      ..._statusOrder.where(present.contains),
      ...(present.difference(_statusOrder.toSet()).toList()..sort()),
    ];
    final showFilters = ordered.length >= 2;
    final filter =
        ordered.contains(_statusFilter) ? _statusFilter : _allStatuses;
    final visible = filter == _allStatuses
        ? list.items
        : list.items.where((b) => b.status.toLowerCase() == filter).toList();

    return Column(
      children: [
        if (showFilters)
          FilterChipBar<String>(
            value: filter,
            options: [
              const FilterOption(_allStatuses, 'All'),
              for (final status in ordered)
                FilterOption(status, _statusLabel(status)),
            ],
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
        Expanded(
          child: RefreshIndicator(
            color: BeelsColors.accent,
            onRefresh: () =>
                ref.read(beelsListControllerProvider.notifier).refresh(),
            child: visible.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.filter_list_rounded,
                        title:
                            'No ${_statusLabel(filter).toLowerCase()} beels loaded',
                        message:
                            'Nothing with this status in the beels loaded so far.',
                        actionLabel: list.hasMore ? 'Load more' : null,
                        onAction: () => ref
                            .read(beelsListControllerProvider.notifier)
                            .loadMore(),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        EdgeInsets.fromLTRB(16, showFilters ? 4 : 12, 16, 96),
                    itemCount: visible.length + (list.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        // A filtered list can be too short to scroll, which
                        // would never trigger infinite scroll: offer a button.
                        if (filter != _allStatuses) {
                          return Center(
                            child: TextButton(
                              onPressed: () => ref
                                  .read(beelsListControllerProvider.notifier)
                                  .loadMore(),
                              child: const Text('Load more'),
                            ),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        );
                      }
                      return BeelCard(beel: visible[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

ApiException _toApiException(Object error) =>
    error is ApiException ? error : ApiException('$error', statusCode: 0);

/// Card for one beel in the list.
class BeelCard extends StatelessWidget {
  const BeelCard({super.key, required this.beel});

  final Contribution beel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextOccurrence = beel.nextOccurrence == null
        ? null
        : DateFormat('d MMM, yyyy').format(beel.nextOccurrence!);
    final onTap =
        beel.id == null ? null : () => context.push('/beels/${beel.id}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: onTap,
        child: SurfaceCard(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: BeelsColors.dye,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.savings_rounded,
                        size: 22, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: BeelsColors.ink0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _amountSummary(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: BeelsColors.ink1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    label: beel.status,
                    kind: statusKind(beel.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event_repeat_rounded,
                      size: 15, color: BeelsColors.ink2),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      recurrenceLabel(beel) +
                          (nextOccurrence == null
                              ? ''
                              : '  ·  Next: $nextOccurrence'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: BeelsColors.ink2),
                    ),
                  ),
                  if (beel.isOpenLink) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BeelsColors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Open link',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BeelsColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _amountSummary() {
    final unit = beel.unitAmount == null
        ? '₦0'
        : '${formatNaira(beel.unitAmount!)} × ${beel.occurrences ?? 1}';
    return unit;
  }
}

class _BeelsSkeleton extends StatelessWidget {
  const _BeelsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(width: 150, height: 16),
                        Spacer(),
                        SkeletonBox(width: 70, height: 24, radius: 12),
                      ],
                    ),
                    SizedBox(height: 10),
                    SkeletonBox(width: 90, height: 14),
                    SizedBox(height: 24),
                    SkeletonBox(width: 200, height: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
