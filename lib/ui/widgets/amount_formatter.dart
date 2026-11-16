import 'package:flutter/services.dart';

import '../../core/format.dart';

/// Adds the thousands separator every 3 digits while typing (1250000 → 1.250.000),
/// keeping the cursor in place.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({String? group, String? decimal})
    : group = group ?? Money.groupSeparator,
      decimal = decimal ?? Money.decimalSeparator;

  final String group;
  final String decimal;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var cursor = newValue.selection.isValid
        ? newValue.selection.end
        : text.length;

    final typedOne = text.length == oldValue.text.length + 1 && cursor > 0;
    final deletedOne =
        text.length == oldValue.text.length - 1 &&
        newValue.selection.isCollapsed;

    if (typedOne && group != decimal && text[cursor - 1] == group) {
      // The separator is inserted automatically, so a typed one means "decimal" (1.5jt → 1,5jt).
      text = text.replaceRange(cursor - 1, cursor, decimal);
    } else if (deletedOne &&
        cursor < oldValue.text.length &&
        oldValue.text[cursor] == group &&
        cursor > 0) {
      // Backspace over a separator removes the digit before it instead of doing nothing.
      text = text.replaceRange(cursor - 1, cursor, '');
      cursor -= 1;
    }

    final significantBefore = text
        .substring(0, cursor.clamp(0, text.length))
        .replaceAll(group, '')
        .length;
    final formatted = groupDigits(text, group, decimal);

    var pos = 0, seen = 0;
    while (pos < formatted.length && seen < significantBefore) {
      if (formatted[pos] != group) seen++;
      pos++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}
