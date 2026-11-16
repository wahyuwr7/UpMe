import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

class InvestmentsTab extends StatelessWidget {
  const InvestmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final items = repo.investments;
    final gain = repo.investmentValue - repo.investmentInvested;
    final pct = repo.investmentInvested == 0 ? 0 : gain / repo.investmentInvested * 100;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.trending_up,
        title: 'No investments yet',
        subtitle: 'Track stocks, mutual funds, crypto, gold or deposits. Just update the value whenever you feel like it.',
        action: FilledButton.icon(onPressed: () => showInvestmentSheet(context), icon: const Icon(Icons.add), label: const Text('Add investment')),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Portfolio value', style: Theme.of(context).textTheme.labelMedium),
            MoneyText(repo.investmentValue, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              MoneyText(gain, signed: true, color: gain >= 0 ? incomeColor : expenseColor),
              Text('  (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                  style: TextStyle(color: gain >= 0 ? incomeColor : expenseColor)),
              const Spacer(),
              Text('Invested ', style: Theme.of(context).textTheme.labelSmall),
              MoneyText(repo.investmentInvested, style: Theme.of(context).textTheme.labelSmall),
            ]),
          ]),
        ),
        for (final i in items)
          AppCard(
            onTap: () => showInvestmentSheet(context, existing: i),
            child: Row(children: [
              CircleAvatar(child: Text(i.kind.label[0])),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${i.kind.label} · updated ${dayLabel(i.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                MoneyText(i.currentValue, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${i.gainPct >= 0 ? '+' : ''}${i.gainPct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: i.gain >= 0 ? incomeColor : expenseColor)),
              ]),
              IconButton(
                tooltip: 'Update value',
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  final v = await askAmount(context, title: 'Current value of ${i.name}', initial: i.currentValue);
                  if (v != null) {
                    await repo.saveInvestment(Investment(
                        id: i.id, name: i.name, kind: i.kind, invested: i.invested, currentValue: v, note: i.note, updatedAt: DateTime.now()));
                  }
                },
              ),
            ]),
          ),
      ],
    );
  }
}

Future<void> showInvestmentSheet(BuildContext context, {Investment? existing}) {
  final repo = context.read<FinanceRepository>();
  final name = TextEditingController(text: existing?.name ?? '');
  final invested = TextEditingController(text: existing == null ? '' : Money.plain(existing.invested));
  final current = TextEditingController(text: existing == null ? '' : Money.plain(existing.currentValue));
  var kind = existing?.kind ?? InvestmentKind.stock;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(existing == null ? 'New investment' : 'Edit investment', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. BBCA, Reksadana XYZ, BTC')),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in InvestmentKind.values)
                ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setState(() => kind = k)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: invested,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Total invested (cost)', prefixText: '${Money.config.symbol} '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: current,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Current value',
                helperText: 'Leave empty to use the invested amount',
                prefixText: '${Money.config.symbol} ',
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              if (existing != null)
                IconButton.outlined(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(c, 'Delete ${existing.name}?', 'This cannot be undone.')) {
                      await repo.deleteInvestment(existing.id!);
                      if (c.mounted) Navigator.pop(c);
                    }
                  },
                ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    final inv = parseAmountInput(invested.text) ?? 0;
                    if (name.text.trim().isEmpty) return;
                    await repo.saveInvestment(Investment(
                      id: existing?.id,
                      name: name.text.trim(),
                      kind: kind,
                      invested: inv,
                      currentValue: parseAmountInput(current.text) ?? inv,
                      note: existing?.note ?? '',
                      updatedAt: DateTime.now(),
                    ));
                    if (c.mounted) Navigator.pop(c);
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
