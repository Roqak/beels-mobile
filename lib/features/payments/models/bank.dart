/// A Nigerian bank offered by the backend for mandates and transfers.
class Bank {
  const Bank({
    this.id,
    this.name = '',
    this.cbnCode = '',
    this.nipCode = '',
    this.logoUrl,
  });

  final int? id;
  final String name;

  /// CBN bank code (e.g. `058`) — used for name enquiry.
  final String cbnCode;

  /// NIP sort code used by some transfer endpoints.
  final String nipCode;
  final String? logoUrl;

  factory Bank.fromJson(dynamic json) {
    if (json is! Map) return Bank();
    return Bank(
      id: json['id'] is num ? (json['id'] as num).toInt() : null,
      name: (json['bank_name'] ?? json['name'] ?? '') as String,
      cbnCode: (json['bank_cbn_code'] ?? json['cbn_code'] ?? '') as String,
      nipCode: (json['bank_nip_code'] ?? json['nip_code'] ?? '') as String,
      logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
    );
  }
}