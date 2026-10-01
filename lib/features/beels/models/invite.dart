import '../../../core/config.dart';
import '../../../core/money.dart';

// Tolerant JSON helpers — same convention as the other model files: nullable
// fields stay nullable, unknown keys are ignored, numbers accept int/double/
// String input.

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _nullableString(dynamic value) => value?.toString();

int? _nullableInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _nullableDate(dynamic value) {
  if (value is DateTime) return value;
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// An invite created for a beel, as returned by POST /contributions/:id/invites.
///
/// `shareAmount` is stored in kobo by the API and converted to naira here —
/// models divide on parse, never in screens.
class BeelInvite {
  const BeelInvite({
    required this.token,
    required this.joinUrl,
    this.shareAmount,
    this.maxUses,
    this.expiresAt,
    this.slotsLeft,
  });

  final String token;

  /// Absolute web link the friend taps/opens; rebuilt locally when the
  /// backend omits or truncates it.
  final String joinUrl;
  final num? shareAmount;
  final int? maxUses;
  final DateTime? expiresAt;
  final int? slotsLeft;

  factory BeelInvite.fromJson(dynamic json) {
    final map = _asMap(json);
    final url = _nullableString(map['join_url']) ?? '';
    return BeelInvite(
      token: _nullableString(map['token']) ?? '',
      joinUrl: url.isEmpty
          ? beelInviteJoinLink(_nullableString(map['token']) ?? '')
          : url,
      shareAmount: koboToNaira(map['share_amount']),
      maxUses: _nullableInt(map['max_uses']),
      expiresAt: _nullableDate(map['expires_at']),
      slotsLeft: _nullableInt(map['slots_left']),
    );
  }

  /// True once every slot has been used up.
  bool get exhausted {
    final left = slotsLeft;
    return left != null && left <= 0;
  }

  /// True once [expiresAt] has passed.
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

/// Public preview of an invite, as returned by GET /invites/:token. Enough
/// for the friend to decide whether to join without authenticating first.
class InvitePreview {
  const InvitePreview({
    required this.beelName,
    required this.organizerFirstName,
    required this.organizerLastName,
    this.recurrenceType,
    this.nextOccurrence,
    this.amountPerContributor,
    this.shareAmount,
    this.slotsLeft,
  });

  final String beelName;
  final String organizerFirstName;
  final String organizerLastName;
  final String? recurrenceType;
  final DateTime? nextOccurrence;
  final num? amountPerContributor;
  final num? shareAmount;
  final int? slotsLeft;

  /// "Chuka O." style organizer label.
  String get organizerLabel {
    final last = organizerLastName;
    final name = last.isEmpty
        ? organizerFirstName
        : '$organizerFirstName ${last[0]}.';
    return name.isEmpty ? 'the organizer' : name;
  }

  factory InvitePreview.fromJson(dynamic json) {
    final map = _asMap(json);
    final beel = _asMap(map['beel']);
    final organizer = _asMap(map['organizer']);
    return InvitePreview(
      beelName: _nullableString(beel['name']) ?? '',
      organizerFirstName: _nullableString(organizer['first_name']) ?? '',
      organizerLastName: _nullableString(organizer['last_name']) ?? '',
      recurrenceType: _nullableString(beel['recurrence_type']),
      nextOccurrence: _nullableDate(beel['next_occurrence']),
      amountPerContributor: koboToNaira(beel['amount_per_contributor']),
      shareAmount: koboToNaira(map['share_amount']),
      slotsLeft: _nullableInt(map['slots_left']),
    );
  }
}

/// Result of POST /invites/:token/accept.
class InviteAcceptResult {
  const InviteAcceptResult({
    required this.contributorId,
    required this.beelName,
    this.unitAmount,
    this.firstName,
    this.slotsLeft,
  });

  final int? contributorId;
  final String beelName;
  final num? unitAmount;
  final String? firstName;
  final int? slotsLeft;

  factory InviteAcceptResult.fromJson(dynamic json) {
    final map = _asMap(json);
    final contributor = _asMap(map['contributor']);
    return InviteAcceptResult(
      contributorId: _nullableInt(contributor['id']),
      unitAmount: koboToNaira(contributor['unit_amount']),
      firstName: _nullableString(contributor['first_name']),
      beelName: _nullableString(map['beel_name']) ?? '',
      slotsLeft: _nullableInt(map['slots_left']),
    );
  }
}

/// Web link a friend opens (by tap or browser) to join a beel invite.
String beelInviteJoinLink(String token) =>
    '${AppConfig.frontendBaseUrl}/join/$token';

/// The invite token inside a join link URI, or null when [uri] is not a
/// Beels join link. Only the deployed frontend host is honoured so links
/// from other sites can never land on the join route.
String? joinTokenFromUri(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length != 2 || segments[0] != 'join') return null;
  final host = Uri.parse(AppConfig.frontendBaseUrl).host.toLowerCase();
  if (uri.host.toLowerCase() != host) return null;
  final token = segments[1];
  return token.isEmpty ? null : token;
}