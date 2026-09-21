import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/core/api/envelope.dart';
import 'package:beels_mobile/core/api/paginated.dart';
import 'package:beels_mobile/core/providers.dart';

/// Aggregated organizer stats from `GET /analytics`.
class DashboardAnalytics {
  final num totalDeposited;
  final num totalWithdrawn;
  final num totalContributions;
  final num totalTransactions;

  const DashboardAnalytics({
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.totalContributions,
    required this.totalTransactions,
  });

  factory DashboardAnalytics.fromJson(dynamic json) {
    final map = json is Map
        ? json.cast<String, dynamic>()
        : const <String, dynamic>{};
    return DashboardAnalytics(
      totalDeposited: _toNum(map['total_deposited']),
      totalWithdrawn: _toNum(map['total_withdrawn']),
      totalContributions: _toNum(map['total_contributions']),
      totalTransactions: _toNum(map['total_transactions']),
    );
  }
}

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  /// GET /analytics
  Future<DashboardAnalytics> analytics() async {
    final res = await _api.get('/analytics');
    return envelope(res, DashboardAnalytics.fromJson);
  }

  /// GET /transactions?per_page=N — recent rows stay generic maps so the
  /// dashboard does not import the transactions feature model.
  Future<Paginated<Map<String, dynamic>>> recentTransactions({
    int page = 1,
    int perPage = 5,
  }) async {
    // The API validates `page` on /transactions; omitting it is a 400.
    final res = await _api.get(
      '/transactions',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.parse<Map<String, dynamic>>(
      res,
      (item) =>
          item is Map ? item.cast<String, dynamic>() : <String, dynamic>{},
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

class DashboardData {
  final DashboardAnalytics analytics;
  final Paginated<Map<String, dynamic>> recent;

  const DashboardData({required this.analytics, required this.recent});
}

class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  FutureOr<DashboardData> build() async {
    final repo = ref.watch(dashboardRepositoryProvider);
    final analyticsFuture = repo.analytics();
    final recentFuture = repo.recentTransactions(perPage: 5);
    return DashboardData(
      analytics: await analyticsFuture,
      recent: await recentFuture,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardData>();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(dashboardRepositoryProvider);
      final analyticsFuture = repo.analytics();
      final recentFuture = repo.recentTransactions(perPage: 5);
      return DashboardData(
        analytics: await analyticsFuture,
        recent: await recentFuture,
      );
    });
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
        DashboardController.new);

/// Accessors for rendering a raw transaction row as a compact dashboard row.
extension DashboardTransactionRow on Map<String, dynamic> {
  /// 'deposit' | 'withdrawal' (empty string when unknown).
  String get txnType => (this['type'] ?? '').toString();

  bool get isIncoming => txnType == 'deposit';

  num get txnAmount => _toNum(this['amount']);

  String get txnStatus => (this['status'] ?? '').toString();

  DateTime? get txnDate {
    final raw = this['created_at'] ?? this['createdAt'];
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  /// Beel name from deposit.contributor.contribution.name or
  /// withdrawal.contribution.name, else the transaction reference.
  String? get txnLabel {
    return _firstString([
      _pick(this['deposit'], 'contributor', 'contribution', 'name'),
      _pick(this['withdrawal'], 'contribution', 'name'),
      _pick(this['deposit'], 'transaction_reference'),
      _pick(this['withdrawal'], 'transaction_reference'),
      this['reference'],
    ]);
  }
}

dynamic _pick(dynamic node, Object path0, [Object? path1, Object? path2]) {
  dynamic current = node;
  // Fewer supplied segments is normal; a null sentinel must stop the walk,
  // not discard the already-resolved leaf value.
  for (final key in [path0, path1, path2]) {
    if (key == null) break;
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

String? _firstString(List<dynamic> candidates) {
  for (final candidate in candidates) {
    if (candidate is String && candidate.isNotEmpty) return candidate;
  }
  return null;
}

num _toNum(dynamic value) {
  if (value is num) return value;
  if (value is String) {
    return num.tryParse(value) ?? 0;
  }
  return 0;
}