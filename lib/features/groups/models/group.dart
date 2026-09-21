import 'package:beels_mobile/core/config.dart';

/// A contact group owned by the organizer.
///
/// Tolerant fromJson: unknown keys ignored, numeric fields accept
/// int/double/String, `invite_link` falls back to a link built from
/// `invite_token`/`invite_link_token`.
class Group {
  final int id;
  final String name;
  final String? description;
  final String? inviteToken;
  final String? inviteLink;
  final int membersCount;
  final List<GroupMember> members;
  final DateTime? createdAt;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.inviteToken,
    this.inviteLink,
    required this.membersCount,
    required this.members,
    this.createdAt,
  });

  factory Group.fromJson(dynamic json) {
    final map = _asMap(json);
    final token = _asString(map['invite_link_token'] ?? map['invite_token']);
    final rawLink = _asString(map['invite_link']);
    final link = (rawLink == null || rawLink.isEmpty)
        ? _buildInviteLink(token)
        : rawLink;
    final members = _asList(map['members'])
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => GroupMember.fromJson(m))
        .toList();
    final countRaw = map['members_count'];
    return Group(
      id: _toInt(map['id']),
      name: _asString(map['name']) ?? '',
      description: _asString(map['description']),
      inviteToken: token,
      inviteLink: link,
      membersCount: countRaw == null ? members.length : _toInt(countRaw),
      members: members,
      createdAt: _toDate(map['created_at'] ?? map['createdAt']),
    );
  }

  static String? _buildInviteLink(String? token) {
    if (token == null || token.isEmpty) return null;
    return '${AppConfig.frontendBaseUrl}/groups/join/$token';
  }

  Group copyWith({
    int? id,
    String? name,
    String? description,
    String? inviteToken,
    String? inviteLink,
    int? membersCount,
    List<GroupMember>? members,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteToken: inviteToken ?? this.inviteToken,
      inviteLink: inviteLink ?? this.inviteLink,
      membersCount: membersCount ?? this.membersCount,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.inviteToken == inviteToken &&
          other.inviteLink == inviteLink &&
          other.membersCount == membersCount &&
          other.createdAt == createdAt &&
          _listEquals(other.members, members);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        inviteToken,
        inviteLink,
        membersCount,
        Object.hashAll(members),
        createdAt,
      );
}

/// A member of a contact group.
class GroupMember {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;

  const GroupMember({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
  });

  factory GroupMember.fromJson(dynamic json) {
    final map = _asMap(json);
    return GroupMember(
      id: map['id'] == null ? null : _toInt(map['id']),
      firstName: _asString(map['first_name'] ?? map['firstName']) ?? '',
      lastName: _asString(map['last_name'] ?? map['lastName']) ?? '',
      email: _asString(map['email']) ?? '',
      phoneNumber: _asString(map['phone_number'] ?? map['phoneNumber']),
    );
  }

  String get fullName =>
      [firstName, lastName].where((part) => part.isNotEmpty).join(' ');

  /// Payload for create/add-member endpoints; nulls omitted.
  Map<String, dynamic> toCreateJson() {
    return {
      'first_name': firstName,
      if (lastName.isNotEmpty) 'last_name': lastName,
      if (email.isNotEmpty) 'email': email,
      if (phoneNumber != null && phoneNumber!.isNotEmpty)
        'phone_number': phoneNumber,
    };
  }

  GroupMember copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
  }) {
    return GroupMember(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          other.id == id &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.email == email &&
          other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(id, firstName, lastName, email, phoneNumber);
}

Map<String, dynamic> _asMap(dynamic json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) return json.cast<String, dynamic>();
  return const {};
}

List<dynamic> _asList(dynamic json) {
  if (json is List) return json;
  return const [];
}

String? _asString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  }
  return fallback;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

bool _listEquals(List<GroupMember> a, List<GroupMember> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
