import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contacts/contact_picker.dart';
import '../../../../core/money.dart';
import '../../../../core/money_input.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/contact_pick_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/surface_card.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';
import 'create_widgets.dart';
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

class _ClosedPeople extends ConsumerStatefulWidget {
  const _ClosedPeople({required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  @override
  ConsumerState<_ClosedPeople> createState() => _ClosedPeopleState();
}

class _ClosedPeopleState extends ConsumerState<_ClosedPeople> {
  int? _expanded;

  @override
  void initState() {
    super.initState();
    final d = ref.read(beelDraftProvider);
    if (d.contributors.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() =>
            _expanded = ref.read(beelDraftProvider.notifier).addContributor());
      });
    } else {
      _expanded = d.contributors.length == 1 ? d.contributors.first.id : null;
    }
  }

  void _add([PickedContact? contact]) {
    final id = ref.read(beelDraftProvider.notifier).addContributor(contact);
    HapticFeedback.selectionClick();
    // A picked contact usually still needs an amount, so open the new card.
    setState(() => _expanded = id);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    final target = draft.target ?? 0;
    final people = draft.contributors;

    // If validation flagged someone, open the first flagged card.
    int? flagged;
    for (var i = 0; i < people.length; i++) {
      if (widget.errors.keys.any((k) => k.startsWith('contributor_${i}_'))) {
        flagged = people[i].id;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: widget.scroller.keyFor('people'),
          child: AllocationBar(
            assigned: draft.contributorTotal,
            total: target,
            noun: 'assigned',
          ),
        ),
        if (widget.errors['people'] != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 15, color: BeelsColors.err),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.errors['people']!,
                  style: TextStyle(fontSize: 12.5, color: BeelsColors.err),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
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
        for (var i = 0; i < people.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _PersonCard(
              key: ValueKey(people[i].id),
              index: i,
              person: people[i],
              expanded: (flagged ?? _expanded) == people[i].id,
              errors: widget.errors,
              scroller: widget.scroller,
              canRemove: people.length > 1,
              onToggle: () => setState(() {
                _expanded = _expanded == people[i].id ? null : people[i].id;
              }),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('Add person'),
              ),
            ),
            ContactPickButton(onPicked: _add),
          ],
        ),
      ],
    );
  }
}

class _PersonCard extends ConsumerStatefulWidget {
  const _PersonCard({
    super.key,
    required this.index,
    required this.person,
    required this.expanded,
    required this.errors,
    required this.scroller,
    required this.canRemove,
    required this.onToggle,
  });

  final int index;
  final DraftContributor person;
  final bool expanded;
  final Map<String, String> errors;
  final ErrorScroller scroller;
  final bool canRemove;
  final VoidCallback onToggle;

  @override
  ConsumerState<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends ConsumerState<_PersonCard> {
  late final _first = TextEditingController(text: widget.person.firstName);
  late final _last = TextEditingController(text: widget.person.lastName);
  late final _phone = TextEditingController(text: widget.person.phone);
  late final _email = TextEditingController(text: widget.person.email);
  late final _amount = TextEditingController(text: widget.person.amount);

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? _err(String suffix) =>
      widget.errors['contributor_${widget.index}_$suffix'];

  bool get _hasErrors => widget.errors.keys
      .any((k) => k.startsWith('contributor_${widget.index}_'));

  void _update(DraftContributor Function(DraftContributor) f) => ref
      .read(beelDraftProvider.notifier)
      .updateContributor(widget.person.id, f);

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    syncController(_first, p.firstName);
    syncController(_last, p.lastName);
    syncController(_phone, p.phone);
    syncController(_email, p.email);
    syncController(_amount, p.amount);
    final amount = parseMoney(p.amount);

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Pressable(
            onTap: widget.onToggle,
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hasErrors
                          ? BeelsColors.errSoft
                          : BeelsColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: _hasErrors
                        ? Icon(Icons.priority_high_rounded,
                            size: 18, color: BeelsColors.err)
                        : Text(
                            '${widget.index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: BeelsColors.accent,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.fullName.isEmpty ? 'New person' : p.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.fullName.isEmpty
                            ? BeelsColors.ink2
                            : BeelsColors.ink0,
                      ),
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
                  Icon(
                    widget.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: BeelsColors.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: BeelsColors.border),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FormBlock(
                          label: 'First name',
                          field: 'contributor_${widget.index}_first',
                          scroller: widget.scroller,
                          error: _err('first'),
                          child: TextField(
                            controller: _first,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onChanged: (v) =>
                                _update((c) => c.copyWith(firstName: v)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FormBlock(
                          label: 'Last name',
                          field: 'contributor_${widget.index}_last',
                          scroller: widget.scroller,
                          error: _err('last'),
                          child: TextField(
                            controller: _last,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onChanged: (v) =>
                                _update((c) => c.copyWith(lastName: v)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FormBlock(
                    label: 'Phone number',
                    field: 'contributor_${widget.index}_phone',
                    scroller: widget.scroller,
                    error: _err('phone'),
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onChanged: (v) => _update((c) => c.copyWith(phone: v)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FormBlock(
                    label: 'Email',
                    field: 'contributor_${widget.index}_email',
                    scroller: widget.scroller,
                    error: _err('email'),
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (v) => _update((c) => c.copyWith(email: v)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FormBlock(
                    label: 'Amount this person pays',
                    field: 'contributor_${widget.index}_amount',
                    scroller: widget.scroller,
                    error: _err('amount'),
                    child: TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [
                        ThousandsFormatter(),
                      ],
                      onChanged: (v) => _update((c) => c.copyWith(amount: v)),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 4),
                          child: Text('₦',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: BeelsColors.ink1)),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ContactPickButton(
                        onPicked: (c) => _update((p) => p.copyWith(
                              firstName:
                                  c.firstName.isNotEmpty ? c.firstName : null,
                              lastName:
                                  c.lastName.isNotEmpty ? c.lastName : null,
                              email: c.email.isNotEmpty ? c.email : null,
                              phone: c.phone.isNotEmpty ? c.phone : null,
                            )),
                      ),
                      const Spacer(),
                      if (widget.canRemove)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: BeelsColors.err),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(beelDraftProvider.notifier)
                                .removeContributor(widget.person.id);
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
