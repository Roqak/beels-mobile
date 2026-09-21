import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beels_mobile/core/api/api_client.dart';
import 'package:beels_mobile/core/api/envelope.dart';
import 'package:beels_mobile/core/providers.dart';
import 'package:beels_mobile/features/groups/models/group.dart';

/// Fresh invite material returned by `POST /groups/:id/invite-link`.
class InviteLink {
  final String token;
  final String url;

  const InviteLink({required this.token, required this.url});

  factory InviteLink.fromJson(dynamic json) {
    final map = json is Map
        ? json.cast<String, dynamic>()
        : const <String, dynamic>{};
    final token = (map['invite_link_token'] ?? map['invite_token'])?.toString();
    return InviteLink(
      token: token ?? '',
      url: (map['invite_link'] ?? map['invite_link_url'])?.toString() ?? '',
    );
  }
}

class GroupsRepository {
  GroupsRepository(this._api);

  final ApiClient _api;

  /// GET /groups — payload is double-nested (`data.data`), parsed tolerantly.
  Future<List<Group>> list() async {
    final res = await _api.get('/groups');
    return envelopeList<Group>(res, Group.fromJson);
  }

  /// GET /groups/:id
  Future<Group> get(int id) async {
    final res = await _api.get('/groups/$id');
    return envelope(res, Group.fromJson);
  }

  /// POST /groups — {name, description?, members?: [{first_name, ...}]}
  Future<Group> create({
    required String name,
    String? description,
    List<GroupMember> members = const [],
  }) async {
    final res = await _api.post('/groups', body: {
      'name': name,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (members.isNotEmpty)
        'members': members.map((m) => m.toCreateJson()).toList(),
    });
    return envelope(res, Group.fromJson);
  }

  /// POST /groups/:id/members — returns the created member.
  Future<GroupMember> addMember(
    int groupId, {
    required String firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
  }) async {
    final member = GroupMember(
      firstName: firstName,
      lastName: lastName ?? '',
      email: email ?? '',
      phoneNumber: phoneNumber,
    );
    final res = await _api.post('/groups/$groupId/members',
        body: member.toCreateJson());
    return envelope(res, GroupMember.fromJson);
  }

  /// DELETE /groups/:id/members/:memberId
  Future<void> removeMember(int groupId, int memberId) async {
    await _api.delete('/groups/$groupId/members/$memberId');
  }

  /// POST /groups/:id/invite-link — fresh token + shareable URL.
  Future<InviteLink> regenerateInvite(int groupId) async {
    final res = await _api.post('/groups/$groupId/invite-link');
    return envelope(res, InviteLink.fromJson);
  }

  /// DELETE /groups/:id
  Future<void> delete(int groupId) async {
    await _api.delete('/groups/$groupId');
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(apiClientProvider));
});

/// All groups of the signed-in organizer.
class GroupsController extends AsyncNotifier<List<Group>> {
  @override
  FutureOr<List<Group>> build() => ref.watch(groupsRepositoryProvider).list();
}

final groupsListProvider =
    AsyncNotifierProvider<GroupsController, List<Group>>(GroupsController.new);

/// A single group, refreshed after mutations.
class GroupDetailController extends FamilyAsyncNotifier<Group, int> {
  @override
  FutureOr<Group> build(int arg) => ref.watch(groupsRepositoryProvider).get(arg);

  Future<void> addMember({
    required String firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
  }) async {
    final member = await ref.read(groupsRepositoryProvider).addMember(
          arg,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phoneNumber: phoneNumber,
        );
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          members: [...current.members, member],
          membersCount: current.members.length + 1,
        ),
      );
    }
  }

  Future<void> removeMember(int memberId) async {
    await ref.read(groupsRepositoryProvider).removeMember(arg, memberId);
    final current = state.valueOrNull;
    if (current != null) {
      final remaining =
          current.members.where((m) => m.id != memberId).toList();
      state = AsyncData(
        current.copyWith(members: remaining, membersCount: remaining.length),
      );
    }
  }

  Future<InviteLink> regenerateInvite() async {
    final link = await ref.read(groupsRepositoryProvider).regenerateInvite(arg);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(inviteToken: link.token, inviteLink: link.url),
      );
    }
    return link;
  }

  Future<void> deleteGroup() async {
    await ref.read(groupsRepositoryProvider).delete(arg);
    ref.invalidate(groupsListProvider);
  }
}

final groupDetailProvider = AsyncNotifierProvider.family<GroupDetailController,
    Group, int>(GroupDetailController.new);