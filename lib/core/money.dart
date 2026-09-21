import 'package:intl/intl.dart';

final NumberFormat _naira =
    NumberFormat.currency(symbol: '₦', decimalDigits: 0);
final NumberFormat _nairaFractional =
    NumberFormat.currency(symbol: '₦', decimalDigits: 2);

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
