import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart';

import '../brain/transaction_brain.dart';
import 'database.dart';
import 'models.dart';

class MonthSummary {
  MonthSummary(this.income, this.expense, this.byCategory);
  final double income;
  final double expense;

  /// categoryId (or -1 for uncategorized) -> total
  final Map<int, double> byCategory;
  double get net => income - expense;
}

/// Single source of truth for the UI. Personal finance data is small, so
/// everything is kept in memory and recomputed on change — simple and fast.
class FinanceRepository extends ChangeNotifier {
  FinanceRepository(this._appDb);
  final AppDatabase _appDb;
  Database get _db => _appDb.db;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<Txn> transactions = []; // newest first
  List<Debt> debts = [];
  List<Investment> investments = [];
  List<InboxItem> inbox = [];
  Map<String, LearnedRule> rules = {};
  bool loaded = false;

  Future<void> load() async {
    accounts = (await _db.query('accounts', orderBy: 'sort, id')).map(Account.fromMap).toList();
    categories = (await _db.query('categories', orderBy: 'id')).map(Category.fromMap).toList();
    transactions =
        (await _db.query('transactions', orderBy: 'date DESC, id DESC')).map(Txn.fromMap).toList();
    final payments = (await _db.query('debt_payments', orderBy: 'date')).map(DebtPayment.fromMap).toList();
    debts = (await _db.query('debts', orderBy: 'created_at DESC'))
        .map((m) => Debt.fromMap(m, payments.where((p) => p.debtId == m['id']).toList()))
        .toList();
    investments = (await _db.query('investments', orderBy: 'id')).map(Investment.fromMap).toList();
    inbox = (await _db.query('inbox', orderBy: 'posted_at')).map(InboxItem.fromMap).toList();
    rules = {
      for (final r in (await _db.query('learned_rules')).map(LearnedRule.fromMap)) r.key: r,
    };
    loaded = true;
    notifyListeners();
  }

  TransactionBrain get brain => TransactionBrain(accounts: accounts, categories: categories, rules: rules);

  // ---------------------------------------------------------------- lookups
  Account? account(int? id) => accounts.where((a) => a.id == id).firstOrNull;
  Category? category(int? id) => categories.where((c) => c.id == id).firstOrNull;
  List<Account> get activeAccounts => accounts.where((a) => !a.archived).toList();
  List<Category> categoriesFor(TxnType t) => categories.where((c) => c.type == t).toList();

  double balanceOf(int accountId) {
    final a = account(accountId);
    var b = a?.initialBalance ?? 0;
    for (final t in transactions) {
      if (t.accountId == accountId) {
        b += t.type == TxnType.income ? t.amount : -t.amount;
      } else if (t.type == TxnType.transfer && t.toAccountId == accountId) {
        b += t.amount;
      }
    }
    return b;
  }

  double get cashTotal => activeAccounts.where((a) => !a.isCreditCard).fold(0, (s, a) => s + balanceOf(a.id!));

  /// Positive number = how much you owe on cards.
  double get creditCardOutstanding =>
      activeAccounts.where((a) => a.isCreditCard).fold(0, (s, a) => s - balanceOf(a.id!));
  double get investmentValue => investments.fold(0, (s, i) => s + i.currentValue);
  double get investmentInvested => investments.fold(0, (s, i) => s + i.invested);
  double get iOwe =>
      debts.where((d) => d.direction == DebtDirection.iOwe).fold(0, (s, d) => s + d.remaining);
  double get owedToMe =>
      debts.where((d) => d.direction == DebtDirection.owedToMe).fold(0, (s, d) => s + d.remaining);
  double get netWorth => cashTotal - creditCardOutstanding + investmentValue + owedToMe - iOwe;

  bool _countsInStats(Txn t) =>
      t.type != TxnType.transfer && !(category(t.categoryId)?.excludeFromStats ?? false);

  List<Txn> transactionsInMonth(DateTime month) => transactions
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList();

  MonthSummary summary(DateTime month) {
    double inc = 0, exp = 0;
    final byCat = <int, double>{};
    for (final t in transactionsInMonth(month)) {
      if (!_countsInStats(t)) continue;
      if (t.type == TxnType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
        byCat.update(t.categoryId ?? -1, (v) => v + t.amount, ifAbsent: () => t.amount);
      }
    }
    return MonthSummary(inc, exp, byCat);
  }

