import 'package:flutter/services.dart';

/// Formats a naira amount as it is typed: `60000` -> `60,000`, keeps one
/// decimal point and at most two decimals, and drops anything else. The saved
/// text still parses with `parseMoney` (commas are stripped there).
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return const TextEditingValue();

    final dot = raw.indexOf('.');
    var whole = dot == -1 ? raw : raw.substring(0, dot);
    var frac = dot == -1 ? null : raw.substring(dot + 1).replaceAll('.', '');
    if (frac != null && frac.length > 2) frac = frac.substring(0, 2);

    // Leading zeros carry no meaning ("007" -> "7"); keep a lone zero.
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty) whole = '0';

    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    final text = frac == null ? buf.toString() : '$buf.$frac';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
