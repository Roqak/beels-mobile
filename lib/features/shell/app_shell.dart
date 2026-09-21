import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Shell around the four tab branches, with a floating pill navigation bar
/// and a raised centre button that opens the Create sheet.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) {
          if (index != navigationShell.currentIndex) {
            HapticFeedback.selectionClick();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        onCreate: () => showCreateSheet(context),
      ),
    );
  }
}

/// Tab destinations, left of centre then right of centre.
const _tabs = <_Tab>[
  _Tab('Home', Icons.home_outlined, Icons.home_rounded),
  _Tab('Beels', Icons.savings_outlined, Icons.savings_rounded),
  _Tab('Transactions', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Tab('Groups', Icons.group_outlined, Icons.group_rounded),
];

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Pill-shaped bar floating above the content: two tabs, a raised Create
/// button, two tabs. Public so it can be rendered on its own in tests.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onCreate,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  static const _barHeight = 64.0;
  static const _raise = 20.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _barHeight + _raise + 12,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              height: _barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BeelsColors.panel,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: BeelsColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          BeelsColors.brightness == Brightness.dark
                              ? 0.35
                              : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _item(0),
                    _item(1),
                    const Spacer(),
                    _item(2),
                    _item(3),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12 + _barHeight - 30,
              child: Semantics(
                button: true,
                label: 'Create',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onCreate();
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: BeelsColors.dye,
                      shape: BoxShape.circle,
                      border: Border.all(color: BeelsColors.surface, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: BeelsColors.dye.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.add_rounded,
                        size: 30, color: BeelsColors.turmeric),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(int index) {
    final tab = _tabs[index];
    final selected = index == currentIndex;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          // The wrapper already announces label + selected state; hiding the
          // visible text avoids a screen reader saying it twice.
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutQuart,
                  width: selected ? 46 : 32,
                  height: 28,
                  decoration: BoxDecoration(
                    color:
                        selected ? BeelsColors.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutQuart,
                    child: Icon(
                      selected ? tab.selectedIcon : tab.icon,
                      size: 22,
                      color: selected ? BeelsColors.accent : BeelsColors.ink2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? BeelsColors.ink0 : BeelsColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What can be created from anywhere: opened by the raised centre button.
Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => const _CreateSheet(),
  );
}

class _CreateSheet extends StatelessWidget {
  const _CreateSheet();

  void _go(BuildContext context, String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(location);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: BeelsColors.ink0,
              ),
            ),
            const SizedBox(height: 12),
            _CreateRow(
              icon: Icons.savings_rounded,
              title: 'New beel',
              subtitle: 'Collect contributions from people, on a schedule.',
              onTap: () => _go(context, '/beels/new'),
            ),
            _CreateRow(
              icon: Icons.group_add_rounded,
              title: 'New group',
              subtitle: 'Keep the people you save with in one place.',
              onTap: () => _go(context, '/groups/new'),
            ),
            _CreateRow(
              icon: Icons.account_balance_rounded,
              title: 'Set up direct debit',
              subtitle: 'Let Beels collect your contributions automatically.',
              onTap: () => _go(context, '/mandates/setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: BeelsColors.accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: BeelsColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BeelsColors.ink0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 13, height: 1.35, color: BeelsColors.ink2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: BeelsColors.ink3),
          ],
        ),
      ),
    );
  }
}
