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

class _MixedController extends BeelsListController {
  _MixedController({this.hasMore = false, this.statuses});

  final bool hasMore;
  final List<String>? statuses;
  int loadMoreCalls = 0;

  @override
  Future<BeelsListState> build() async {
    final list = statuses ?? ['active', 'pending', 'failed', 'active'];
    return BeelsListState(
      items: [
        for (var i = 0; i < list.length; i++)
          Contribution.fromJson({
            'id': i + 1,
            'name': 'Beel ${i + 1}',
            'unit_amount': 1000,
            'status': list[i],
            'recurrence_type': 'one_time',
            'contribution_mode': 'closed',
          }),
      ],
      page: 1,
      lastPage: hasMore ? 2 : 1,
      total: list.length,
    );
  }

  @override
  Future<void> loadMore() async => loadMoreCalls++;

  @override
  Future<void> refresh() async {}
}

Widget _appWith(BeelsListController controller) {
  return ProviderScope(
    overrides: [beelsListControllerProvider.overrideWith(() => controller)],
    child: const MaterialApp(home: BeelsScreen()),
  );
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

  testWidgets('status filters are built from the statuses present',
      (tester) async {
    await tester.pumpWidget(_appWith(_MixedController()));
    await tester.pumpAndSettle();

    // Ordered by usefulness, no chip for statuses that are not there.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Cancelled'), findsNothing);
    expect(find.text('Completed'), findsNothing);
    // Everything shows by default.
    expect(find.byType(BeelCard), findsNWidgets(4));
  });

  testWidgets('choosing a status shows only those beels; All restores',
      (tester) async {
    await tester.pumpWidget(_appWith(_MixedController()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.byType(BeelCard), findsNWidgets(2));
    expect(find.text('Beel 1'), findsOneWidget);
    expect(find.text('Beel 4'), findsOneWidget);
    expect(find.text('Beel 2'), findsNothing);

    await tester.tap(find.text('Failed'));
    await tester.pumpAndSettle();
    expect(find.byType(BeelCard), findsOneWidget);
    expect(find.text('Beel 3'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byType(BeelCard), findsNWidgets(4));
  });

  testWidgets('no filter bar when every beel has the same status',
      (tester) async {
    await tester.pumpWidget(
      _appWith(_MixedController(statuses: ['active', 'active'])),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsNothing);
    expect(find.byType(BeelCard), findsNWidgets(2));
  });

  testWidgets('a filtered list offers Load more when more pages exist',
      (tester) async {
    final controller = _MixedController(hasMore: true);
    await tester.pumpWidget(_appWith(controller));
    // The trailing spinner never settles, so pump a fixed duration.
    await tester.pump(const Duration(milliseconds: 500));

    // Unfiltered: infinite scroll (spinner), no button.
    expect(find.text('Load more'), findsNothing);

    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('Load more'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pump();
    expect(controller.loadMoreCalls, 1);
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
