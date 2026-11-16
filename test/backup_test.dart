import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:upme/core/format.dart';
import 'package:upme/core/settings.dart';
import 'package:upme/data/backup.dart';
import 'package:upme/data/database.dart';
import 'package:upme/data/models.dart';
import 'package:upme/data/repository.dart';

Future<FinanceRepository> newRepo() async {
  sqfliteFfiInit();
  final db = await AppDatabase.open(
      path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate, singleInstance: false);
  final repo = FinanceRepository(db);
  await repo.load();
  return repo;
}

Future<FinanceRepository> filledRepo() async {
  final repo = await newRepo();
  final now = DateTime(2026, 11, 10, 12);
  final bank = await repo.saveAccount(Account(
      name: 'BCA', type: AccountType.bank, initialBalance: 1000000, last4: '7788', packages: ['com.bca'], keywords: ['bca']));
  final cc = await repo.saveAccount(Account(name: 'Visa', type: AccountType.creditCard, initialBalance: -50000, creditLimit: 5e6));
  await repo.saveCategory(Category(name: 'Coffee', type: TxnType.expense, icon: 0xe000, color: 0xFF795548));
  final coffee = repo.categories.last.id;
  await repo.saveTxn(Txn(type: TxnType.expense, amount: 35000, accountId: bank, categoryId: coffee,
      merchant: 'Kopi Kenangan', note: 'pagi', date: now, source: 'notification', rawText: 'Payment Rp35.000'), learn: true);
  await repo.saveTxn(Txn(type: TxnType.transfer, amount: 50000, accountId: bank, toAccountId: cc, date: now));
  await repo.saveInvestment(Investment(name: 'BBCA', kind: InvestmentKind.stock, invested: 1e6, currentValue: 1.2e6, updatedAt: now));
  await repo.saveDebt(Debt(person: 'Andi', direction: DebtDirection.owedToMe, amount: 200000, createdAt: now,
      dueDate: DateTime(2026, 12, 1)));
  await repo.addDebtPayment(repo.debts.single, 50000, date: now);
  await repo.addToInbox([InboxItem(id: 'n1', packageName: 'com.bca', appName: 'BCA', title: 't', text: 'Rp 10.000', postedAt: now)]);
  return repo;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('backup → restore into a fresh install reproduces everything', () async {
    final src = await filledRepo();
    final json = await BackupService(src.database).exportJson();

    final dst = await newRepo();
    await dst.saveTxn(Txn(type: TxnType.expense, amount: 1, accountId: dst.accounts.first.id!, date: DateTime.now()));
    final summary = await BackupService(dst.database).restore(json);
    await dst.load();

    expect(summary.transactions, src.transactions.length);
    for (final t in backupTables) {
      final a = await src.database.db.query(t, orderBy: 'rowid');
      final b = await dst.database.db.query(t, orderBy: 'rowid');
      expect(b, a, reason: t);
    }
    for (final a in src.accounts) {
      expect(dst.balanceOf(a.id!), src.balanceOf(a.id!));
    }
    expect(dst.netWorth, src.netWorth);
    expect(dst.debts.single.remaining, 150000);
    expect(dst.rules.keys, containsAll(src.rules.keys));

    // New rows after restore must not collide with restored ids.
    await dst.saveTxn(Txn(type: TxnType.expense, amount: 5, accountId: dst.accounts.first.id!, date: DateTime.now()));
    expect(dst.transactions.length, src.transactions.length + 1);
  });

  test('inspect summarises without touching data', () async {
    final src = await filledRepo();
    final s = BackupService.inspect(await BackupService(src.database).exportJson());
    expect(s.transactions, src.transactions.length);
    expect(s.accounts, src.accounts.length);
    expect(s.exportedAt, isNotNull);
  });

  test('settings travel with the backup', () async {
    final src = await filledRepo();
    final settings = await AppSettings.load();
    settings.currency = CurrencyConfig.byCode('USD');
    settings.hideAmounts = true;
    final json = await BackupService(src.database, settings).exportJson();

    SharedPreferences.setMockInitialValues({});
    final fresh = await AppSettings.load();
    fresh.currency = CurrencyConfig.byCode('IDR');
    await BackupService((await newRepo()).database, fresh).restore(json);
    expect(fresh.currency.code, 'USD');
    expect(fresh.hideAmounts, isTrue);
    Money.config = CurrencyConfig.byCode('IDR');
  });

  test('rejects files that are not UpMe backups', () async {
    expect(() => BackupService.inspect('hello'), throwsA(isA<BackupException>()));
    expect(() => BackupService.inspect('{"foo":1}'), throwsA(isA<BackupException>()));
    expect(() => BackupService.inspect(jsonEncode({'app': 'upme', 'format': 99, 'tables': {}})),
        throwsA(isA<BackupException>()));
  });

  test('a broken backup leaves current data untouched', () async {
    final repo = await filledRepo();
    final before = repo.transactions.length;
    final m = jsonDecode(await BackupService(repo.database).exportJson()) as Map<String, dynamic>;
    // Transaction pointing at an account that doesn't exist → FK failure mid-restore.
    (m['tables']['transactions'] as List).add({'type': 'expense', 'amount': 1, 'account_id': 999, 'date': 0});
    await expectLater(BackupService(repo.database).restore(jsonEncode(m)), throwsA(anything));
    await repo.load();
    expect(repo.transactions.length, before);
    expect(repo.accounts.length, 3);
  });

  test('backups from a future version with extra columns still restore', () async {
    final repo = await filledRepo();
    final m = jsonDecode(await BackupService(repo.database).exportJson()) as Map<String, dynamic>;
    for (final r in m['tables']['accounts'] as List) {
      (r as Map)['some_new_column'] = 'x';
    }
    final dst = await newRepo();
    await BackupService(dst.database).restore(jsonEncode(m));
    await dst.load();
    expect(dst.accounts.length, repo.accounts.length);
  });

  test('file name', () {
    expect(backupFileName(DateTime(2026, 11, 16, 9, 5)), 'upme-backup-2026-11-16-0905.json');
  });
}
