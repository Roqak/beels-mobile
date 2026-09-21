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

  /// Switches between even shares and typed amounts. Going to custom copies
  /// the current even shares into each person so they can be adjusted.
  void setContributorSplit(ContributorSplit mode) {
    if (mode == state.contributorSplit) return;
    if (mode == ContributorSplit.custom) {
      final shares = state.evenShares;
      _set(state.copyWith(
        contributorSplit: mode,
        contributors: [
          for (var i = 0; i < state.contributors.length; i++)
            state.contributors[i].copyWith(
              amount: i < shares.length ? _text(shares[i]) : '',
            ),
        ],
      ));
      return;
    }
    _set(state.copyWith(contributorSplit: mode));
  }

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

  /// Adds a new person (id < 0) or replaces an existing one; returns the id.
  int upsertContributor(DraftContributor person) {
    if (person.id >= 0 && state.contributors.any((c) => c.id == person.id)) {
      _set(state.copyWith(contributors: [
        for (final c in state.contributors) c.id == person.id ? person : c,
      ]));
      return person.id;
    }
    final id = state.nextId;
    _set(state.copyWith(
      contributors: [
        ...state.contributors,
        DraftContributor(
          id: id,
          firstName: person.firstName,
          lastName: person.lastName,
          email: person.email,
          phone: person.phone,
          amount: person.amount,
        ),
      ],
      nextId: id + 1,
    ));
    return id;
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

  /// Adds a new account (id < 0) or replaces an existing one. When a second
  /// account joins a lone account that was implicitly taking everything, that
  /// first account is given what is left so the two still add up.
  int upsertBeneficiary(DraftBeneficiary account) {
    if (account.id >= 0 && state.beneficiaries.any((b) => b.id == account.id)) {
      _set(state.copyWith(beneficiaries: [
        for (final b in state.beneficiaries) b.id == account.id ? account : b,
      ]));
      return account.id;
    }
    final id = state.nextId;
    final added = DraftBeneficiary(
      id: id,
      type: account.type,
      name: account.name,
      accountNumber: account.accountNumber,
      bankCode: account.bankCode,
      bankName: account.bankName,
      serviceNumber: account.serviceNumber,
      serviceIdentifier: account.serviceIdentifier,
      amount: account.amount,
    );
    var existing = state.beneficiaries;
    final target = state.target;
    if (existing.length == 1 &&
        existing.first.wantsAmount &&
        existing.first.amount.trim().isEmpty &&
        target != null) {
      final taken = parseMoney(added.amount) ?? 0;
      final rest = target - taken;
      if (rest > 0) {
        existing = [existing.first.copyWith(amount: _text(rest))];
      }
    }
    _set(state.copyWith(beneficiaries: [...existing, added], nextId: id + 1));
    return id;
  }

  /// Gives every amount-carrying account an equal share of the target.
  void splitBeneficiariesEvenly() {
    final target = state.target;
    final rows = state.beneficiaries.where((b) => b.wantsAmount).toList();
    if (target == null || target <= 0 || rows.isEmpty) return;
    final parts = splitEvenly(target, rows.length);
    var i = 0;
    _set(state.copyWith(beneficiaries: [
      for (final b in state.beneficiaries)
        b.wantsAmount ? b.copyWith(amount: _text(parts[i++])) : b,
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
