import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contacts/contact_picker.dart';
import 'beel_draft.dart';

/// Holds the beel being created. Auto-disposed, so leaving the flow discards
/// the draft; steps read it with `ref.watch` and change it through here.
class BeelDraftController extends AutoDisposeNotifier<BeelDraft> {
  @override
  BeelDraft build() => const BeelDraft(
        // Everyone needs at least one payout, so start with one.
        beneficiaries: [DraftBeneficiary(id: 0)],
        nextId: 1,
      );

  void _set(BeelDraft next) => state = next;

  // -- basics -------------------------------------------------------------

  void setMode(BeelMode mode) => _set(state.copyWith(mode: mode));
  void setName(String v) => _set(state.copyWith(name: v));
  void setAmount(String v) => _set(state.copyWith(amount: v));

  // -- schedule -----------------------------------------------------------

  void setRecurrence(String v) => _set(state.copyWith(recurrenceType: v));
  void setDayOfWeek(String v) => _set(state.copyWith(dayOfWeek: v));
  void setDayOfMonth(int v) => _set(state.copyWith(dayOfMonth: v));

  // -- people (open) ------------------------------------------------------

  void setOpenSplit(OpenSplit v) => _set(state.copyWith(openSplit: v));
  void setPerContributor(String v) => _set(state.copyWith(perContributor: v));
  void setExpected(String v) => _set(state.copyWith(expectedContributors: v));

  // -- people (closed) ----------------------------------------------------

  /// Adds a blank person, or one prefilled from a picked contact. Returns the
  /// new person's id so the UI can expand it.
  int addContributor([PickedContact? contact]) {
    final id = state.nextId;
    final person = DraftContributor(
      id: id,
      firstName: contact?.firstName ?? '',
      lastName: contact?.lastName ?? '',
      email: contact?.email ?? '',
      phone: contact?.phone ?? '',
    );
    _set(state.copyWith(
      contributors: [...state.contributors, person],
      nextId: id + 1,
    ));
    return id;
  }

  void updateContributor(
      int id, DraftContributor Function(DraftContributor) f) {
    _set(state.copyWith(contributors: [
      for (final c in state.contributors) c.id == id ? f(c) : c,
    ]));
  }

  void removeContributor(int id) => _set(state.copyWith(
        contributors: [
          for (final c in state.contributors)
            if (c.id != id) c,
        ],
      ));

  /// Gives everyone an equal share of the target, to the kobo.
  void splitContributorsEvenly() {
    final target = state.target;
    final people = state.contributors;
    if (target == null || target <= 0 || people.isEmpty) return;
    final parts = splitEvenly(target, people.length);
    _set(state.copyWith(contributors: [
      for (var i = 0; i < people.length; i++)
        people[i].copyWith(amount: _text(parts[i])),
    ]));
  }

  // -- payout -------------------------------------------------------------

  int addBeneficiary() {
    final id = state.nextId;
    _set(state.copyWith(
      beneficiaries: [...state.beneficiaries, DraftBeneficiary(id: id)],
      nextId: id + 1,
    ));
    return id;
  }

  void updateBeneficiary(
      int id, DraftBeneficiary Function(DraftBeneficiary) f) {
    _set(state.copyWith(beneficiaries: [
      for (final b in state.beneficiaries) b.id == id ? f(b) : b,
    ]));
  }

  void removeBeneficiary(int id) => _set(state.copyWith(
        beneficiaries: [
          for (final b in state.beneficiaries)
            if (b.id != id) b,
        ],
      ));

  static String _text(num n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(2);
}

final beelDraftProvider =
    NotifierProvider.autoDispose<BeelDraftController, BeelDraft>(
  BeelDraftController.new,
);
