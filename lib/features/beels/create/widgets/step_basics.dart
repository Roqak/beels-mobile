import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../beel_draft.dart';
import '../beel_draft_controller.dart';
import 'create_widgets.dart';
import 'text_sync.dart';

/// Step 1: what kind of beel, its name and target.
class BasicsStep extends ConsumerStatefulWidget {
  const BasicsStep({super.key, required this.errors, required this.scroller});

  final Map<String, String> errors;
  final ErrorScroller scroller;

  @override
  ConsumerState<BasicsStep> createState() => _BasicsStepState();
}

class _BasicsStepState extends ConsumerState<BasicsStep> {
  late final _name =
      TextEditingController(text: ref.read(beelDraftProvider).name);
  late final _amount =
      TextEditingController(text: ref.read(beelDraftProvider).amount);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(beelDraftProvider);
    final notifier = ref.read(beelDraftProvider.notifier);
    syncController(_name, draft.name);
    syncController(_amount, draft.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChoiceCard(
          icon: Icons.group_rounded,
          title: 'I choose the people',
          body: 'Add everyone who pays and how much each person owes.',
          selected: draft.mode == BeelMode.closed,
          onTap: () => notifier.setMode(BeelMode.closed),
        ),
        const SizedBox(height: 10),
        ChoiceCard(
          icon: Icons.link_rounded,
          title: 'Anyone with a link',
          body: 'Share one link. People join and pay on their own.',
          selected: draft.mode == BeelMode.open,
          onTap: () => notifier.setMode(BeelMode.open),
        ),
        const SizedBox(height: 28),
        FormBlock(
          label: 'Name your beel',
          field: 'name',
          scroller: widget.scroller,
          error: widget.errors['name'],
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: notifier.setName,
            decoration: const InputDecoration(
              hintText: 'e.g. Family rent, Ajo circle',
            ),
          ),
        ),
        const SizedBox(height: 22),
        FormBlock(
          label: 'How much do you want to collect?',
          field: 'amount',
          scroller: widget.scroller,
          error: widget.errors['amount'],
          helper: draft.isOpen
              ? 'The total across everyone who joins.'
              : 'The total across everyone you add.',
          child: BigAmountField(
            controller: _amount,
            onChanged: notifier.setAmount,
            hasError: widget.errors.containsKey('amount'),
          ),
        ),
      ],
    );
  }
}
