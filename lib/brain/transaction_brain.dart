import '../core/format.dart';
import '../data/models.dart';
import 'merchant_hints.dart';

/// What the brain thinks a notification means. Every field is a *suggestion*
/// that the user can edit in the confirmation dialog.
class Suggestion {
  Suggestion({
    required this.isTransaction,
    this.amount,
    this.type = TxnType.expense,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.merchant = '',
    this.confidence = 0,
    this.reasons = const [],
  });

  final bool isTransaction;
  final double? amount;
  final TxnType type;
  final int? accountId;
  final int? toAccountId;
  final int? categoryId;
  final String merchant;

  /// 0..1 — shown in the dialog so you know how much to double check.
  final double confidence;

  /// Human readable explanation of each decision (shown in the Brain playground).
  final List<String> reasons;
}

/// Rule-based, fully on-device classifier that improves from your confirmations.
///
/// Pipeline: filter noise (OTP/promo) → extract amount → decide
/// expense/income/transfer → match account → extract merchant → pick category.
class TransactionBrain {
  TransactionBrain({
    required this.accounts,
    required this.categories,
    this.rules = const {},
  });

  final List<Account> accounts;
  final List<Category> categories;

  /// Learned rules keyed by `m:<merchant>` / `p:<package>`.
  final Map<String, LearnedRule> rules;

  // ---------------------------------------------------------------- patterns
  static const _cur =
      r'(?:rp\.?|idr|usd|us\$|sgd|s\$|myr|\brm|eur|gbp|jpy|inr|php|thb|aud|a\$|[\$€£¥₹₱฿])';
  static final _amountBefore = RegExp('$_cur\\s?(\\d[\\d.,]*\\d|\\d)', caseSensitive: false);
  static final _amountAfter =
      RegExp(r'(\d[\d.,]*\d|\d)\s?(?:idr|usd|rupiah|eur|sgd|myr)\b', caseSensitive: false);
  static final _otp = RegExp(
      r'\b(otp|kode verifikasi|verification code|one[- ]time password|jangan berikan|do not share|kode rahasia|passcode)\b',
      caseSensitive: false);
  static final _moneyVerb = RegExp(
      r'(berhasil|sukses|success|received|diterima|menerima|terima|paid|dibayar|bayar|pembayaran|payment|debit|kredit|credit|transfer|spent|purchase|pembelian|belanja|transaksi|transaction|withdraw|tarik|top ?up|refund|charged|masuk|keluar|dikirim|kirim|sent|gaji|salary|cashback)',
      caseSensitive: false);
  static final _promo = RegExp(
      r'\b(promo|diskon|discount|voucher|kupon|coupon|giveaway|flash sale|gratis|free|up to|hingga|s/d|min\.|minimal|dapatkan|get up|klaim|claim|buruan|hurry|limited)\b',
      caseSensitive: false);
  static final _completed = RegExp(
      r'(berhasil|sukses|successful|success|received|diterima|menerima|telah|has been|have been|was|were|done|completed|paid|dibayar|debited|credited)',
      caseSensitive: false);
  static final _failed = RegExp(r'\b(gagal|failed|declined|ditolak|dibatalkan|cancelled|canceled)\b',
      caseSensitive: false);
  static final _balanceWord = RegExp(
      r'(saldo|balance|sisa|limit|available|tersedia|total tagihan|minimum payment|pembayaran minimum)[^\d]{0,25}$',
      caseSensitive: false);
  static final _creditCard = RegExp(r'(kartu kredit|credit card|\bcc\b|kk\s?\*)', caseSensitive: false);
  static final _topUp = RegExp(r'(top ?up|isi saldo|topup)', caseSensitive: false);
  static final _ccPayment = RegExp(
      r'(pembayaran kartu kredit|bayar kartu kredit|credit card payment|payment to (your )?credit card|pembayaran tagihan kartu)',
      caseSensitive: false);

