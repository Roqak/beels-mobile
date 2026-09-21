import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/features/auth/widgets/biometric_offer.dart';
import 'package:beels_mobile/core/money.dart';
import 'package:beels_mobile/core/theme.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:beels_mobile/features/auth/controllers/auth_controller.dart';
import 'package:beels_mobile/features/auth/models/profile.dart';
import 'package:beels_mobile/features/beels/controllers/beels_controllers.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/dashboard/data/dashboard_repository.dart';

/// Active beels with a known next date, soonest first (max 3). Empty until
/// the beels list has loaded; failures degrade to "nothing upcoming".
final upcomingBeelsProvider = Provider<AsyncValue<List<Contribution>>>((ref) {
  return ref.watch(beelsListControllerProvider).whenData((list) {
    final rows = list.items
        .where((b) => b.nextOccurrence != null && b.status == 'active')
        .toList()
      ..sort((a, b) => a.nextOccurrence!.compareTo(b.nextOccurrence!));
    return rows.take(3).toList();
  });
});

const _tabular = [FontFeature.tabularFigures()];

/// Privacy toggle: masks money on Home. Persisted on the device.
class HideBalancesController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final saved = await ref.read(preferencesStoreProvider).hideBalances();
    if (saved != state) state = saved;
  }

  void toggle() {
    state = !state;
    ref.read(preferencesStoreProvider).setHideBalances(state);
  }
}

final hideBalancesProvider =
    NotifierProvider<HideBalancesController, bool>(HideBalancesController.new);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).valueOrNull;
    final dashboard = ref.watch(dashboardControllerProvider);
    final upcoming = ref.watch(upcomingBeelsProvider);
    final hidden = ref.watch(hideBalancesProvider);
    final beelsLoaded = ref.watch(beelsListControllerProvider).valueOrNull;
    final noBeels = beelsLoaded != null && beelsLoaded.items.isEmpty;

    return Scaffold(
      backgroundColor: BeelsColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/beels/new');
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Beel'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: BeelsColors.accent,
          onRefresh: () async {
            ref.invalidate(beelsListControllerProvider);
            await ref.read(dashboardControllerProvider.notifier).refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
            children: [
              const BiometricOfferTrigger(),
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
                    _HeroPanel(
                      analytics: data.analytics,
                      hidden: hidden,
                      onToggleHidden: () {
                        HapticFeedback.selectionClick();
                        ref.read(hideBalancesProvider.notifier).toggle();
                      },
                    ),
                    ..._comingUp(context, upcoming, noBeels: noBeels),
                    const SizedBox(height: 32),
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

  List<Widget> _comingUp(
    BuildContext context,
    AsyncValue<List<Contribution>> upcoming, {
    required bool noBeels,
  }) {
    if (noBeels) {
      return [
        const SizedBox(height: 32),
        const SectionHeader('Get started'),
        const SizedBox(height: 12),
        const _FirstBeelCard(),
      ];
    }
    final rows = upcoming.valueOrNull;
    if (rows == null || rows.isEmpty) return const [];
    return [
      const SizedBox(height: 32),
      const SectionHeader('Coming up'),
      const SizedBox(height: 12),
      _NextUpCard(beel: rows.first),
      if (rows.length > 1) ...[
        const SizedBox(height: 10),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 1; i < rows.length; i++) ...[
                if (i > 1) const Divider(indent: 16, endIndent: 16),
                _UpcomingRow(beel: rows[i]),
              ],
            ],
          ),
        ),
      ],
    ];
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
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
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
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BeelsColors.dye,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Drenched dye surface with the adire motif field. Deposited total is the
/// focus; withdrawn reads as a share of it; counters link to their tabs.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.analytics,
    required this.hidden,
    required this.onToggleHidden,
  });

  final DashboardAnalytics analytics;
  final bool hidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();
    final deposited = analytics.totalDeposited;
    final share = deposited <= 0
        ? 0.0
        : (analytics.totalWithdrawn / deposited).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutQuart,
              builder: (_, t, __) => AdirePattern(progress: t),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total Deposited',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                    const Spacer(),
                    Pressable(
                      onTap: onToggleHidden,
                      semanticLabel: hidden ? 'Show balances' : 'Hide balances',
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _Money(
                    deposited,
                    hidden: hidden,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 46,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                      color: Colors.white,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text(
                      'Total Withdrawn',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hidden
                          ? '\u20A6 \u2022\u2022\u2022\u2022'
                          : formatNaira(analytics.totalWithdrawn),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutQuart,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.16),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.14),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _HeroCounter(
                        value: compact.format(analytics.totalContributions),
                        label: 'Beels',
                        onTap: () => context.go('/beels'),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: Colors.white.withOpacity(0.14),
                    ),
                    Expanded(
                      child: _HeroCounter(
                        value: compact.format(analytics.totalTransactions),
                        label: 'Transactions',
                        onTap: () => context.go('/transactions'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Naira amount that counts up, or a mask when balances are hidden.
class _Money extends StatelessWidget {
  const _Money(this.value, {required this.hidden, required this.style});

  final num value;
  final bool hidden;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return Text('\u20A6 \u2022\u2022\u2022\u2022\u2022\u2022',
          maxLines: 1, style: style);
    }
    return AnimatedNaira(value, style: style);
  }
}

class _FirstBeelCard extends StatelessWidget {
  const _FirstBeelCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BeelsColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.savings_rounded, color: BeelsColors.accent),
          ),
          const SizedBox(height: 14),
          Text(
            'Start your first beel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: BeelsColors.ink0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Collect contributions from friends, family or a group, on a schedule you choose.',
            style:
                TextStyle(fontSize: 14, height: 1.45, color: BeelsColors.ink1),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/beels/new');
            },
            child: const Text('Create a beel'),
          ),
        ],
      ),
    );
  }
}

