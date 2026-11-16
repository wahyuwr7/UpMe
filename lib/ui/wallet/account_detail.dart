import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../transactions/txn_editor.dart';
import '../widgets/common.dart';
import 'account_form.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.accountId});
  final int accountId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final a = repo.account(accountId);
    if (a == null) return const Scaffold();
    final bal = repo.balanceOf(accountId);
    final txns = repo.transactions.where((t) => t.accountId == accountId || t.toAccountId == accountId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountFormScreen(account: a))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.isCreditCard ? 'Outstanding' : 'Balance', style: Theme.of(context).textTheme.labelLarge),
              MoneyText(a.isCreditCard ? -bal : bal, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(a.isCreditCard ? 'Set outstanding' : 'Set actual balance'),
                  onPressed: () async {
                    final v = await askAmount(
                      context,
                      title: a.isCreditCard ? 'Actual outstanding' : 'Actual balance',
                      initial: a.isCreditCard ? -bal : bal,
                      hint: 'UpMe records the difference as an adjustment (not counted as spending).',
                    );
                    if (v != null) await repo.adjustBalance(accountId, a.isCreditCard ? -v : v);
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(a.isCreditCard ? 'Pay card' : 'Transfer'),
                  onPressed: () => showTxnSheet(
                    context,
                    draft: a.isCreditCard
                        ? TxnDraft(type: TxnType.transfer, toAccountId: a.id, amount: bal < 0 ? -bal : null,
                            accountId: repo.activeAccounts.where((x) => !x.isCreditCard).firstOrNull?.id)
                        : TxnDraft(type: TxnType.transfer, accountId: a.id),
                  ),
                ),
              ]),
            ]),
          ),
          const SectionHeader('History'),
          if (txns.isEmpty)
            const EmptyState(icon: Icons.history, title: 'No transactions yet')
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                for (final t in txns.take(200))
                  TxnTile(txn: t, showDate: true, onTap: () => showTxnSheet(context, existing: t)),
              ]),
            ),
        ],
      ),
    );
  }
}
