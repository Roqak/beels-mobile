import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../controllers/beels_controllers.dart';
import '../create/beel_draft.dart';
import '../create/beel_draft_controller.dart';
import '../create/widgets/beel_created_view.dart';
import '../create/widgets/create_widgets.dart';
import '../create/widgets/step_basics.dart';
import '../create/widgets/step_payout.dart';
import '../create/widgets/step_people.dart';
import '../create/widgets/step_review.dart';
import '../create/widgets/step_schedule.dart';
import '../models/contribution.dart';

const _stepCount = 5;

/// Guided "create a beel" flow: one decision per step, live totals, inline
/// errors, and a proper finish. All state lives in [beelDraftProvider].
class CreateBeelScreen extends ConsumerStatefulWidget {
  const CreateBeelScreen({super.key, this.now});

  /// Overrides "today" for tests and goldens.
  final DateTime? now;

  @override
  ConsumerState<CreateBeelScreen> createState() => _CreateBeelScreenState();
}

class _CreateBeelScreenState extends ConsumerState<CreateBeelScreen> {
  int _step = 0;
  Map<String, String> _errors = const {};
  final ErrorScroller _scroller = ErrorScroller();
  final ScrollController _scroll = ScrollController();
  bool _submitting = false;
  String? _submitError;
  Contribution? _created;
  // What the finish screen shows, captured at creation time.
  String _createdName = '';
  num _createdTarget = 0;
  String _createdSchedule = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  (String, String?) _titles(BeelDraft d) {
    switch (_step) {
      case 0:
        return (
          'What are you collecting for?',
          'Choose how people join, then name it.'
        );
      case 1:
        return ('When does it repeat?', 'Pick how often collection happens.');
      case 2:
        return d.isOpen
            ? (
                'What does each person pay?',
                'People join with your link and pay this amount.'
              )
            : (
                'Who is paying?',
                d.sharesEvenly
                    ? 'Add the people. We split the target between them.'
                    : 'Add each person and what they owe. The total must match your target.'
              );
      case 3:
        return (
          'Where should the money go?',
          'We check bank accounts so nothing goes to the wrong place.'
        );
      default:
        return (
          'Review and create',
          'Check everything, then create your beel.'
        );
    }
  }

