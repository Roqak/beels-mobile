/// Latest group-health report for a beel, produced nightly by the backend
/// (GET /group-health/:id). Tolerant of missing fields so older reports
/// still render.
class GroupHealth {
  GroupHealth({
    this.score,
    this.riskLevel = '',
    this.forecastHitTarget,
    this.expectedTotalByNow,
    this.actualTotalByNow,
    this.shortfallPct,
    this.lateContributorsCount,
    this.avgLatenessDays,
    this.daysSinceLastDeposit,
    this.factors = const [],
    this.interventions = const [],
  });

  /// 0–100 composite health score.
  final num? score;

  /// healthy | watch | at_risk | critical.
  final String riskLevel;

  /// Whether the current pace still reaches the beel target.
  final bool? forecastHitTarget;
  final num? expectedTotalByNow;
  final num? actualTotalByNow;

  /// Percentage below the expected collected amount, 0–100.
  final num? shortfallPct;
  final int? lateContributorsCount;
  final num? avgLatenessDays;
  final int? daysSinceLastDeposit;
  final List<HealthFactor> factors;
  final List<SuggestedIntervention> interventions;

  factory GroupHealth.fromJson(dynamic json) {
    final map = _asMap(json);
    return GroupHealth(
      score: _nullableNum(map['score']),
      riskLevel: _asString(map['risk_level']).toLowerCase(),
      forecastHitTarget: map['forecast_hit_target'] is bool
          ? map['forecast_hit_target'] as bool
          : null,
      expectedTotalByNow: _nullableNum(map['expected_total_by_now']),
      actualTotalByNow: _nullableNum(map['actual_total_by_now']),
      shortfallPct: _nullableNum(map['shortfall_pct']),
      lateContributorsCount: _nullableInt(map['late_contributors_count']),
      avgLatenessDays: _nullableNum(map['avg_lateness_days']),
      daysSinceLastDeposit: _nullableInt(map['days_since_last_deposit']),
      factors: HealthFactor.listFrom(map['factors']),
      interventions: SuggestedIntervention.listFrom(
        map['suggested_interventions'],
      ),
    );
  }
}

/// One scoring factor behind the health score.
class HealthFactor {
  HealthFactor({
    this.key = '',
    this.label = '',
    this.severity = '',
    this.detail = '',
  });

  final String key;
  final String label;

  /// low | medium | high.
  final String severity;
  final String detail;

  static List<HealthFactor> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json
        .map<HealthFactor>((row) => HealthFactor.fromJson(row))
        .toList();
  }

  factory HealthFactor.fromJson(dynamic json) {
    final map = _asMap(json);
    return HealthFactor(
      key: _asString(map['key']),
      label: _asString(map['label']),
      severity: _asString(map['severity']).toLowerCase(),
      detail: _asString(map['detail']),
    );
  }
}

/// An action the backend suggests for a beel. Auto-executable ones (nudge,
/// broadcast) run immediately when the organizer approves them.
class SuggestedIntervention {
  SuggestedIntervention({
    this.key = '',
    this.label = '',
    this.detail = '',
    this.autoExecutable = false,
  });

  final String key;
  final String label;
  final String detail;
  final bool autoExecutable;

  static List<SuggestedIntervention> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json
        .map<SuggestedIntervention>((row) => SuggestedIntervention.fromJson(row))
        .toList();
  }

  factory SuggestedIntervention.fromJson(dynamic json) {
    final map = _asMap(json);
    return SuggestedIntervention(
      key: _asString(map['key']),
      label: _asString(map['label']),
      detail: _asString(map['detail']),
      autoExecutable: map['auto_executable'] == true,
    );
  }
}

/// Result of POST /group-health/:id/intervene. Auto-executable interventions
/// return executed=true with counters; manual ones return guidance.
class InterveneResult {
  const InterveneResult({
    this.executed = false,
    this.message = '',
    this.nudged,
    this.totalLate,
    this.broadcasted,
    this.totalContributors,
  });

  final bool executed;
  final String message;
  final int? nudged;
  final int? totalLate;
  final int? broadcasted;
  final int? totalContributors;

  factory InterveneResult.fromJson(dynamic json) {
    final map = _asMap(json);
    return InterveneResult(
      executed: map['executed'] == true,
      message: _asString(map['message']),
      nudged: _nullableInt(map['nudged']),
      totalLate: _nullableInt(map['total_late']),
      broadcasted: _nullableInt(map['broadcasted']),
      totalContributors: _nullableInt(map['total_contributors']),
    );
  }
}

Map<dynamic, dynamic> _asMap(dynamic json) =>
    json is Map ? json : const {};

num? _nullableNum(dynamic value) =>
    value is num ? value : (value is String ? num.tryParse(value) : null);

int? _nullableInt(dynamic value) => value is int
    ? value
    : (value is num ? value.toInt() : (value is String ? int.tryParse(value) : null));

String _asString(dynamic value) => value?.toString() ?? '';