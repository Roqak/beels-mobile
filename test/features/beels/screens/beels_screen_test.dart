import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beels_mobile/features/beels/controllers/beels_controllers.dart';
import 'package:beels_mobile/features/beels/models/contribution.dart';
import 'package:beels_mobile/features/beels/screens/beels_screen.dart';

class _FakeBeelsListController extends BeelsListController {
  @override
  Future<BeelsListState> build() async => BeelsListState(
        items: [
          Contribution.fromJson({
            'id': 1,
            'name': 'Family Savings',
            'unit_amount': 5000,
            'total_amount': 60000,
            'status': 'active',
            'recurrence_type': 'weekly',
            'day_of_week': 'monday',
            'occurrences': 12,
            'contribution_mode': 'closed',
          }),
          Contribution.fromJson({
            'id': 2,
            'name': 'Birthday Fund',
            'unit_amount': 2500,
            'total_amount': 25000,
            'status': 'pending',
            'recurrence_type': 'one_time',
            'contribution_mode': 'open_link',
            'payment_link_token': 'tok_abc',
          }),
        ],
        page: 1,
        lastPage: 1,
        total: 2,
      );

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

Widget _app() {
  return ProviderScope(
    overrides: [
      beelsListControllerProvider.overrideWith(_FakeBeelsListController.new),
    ],
    child: const MaterialApp(home: BeelsScreen()),
  );
}

void main() {
  testWidgets('renders beel cards with amounts, recurrence and status',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Family Savings'), findsOneWidget);
    expect(find.text('Birthday Fund'), findsOneWidget);

    // ₦unit × occurrences summary.
    expect(find.text('₦5,000 × 12'), findsOneWidget);
    expect(find.text('₦2,500 × 1'), findsOneWidget);

    expect(find.text('Weekly · Monday'), findsOneWidget);
    expect(find.text('One-time'), findsOneWidget);

    expect(find.text('active'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);

    // Open-link badge only on the open beel.
    expect(find.text('Open link'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no beels', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        beelsListControllerProvider.overrideWith(_EmptyBeelsListController.new),
      ],
      child: const MaterialApp(home: BeelsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Family Savings'), findsNothing);
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
  });

  testWidgets('shows the error view with retry on failure', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        beelsListControllerProvider.overrideWith(_FailingController.new),
      ],
      child: const MaterialApp(home: BeelsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Family Savings'), findsNothing);
    expect(find.byKey(const Key('error-view')), findsOneWidget);
  });
}

class _EmptyBeelsListController extends BeelsListController {
  @override
  Future<BeelsListState> build() async => const BeelsListState(
        items: [],
        page: 1,
        lastPage: 1,
        total: 0,
      );
}

class _FailingController extends BeelsListController {
  @override
  Future<BeelsListState> build() async => throw Exception('network down');
}
