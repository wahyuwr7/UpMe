import 'package:material_ui/material_ui.dart';

enum TxnType { expense, income, transfer }

/// Every icon a category may use (stored by code point in the DB).
const categoryIcons = <IconData>[
  Icons.restaurant, Icons.local_cafe, Icons.shopping_basket, Icons.shopping_bag, Icons.directions_car,
  Icons.two_wheeler, Icons.local_gas_station, Icons.receipt_long, Icons.bolt, Icons.wifi, Icons.phone_android,
  Icons.home, Icons.movie, Icons.sports_esports, Icons.fitness_center, Icons.local_hospital, Icons.school,
  Icons.flight, Icons.pets, Icons.child_care, Icons.card_giftcard, Icons.volunteer_activism, Icons.work,
  Icons.storefront, Icons.trending_up, Icons.savings, Icons.redeem, Icons.replay, Icons.percent,
  Icons.handshake, Icons.tune, Icons.more_horiz,
];

enum AccountType {
  cash('Cash', Icons.payments_outlined),
  bank('Bank', Icons.account_balance_outlined),
  eWallet('E-Wallet', Icons.account_balance_wallet_outlined),
  creditCard('Credit Card', Icons.credit_card),
  other('Other', Icons.savings_outlined);

  const AccountType(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum InvestmentKind {
  stock('Stocks'),
  mutualFund('Mutual Fund'),
  crypto('Crypto'),
  gold('Gold'),
  deposit('Time Deposit'),
  bond('Bonds'),
  other('Other');

  const InvestmentKind(this.label);
  final String label;
}

enum DebtDirection {
  iOwe('I owe'),
  owedToMe('Owed to me');

  const DebtDirection(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

DateTime _date(Object? ms) => DateTime.fromMillisecondsSinceEpoch(ms as int);

List<String> _splitList(Object? v) => (v as String? ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

class Account {
  Account({
    this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.creditLimit = 0,
    this.last4 = '',
    this.color = 0xFF0F9D7A,
    this.packages = const [],
    this.keywords = const [],
    this.archived = false,
    this.sort = 0,
  });

  final int? id;
  final String name;
  final AccountType type;

  /// For credit cards this is negative when there is outstanding debt.
  final double initialBalance;
  final double creditLimit;

  /// Last 4 digits of the card / account number, used by the brain.
  final String last4;
  final int color;

  /// Android package names whose notifications belong to this account.
  final List<String> packages;

  /// Extra words that identify this account in a notification (e.g. "BCA", "Jenius").
  final List<String> keywords;
  final bool archived;
  final int sort;

  bool get isCreditCard => type == AccountType.creditCard;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'initial_balance': initialBalance,
        'credit_limit': creditLimit,
        'last4': last4,
        'color': color,
        'packages': packages.join(','),
        'keywords': keywords.join(','),
        'archived': archived ? 1 : 0,
        'sort': sort,
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: _enumByName(AccountType.values, m['type'], AccountType.other),
        initialBalance: (m['initial_balance'] as num).toDouble(),
        creditLimit: (m['credit_limit'] as num? ?? 0).toDouble(),
        last4: m['last4'] as String? ?? '',
        color: m['color'] as int? ?? 0xFF0F9D7A,
        packages: _splitList(m['packages']),
        keywords: _splitList(m['keywords']),
        archived: (m['archived'] as int? ?? 0) == 1,
        sort: m['sort'] as int? ?? 0,
      );

  Account copyWith({int? id, double? initialBalance, bool? archived, List<String>? packages}) =>
      Account(
        id: id ?? this.id,
        name: name,
        type: type,
        initialBalance: initialBalance ?? this.initialBalance,
        creditLimit: creditLimit,
        last4: last4,
        color: color,
        packages: packages ?? this.packages,
        keywords: keywords,
        archived: archived ?? this.archived,
        sort: sort,
      );
}

class Category {
  Category({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.excludeFromStats = false,
  });

  final int? id;
  final String name;

  /// Only [TxnType.expense] or [TxnType.income].
  final TxnType type;
  final int icon;
  final int color;

  /// Debt movements & balance adjustments move money without being "spending".
  final bool excludeFromStats;

  /// Looked up from a const list so release builds can tree-shake icon fonts.
  IconData get iconData => categoryIcons.firstWhere((i) => i.codePoint == icon, orElse: () => Icons.more_horiz);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'icon': icon,
        'color': color,
        'exclude_stats': excludeFromStats ? 1 : 0,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: _enumByName(TxnType.values, m['type'], TxnType.expense),
        icon: m['icon'] as int,
        color: m['color'] as int,
        excludeFromStats: (m['exclude_stats'] as int? ?? 0) == 1,
      );
}

class Txn {
  Txn({
    this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.merchant = '',
    this.note = '',
    required this.date,
    this.source = 'manual',
    this.rawText = '',
  });

  final int? id;
  final TxnType type;

  /// Always positive; [type] carries the direction.
  final double amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final String merchant;
  final String note;
  final DateTime date;

  /// 'manual' | 'notification' | 'shortcut'
  final String source;
  final String rawText;

  String get title => merchant.isNotEmpty ? merchant : note;

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'category_id': categoryId,
        'merchant': merchant,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'source': source,
        'raw_text': rawText,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int?,
        type: _enumByName(TxnType.values, m['type'], TxnType.expense),
        amount: (m['amount'] as num).toDouble(),
        accountId: m['account_id'] as int,
        toAccountId: m['to_account_id'] as int?,
        categoryId: m['category_id'] as int?,
        merchant: m['merchant'] as String? ?? '',
        note: m['note'] as String? ?? '',
        date: _date(m['date']),
        source: m['source'] as String? ?? 'manual',
        rawText: m['raw_text'] as String? ?? '',
      );
}

class Debt {
  Debt({
    this.id,
    required this.person,
    required this.direction,
    required this.amount,
    this.note = '',
    this.dueDate,
    required this.createdAt,
    this.payments = const [],
  });

  final int? id;
  final String person;
  final DebtDirection direction;
  final double amount;
  final String note;
  final DateTime? dueDate;
  final DateTime createdAt;
  final List<DebtPayment> payments;

  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get remaining => (amount - paid).clamp(0, double.infinity).toDouble();
  bool get settled => remaining <= 0.0001;

  Map<String, Object?> toMap() => {
        'id': id,
        'person': person,
        'direction': direction.name,
        'amount': amount,
        'note': note,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Debt.fromMap(Map<String, Object?> m, List<DebtPayment> payments) => Debt(
        id: m['id'] as int?,
        person: m['person'] as String,
        direction: _enumByName(DebtDirection.values, m['direction'], DebtDirection.iOwe),
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String? ?? '',
        dueDate: m['due_date'] == null ? null : _date(m['due_date']),
        createdAt: _date(m['created_at']),
        payments: payments,
      );
}

class DebtPayment {
  DebtPayment({this.id, required this.debtId, required this.amount, required this.date, this.note = ''});

  final int? id;
  final int debtId;
  final double amount;
  final DateTime date;
  final String note;

  Map<String, Object?> toMap() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };

  factory DebtPayment.fromMap(Map<String, Object?> m) => DebtPayment(
        id: m['id'] as int?,
        debtId: m['debt_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        date: _date(m['date']),
        note: m['note'] as String? ?? '',
      );
}

class Investment {
  Investment({
    this.id,
    required this.name,
    required this.kind,
    required this.invested,
    required this.currentValue,
    this.note = '',
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final InvestmentKind kind;

  /// Total money put in (cost basis).
  final double invested;
  final double currentValue;
  final String note;
  final DateTime updatedAt;

  double get gain => currentValue - invested;
  double get gainPct => invested == 0 ? 0 : gain / invested * 100;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'invested': invested,
        'current_value': currentValue,
        'note': note,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Investment.fromMap(Map<String, Object?> m) => Investment(
        id: m['id'] as int?,
        name: m['name'] as String,
        kind: _enumByName(InvestmentKind.values, m['kind'], InvestmentKind.other),
        invested: (m['invested'] as num).toDouble(),
        currentValue: (m['current_value'] as num).toDouble(),
        note: m['note'] as String? ?? '',
        updatedAt: _date(m['updated_at']),
      );
}

/// A raw notification (or shared text) waiting for the user to confirm.
class InboxItem {
  InboxItem({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  final String id;
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final DateTime postedAt;

  String get fullText => [title, text].where((e) => e.trim().isNotEmpty).join('\n');

  Map<String, Object?> toMap() => {
        'id': id,
        'package': packageName,
        'app_name': appName,
        'title': title,
        'text': text,
        'posted_at': postedAt.millisecondsSinceEpoch,
      };

  factory InboxItem.fromMap(Map<String, Object?> m) => InboxItem(
        id: m['id'] as String,
        packageName: m['package'] as String? ?? '',
        appName: m['app_name'] as String? ?? '',
        title: m['title'] as String? ?? '',
        text: m['text'] as String? ?? '',
        postedAt: _date(m['posted_at']),
      );

  factory InboxItem.fromNative(Map<String, dynamic> m) => InboxItem(
        id: m['id'] as String,
        packageName: m['package'] as String? ?? '',
        appName: m['appName'] as String? ?? '',
        title: m['title'] as String? ?? '',
        text: m['text'] as String? ?? '',
        postedAt: DateTime.fromMillisecondsSinceEpoch((m['postedAt'] as num?)?.toInt() ?? 0),
      );
}

/// What the brain remembers after the user confirms a transaction.
class LearnedRule {
  LearnedRule({required this.key, this.type, this.accountId, this.categoryId, this.hits = 1});

  /// `m:<merchant>` or `p:<package>`
  final String key;
  final TxnType? type;
  final int? accountId;
  final int? categoryId;
  final int hits;

  factory LearnedRule.fromMap(Map<String, Object?> m) => LearnedRule(
        key: m['key'] as String,
        type: m['type'] == null ? null : _enumByName(TxnType.values, m['type'], TxnType.expense),
        accountId: m['account_id'] as int?,
        categoryId: m['category_id'] as int?,
        hits: m['hits'] as int? ?? 1,
      );
}