  static final _incomeWords = <RegExp, double>{
    RegExp(r'\b(received|receive|you got|incoming|credited|credit to|deposit(ed)?)\b', caseSensitive: false): 3,
    RegExp(r'\b(menerima|diterima|terima|dana masuk|transfer masuk|uang masuk|masuk ke rekening|telah masuk)\b',
        caseSensitive: false): 3,
    RegExp(r'\b(refund|cashback|pengembalian|reversal)\b', caseSensitive: false): 2.5,
    RegExp(r'\b(gaji|salary|payroll|bonus|dividen|dividend|bunga|interest)\b', caseSensitive: false): 2.5,
    RegExp(r'\b(dari|from)\b', caseSensitive: false): 0.8,
    RegExp(r'\bmasuk\b', caseSensitive: false): 1,
  };
  static final _expenseWords = <RegExp, double>{
    RegExp(r'\b(paid|payment|pay|spent|purchase|purchased|charged|debited|debit|withdraw(al)?|sent)\b',
        caseSensitive: false): 3,
    RegExp(r'\b(pembayaran|bayar|dibayar|membayar|pembelian|belanja|tarik tunai|penarikan|transfer ke|kirim|mengirim|dikirim|transaksi debit|keluar)\b',
        caseSensitive: false): 3,
    RegExp(r'\b(transaksi|transaction)\b', caseSensitive: false): 1,
    RegExp(r'\b(ke|to|at|di|kepada)\b', caseSensitive: false): 0.6,
  };

  static final _merchantPatterns = <RegExp>[
    RegExp(r'\b(?:merchant|toko|penerima|recipient|beneficiary)\s*[:\-]\s*([^\n,.;]{2,40})', caseSensitive: false),
    RegExp(
        r'\b(?:at|di|to|ke|kepada|from|dari)\s+([A-Za-z0-9][A-Za-z0-9&@\x27._\- ]{1,40}?)(?=\s+(?:on|pada|tgl|tanggal|using|with|via|dengan|telah|has|have|was|is|berhasil|sukses|successful|sebesar|senilai|for|untuk|ref|no\.?|jam|pukul|at)\b|\s*[.,!;\n(]|\s*$)',
        caseSensitive: false),
  ];
  static const _merchantStopWords = {
    'your', 'you', 'rekening', 'account', 'akun', 'kartu', 'card', 'anda', 'kamu', 'saldo',
    'balance', 'the', 'a', 'an', 'my', 'rp', 'idr',
  };

  // ------------------------------------------------------------------- API

  Suggestion analyze({required String text, String packageName = '', String appName = ''}) {
    final reasons = <String>[];
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (_otp.hasMatch(clean)) {
      return Suggestion(isTransaction: false, reasons: ['Looks like an OTP / security code']);
    }
    if (_failed.hasMatch(clean)) {
      return Suggestion(isTransaction: false, reasons: ['Transaction failed / declined']);
    }
    if (_promo.hasMatch(clean) && !_completed.hasMatch(clean)) {
      return Suggestion(isTransaction: false, reasons: ['Looks like a promo / ad']);
    }

    final amount = extractAmount(clean);
    if (amount == null || amount <= 0) {
      return Suggestion(isTransaction: false, reasons: ['No amount found']);
    }
    reasons.add('Amount: ${Money.plain(amount)}');
    if (!_moneyVerb.hasMatch(clean)) {
      return Suggestion(isTransaction: false, amount: amount, reasons: [...reasons, 'No money words found']);
    }

    // --- account
    final isCc = _creditCard.hasMatch(clean);
    final account = _matchAccount(clean, packageName, isCc, reasons);
    var confidence = 0.35;
    if (account != null) confidence += 0.2;

    // --- type
    var type = _classify(clean, isCc || (account?.isCreditCard ?? false), reasons);
    final typeMargin = _lastMargin;
    confidence += (typeMargin.clamp(0, 4) / 4) * 0.25;

    // --- transfer between own accounts (top up e-wallet, pay credit card)
    int? toAccountId;
    if (_topUp.hasMatch(clean) || _ccPayment.hasMatch(clean)) {
      final other = _findOtherAccount(clean, exclude: account?.id, wantCreditCard: _ccPayment.hasMatch(clean));
      if (other != null && account != null) {
        type = TxnType.transfer;
        toAccountId = other.id;
        reasons.add('Transfer to own account "${other.name}"');
      }
    }

    // --- merchant
    final merchant = extractMerchant(clean);
    if (merchant.isNotEmpty) reasons.add('Merchant: $merchant');

    // --- learned merchant rule overrides heuristics
    int? categoryId;
    final mRule = merchant.isEmpty ? null : rules['m:${merchant.toLowerCase()}'];
    if (mRule != null) {
      if (mRule.type != null && toAccountId == null) type = mRule.type!;
      categoryId = mRule.categoryId;
      confidence += 0.15;
      reasons.add('Remembered "$merchant" from ${mRule.hits} past confirmation(s)');
    }
    if (type != TxnType.transfer) {
      categoryId ??= _guessCategory(clean, merchant, type, reasons);
    }

    return Suggestion(
      isTransaction: true,
      amount: amount,
      type: type,
      accountId: account?.id,
      toAccountId: toAccountId,
      categoryId: categoryId,
      merchant: merchant,
      confidence: confidence.clamp(0, 1).toDouble(),
      reasons: reasons,
    );
  }