  /// Daily spending for the given month (index 0 = day 1).
  List<double> dailyExpense(DateTime month) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final out = List<double>.filled(days, 0);
    for (final t in transactionsInMonth(month)) {
      if (_countsInStats(t) && t.type == TxnType.expense) out[t.date.day - 1] += t.amount;
    }
    return out;
  }

  // ----------------------------------------------------------- transactions
  Future<void> saveTxn(Txn t, {bool learn = false}) async {
    if (t.id == null) {
      await _db.insert('transactions', t.toMap()..remove('id'));
    } else {
      await _db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
    }
    if (learn) await learnFrom(t, packageName: null);
    await load();
  }

  Future<void> deleteTxn(int id) async {
    await _db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  // ------------------------------------------------------------------ brain
  /// Remember merchant → category/type and app → account for next time.
  Future<void> learnFrom(Txn t, {String? packageName}) async {
    Future<void> upsert(String key, Map<String, Object?> values) async {
      final existing = rules[key];
      await _db.insert(
        'learned_rules',
        {'key': key, ...values, 'hits': (existing?.hits ?? 0) + 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (t.merchant.trim().isNotEmpty && t.type != TxnType.transfer) {
      await upsert('m:${t.merchant.trim().toLowerCase()}', {'type': t.type.name, 'category_id': t.categoryId});
    }
    if (packageName != null && packageName.isNotEmpty) {
      await upsert('p:$packageName', {'account_id': t.accountId});
    }
  }

  Future<void> forgetRules() async {
    await _db.delete('learned_rules');
    await load();
  }

  // ------------------------------------------------------------------ inbox
  Future<void> addToInbox(List<InboxItem> items) async {
    if (items.isEmpty) return;
    final b = _db.batch();
    for (final i in items) {
      b.insert('inbox', i.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
    await load();
  }

  Future<void> removeFromInbox(String id) async {
    await _db.delete('inbox', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  /// Confirmed from a notification: save, learn, clear from inbox — atomically enough.
  Future<void> confirmInbox(InboxItem item, Txn t) async {
    await _db.insert('transactions', t.toMap()..remove('id'));
    await learnFrom(t, packageName: item.packageName);
    await _db.delete('inbox', where: 'id = ?', whereArgs: [item.id]);
    await load();
  }

  // --------------------------------------------------------------- accounts
  Future<int> saveAccount(Account a) async {
    int id;
    if (a.id == null) {
      id = await _db.insert('accounts', a.toMap()..remove('id'));
    } else {
      id = a.id!;
      await _db.update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    }
    await load();
    return id;
  }

  Future<void> deleteAccount(int id) async {
    await _db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  /// Lazy reconciliation: "my balance is actually X" → records an adjustment.
  Future<void> adjustBalance(int accountId, double actual) async {
    final diff = actual - balanceOf(accountId);
    if (diff.abs() < 0.005) return;
    final type = diff > 0 ? TxnType.income : TxnType.expense;
    final cat = categories.firstWhere((c) => c.name == 'Balance Adjustment' && c.type == type);
    await saveTxn(Txn(
      type: type,
      amount: diff.abs(),
      accountId: accountId,
      categoryId: cat.id,
      note: 'Balance adjustment',
      date: DateTime.now(),
    ));
  }

  // ------------------------------------------------------------- categories
  Future<void> saveCategory(Category c) async {
    if (c.id == null) {
      await _db.insert('categories', c.toMap()..remove('id'));
    } else {
      await _db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    }
    await load();
  }

  Future<void> deleteCategory(int id) async {
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  // ------------------------------------------------------------------ debts
  Future<void> saveDebt(Debt d, {int? accountId}) async {
    final isNew = d.id == null;
    if (isNew) {
      await _db.insert('debts', d.toMap()..remove('id'));
    } else {
      await _db.update('debts', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
    }
    if (isNew && accountId != null) {
      // Borrowing puts money in your account; lending takes it out.
      await _debtMoneyMove(accountId, d.amount,
          incoming: d.direction == DebtDirection.iOwe, note: '${d.direction.label}: ${d.person}', date: d.createdAt);
    }
    await load();
  }

  Future<void> deleteDebt(int id) async {
    await _db.delete('debts', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  Future<void> addDebtPayment(Debt d, double amount, {int? accountId, DateTime? date}) async {
    final when = date ?? DateTime.now();
    await _db.insert('debt_payments', DebtPayment(debtId: d.id!, amount: amount, date: when).toMap()..remove('id'));
    if (accountId != null) {
      await _debtMoneyMove(accountId, amount,
          incoming: d.direction == DebtDirection.owedToMe, note: 'Debt payment: ${d.person}', date: when);
    }
    await load();
  }

  Future<void> _debtMoneyMove(int accountId, double amount,
      {required bool incoming, required String note, required DateTime date}) async {
    final type = incoming ? TxnType.income : TxnType.expense;
    final cat = categories.firstWhere((c) => c.name == 'Debt & Loans' && c.type == type);
    await _db.insert(
        'transactions',
        Txn(type: type, amount: amount, accountId: accountId, categoryId: cat.id, note: note, date: date).toMap()
          ..remove('id'));
  }

  // ------------------------------------------------------------ investments
  Future<void> saveInvestment(Investment i) async {
    if (i.id == null) {
      await _db.insert('investments', i.toMap()..remove('id'));
    } else {
      await _db.update('investments', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
    }
    await load();
  }

  Future<void> deleteInvestment(int id) async {
    await _db.delete('investments', where: 'id = ?', whereArgs: [id]);
    await load();
  }
}
