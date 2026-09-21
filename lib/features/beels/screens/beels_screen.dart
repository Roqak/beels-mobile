import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../controllers/beels_controllers.dart';
import '../models/contribution.dart';

/// Tab screen listing the organizer's beels with infinite scroll.
class BeelsScreen extends ConsumerStatefulWidget {
  const BeelsScreen({super.key});

  @override
  ConsumerState<BeelsScreen> createState() => _BeelsScreenState();
}

class _BeelsScreenState extends ConsumerState<BeelsScreen> {
  final ScrollController _scrollController = ScrollController();

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
      backgroundColor: const Color(0xFFFCFCFE),
      appBar: const BeelsAppBar('Beels'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/beels/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Beel'),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<BeelsListState> state) {
    if (!state.hasValue) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
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
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(beelsListControllerProvider.notifier).refresh(),
      child: list.items.isEmpty
          ? ListView(
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
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.items.length + (list.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= list.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }
                return BeelCard(beel: list.items[index]);
              },
            ),
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
    final nextOccurrence = beel.nextOccurrence == null
        ? null
        : DateFormat('d MMM, yyyy').format(beel.nextOccurrence!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: beel.id == null ? null : () => context.push('/beels/${beel.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF21222D),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _amountSummary(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: const Color(0xFF5B5D6B)),
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
                const SizedBox(height: 8),
                Text(
                  recurrenceLabel(beel) +
                      (nextOccurrence == null
                          ? ''
                          : '  ·  Next: $nextOccurrence'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF7B7D8C)),
                ),
                if (beel.isOpenLink) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEDFB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Open link',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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