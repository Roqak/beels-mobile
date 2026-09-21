import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/money.dart';
import 'package:beels_mobile/core/theme.dart';
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
      backgroundColor: BeelsColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/beels/new');
        },
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
                loading: () => const _DashboardSkeleton(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: ErrorView(
                    error: error is ApiException
                        ? error
                        : ApiException(error.toString(), statusCode: 0),
                    onRetry: () => ref.invalidate(dashboardControllerProvider),
                  ),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _HeroPanel(analytics: data.analytics),
                    const SizedBox(height: 12),
                    _CounterRow(analytics: data.analytics),
                    const SizedBox(height: 28),
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
                      SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < data.recent.items.length;
                                i++) ...[
                              if (i > 0)
                                const Divider(indent: 68, endIndent: 16),
                              _TransactionRow(data.recent.items[i]),
                            ],
                          ],
                        ),
                      ),
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

  static String _tagline() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning. Here is where you stand.';
    if (h < 17) return 'Good afternoon. Here is where you stand.';
    return 'Good evening. Here is where you stand.';
  }

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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: BeelsColors.ink0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _tagline(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BeelsColors.ink2),
              ),
            ],
          ),
        ),
        Pressable(
          onTap: () => context.push('/profile'),
          haptic: true,
          semanticLabel: 'Profile',
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BeelsColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: theme.textTheme.labelLarge?.copyWith(
                color: BeelsColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _tabular = [FontFeature.tabularFigures()];

/// The one committed-color surface on the screen: total deposited, with
/// withdrawn as a quiet secondary line.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.analytics});

  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: BeelsColors.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.south_west_rounded,
                  size: 16, color: Color(0xCCFFFFFF)),
              const SizedBox(width: 6),
              Text(
                'Total Deposited',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatNaira(analytics.totalDeposited),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: Colors.white,
                fontFeatures: _tabular,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.north_east_rounded,
                    size: 16, color: Color(0xCCFFFFFF)),
                const SizedBox(width: 8),
                Text(
                  'Total Withdrawn',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                Text(
                  formatNaira(analytics.totalWithdrawn),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({required this.analytics});

  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();
    return Row(
      children: [
        Expanded(
          child: _Counter(
            title: 'Beels',
            value: compact.format(analytics.totalContributions),
            icon: Icons.savings_rounded,
            onTap: () => context.go('/beels'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Counter(
            title: 'Transactions',
            value: compact.format(analytics.totalTransactions),
            icon: Icons.receipt_long_rounded,
            onTap: () => context.go('/transactions'),
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BeelsColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: BeelsColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: BeelsColors.ink0,
                      fontFeatures: _tabular,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BeelsColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final label = row.txnLabel ?? (incoming ? 'Deposit' : 'Withdrawal');
    final date = row.txnDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: incoming ? BeelsColors.okSoft : BeelsColors.errSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: incoming ? BeelsColors.ok : BeelsColors.err,
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: BeelsColors.ink0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? row.txnType
                      : DateFormat('d MMM yyyy').format(date),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: BeelsColors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatNairaSigned(row.txnAmount, incoming: incoming),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: incoming ? BeelsColors.ok : BeelsColors.err,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout-matched placeholder shown while the dashboard loads.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonScope(
      child: Padding(
        padding: EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 156, radius: 24),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 66, radius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 66, radius: 16)),
              ],
            ),
            SizedBox(height: 28),
            SkeletonBox(width: 150, height: 18),
            SizedBox(height: 12),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [SkeletonRow(), SkeletonRow(), SkeletonRow()],
              ),
            ),
          ],
        ),
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
