import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/filter_chip_bar.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';

/// Step 2: how often collection happens, with the result in plain words.
class ScheduleStep extends ConsumerWidget {
  const ScheduleStep({super.key, this.now});

  /// Overrides "today" for tests and goldens.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    final next = nextRun(draft, now ?? DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('How often?'),
        FilterChipBar<String>(
          padding: EdgeInsets.zero,
          value: draft.recurrenceType,
          options: [
            for (final e in kRecurrences.entries) FilterOption(e.key, e.value),
          ],
          onChanged: notifier.setRecurrence,
        ),
        if (draft.recurrenceType == 'weekly') ...[
          const SizedBox(height: 20),
          const _Label('Which day of the week?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in kWeekdays.entries)
                _DayPill(
                  label: e.value.substring(0, 3),
                  selected: draft.dayOfWeek == e.key,
                  semantics: e.value,
                  onTap: () => notifier.setDayOfWeek(e.key),
                ),
            ],
          ),
        ],
        if (draft.recurrenceType == 'monthly') ...[
          const SizedBox(height: 20),
          const _Label('Which day of the month?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var day = 1; day <= 31; day++)
                _DayPill(
                  label: '$day',
                  selected: draft.dayOfMonth == day,
                  semantics: 'Day $day',
                  round: true,
                  onTap: () => notifier.setDayOfMonth(day),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'In shorter months, collection happens on the last day.',
            style: TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
          ),
        ],
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(
                '${draft.recurrenceType}${draft.dayOfWeek}${draft.dayOfMonth}'),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BeelsColors.turmericSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recurrenceSentence(draft),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: BeelsColors.ink0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? 'People pay once. No repeats.'
                      : 'Next collection: ${DateFormat('EEEE, d MMM').format(next)}',
                  style:
                      TextStyle(fontSize: 14, color: BeelsColors.turmericInk),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BeelsColors.ink1,
          ),
        ),
      );
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.selected,
    required this.semantics,
    required this.onTap,
    this.round = false,
  });

  final String label;
  final bool selected;
  final String semantics;
  final VoidCallback onTap;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      child: GestureDetector(
        onTap: () {
          if (selected) return;
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: round ? 44 : 60,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? BeelsColors.dye : BeelsColors.panel,
              borderRadius: BorderRadius.circular(round ? 22 : 14),
              border: Border.all(
                color: selected ? BeelsColors.dye : BeelsColors.borderStrong,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : BeelsColors.ink1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
