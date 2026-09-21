import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../data/beels_repository.dart';
import '../models/contribution.dart';

/// Cumulative state for the paginated beels list.
class BeelsListState {
  const BeelsListState({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<Contribution> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

/// Paginated list of the organizer's beels with infinite scroll support.
class BeelsListController extends AsyncNotifier<BeelsListState> {
  static const perPage = 20;

  bool _loadingMore = false;

  @override
  Future<BeelsListState> build() async {
    final page = await ref
        .watch(beelsRepositoryProvider)
        .list(page: 1, perPage: perPage);
    return _fromPaginated(page);
  }

  BeelsListState _fromPaginated(Paginated<Contribution> page) => BeelsListState(
        items: page.items,
        page: page.page,
        lastPage: page.lastPage,
        total: page.total,
      );

  /// Reloads the first page, keeping current data visible while refreshing.
  Future<void> refresh() async {
    state = const AsyncLoading<BeelsListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return _fromPaginated(
        await ref.read(beelsRepositoryProvider).list(page: 1, perPage: perPage),
      );
    });
  }

  /// Appends the next page when one exists. No-op while another load runs.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _loadingMore || !current.hasMore) return;
    _loadingMore = true;
    try {
      final next = await ref
          .read(beelsRepositoryProvider)
          .list(page: current.page + 1, perPage: perPage);
      if (state.valueOrNull == null) return;
      state = AsyncData(BeelsListState(
        items: [...current.items, ...next.items],
        page: next.page,
        lastPage: next.lastPage,
        total: next.total,
      ));
    } on Object catch (error, stackTrace) {
      // Keep the loaded pages on screen; only fail when the list is empty.
      if (current.items.isEmpty) {
        state = AsyncError<BeelsListState>(error, stackTrace);
      }
    } finally {
      _loadingMore = false;
    }
  }
}

final beelsListControllerProvider =
    AsyncNotifierProvider<BeelsListController, BeelsListState>(
        BeelsListController.new);

/// A single beel with contributors and beneficiaries.
class BeelDetailController extends FamilyAsyncNotifier<Contribution, int> {
  @override
  FutureOr<Contribution> build(int arg) {
    return ref.watch(beelsRepositoryProvider).get(arg);
  }

  /// Reloads the beel, keeping current data visible while refreshing.
  Future<void> refresh() async {
    state = const AsyncLoading<Contribution>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(beelsRepositoryProvider).get(arg),
    );
  }

  /// Cancels the beel, then refreshes. Throws on failure.
  Future<void> cancelBeel() async {
    await ref.read(beelsRepositoryProvider).cancel(arg);
    await refresh();
  }

  /// Retries a failed beel, then refreshes. Throws on failure.
  Future<void> retry() async {
    await ref.read(beelsRepositoryProvider).retry(arg);
    await refresh();
  }

  /// Removes a contributor, then refreshes. Throws on failure.
  Future<void> removeContributor(int contributorId) async {
    await ref.read(beelsRepositoryProvider).removeContributor(contributorId);
    await refresh();
  }

  /// Disburses to a beneficiary, then refreshes. Throws on failure.
  Future<void> disburse(int beneficiaryId) async {
    await ref.read(beelsRepositoryProvider).disburse(
          contributionId: arg,
          beneficiaryId: beneficiaryId,
        );
    await refresh();
  }
}

final beelDetailControllerProvider =
    AsyncNotifierProvider.family<BeelDetailController, Contribution, int>(
        BeelDetailController.new);

/// Submits new beels (closed and open-link modes).
class CreateBeelController extends AsyncNotifier<Contribution?> {
  @override
  FutureOr<Contribution?> build() => null;

  /// Creates a closed beel. Returns the created beel (no id — the backend
  /// response omits it) or rethrows on failure.
  Future<Contribution> submitClosed({
    required String name,
    required num amount,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<ContributorInput> contributors,
    required List<BeneficiaryInput> beneficiaries,
  }) async {
    state = const AsyncLoading();
    try {
      final created = await ref.read(beelsRepositoryProvider).create(
            name: name,
            amount: amount,
            recurrenceType: recurrenceType,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth,
            contributors: contributors,
            beneficiaries: beneficiaries,
          );
      ref.invalidate(beelsListControllerProvider);
      state = AsyncData(created);
      return created;
    } on Object {
      state = const AsyncData(null);
      rethrow;
    }
  }

  /// Creates an open-link beel. Returns the created beel with its id and
  /// payment link token, or rethrows on failure.
  Future<Contribution> submitOpen({
    required String name,
    required num amount,
    num? amountPerContributor,
    int? expectedContributors,
    required String recurrenceType,
    String? dayOfWeek,
    int? dayOfMonth,
    required List<BeneficiaryInput> beneficiaries,
  }) async {
    state = const AsyncLoading();
    try {
      final created = await ref.read(beelsRepositoryProvider).createOpen(
            name: name,
            amount: amount,
            amountPerContributor: amountPerContributor,
            expectedContributors: expectedContributors,
            recurrenceType: recurrenceType,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth,
            beneficiaries: beneficiaries,
          );
      ref.invalidate(beelsListControllerProvider);
      state = AsyncData(created);
      return created;
    } on Object {
      state = const AsyncData(null);
      rethrow;
    }
  }
}

final createBeelControllerProvider =
    AsyncNotifierProvider<CreateBeelController, Contribution?>(
        CreateBeelController.new);
