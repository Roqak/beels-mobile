import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/money.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/dashboard/data/dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).valueOrNull;
    final dashboard = ref.watch(dashboardControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFE),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/beels/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Beel'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _GreetingHeader(profile: profile),
              dashboard.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 96),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: ErrorView(
                    error: error is ApiException
                        ? error
                        : ApiException(error.toString(), statusCode: 0),
                    onRetry: () =>
                        ref.invalidate(dashboardControllerProvider),
                  ),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _StatGrid(analytics: data.analytics),
                    const SizedBox(height: 20),
                    SectionHeader(
                      'Recent transactions',
                      action: TextButton(
                        onPressed: () => context.go('/transactions'),
                        child: const Text('View all'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (data.recent.items.isEmpty)
                      const _NoTransactions()
                    else
                      ...data.recent.items.map(_TransactionRow.new),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = profile?.firstName ?? '';
    final initials = profile?.initials ?? '?';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isEmpty ? 'Hello' : 'Hello, $firstName',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Here is how your money is doing.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF7B7D8C)),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEEEDFB),
            child: Text(
              initials,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.analytics});

  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Deposited',
                value: formatNaira(analytics.totalDeposited),
                icon: Icons.south_west,
                color: const Color(0xFF1F7A4D),
                background: const Color(0xFFEAF6F0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Total Withdrawn',
                value: formatNaira(analytics.totalWithdrawn),
                icon: Icons.north_east,
                color: const Color(0xFFB23A3A),
                background: const Color(0xFFFBEDED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Beels',
                value: compact.format(analytics.totalContributions),
                icon: Icons.savings,
                color: const Color(0xFF4F46E5),
                background: const Color(0xFFEEEDFB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Transactions',
                value: compact.format(analytics.totalTransactions),
                icon: Icons.receipt_long,
                color: const Color(0xFF5B5D6B),
                background: const Color(0xFFF7F7FA),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF21222D),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF7B7D8C)),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.row);

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incoming = row.isIncoming;
    final label = row.txnLabel ??
        (incoming ? 'Deposit' : 'Withdrawal');
    final date = row.txnDate;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: incoming
                  ? const Color(0xFFEAF6F0)
                  : const Color(0xFFFBEDED),
              shape: BoxShape.circle,
            ),
            child: Icon(
              incoming ? Icons.south_west : Icons.north_east,
              size: 16,
              color: incoming
                  ? const Color(0xFF1F7A4D)
                  : const Color(0xFFB23A3A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  date == null
                      ? row.txnType
                      : DateFormat('d MMM yyyy').format(date),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF9DA0AE)),
                ),
              ],
            ),
          ),
          Text(
            formatNairaSigned(row.txnAmount, incoming: incoming),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: incoming
                  ? const Color(0xFF1F7A4D)
                  : const Color(0xFFB23A3A),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTransactions extends StatelessWidget {
  const _NoTransactions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        message: 'Your deposits and withdrawals will show up here.',
      ),
    );
  }
}