import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/features/shell/app_shell.dart';

Widget _bar({
  int index = 0,
  ValueChanged<int>? onSelect,
  VoidCallback? onCreate,
}) =>
    MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: index,
          onSelect: onSelect ?? (_) {},
          onCreate: onCreate ?? () {},
        ),
      ),
    );

void main() {
  testWidgets('tapping a tab reports its index', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_bar(onSelect: picked.add));

    await tester.tap(find.text('Beels'));
    await tester.tap(find.text('Transactions'));
    await tester.tap(find.text('Groups'));
    await tester.tap(find.text('Home'));

    expect(picked, [1, 2, 3, 0]);
  });

  testWidgets('the raised centre button creates', (tester) async {
    var created = 0;
    await tester.pumpWidget(_bar(onCreate: () => created++));

    await tester.tap(find.bySemanticsLabel('Create'));

    expect(created, 1);
  });

  testWidgets('the selected tab is exposed as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(index: 2));

    expect(
      tester.getSemantics(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Transactions',
      )),
      containsSemantics(
        label: 'Transactions',
        isButton: true,
        isSelected: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the create sheet lists the three actions and routes to them',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCreateSheet(context),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
        GoRoute(
            path: '/beels/new',
            builder: (_, __) => const Scaffold(body: Text('NEW_BEEL'))),
        GoRoute(
            path: '/groups/new',
            builder: (_, __) => const Scaffold(body: Text('NEW_GROUP'))),
        GoRoute(
            path: '/mandates/setup',
            builder: (_, __) => const Scaffold(body: Text('SETUP_MANDATE'))),
      ],
    );
    addTearDown(router.dispose);

    Future<void> openAndPick(String title, String expected) async {
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('New beel'), findsOneWidget);
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('Set up direct debit'), findsOneWidget);

      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await openAndPick('New beel', 'NEW_BEEL');
    await openAndPick('New group', 'NEW_GROUP');
    await openAndPick('Set up direct debit', 'SETUP_MANDATE');
  });
}
