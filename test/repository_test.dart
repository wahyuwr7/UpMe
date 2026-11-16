import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:upme/data/database.dart';
import 'package:upme/data/models.dart';
import 'package:upme/data/repository.dart';

Future<FinanceRepository> newRepo() async {
  sqfliteFfiInit();
  final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate, singleInstance: false);
  final repo = FinanceRepository(db);
  await repo.load();
  return repo;
}

void main() {
  test('seeds a cash account and categories', () async {
    final repo = await newRepo();
    expect(repo.accounts.single.name, 'Cash');
    expect(repo.categoriesFor(TxnType.expense).length, greaterThan(5));
  });

  test('balances, transfers, credit cards and net worth', () async {
    final repo = await newRepo();
    final cash = repo.accounts.first.id!;
    final bank = await repo.saveAccount(Account(name: 'BCA', type: AccountType.bank, initialBalance: 1000000));
    final cc = await repo.saveAccount(
        Account(name: 'Visa', type: AccountType.creditCard, initialBalance: -200000, creditLimit: 5000000));
    final food = repo.categoriesFor(TxnType.expense).first.id;
    final salary = repo.categoriesFor(TxnType.income).first.id;
    final now = DateTime.now();

    await repo.saveTxn(Txn(type: TxnType.income, amount: 5000000, accountId: bank, categoryId: salary, date: now));
    await repo.saveTxn(Txn(type: TxnType.expense, amount: 50000, accountId: cash, categoryId: food, date: now));
    await repo.saveTxn(Txn(type: TxnType.expense, amount: 300000, accountId: cc, categoryId: food, date: now));
    await repo.saveTxn(Txn(type: TxnType.transfer, amount: 500000, accountId: bank, toAccountId: cc, date: now));

    expect(repo.balanceOf(bank), 1000000 + 5000000 - 500000);
    expect(repo.balanceOf(cash), -50000);
    expect(repo.balanceOf(cc), -200000 - 300000 + 500000);
    expect(repo.creditCardOutstanding, 0);

    final s = repo.summary(DateTime(now.year, now.month));
    expect(s.income, 5000000);
    expect(s.expense, 350000); // transfer not counted

    await repo.saveInvestment(Investment(
        name: 'BBCA', kind: InvestmentKind.stock, invested: 1000000, currentValue: 1200000, updatedAt: now));
    await repo.saveDebt(Debt(person: 'Andi', direction: DebtDirection.owedToMe, amount: 100000, createdAt: now),
        accountId: cash);
    // Lending moved cash out but doesn't count as spending.
    expect(repo.balanceOf(cash), -150000);
    expect(repo.summary(DateTime(now.year, now.month)).expense, 350000);
    expect(repo.owedToMe, 100000);

    final d = repo.debts.single;
    await repo.addDebtPayment(d, 40000, accountId: cash);
    expect(repo.debts.single.remaining, 60000);
    expect(repo.balanceOf(cash), -110000);

    expect(repo.netWorth, repo.cashTotal - repo.creditCardOutstanding + 1200000 + 60000);
  });

  test('adjust balance creates an excluded adjustment', () async {
    final repo = await newRepo();
    final cash = repo.accounts.first.id!;
    await repo.adjustBalance(cash, 75000);
    expect(repo.balanceOf(cash), 75000);
    final now = DateTime.now();
    expect(repo.summary(DateTime(now.year, now.month)).income, 0);
  });

  test('confirming an inbox item saves, learns and clears it', () async {
    final repo = await newRepo();
    final bank = await repo.saveAccount(Account(name: 'Jago', type: AccountType.bank));
    final groceries = repo.categories.firstWhere((c) => c.name == 'Family & Gifts').id;
    final item = InboxItem(
        id: 'x1',
        packageName: 'com.jago.app',
        appName: 'Jago',
        title: 'Pembayaran berhasil',
        text: 'Pembayaran Rp 20.000 ke WARUNG BU TINI berhasil',
        postedAt: DateTime.now());
    await repo.addToInbox([item]);
    expect(repo.inbox, hasLength(1));

    final s = repo.brain.analyze(text: item.fullText, packageName: item.packageName);
    expect(s.amount, 20000);
    await repo.confirmInbox(
        item,
        Txn(type: s.type, amount: s.amount!, accountId: bank, categoryId: groceries, merchant: s.merchant,
            date: DateTime.now(), source: 'notification'));
    expect(repo.inbox, isEmpty);
    expect(repo.transactions, hasLength(1));

    // Next time: same app → same account, same merchant → same category.
    final again = repo.brain.analyze(
        text: 'Pembayaran Rp 18.000 ke WARUNG BU TINI berhasil', packageName: 'com.jago.app');
    expect(again.accountId, bank);
    expect(again.categoryId, groceries);
  });
}
