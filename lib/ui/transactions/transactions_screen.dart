import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';
import 'txn_editor.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  TxnType? _filter;
  int? _accountFilter;
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final q = _query.toLowerCase();
    final list = (q.isEmpty ? repo.transactionsInMonth(_month) : repo.transactions).where((t) {
      if (_filter != null && t.type != _filter) return false;
      if (_accountFilter != null && t.accountId != _accountFilter && t.toAccountId != _accountFilter) return false;
      if (q.isEmpty) return true;
      final cat = repo.category(t.categoryId)?.name ?? '';
      return '${t.merchant} ${t.note} $cat ${repo.account(t.accountId)?.name}'.toLowerCase().contains(q) ||
          Money.plain(t.amount).contains(q);
    }).toList();
    final sum = repo.summary(_month);

    // Group by day.
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search all transactions', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Activity'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
        ],
      ),
      body: Column(children: [
        if (q.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Column(children: [
                  Text(monthLabel(_month), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    MoneyText(sum.income, signed: true, compact: true, color: incomeColor, style: const TextStyle(fontSize: 12)),
                    const Text('  ·  '),
                    MoneyText(-sum.expense, signed: true, compact: true, color: expenseColor, style: const TextStyle(fontSize: 12)),
                  ]),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ]),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in <TxnType?>[null, ...TxnType.values])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f == null ? 'All' : '${f.name[0].toUpperCase()}${f.name.substring(1)}'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
              const VerticalDivider(indent: 10, endIndent: 10),
              for (final a in repo.activeAccounts)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(a.name),
                    selected: _accountFilter == a.id,
                    onSelected: (v) => setState(() => _accountFilter = v ? a.id : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.search_off, title: 'Nothing here', subtitle: 'No transactions match.')
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final e in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                        child: Row(children: [
                          Expanded(child: Text(dayLabel(e.key), style: Theme.of(context).textTheme.labelLarge)),
                          MoneyText(
                            e.value.fold<double>(0, (s, t) => s + switch (t.type) {
                                  TxnType.income => t.amount,
                                  TxnType.expense => -t.amount,
                                  TxnType.transfer => 0,
                                }),
                            signed: true,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ]),
                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(children: [
                          for (final t in e.value)
                            Dismissible(
                              key: ValueKey(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: expenseColor,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (_) => confirmDialog(context, 'Delete transaction?', 'This cannot be undone.'),
                              onDismissed: (_) => repo.deleteTxn(t.id!),
                              child: TxnTile(
                                txn: t,
                                showDate: q.isNotEmpty,
                                onTap: () => showTxnSheet(context, existing: t),
                              ),
                            ),
                        ]),
                      ),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}
