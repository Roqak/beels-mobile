class Profile {
  const Profile({
    required this.email,
    required this.firstName,
    this.lastName,
    this.phoneNumber,
    this.status,
    this.role,
  });

  final String email;
  final String firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? status;
  final String? role;

  String get fullName => ('$firstName ${lastName ?? ''}').trim();

  String get initials {
    final first = firstName.trim();
    final last = (lastName ?? '').trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final result = (a + b).toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  /// Tolerant parse: unknown keys ignored, snake_case or camelCase accepted,
  /// nullable fields stay nullable. `email`/`firstName` fall back to ''.
  factory Profile.fromJson(dynamic json) {
    final map = json is Map<dynamic, dynamic> ? json : const <dynamic, dynamic>{};
    String readRequired(dynamic value) => value?.toString() ?? '';
    String? readOptional(dynamic value) => value?.toString();
    return Profile(
      email: readRequired(map['email']),
      firstName: readRequired(map['first_name'] ?? map['firstName']),
      lastName: readOptional(map['last_name'] ?? map['lastName']),
      phoneNumber: readOptional(map['phone_number'] ?? map['phoneNumber']),
      status: readOptional(map['status']),
      role: readOptional(map['role']),
    );
  }

  Profile copyWith({
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? status,
    String? role,
  }) {
    return Profile(
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile &&
        other.email == email &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.phoneNumber == phoneNumber &&
        other.status == status &&
        other.role == role;
  }

  @override
  int get hashCode =>
      Object.hash(email, firstName, lastName, phoneNumber, status, role);
}