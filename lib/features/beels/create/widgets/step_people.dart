import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/contact_pick_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/surface_card.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';
import 'create_widgets.dart';
import 'sheets.dart';
import 'text_sync.dart';

/// Step 3: who pays.
class PeopleStep extends ConsumerWidget {
  const PeopleStep({super.key, required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(beelDraftProvider.select((d) => d.isOpen));
    return isOpen
        ? _OpenPeople(errors: errors, scroller: scroller)
        : _ClosedPeople(errors: errors, scroller: scroller);
  }
}

// ---------------------------------------------------------------- open link

class _OpenPeople extends ConsumerStatefulWidget {
  const _OpenPeople({required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  @override
  ConsumerState<_OpenPeople> createState() => _OpenPeopleState();
}

class _OpenPeopleState extends ConsumerState<_OpenPeople> {
  late final _fixed =
      TextEditingController(text: ref.read(beelDraftProvider).perContributor);

  @override
  void initState() {
    super.initState();
    // A head count is always shown in "even" mode, so make it real.
    final d = ref.read(beelDraftProvider);
    if (d.openSplit == OpenSplit.even &&
        (int.tryParse(d.expectedContributors.trim()) ?? 0) < 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(beelDraftProvider.notifier).setExpected('2'),
      );
    }
  }

  @override
  void dispose() {
    _fixed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    syncController(_fixed, draft.perContributor);
    final preview = draft.perPersonPreview;
    final count = int.tryParse(draft.expectedContributors.trim()) ?? 2;
    final target = draft.target ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChoiceCard(
          icon: Icons.balance_rounded,
          title: 'Split it evenly',
          body: 'Everyone who joins pays the same share of the target.',
          selected: draft.openSplit == OpenSplit.even,
          onTap: () => notifier.setOpenSplit(OpenSplit.even),
        ),
        const SizedBox(height: 10),
        ChoiceCard(
          icon: Icons.sell_rounded,
          title: 'Set a price per person',
          body: 'You decide the amount each person pays.',
          selected: draft.openSplit == OpenSplit.fixed,
          onTap: () => notifier.setOpenSplit(OpenSplit.fixed),
        ),
        const SizedBox(height: 26),
        if (draft.openSplit == OpenSplit.even)
          FormBlock(
            label: 'How many people do you expect?',
            field: 'expected',
            scroller: widget.scroller,
            error: widget.errors['expected'],
            child: Align(
              alignment: Alignment.centerLeft,
              child: CountStepper(
                value: count < 1 ? 1 : count,
                onChanged: (v) => notifier.setExpected('$v'),
              ),
            ),
          )
        else
          FormBlock(
            label: 'How much does each person pay?',
            field: 'per_person',
            scroller: widget.scroller,
            error: widget.errors['per_person'],
            child: BigAmountField(
              controller: _fixed,
              onChanged: notifier.setPerContributor,
              hasError: widget.errors.containsKey('per_person'),
            ),
          ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey('${draft.openSplit}${preview?.toStringAsFixed(2)}'),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BeelsColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: preview == null
                ? Text(
                    'Fill in the amount to see what each person pays.',
                    style: TextStyle(fontSize: 14, color: BeelsColors.ink1),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Each person pays',
                        style: TextStyle(fontSize: 13, color: BeelsColors.ink1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatNaira(_roundKobo(preview)),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: BeelsColors.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (draft.openSplit == OpenSplit.fixed && target > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(target / preview).ceil()} people reach your target of ${formatNaira(target)}.',
                          style:
                              TextStyle(fontSize: 13, color: BeelsColors.ink1),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  static num _roundKobo(num n) => (n * 100).round() / 100;
}

// -------------------------------------------------------------- chosen people

class _ClosedPeople extends ConsumerWidget {
  const _ClosedPeople({required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  static const _labels = {
    'first': 'first name',
    'last': 'last name',
    'email': 'email',
    'phone': 'phone',
    'amount': 'amount',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    final people = draft.contributors;
    final target = draft.target ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, not Row: with large text the two buttons must stack rather
        // than squeeze each other.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => showPersonSheet(context),
              icon: const Icon(Icons.person_add_alt_rounded, size: 20),
              label: const Text('Add person'),
            ),
            ContactPickButton(
              onPicked: (c) => showPersonSheet(context, prefill: c),
            ),
          ],
        ),
        if (people.length >= 2 && target > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                notifier.splitContributorsEvenly();
              },
              icon: const Icon(Icons.balance_rounded, size: 18),
              label: Text(
                  'Split ${formatNaira(target)} equally between ${people.length}'),
            ),
          ),
        const SizedBox(height: 8),
        if (people.isEmpty)
          SurfaceCard(
            color: BeelsColors.surfaceAlt,
            child: Text(
              'No one added yet. Add the first person, or pick them from your contacts.',
              style:
                  TextStyle(fontSize: 14, height: 1.4, color: BeelsColors.ink1),
            ),
          )
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < people.length; i++) ...[
                  if (i > 0) Divider(indent: 64, color: BeelsColors.border),
                  _PersonRow(
                    index: i,
                    person: people[i],
                    errorFields: [
                      for (final k in errors.keys)
                        if (k.startsWith('contributor_${i}_'))
                          _labels[k.substring('contributor_${i}_'.length)] ??
                              '',
                    ],
                    rowKey: errors.keys
                        .where((k) => k.startsWith('contributor_${i}_'))
                        .map(scroller.keyFor)
                        .firstOrNull,
                  ),
                ],
              ],
            ),
          ),
        if (errors['people'] != null) ...[
          const SizedBox(height: 10),
          KeyedSubtree(
            key: scroller.keyFor('people'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 15, color: BeelsColors.err),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    errors['people']!,
                    style: TextStyle(fontSize: 12.5, color: BeelsColors.err),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.index,
    required this.person,
    required this.errorFields,
    this.rowKey,
  });

  final int index;
  final DraftContributor person;
  final List<String> errorFields;
  final GlobalKey? rowKey;

  @override
  Widget build(BuildContext context) {
    final amount = parseMoney(person.amount);
    final hasErrors = errorFields.isNotEmpty;
    return KeyedSubtree(
      key: rowKey ?? ValueKey('person-${person.id}'),
      child: Pressable(
        onTap: () =>
            showPersonSheet(context, editing: person, showErrors: hasErrors),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      hasErrors ? BeelsColors.errSoft : BeelsColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: hasErrors
                    ? Icon(Icons.priority_high_rounded,
                        size: 18, color: BeelsColors.err)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: BeelsColors.accent,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName.isEmpty ? 'New person' : person.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BeelsColors.ink0,
                      ),
                    ),
                    if (hasErrors)
                      Text(
                        'Needs ${errorFields.where((f) => f.isNotEmpty).join(', ')}',
                        style:
                            TextStyle(fontSize: 12.5, color: BeelsColors.err),
                      )
                    else if (person.phone.isNotEmpty)
                      Text(
                        person.phone,
                        style:
                            TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
                      ),
                  ],
                ),
              ),
              if (amount != null && amount > 0)
                Text(
                  formatNaira(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BeelsColors.ink1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: BeelsColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