  /// Picks the transaction amount, skipping "saldo/balance/limit" figures.
  static double? extractAmount(String text) {
    final candidates = <({int pos, double value})>[];
    for (final m in _amountBefore.allMatches(text)) {
      final v = parseLocalizedNumber(m.group(1)!);
      if (v != null) candidates.add((pos: m.start, value: v));
    }
    for (final m in _amountAfter.allMatches(text)) {
      final v = parseLocalizedNumber(m.group(1)!);
      if (v != null && !candidates.any((c) => (c.pos - m.start).abs() < 4)) {
        candidates.add((pos: m.start, value: v));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.pos.compareTo(b.pos));
    for (final c in candidates) {
      final before = text.substring(0, c.pos);
      if (!_balanceWord.hasMatch(before)) return c.value;
    }
    return candidates.first.value;
  }

  static String extractMerchant(String text) {
    // Strip amounts so "ke Rp 50.000" never becomes a merchant.
    final t = text.replaceAll(_amountBefore, ' ').replaceAll(_amountAfter, ' ');
    for (final p in _merchantPatterns) {
      for (final m in p.allMatches(t)) {
        var name = m.group(1)!.trim();
        name = name.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\-:]+$'), '').trim();
        final words = name.toLowerCase().split(' ');
        if (name.length < 2 || _merchantStopWords.contains(words.first)) continue;
        if (RegExp(r'^[\d\s*x/.\-:]+$').hasMatch(name)) continue; // card numbers, dates
        if (RegExp(r'^(rekening|account|kartu|card)\b', caseSensitive: false).hasMatch(name)) continue;
        return _titleCase(name);
      }
    }
    return '';
  }

  // --------------------------------------------------------------- helpers

  double _lastMargin = 0;

  TxnType _classify(String text, bool creditCardContext, List<String> reasons) {
    // "credit card" must not count as "credited".
    final t = text.replaceAll(_creditCard, ' ');
    double inc = 0, exp = 0;
    _incomeWords.forEach((re, w) => inc += re.allMatches(t).length * w);
    _expenseWords.forEach((re, w) => exp += re.allMatches(t).length * w);
    if (creditCardContext && !RegExp(r'refund|reversal|pengembalian', caseSensitive: false).hasMatch(t)) {
      exp += 2; // card notifications are almost always purchases
    }
    _lastMargin = (inc - exp).abs();
    final type = inc > exp ? TxnType.income : TxnType.expense;
    reasons.add('${type == TxnType.income ? "Income" : "Expense"} '
        '(income score ${inc.toStringAsFixed(1)} vs expense ${exp.toStringAsFixed(1)})');
    return type;
  }

