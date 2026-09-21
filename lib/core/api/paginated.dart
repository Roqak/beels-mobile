/// Laravel-style paginated envelope: `{data: [...], current_page, per_page,
/// total, last_page}`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasMore => page < lastPage && items.isNotEmpty;

  /// Parses a paginated envelope, tolerating int/double/String numbers, a
  /// missing payload, and the groups `data.data` double-nesting quirk.
  static Paginated<R> parse<R>(dynamic json, R Function(dynamic) mapItem) {
    final map = json is Map ? json : null;
    var rawItems = map?['data'];
    if (rawItems is Map && rawItems['data'] is List) {
      rawItems = rawItems['data'];
    }
    final items = rawItems is List ? rawItems.map<R>(mapItem).toList() : <R>[];
    return Paginated<R>(
      items: items,
      page: _asInt(map?['current_page']),
      perPage: _asInt(map?['per_page']),
      total: _asInt(map?['total']),
      lastPage: _asInt(map?['last_page']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
