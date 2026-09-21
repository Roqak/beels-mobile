import 'package:flutter/material.dart';

import '../theme.dart';

/// Standard screen app bar: surface background, display-font title, automatic
/// back leading on pushed routes.
class BeelsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BeelsAppBar(this.title, {super.key, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      backgroundColor: BeelsColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
    );
  }
}