class _HeroCounter extends StatelessWidget {
  const _HeroCounter({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
                fontFeatures: _tabular,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date tile: the one place turmeric appears on Home.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, this.large = true});

  final DateTime date;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 60.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BeelsColors.turmeric,
        borderRadius: BorderRadius.circular(large ? 18 : 14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: TextStyle(
              fontSize: large ? 11 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: BeelsColors.dye.withOpacity(0.75),
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: large ? 24 : 17,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: BeelsColors.dye,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.beel});

  final Contribution beel;

  @override
  Widget build(BuildContext context) {
    final date = beel.nextOccurrence!;
    final amount = beel.unitAmount ?? beel.totalAmount;
    return Pressable(
      onTap: beel.id == null ? null : () => context.push('/beels/${beel.id}'),
      haptic: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BeelsColors.turmericSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _DateTile(date: date),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: BeelsColors.turmericInk.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    beel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: BeelsColors.ink0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recurrenceLabel(beel),
                    style:
                        TextStyle(fontSize: 13, color: BeelsColors.turmericInk),
                  ),
                ],
              ),
            ),
            if (amount != null)
              Text(
                formatNaira(amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: BeelsColors.ink0,
                  fontFeatures: _tabular,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.beel});

  final Contribution beel;

  @override
  Widget build(BuildContext context) {
    final amount = beel.unitAmount ?? beel.totalAmount;
    return Pressable(
      onTap: beel.id == null ? null : () => context.push('/beels/${beel.id}'),
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _DateTile(date: beel.nextOccurrence!, large: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BeelsColors.ink0,
                    ),
                  ),
                  Text(
                    recurrenceLabel(beel),
                    style: TextStyle(fontSize: 12, color: BeelsColors.ink2),
                  ),
                ],
              ),
            ),
            if (amount != null)
              Text(
                formatNaira(amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BeelsColors.ink1,
                  fontFeatures: _tabular,
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
            SkeletonBox(height: 226, radius: 28),
            SizedBox(height: 32),
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
