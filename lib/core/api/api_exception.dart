/// Normalized API failure surfaced to the UI layer.
class ApiException implements Exception {
  const ApiException(this.message, {required this.statusCode});

  /// Human-readable message. Validation errors (a list of messages) are
  /// joined with '; '.
  final String message;

  /// HTTP status code, or 0 when the request never reached the server.
  final int statusCode;

  /// Builds an exception from an error response body, tolerating string
  /// messages, lists of validation messages, and a bare `error` field.
  factory ApiException.fromResponse(dynamic json, int statusCode) {
    if (json is Map) {
      final raw = json['message'];
      if (raw is String && raw.trim().isNotEmpty) {
        return ApiException(raw, statusCode: statusCode);
      }
      if (raw is List) {
        final joined =
            raw.whereType<Object>().map((e) => e.toString()).join('; ').trim();
        if (joined.isNotEmpty) {
          return ApiException(joined, statusCode: statusCode);
        }
      }
      final error = json['error'];
      if (error is String && error.trim().isNotEmpty) {
        return ApiException(error, statusCode: statusCode);
      }
    }
    return ApiException(
      'Something went wrong. Please try again.',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
