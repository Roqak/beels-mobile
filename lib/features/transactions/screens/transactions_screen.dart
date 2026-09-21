import 'package:flutter/material.dart';

import 'package:beels_mobile/core/theme.dart';
import 'package:beels_mobile/core/widgets/skeleton.dart';
import 'package:beels_mobile/core/widgets/surface_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../controllers/transactions_controllers.dart';
import '../models/transaction.dart';

/// Tab screen listing the user's transaction history with infinite scroll
/// and expandable rows.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
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
      ref.read(transactionsListControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsListControllerProvider);

    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Transactions'),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(
      BuildContext context, AsyncValue<TransactionsListState> state) {
    if (!state.hasValue) {
      if (state.isLoading) {
        return const _ListSkeleton();
      }
      return KeyedSubtree(
        key: const Key('error-view'),
        child: ErrorView(
          error: _toApiException(state.error!),
          onRetry: () => ref.invalidate(transactionsListControllerProvider),
        ),
      );
    }

    final list = state.requireValue;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(transactionsListControllerProvider.notifier).refresh(),
      child: list.items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                KeyedSubtree(
                  key: Key('empty-state'),
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message:
                        'Payments and disbursements will appear here once activity starts.',
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                return TransactionTile(
                  key: ValueKey(list.items[index].id),
                  transaction: list.items[index],
                );
              },
            ),
    );
  }
}

ApiException _toApiException(Object error) =>
    error is ApiException ? error : ApiException('$error', statusCode: 0);

/// One transaction row; tapping toggles the detail card.
class TransactionTile extends StatefulWidget {
  const TransactionTile({super.key, required this.transaction});

  final Transaction transaction;

  @override
  State<TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<TransactionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final date = transaction.createdAt == null
        ? '—'
        : DateFormat('d MMM, yyyy · HH:mm')
            .format(transaction.createdAt!.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BeelsColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeBadge(isDeposit: transaction.isDeposit),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.beelName == null ||
                                    transaction.beelName!.isEmpty
                                ? (transaction.isDeposit
                                    ? 'Deposit'
                                    : 'Withdrawal')
                                : transaction.beelName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: BeelsColors.ink0,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${transaction.reference ?? 'No reference'}  ·  $date',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: BeelsColors.ink2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatNairaSigned(
                            transaction.amount ?? 0,
                            incoming: transaction.isDeposit,
                          ),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: transaction.isDeposit
                                        ? BeelsColors.ok
                                        : BeelsColors.ink0,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        StatusChip(
                          label: transaction.status,
                          kind: statusKind(transaction.status),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const Divider(height: 20, color: BeelsColors.border),
                  _detailRow(
                      'Reference',
                      transaction.reference == null ||
                              transaction.reference!.isEmpty
                          ? '—'
                          : transaction.reference!),
                  _detailRow(
                      'Beel',
                      transaction.beelName == null ||
                              transaction.beelName!.isEmpty
                          ? '—'
                          : transaction.beelName!),
                  _detailRow(
                      'Unit Amount',
                      transaction.unitAmount == null
                          ? '—'
                          : formatNaira(transaction.unitAmount!)),
                  _detailRow(
                      'Total Amount',
                      transaction.totalAmount == null
                          ? '—'
                          : formatNaira(transaction.totalAmount!)),
                  _detailRow(
                      'Amount',
                      transaction.amount == null
                          ? '—'
                          : formatNaira(transaction.amount!)),
                  _detailRow('Status',
                      transaction.status.isEmpty ? '—' : transaction.status),
                  _detailRow('Date', date),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: BeelsColors.ink2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: BeelsColors.ink0),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isDeposit});

  final bool isDeposit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDeposit ? BeelsColors.okSoft : BeelsColors.errSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isDeposit ? 'Deposit' : 'Withdrawal',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDeposit ? BeelsColors.ok : BeelsColors.err,
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonScope(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
            ],
          ),
        ),
      ),
    );
  }
}
