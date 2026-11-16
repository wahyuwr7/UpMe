import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:upme/core/settings.dart';
import 'package:upme/data/database.dart';
import 'package:upme/data/models.dart';
import 'package:upme/data/repository.dart';
import 'package:upme/ui/app.dart';

void main() {
  testWidgets('every tab renders with data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late FinanceRepository repo;
    late AppSettings settings;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate, singleInstance: false);
      repo = FinanceRepository(db);
      await repo.load();
      settings = await AppSettings.load();
      final food = repo.categoriesFor(TxnType.expense).first.id;
      await repo.saveTxn(Txn(type: TxnType.expense, amount: 35000, accountId: repo.accounts.first.id!,
          categoryId: food, merchant: 'Kopi Kenangan', date: DateTime.now()));
      await repo.saveAccount(Account(name: 'Visa', type: AccountType.creditCard, initialBalance: -100, creditLimit: 1000));
    });

    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(UpMeApp(repo: repo, settings: settings));
    await tester.pump();
    expect(find.text('Net worth'), findsOneWidget);

    for (final tab in ['Activity', 'Wallet', 'Settings', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: tab);
      if (tab == 'Activity') expect(find.text('Kopi Kenangan'), findsWidgets);
    }

    // Open the add sheet.
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
  });
}