  Account? _matchAccount(String text, String pkg, bool isCc, List<String> reasons) {
    final lower = text.toLowerCase();
    final active = accounts.where((a) => !a.archived).toList();
    Account? best;
    double bestScore = 0;
    String why = '';
    final hints = knownFinanceApps[pkg] ?? const [];
    final pRule = rules['p:$pkg'];
    for (final a in active) {
      double s = 0;
      final w = <String>[];
      if (pkg.isNotEmpty && a.packages.contains(pkg)) {
        s += 4;
        w.add('linked app');
      }
      if (a.last4.length >= 3 && RegExp('[*x•.\\s]${RegExp.escape(a.last4)}\\b|ending ${RegExp.escape(a.last4)}|akhiran ${RegExp.escape(a.last4)}', caseSensitive: false).hasMatch(lower)) {
        s += 6;
        w.add('card ••${a.last4}');
      }
      for (final k in a.keywords) {
        if (k.isNotEmpty && RegExp('\\b${RegExp.escape(k.toLowerCase())}\\b').hasMatch(lower)) {
          s += 3;
          w.add('keyword "$k"');
          break;
        }
      }
      final nameWords = a.name.toLowerCase().split(RegExp(r'\s+')).where((e) => e.length >= 3);
      if (nameWords.any((n) => RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(lower) || hints.contains(n))) {
        s += 2;
        w.add('name');
      }
      if (pRule?.accountId == a.id) {
        s += 3;
        w.add('learned from this app');
      }
      if (isCc && a.isCreditCard) s += 1.5;
      if (!isCc && a.isCreditCard && s > 0) s -= 1;
      if (s > bestScore) {
        bestScore = s;
        best = a;
        why = w.join(', ');
      }
    }
    if (best != null && bestScore >= 2) {
      reasons.add('Account: ${best.name} ($why)');
      return best;
    }
    reasons.add('Account: not sure — please pick');
    return null;
  }

  Account? _findOtherAccount(String text, {int? exclude, bool wantCreditCard = false}) {
    final lower = text.toLowerCase();
    for (final a in accounts.where((a) => !a.archived && a.id != exclude)) {
      if (wantCreditCard && !a.isCreditCard) continue;
      final words = [...a.keywords, ...a.name.split(RegExp(r'\s+')).where((e) => e.length >= 3)];
      if (words.any((k) => k.isNotEmpty && RegExp('\\b${RegExp.escape(k.toLowerCase())}\\b').hasMatch(lower))) {
        return a;
      }
      if (a.last4.length >= 3 && lower.contains(a.last4)) return a;
    }
    return null;
  }

  int? _guessCategory(String text, String merchant, TxnType type, List<String> reasons) {
    final hay = '${merchant.toLowerCase()} ${text.toLowerCase()}';
    final candidates = categories.where((c) => c.type == type && !c.excludeFromStats);
    for (final entry in categoryKeywords.entries) {
      final cat = candidates.where((c) => c.name == entry.key).firstOrNull;
      if (cat == null) continue;
      final hit = entry.value.firstWhere((k) => hay.contains(k), orElse: () => '');
      if (hit.isNotEmpty) {
        reasons.add('Category: ${cat.name} (matched "${hit.trim()}")');
        return cat.id;
      }
    }
    final fallback = candidates.where((c) => c.name == 'Other').firstOrNull ?? candidates.firstOrNull;
    if (fallback != null) reasons.add('Category: ${fallback.name} (default)');
    return fallback?.id;
  }

  static String _titleCase(String s) {
    // Keep ALL-CAPS short words (BCA, PLN) but tidy SHOUTED merchant names.
    return s.split(' ').map((w) {
      if (w.length <= 3 && w.toUpperCase() == w) return w;
      if (w.toUpperCase() == w || w.toLowerCase() == w) {
        return w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
      }
      return w;
    }).join(' ');
  }
}