  Map<String, String> _validate(BeelDraft d) {
    switch (_step) {
      case 0:
        return validateBasics(d);
      case 2:
        return validatePeople(d);
      case 3:
        return validatePayout(d);
      default:
        return const {};
    }
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _errors = const {};
      _submitError = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    final draft = ref.read(beelDraftProvider);
    final errors = _validate(draft);
    if (errors.isNotEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _errors = errors);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scroller.scrollToFirst(errors.keys),
      );
      return;
    }
    HapticFeedback.selectionClick();
    _goTo(_step + 1);
  }

  Future<void> _back() async {
    if (_step == 0) {
      await _maybeLeave();
      return;
    }
    _goTo(_step - 1);
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this beel?'),
        content: const Text('What you have entered so far will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: BeelsColors.err),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _maybeLeave() async {
    final dirty = ref.read(beelDraftProvider).isDirty;
    if (!dirty || await _confirmDiscard()) {
      if (mounted) context.pop();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final d = ref.read(beelDraftProvider);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final controller = ref.read(createBeelControllerProvider.notifier);
    try {
      final Contribution created;
      if (d.isOpen) {
        created = await controller.submitOpen(
          name: d.name.trim(),
          amount: d.target!,
          amountPerContributor: d.openSplit == OpenSplit.fixed
              ? parseMoney(d.perContributor)
              : null,
          expectedContributors: d.openSplit == OpenSplit.even
              ? int.tryParse(d.expectedContributors.trim())
              : null,
          recurrenceType: d.recurrenceType,
          dayOfWeek: d.recurrenceType == 'weekly' ? d.dayOfWeek : null,
          dayOfMonth: d.recurrenceType == 'monthly' ? d.dayOfMonth : null,
          beneficiaries: d.toBeneficiaryInputs(),
        );
      } else {
        created = await controller.submitClosed(
          name: d.name.trim(),
          amount: d.target!,
          recurrenceType: d.recurrenceType,
          dayOfWeek: d.recurrenceType == 'weekly' ? d.dayOfWeek : null,
          dayOfMonth: d.recurrenceType == 'monthly' ? d.dayOfMonth : null,
          contributors: d.toContributorInputs(),
          beneficiaries: d.toBeneficiaryInputs(),
        );
      }
      if (!mounted) return;
      setState(() {
        _created = created;
        _createdName = d.name.trim();
        _createdTarget = d.target!;
        _createdSchedule = recurrenceSentence(d);
        _submitting = false;
      });
    } on ApiException catch (error) {
      _fail(error.message);
    } on Object catch (error) {
      _fail('$error');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _submitting = false;
      _submitError = message;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _createAnother() {
    ref.invalidate(beelDraftProvider);
    setState(() {
      _step = 0;
      _errors = const {};
      _submitError = null;
      _created = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (created != null) {
      final link = created.paymentLink;
      final isOpen = link.isNotEmpty;
      return Scaffold(
        backgroundColor: BeelsColors.dye,
        body: BeelCreatedView(
          name: _createdName,
          target: _createdTarget,
          schedule: _createdSchedule,
          link: isOpen ? link : null,
          onShare:
              isOpen ? () => Share.share(link, subject: 'Join my beel') : null,
          onView: () {
            if (created.id != null) {
              context.pushReplacement('/beels/${created.id}');
            } else {
              context.go('/beels');
            }
          },
          onAnother: _createAnother,
        ),
      );
    }

    final draft = ref.watch(beelDraftProvider);
    final (title, subtitle) = _titles(draft);
    final last = _step == _stepCount - 1;

    return PopScope(
      canPop: !draft.isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: BeelsColors.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step == 0 ? 'Close' : 'Back',
            icon: Icon(
                _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: const Text('New beel'),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StepHeader(
                      step: _step,
                      total: _stepCount,
                      title: title,
                      subtitle: subtitle,
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutQuart,
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _stepBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _pinned(draft),
            _BottomBar(
              step: _step,
              last: last,
              busy: _submitting,
              onBack: _back,
              onNext: last ? _submit : _next,
            ),
          ],
        ),
      ),
    );
  }

  /// Running total kept in view above the action bar, so the user never
  /// scrolls up to check whether the amounts add up.
  Widget _pinned(BeelDraft draft) {
    num? assigned;
    String? noun;
    if (_step == 2 && !draft.isOpen && draft.sharesEvenly) {
      return _evenSummary(draft);
    }
    if (_step == 2 && !draft.isOpen) {
      assigned = draft.contributorTotal;
      noun = 'assigned';
    } else if (_step == 3 && draft.beneficiaries.length > 1) {
      assigned = draft.payoutTotal;
      noun = 'paid out';
    }
    if (assigned == null || noun == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BeelsColors.panel,
        border: Border(top: BorderSide(color: BeelsColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: AllocationBar(
          assigned: assigned,
          total: draft.target ?? 0,
          noun: noun,
          compact: true,
        ),
      ),
    );
  }

  /// Even mode has nothing to reconcile, so pin what each person pays instead.
  Widget _evenSummary(BeelDraft draft) {
    final shares = draft.evenShares;
    final text = shares.isEmpty
        ? 'Add people to see each share'
        : shares.first == shares.last
            ? '${formatNaira(draft.target ?? 0)} ÷ ${shares.length} = ${formatNaira(shares.first)} each'
            : '${formatNaira(draft.target ?? 0)} ÷ ${shares.length} = about ${formatNaira(shares.last)} each';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BeelsColors.panel,
        border: Border(top: BorderSide(color: BeelsColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Icon(Icons.balance_rounded, size: 18, color: BeelsColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: BeelsColors.ink0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return BasicsStep(errors: _errors, scroller: _scroller);
      case 1:
        return ScheduleStep(now: widget.now);
      case 2:
        return PeopleStep(errors: _errors, scroller: _scroller);
      case 3:
        return PayoutStep(errors: _errors, scroller: _scroller);
      default:
        return ReviewStep(
          onEdit: _goTo,
          submitError: _submitError,
          now: widget.now,
        );
    }
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.last,
    required this.busy,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool last;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BeelsColors.panel,
        border: Border(top: BorderSide(color: BeelsColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            if (step > 0) ...[
              OutlinedButton(
                onPressed: busy ? null : onBack,
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: PrimaryButton(
                label: last ? 'Create beel' : 'Continue',
                loading: busy,
                onPressed: busy ? null : onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
