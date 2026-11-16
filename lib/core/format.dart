import 'package:intl/intl.dart';

class CurrencyConfig {
  const CurrencyConfig(this.code, this.symbol, this.decimals, this.locale);
  final String code;
  final String symbol;
  final int decimals;
  final String locale;

  static const presets = <CurrencyConfig>[
    CurrencyConfig('IDR', 'Rp', 0, 'id_ID'),
    CurrencyConfig('USD', '\$', 2, 'en_US'),
    CurrencyConfig('EUR', '€', 2, 'de_DE'),
    CurrencyConfig('GBP', '£', 2, 'en_GB'),
    CurrencyConfig('SGD', 'S\$', 2, 'en_SG'),
    CurrencyConfig('MYR', 'RM', 2, 'ms_MY'),
    CurrencyConfig('AUD', 'A\$', 2, 'en_AU'),
    CurrencyConfig('JPY', '¥', 0, 'ja_JP'),
    CurrencyConfig('INR', '₹', 2, 'en_IN'),
    CurrencyConfig('PHP', '₱', 2, 'en_PH'),
    CurrencyConfig('THB', '฿', 2, 'th_TH'),
  ];

  static CurrencyConfig byCode(String? code) =>
      presets.firstWhere((c) => c.code == code, orElse: () => presets.first);
}

/// Global money formatter; updated when the user changes currency in settings.
class Money {
  static CurrencyConfig config = CurrencyConfig.presets.first;

  static String format(double v, {bool signed = false, bool compact = false}) {
    final sign = v < 0 ? '-' : (signed && v > 0 ? '+' : '');
    final abs = v.abs();
    if (compact && abs >= 1000) {
      final f = NumberFormat.compact(locale: config.locale);
      return '$sign${config.symbol}${f.format(abs)}';
    }
    final f = NumberFormat.currency(
      locale: config.locale,
      symbol: '',
      decimalDigits: config.decimals,
    );
    return '$sign${config.symbol}${f.format(abs).trim()}';
  }

  static String plain(double v) {
    final f = NumberFormat.decimalPatternDigits(locale: config.locale, decimalDigits: config.decimals);
    return f.format(v);
  }
}

/// Parses a number written the way humans write money, in any locale:
/// `1.250.000,50`, `1,250,000.50`, `1.500`, `12,5`, `25k`, `1.5jt`, `10rb`, `2m`.
/// Supports `+`/`-` so `25k+12k` works in the amount field. Returns null if unparseable.
double? parseAmountInput(String input) {
  final s = input.toLowerCase().replaceAll(RegExp(r'[^0-9.,+\-kmbjtr ]'), '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  final parts = RegExp(r'[+\-]?[^+\-]+').allMatches(s).map((m) => m.group(0)!).toList();
  if (parts.isEmpty) return null;
  double total = 0;
  for (var p in parts) {
    var sign = 1.0;
    if (p.startsWith('-')) {
      sign = -1;
      p = p.substring(1);
    } else if (p.startsWith('+')) {
      p = p.substring(1);
    }
    var mult = 1.0;
    final suffix = RegExp(r'(k|rb|ribu|jt|juta|m|mio|b|bn|t)$').firstMatch(p);
    if (suffix != null) {
      mult = switch (suffix.group(1)) {
        'k' || 'rb' || 'ribu' => 1e3,
        'jt' || 'juta' || 'm' || 'mio' => 1e6,
        'b' || 'bn' => 1e9,
        't' => 1e12,
        _ => 1,
      };
      p = p.substring(0, suffix.start);
    }
    final n = parseLocalizedNumber(p, preferDecimal: mult > 1);
    if (n == null) return null;
    total += sign * n * mult;
  }
  return total;
}

/// Decides whether `.` / `,` are thousands or decimal separators.
/// When [preferDecimal] (e.g. "1.5jt"), a single separator is always decimal.
double? parseLocalizedNumber(String raw, {bool preferDecimal = false}) {
  var s = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
  s = s.replaceAll(RegExp(r'[.,]+$'), '');
  if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String normalized;
  if (lastDot >= 0 && lastComma >= 0) {
    final decimalSep = lastDot > lastComma ? '.' : ',';
    final thousandSep = decimalSep == '.' ? ',' : '.';
    normalized = s.replaceAll(thousandSep, '').replaceAll(decimalSep, '.');
  } else if (lastDot >= 0 || lastComma >= 0) {
    final sep = lastDot >= 0 ? '.' : ',';
    final count = sep.allMatches(s).length;
    final after = s.length - s.lastIndexOf(sep) - 1;
    if (count > 1) {
      normalized = s.replaceAll(sep, '');
    } else if (preferDecimal || after != 3) {
      normalized = s.replaceAll(sep, '.');
    } else {
      normalized = s.replaceAll(sep, '');
    }
  } else {
    normalized = s;
  }
  return double.tryParse(normalized);
}

String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);
String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, d MMM yyyy').format(d);
}

String timeLabel(DateTime d) => DateFormat('HH:mm').format(d);
