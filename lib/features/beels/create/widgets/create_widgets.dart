import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/money.dart';
import '../../../../core/money_input.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/pressable.dart';

/// Remembers a key per field so the flow can scroll the first problem into
/// view after a failed "Continue".
class ErrorScroller {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey keyFor(String field) => _keys.putIfAbsent(field, GlobalKey.new);

  /// Scrolls to the first of [fields] that is on screen (or was built).
  void scrollToFirst(Iterable<String> fields) {
    for (final field in fields) {
      final context = _keys[field]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.15,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
        );
        return;
      }
    }
  }
}

/// A form field with a label above and an inline error below.
class FormBlock extends StatelessWidget {
  const FormBlock({
    super.key,
    required this.label,
    required this.child,
    this.error,
    this.helper,
    this.scroller,
    this.field,
  });

  final String label;
  final Widget child;
  final String? error;
  final String? helper;

  /// With [field], lets the flow scroll to this block when it has an error.
  final ErrorScroller? scroller;
  final String? field;

  @override
  Widget build(BuildContext context) {
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BeelsColors.ink1,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 15, color: BeelsColors.err),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(fontSize: 12.5, color: BeelsColors.err),
                  ),
                ),
              ],
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper!,
              style: TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
            ),
          ),
      ],
    );
    if (scroller != null && field != null) {
      return KeyedSubtree(key: scroller!.keyFor(field!), child: block);
    }
    return block;
  }
}

/// "Step 2 of 5" with segmented progress and the step's title.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
  });

  final int step;
  final int total;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $total: $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutQuart,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          i <= step ? BeelsColors.accent : BeelsColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (i < total - 1) const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Step ${step + 1} of $total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: BeelsColors.ink2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
              color: BeelsColors.ink0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style:
                  TextStyle(fontSize: 14, height: 1.4, color: BeelsColors.ink1),
            ),
          ],
        ],
      ),
    );
  }
}

/// A big tappable option with an icon, a title and one line of explanation.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Pressable(
        haptic: true,
        onTap: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutQuart,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? BeelsColors.accentSoft : BeelsColors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? BeelsColors.accent : BeelsColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        selected ? BeelsColors.accent : BeelsColors.fieldFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: selected ? Colors.white : BeelsColors.ink1,
                  ),
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
                        body,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: BeelsColors.ink1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color:
                      selected ? BeelsColors.accent : BeelsColors.borderStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large naira input for the headline amount.
class BigAmountField extends StatelessWidget {
  const BigAmountField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hasError = false,
    this.hint = '0',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: BeelsColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? BeelsColors.err : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            '₦',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: BeelsColors.ink2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [
                ThousandsFormatter(),
              ],
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: BeelsColors.ink0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.bricolageGrotesque(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: BeelsColors.ink3,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "₦40,000 of ₦60,000 assigned" with a bar that turns green when exact and
/// red when over. The point is to show the mismatch while the user can still
/// fix it, not at the end.
class AllocationBar extends StatelessWidget {
  const AllocationBar({
    super.key,
    required this.assigned,
    required this.total,
    required this.noun,
    this.compact = false,
  });

  /// One tight row for pinning above the action bar.
  final bool compact;

  final num assigned;
  final num total;

  /// "assigned" or "paid out".
  final String noun;

  @override
  Widget build(BuildContext context) {
    final exact = total > 0 && assigned == total;
    final over = assigned > total;
    final color = exact
        ? BeelsColors.ok
        : over
            ? BeelsColors.err
            : BeelsColors.accent;
    final diff = (total - assigned).abs();
    final status = exact
        ? 'Perfect. Every naira is $noun.'
        : over
            ? '${formatNaira(diff)} too much'
            : '${formatNaira(diff)} left to go';
    final fraction =
        total <= 0 ? 0.0 : (assigned / total).clamp(0.0, 1.0).toDouble();

    if (compact) {
      return Semantics(
        liveRegion: true,
        label:
            '${formatNaira(assigned)} of ${formatNaira(total)} $noun. $status',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatNaira(assigned)} of ${formatNaira(total)} $noun',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BeelsColors.ink0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (exact)
                    Icon(Icons.check_circle_rounded, size: 16, color: color),
                  if (exact) const SizedBox(width: 4),
                  Text(
                    exact
                        ? 'All set'
                        : over
                            ? '${formatNaira(diff)} over'
                            : '${formatNaira(diff)} left',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: exact || over ? color : BeelsColors.ink2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: BeelsColors.fieldFill,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      label: '${formatNaira(assigned)} of ${formatNaira(total)} $noun. $status',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BeelsColors.panel,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: exact ? BeelsColors.ok : BeelsColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatNaira(assigned)} of ${formatNaira(total)} $noun',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BeelsColors.ink0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (exact)
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: BeelsColors.ok),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: BeelsColors.fieldFill,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: exact || over ? color : BeelsColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small − / + counter.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 500,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, bool enabled, int next) {
      return Semantics(
        button: true,
        label: label,
        enabled: enabled,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onChanged(next);
                }
              : null,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: enabled ? BeelsColors.accentSoft : BeelsColors.fieldFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: enabled ? BeelsColors.accent : BeelsColors.ink3,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, 'Fewer people', value > min, value - 1),
        SizedBox(
          width: 64,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: BeelsColors.ink0,
            ),
          ),
        ),
        button(Icons.add_rounded, 'More people', value < max, value + 1),
      ],
    );
  }
}
