import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upme/core/format.dart';
import 'package:upme/ui/widgets/amount_formatter.dart';

/// Types [keys] one at a time at the cursor (`<` = backspace), like a keyboard would.
TextEditingValue type(AmountInputFormatter f, String keys, {TextEditingValue? start}) {
  var v = start ?? TextEditingValue.empty;
  for (final k in keys.split('')) {
    final c = v.selection.isValid ? v.selection.end : v.text.length;
    final next = k == '<'
        ? TextEditingValue(
            text: v.text.replaceRange(c - 1, c, ''), selection: TextSelection.collapsed(offset: c - 1))
        : TextEditingValue(
            text: v.text.replaceRange(c, c, k), selection: TextSelection.collapsed(offset: c + 1));
    v = f.formatEditUpdate(v, next);
  }
  return v;
}

void main() {
  final idr = AmountInputFormatter(group: '.', decimal: ',');
  final usd = AmountInputFormatter(group: ',', decimal: '.');

  test('groups every 3 digits while typing (IDR)', () {
    expect(type(idr, '1250000').text, '1.250.000');
    expect(type(idr, '1250000').selection.end, 9);
    expect(type(idr, '999').text, '999');
    expect(type(idr, '1000').text, '1.000');
  });

  test('groups with comma for USD and keeps decimals', () {
    expect(type(usd, '1250000.5').text, '1,250,000.5');
    expect(type(usd, '12.50').text, '12.50');
  });

  test('shortcuts and math still work', () {
    expect(type(idr, '25000+12500').text, '25.000+12.500');
    expect(type(idr, '25k').text, '25k');
    expect(type(idr, '1.5jt').text, '1,5jt'); // typed "." becomes the decimal ","
    expect(parseAmountInput('1,5jt', groupSep: '.', decimalSep: ','), 1500000);
    expect(parseAmountInput('25.000+12.500', groupSep: '.', decimalSep: ','), 37500);
    expect(parseAmountInput('1.250.000,50', groupSep: '.', decimalSep: ','), 1250000.5);
    expect(parseAmountInput('1,250.5', groupSep: ',', decimalSep: '.'), 1250.5);
  });

  test('backspace over a separator deletes the digit before it', () {
    final v = type(idr, '1000<');
    expect(v.text, '100');
    final v2 = type(idr, '1000');
    // Cursor right after the dot: "1.|000"
    final at = TextEditingValue(text: v2.text, selection: const TextSelection.collapsed(offset: 2));
    expect(type(idr, '<', start: at).text, '000'.replaceFirst(RegExp(r'^0+(?=\d)'), ''));
  });

  test('editing in the middle keeps the cursor next to the typed digit', () {
    final start = TextEditingValue(text: '1.000', selection: const TextSelection.collapsed(offset: 1));
    final v = type(idr, '2', start: start); // "12000"
    expect(v.text, '12.000');
    expect(v.selection.end, 2);
  });

  test('Money.input formats initial values', () {
    Money.config = CurrencyConfig.byCode('IDR');
    expect(Money.input(1250000), '1.250.000');
    Money.config = CurrencyConfig.byCode('USD');
    expect(Money.input(1250.5), '1,250.50');
    Money.config = CurrencyConfig.byCode('IDR');
  });
}
