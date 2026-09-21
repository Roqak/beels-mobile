/// Unwraps the API success envelope `{statusCode, message, data}` and builds
/// the result from `data`.
T envelope<T>(dynamic json, T Function(dynamic) fromData) {
  final data = json is Map ? json['data'] : null;
  return fromData(data);
}

/// Unwraps a list payload, tolerating the groups double-nesting quirk
/// (`data.data`) and a bare list body.
List<R> envelopeList<R>(dynamic json, R Function(dynamic) mapItem) {
  var data = json is Map ? json['data'] : json;
  if (data is Map && data['data'] is List) {
    data = data['data'];
  }
  if (data is List) return data.map<R>(mapItem).toList();
  return <R>[];
}
