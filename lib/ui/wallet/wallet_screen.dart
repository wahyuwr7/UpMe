import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';
import 'account_detail.dart';
import 'account_form.dart';
import 'debts.dart';
import 'investments.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Wallet'),
            bottom: const TabBar(tabs: [Tab(text: 'Accounts'), Tab(text: 'Investments'), Tab(text: 'Debts')]),
          ),
          body: const TabBarView(children: [_AccountsTab(), InvestmentsTab(), DebtsTab()]),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              switch (DefaultTabController.of(context).index) {
                case 0:
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountFormScreen()));
                case 1:
                  showInvestmentSheet(context);
                default:
                  showDebtSheet(context);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      }),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final accounts = repo.activeAccounts;
    final archived = repo.accounts.where((a) => a.archived).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 96, top: 8),
      children: [
        AppCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cash & bank', style: Theme.of(context).textTheme.labelMedium),
                MoneyText(repo.cashTotal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Credit cards owed', style: Theme.of(context).textTheme.labelMedium),
                MoneyText(repo.creditCardOutstanding,
                    color: repo.creditCardOutstanding > 0 ? expenseColor : null,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        for (final type in AccountType.values)
          if (accounts.any((a) => a.type == type)) ...[
            SectionHeader(switch (type) {
              AccountType.cash => 'Cash',
              AccountType.bank => 'Banks',
              AccountType.eWallet => 'E-Wallets',
              AccountType.creditCard => 'Credit cards',
              AccountType.other => 'Other',
            }),
            for (final a in accounts.where((a) => a.type == type)) AccountTile(account: a),
          ],
        if (archived.isNotEmpty) ...[
          const SectionHeader('Archived'),
          for (final a in archived) AccountTile(account: a),
        ],
      ],
    );
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final bal = repo.balanceOf(account.id!);
    final a = account;
    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(accountId: a.id!))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: Color(a.color).withValues(alpha: 0.15),
            child: Icon(a.type.icon, color: Color(a.color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                [a.type.label, if (a.last4.isNotEmpty) '•••• ${a.last4}', if (a.packages.isNotEmpty) 'auto-capture'].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
          MoneyText(a.isCreditCard ? -bal : bal,
              color: (a.isCreditCard ? bal < 0 : bal < 0) ? expenseColor : null,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        if (a.isCreditCard && a.creditLimit > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (-bal / a.creditLimit).clamp(0, 1).toDouble(),
              minHeight: 6,
              color: (-bal / a.creditLimit) > 0.8 ? expenseColor : Color(a.color),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text('Available ', style: Theme.of(context).textTheme.labelSmall),
            MoneyText(a.creditLimit + bal, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text('Limit ', style: Theme.of(context).textTheme.labelSmall),
            MoneyText(a.creditLimit, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ],
      ]),
    );
  }
}
