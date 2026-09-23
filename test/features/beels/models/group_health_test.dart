import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/beels/models/group_health.dart';

GroupHealth report([Map<String, Object?>? overrides]) =>
    GroupHealth.fromJson({
      'score': 72,
      'risk_level': 'WATCH',
      'forecast_hit_target': true,
      'expected_total_by_now': 20000,
      'actual_total_by_now': 15000,
      'shortfall_pct': 25,
      'late_contributors_count': 2,
      'avg_lateness_days': 5,
      'days_since_last_deposit': 3,
      'factors': [
        {
          'key': 'shortfall',
          'label': 'Contribution shortfall',
          'value': 25,
          'severity': 'MEDIUM',
          'detail': '25% below the expected collected amount.',
        },
      ],
      'suggested_interventions': [
        {
          'key': 'nudge_late_contributors',
          'label': 'Nudge late contributors',
          'detail': 'Send a reminder to the 2 contributor(s) behind.',
          'auto_executable': true,
        },
        {
          'key': 'extend_cycle',
          'label': 'Extend the cycle by 1 month',
          'detail': 'The beel is 25% short.',
          'auto_executable': false,
        },
      ],
    });

void main() {
  test('parses score, lowercased risk level and counters', () {
    final health = report();
    expect(health.score, 72);
    expect(health.riskLevel, 'watch');
    expect(health.forecastHitTarget, isTrue);
    expect(health.shortfallPct, 25);
    expect(health.lateContributorsCount, 2);
    expect(health.avgLatenessDays, 5);
    expect(health.daysSinceLastDeposit, 3);
  });

  test('parses factors and interventions with case tolerance', () {
    final health = report();
    expect(health.factors, hasLength(1));
    expect(health.factors.single.severity, 'medium');
    expect(health.interventions, hasLength(2));
    expect(health.interventions.first.key, 'nudge_late_contributors');
    expect(health.interventions.first.autoExecutable, isTrue);
    expect(health.interventions.last.autoExecutable, isFalse);
  });

  test('tolerates empty and malformed payloads', () {
    final health = GroupHealth.fromJson(null);
    expect(health.score, isNull);
    expect(health.riskLevel, '');
    expect(health.factors, isEmpty);
    expect(health.interventions, isEmpty);

    expect(GroupHealth.fromJson({'factors': 'nope'}).factors, isEmpty);
  });

  test('InterveneResult parses nudge and manual outcomes', () {
    final nudge = InterveneResult.fromJson({
      'executed': true,
      'intervention': 'nudge_late_contributors',
      'nudged': 2,
      'total_late': 3,
    });
    expect(nudge.executed, isTrue);
    expect(nudge.nudged, 2);
    expect(nudge.totalLate, 3);

    final manual = InterveneResult.fromJson({
      'executed': false,
      'message': 'This intervention is not auto-executable.',
    });
    expect(manual.executed, isFalse);
    expect(manual.message, 'This intervention is not auto-executable.');
  });

  test('numeric string fields still parse', () {
    final health = GroupHealth.fromJson({'score': '88', 'risk_level': 1});
    expect(health.score, 88);
    expect(health.riskLevel, '1');
  });

}