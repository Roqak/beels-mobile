import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:beels_mobile/core/theme.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../controllers/transactions_controllers.dart';
import '../models/transaction.dart';

/// Tab screen listing the user's transaction history with infinite scroll
/// and expandable rows.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _TxFilter { all, deposits, withdrawals }

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  _TxFilter _filter = _TxFilter.all;

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
    if (list.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(transactionsListControllerProvider.notifier).refresh(),
        child: ListView(
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
        ),
      );
    }

    final visible = list.items.where((t) {
      switch (_filter) {
        case _TxFilter.all:
          return true;
        case _TxFilter.deposits:
          return t.isDeposit;
        case _TxFilter.withdrawals:
          return !t.isDeposit;
      }
    }).toList();

    // Flat entries: DateTime header markers (as String) and transactions.
    final entries = <Object>[];
    String? lastLabel;
    for (final t in visible) {
      final label = _dayLabel(t.createdAt);
      if (label != lastLabel) {
        entries.add(label);
        lastLabel = label;
      }
      entries.add(t);
    }

    return Column(
      children: [
        FilterChipBar<_TxFilter>(
          value: _filter,
          options: const [
            FilterOption(_TxFilter.all, 'All'),
            FilterOption(_TxFilter.deposits, 'Deposits'),
            FilterOption(_TxFilter.withdrawals, 'Withdrawals'),
          ],
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: RefreshIndicator(
            color: BeelsColors.accent,
            onRefresh: () =>
                ref.read(transactionsListControllerProvider.notifier).refresh(),
            child: visible.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.filter_list_rounded,
                        title: _filter == _TxFilter.deposits
                            ? 'No deposits loaded'
                            : 'No withdrawals loaded',
                        message:
                            'Nothing of this kind in the activity loaded so far.',
                        actionLabel: list.hasMore ? 'Load more' : null,
                        onAction: () => ref
                            .read(transactionsListControllerProvider.notifier)
                            .loadMore(),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: entries.length + (list.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= entries.length) {
                        // A filtered list can be too short to scroll, which
                        // would never trigger infinite scroll: offer a button.
                        if (_filter != _TxFilter.all) {
                          return Center(
                            child: TextButton(
                              onPressed: () => ref
                                  .read(transactionsListControllerProvider
                                      .notifier)
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
                      final entry = entries[index];
                      if (entry is String) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                              4, index == 0 ? 8 : 20, 4, 10),
                          child: Text(
                            entry,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: BeelsColors.ink2,
                            ),
                          ),
                        );
                      }
                      final t = entry as Transaction;
                      return TransactionTile(
                        key: ValueKey(t.id),
                        transaction: t,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  static String _dayLabel(DateTime? when) {
    if (when == null) return 'Undated';
    final d = when.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(d.year == now.year ? 'EEE, d MMM' : 'd MMM yyyy')
        .format(d);
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

    final deposit = transaction.isDeposit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: deposit ? BeelsColors.okSoft : BeelsColors.errSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    deposit
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    size: 19,
                    color: deposit ? BeelsColors.ok : BeelsColors.err,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deposit ? 'Deposit' : 'Withdrawal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: deposit ? BeelsColors.ok : BeelsColors.err,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        transaction.beelName == null ||
                                transaction.beelName!.isEmpty
                            ? (deposit ? 'Deposit' : 'Withdrawal')
                            : transaction.beelName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: BeelsColors.ink0,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${transaction.reference ?? 'No reference'}  ·  $date',
                        maxLines: 2,
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
                        incoming: deposit,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: deposit ? BeelsColors.ok : BeelsColors.ink0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusChip(
                      label: transaction.status,
                      kind: statusKind(transaction.status),
                    ),
                  ],
                ),
              ],
            ),
            if (_expanded) ...[
              Divider(height: 20, color: BeelsColors.border),
              _referenceRow(transaction.reference == null ||
                      transaction.reference!.isEmpty
                  ? '—'
                  : transaction.reference!),
              _detailRow(
                  'Beel',
                  transaction.beelName == null || transaction.beelName!.isEmpty
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
    );
  }

  Widget _referenceRow(String value) {
    final copyable = value != '\u2014';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              'Reference',
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
          if (copyable)
            IconButton(
              tooltip: 'Copy reference',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon:
                  Icon(Icons.copy_rounded, size: 18, color: BeelsColors.accent),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Reference copied')),
                  );
              },
            ),
        ],
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
