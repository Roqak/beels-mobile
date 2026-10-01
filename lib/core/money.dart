import 'package:intl/intl.dart';

/// The backend stores every money amount as integer kobo. The app speaks
/// naira end to end: models divide on parse (koboToNaira) and payload
/// builders multiply on send (nairaToKobo). Never convert in screens.
final NumberFormat _naira =
    NumberFormat.currency(symbol: '₦', decimalDigits: 0);
final NumberFormat _nairaFractional =
    NumberFormat.currency(symbol: '₦', decimalDigits: 2);

/// Kobo amount from the API -> naira for the model/UI layer. Null-safe and
/// tolerant of fractional input so bad payloads degrade instead of crashing.
num? koboToNaira(dynamic kobo) {
  if (kobo == null) return null;
  final n = kobo is num ? kobo : num.tryParse(kobo.toString());
  return n == null ? null : n / 100;
}

/// Naira amount entered or held by the app -> kobo for the API. Always
/// rounds so float drift can never produce ₦99.999999 of kobo.
int nairaToKobo(num naira) => (naira * 100).round();

/// `₦1,250` — two decimals only when the amount is fractional.
String formatNaira(num amount) {
  final fractional = amount is! int && amount % 1 != 0;
  return (fractional ? _nairaFractional : _naira).format(amount);
}

/// `+₦1,250` for incoming, `−₦1,250` (minus sign, U+2212) for outgoing.
String formatNairaSigned(num amount, {required bool incoming}) {
  final magnitude = formatNaira(amount.abs());
  return incoming ? '+$magnitude' : '−$magnitude';
}
