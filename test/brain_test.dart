import 'package:flutter_test/flutter_test.dart';
import 'package:upme/brain/transaction_brain.dart';
import 'package:upme/core/format.dart';
import 'package:upme/data/models.dart';

void main() {
  final accounts = [
    Account(id: 1, name: 'Cash', type: AccountType.cash),
    Account(id: 2, name: 'BCA', type: AccountType.bank, packages: ['com.bca'], keywords: ['bca'], last4: '7788'),
    Account(id: 3, name: 'GoPay', type: AccountType.eWallet, packages: ['com.gojek.app'], keywords: ['gopay']),
    Account(id: 4, name: 'BCA Visa', type: AccountType.creditCard, last4: '1234'),
    Account(id: 5, name: 'Chase', type: AccountType.bank, last4: '4821'),
  ];
  var cid = 0;
  Category cat(String n, TxnType t, {bool ex = false}) =>
      Category(id: ++cid, name: n, type: t, icon: 0, color: 0, excludeFromStats: ex);
  final categories = [
    cat('Food & Drinks', TxnType.expense),
    cat('Groceries', TxnType.expense),
    cat('Transport', TxnType.expense),
    cat('Shopping', TxnType.expense),
    cat('Bills & Utilities', TxnType.expense),
    cat('Other', TxnType.expense),
    cat('Salary', TxnType.income),
    cat('Other', TxnType.income),
  ];
  Category byName(String n, TxnType t) => categories.firstWhere((c) => c.name == n && c.type == t);
  final brain = TransactionBrain(accounts: accounts, categories: categories);

  group('amount parsing', () {
    test('locale aware numbers', () {
      expect(parseLocalizedNumber('1.250.000,00'), 1250000);
      expect(parseLocalizedNumber('1,250,000.50'), 1250000.5);
      expect(parseLocalizedNumber('1.500'), 1500);
      expect(parseLocalizedNumber('12.50'), 12.5);
      expect(parseLocalizedNumber('35.000'), 35000);
    });
    test('lazy input', () {
      expect(parseAmountInput('25k'), 25000);
      expect(parseAmountInput('1.5jt'), 1500000);
      expect(parseAmountInput('1,5jt'), 1500000);
      expect(parseAmountInput('10rb'), 10000);
      expect(parseAmountInput('25k+12.500'), 37500);
      expect(parseAmountInput('Rp 50.000'), 50000);
      expect(parseAmountInput(''), isNull);
    });
    test('skips balance amounts', () {
      expect(TransactionBrain.extractAmount('Saldo Rp 5.000.000. Debit Rp 50.000 di INDOMARET'), 50000);
      expect(TransactionBrain.extractAmount('Payment Rp25.000 success. Balance: Rp1.000.000'), 25000);
    });
  });

  group('classification', () {
    test('GoPay payment', () {
      final s = brain.analyze(
          text: 'Payment successful\nPayment of Rp35.000 to Kopi Kenangan was successful',
          packageName: 'com.gojek.app');
      expect(s.isTransaction, isTrue);
      expect(s.amount, 35000);
      expect(s.type, TxnType.expense);
      expect(s.accountId, 3);
      expect(s.merchant, 'Kopi Kenangan');
      expect(s.categoryId, byName('Food & Drinks', TxnType.expense).id);
    });

    test('BCA debit at Indomaret', () {
      final s = brain.analyze(
          text: 'Transaksi Debit Rp 52.300,00 di INDOMARET PADANG pada 16/11/26 berhasil', packageName: 'com.bca');
      expect(s.amount, 52300);
      expect(s.type, TxnType.expense);
      expect(s.accountId, 2);
      expect(s.merchant, 'Indomaret Padang');
      expect(s.categoryId, byName('Groceries', TxnType.expense).id);
    });

    test('incoming transfer (Indonesian)', () {
      final s = brain.analyze(text: 'Dana Masuk\nKamu menerima Rp100.000 dari BUDI SANTOSO', packageName: 'com.bca');
      expect(s.type, TxnType.income);
      expect(s.amount, 100000);
      expect(s.merchant, 'Budi Santoso');
    });

    test('salary credited (English, USD)', () {
      final s = brain.analyze(text: 'Your account ending 4821 was credited with USD 2,000.00 from ACME PAYROLL');
      expect(s.type, TxnType.income);
      expect(s.amount, 2000);
      expect(s.accountId, 5);
      expect(s.categoryId, byName('Salary', TxnType.income).id);
    });

    test('credit card purchase matched by last 4', () {
      final s = brain.analyze(
          text: 'Transaksi Kartu Kredit BCA ****1234 sebesar Rp 450.000 di TOKOPEDIA telah berhasil',
          packageName: 'com.bca');
      expect(s.type, TxnType.expense);
      expect(s.accountId, 4);
      expect(s.amount, 450000);
      expect(s.merchant, 'Tokopedia');
      expect(s.categoryId, byName('Shopping', TxnType.expense).id);
    });

    test('english card spend', () {
      final s = brain.analyze(text: 'You spent \$12.50 at Starbucks with card ending 4821');
      expect(s.amount, 12.5);
      expect(s.type, TxnType.expense);
      expect(s.accountId, 5);
      expect(s.merchant, 'Starbucks');
    });

    test('top up gopay from bca becomes a transfer', () {
      final s = brain.analyze(text: 'Top Up GoPay Rp 200.000 berhasil dari rekening BCA', packageName: 'com.bca');
      expect(s.type, TxnType.transfer);
      expect(s.accountId, 2);
      expect(s.toAccountId, 3);
    });

    test('ignores OTP, promo and failed', () {
      expect(brain.analyze(text: 'Kode OTP 123456 untuk transaksi Rp 100.000. JANGAN berikan ke siapapun').isTransaction,
          isFalse);
      expect(brain.analyze(text: 'Diskon 50% hingga Rp50.000 untuk pembelian pertama! Buruan').isTransaction, isFalse);
      expect(brain.analyze(text: 'Pembayaran Rp 50.000 ke PLN gagal').isTransaction, isFalse);
      expect(brain.analyze(text: 'Your order has shipped').isTransaction, isFalse);
    });

    test('learned rule overrides heuristics', () {
      final learned = TransactionBrain(accounts: accounts, categories: categories, rules: {
        'm:warung bu tini': LearnedRule(key: 'm:warung bu tini', type: TxnType.expense, categoryId: 2, hits: 3),
        'p:com.example.bank': LearnedRule(key: 'p:com.example.bank', accountId: 5),
      });
      final s = learned.analyze(text: 'Pembayaran QRIS Rp 15.000 ke WARUNG BU TINI berhasil', packageName: 'com.example.bank');
      expect(s.categoryId, 2);
      expect(s.accountId, 5);
    });
  });
}
