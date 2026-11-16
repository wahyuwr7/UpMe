import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory, bool singleInstance = true}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'upme.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await _createSchema(db);
          await _seed(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    final b = db.batch();
    b.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initial_balance REAL NOT NULL DEFAULT 0,
        credit_limit REAL NOT NULL DEFAULT 0,
        last4 TEXT NOT NULL DEFAULT '',
        color INTEGER NOT NULL,
        packages TEXT NOT NULL DEFAULT '',
        keywords TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        exclude_stats INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        to_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        merchant TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        date INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        raw_text TEXT NOT NULL DEFAULT ''
      )''');
    b.execute('CREATE INDEX idx_txn_date ON transactions(date)');
    b.execute('''
      CREATE TABLE debts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        due_date INTEGER,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    b.execute('''
      CREATE TABLE investments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        invested REAL NOT NULL,
        current_value REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE inbox(
        id TEXT PRIMARY KEY,
        package TEXT NOT NULL DEFAULT '',
        app_name TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL DEFAULT '',
        text TEXT NOT NULL DEFAULT '',
        posted_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE learned_rules(
        key TEXT PRIMARY KEY,
        type TEXT,
        account_id INTEGER,
        category_id INTEGER,
        hits INTEGER NOT NULL DEFAULT 1
      )''');
    await b.commit(noResult: true);
  }

  static Future<void> _seed(Database db) async {
    final b = db.batch();
    b.insert('accounts', Account(name: 'Cash', type: AccountType.cash, color: 0xFF4CAF50).toMap());
    void cat(String name, TxnType type, IconData icon, int color, {bool exclude = false}) => b.insert(
        'categories',
        Category(name: name, type: type, icon: icon.codePoint, color: color, excludeFromStats: exclude).toMap());

    cat('Food & Drinks', TxnType.expense, Icons.restaurant, 0xFFFF7043);
    cat('Groceries', TxnType.expense, Icons.shopping_basket, 0xFF8BC34A);
    cat('Transport', TxnType.expense, Icons.directions_car, 0xFF42A5F5);
    cat('Shopping', TxnType.expense, Icons.shopping_bag, 0xFFAB47BC);
    cat('Bills & Utilities', TxnType.expense, Icons.receipt_long, 0xFF26A69A);
    cat('Entertainment', TxnType.expense, Icons.movie, 0xFFEC407A);
    cat('Health', TxnType.expense, Icons.local_hospital, 0xFFEF5350);
    cat('Travel', TxnType.expense, Icons.flight, 0xFF29B6F6);
    cat('Education', TxnType.expense, Icons.school, 0xFF5C6BC0);
    cat('Family & Gifts', TxnType.expense, Icons.card_giftcard, 0xFFFFCA28);
    cat('Fees & Interest', TxnType.expense, Icons.percent, 0xFF78909C);
    cat('Other', TxnType.expense, Icons.more_horiz, 0xFF9E9E9E);
    cat('Salary', TxnType.income, Icons.work, 0xFF43A047);
    cat('Business', TxnType.income, Icons.storefront, 0xFF00897B);
    cat('Refund & Cashback', TxnType.income, Icons.replay, 0xFF7CB342);
    cat('Interest', TxnType.income, Icons.trending_up, 0xFF26C6DA);
    cat('Gift', TxnType.income, Icons.redeem, 0xFFFFB300);
    cat('Other', TxnType.income, Icons.more_horiz, 0xFF9E9E9E);
    // Money that moves but isn't spending/earning: excluded from charts.
    cat('Debt & Loans', TxnType.expense, Icons.handshake, 0xFF8D6E63, exclude: true);
    cat('Debt & Loans', TxnType.income, Icons.handshake, 0xFF8D6E63, exclude: true);
    cat('Balance Adjustment', TxnType.expense, Icons.tune, 0xFF607D8B, exclude: true);
    cat('Balance Adjustment', TxnType.income, Icons.tune, 0xFF607D8B, exclude: true);
    await b.commit(noResult: true);
  }
}
