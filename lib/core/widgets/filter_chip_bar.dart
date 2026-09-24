import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'pressable.dart';

/// One choice in a [FilterChipBar].
class FilterOption<T> {
  const FilterOption(this.value, this.label);

  final T value;
  final String label;
}

/// Single-select pill filters shared by list screens. Scrolls sideways when
/// there are more choices than fit, and gives a light haptic on change.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  final List<FilterOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Outer padding; use [EdgeInsets.zero] inside an already-padded form.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Full width, or a Column would shrink-wrap and centre the row.
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (final option in options) ...[
              Pressable(
                semanticLabel: option.label,
                selected: option.value == value,
                onTap: () {
                  if (option.value == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(option.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutQuart,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? BeelsColors.dye
                        : BeelsColors.panel,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: option.value == value
                          ? BeelsColors.dye
                          : BeelsColors.borderStrong,
                    ),
                  ),
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: option.value == value
                          ? Colors.white
                          : BeelsColors.ink1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
