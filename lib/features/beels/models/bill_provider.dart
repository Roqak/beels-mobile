/// A bills-payment plan (a data bundle or a cable package). Its price is in
/// naira, as the backend lists it.
class BillPlan {
  const BillPlan({this.id = '', this.name = '', this.amount = 0});

  final String id;
  final String name;
  final num amount;

  factory BillPlan.fromJson(dynamic json) {
    if (json is! Map) return const BillPlan();
    final amount = json['amount'];
    return BillPlan(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      amount: amount is num ? amount : num.tryParse('$amount') ?? 0,
    );
  }
}

/// A bills-payment provider: a network (airtime, data), a cable company or an
/// electricity distributor. Airtime and electricity have no plans; the payer
/// chooses the amount.
class BillProvider {
  const BillProvider({this.id = '', this.name = '', this.plans = const []});

  final String id;
  final String name;
  final List<BillPlan> plans;

  factory BillProvider.fromJson(dynamic json) {
    if (json is! Map) return const BillProvider();
    final plans = json['plans'];
    return BillProvider(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      plans: plans is List
          ? plans.map(BillPlan.fromJson).where((p) => p.id.isNotEmpty).toList()
          : const [],
    );
  }
}
