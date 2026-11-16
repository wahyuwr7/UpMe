import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

class DebtsTab extends StatelessWidget {
  const DebtsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final open = repo.debts.where((d) => !d.settled).toList();
    final settled = repo.debts.where((d) => d.settled).toList();
    if (repo.debts.isEmpty) {
      return EmptyState(
        icon: Icons.handshake_outlined,
        title: 'No debts. Nice.',
        subtitle: 'Track money you borrowed or lent to friends, family, or loans.',
        action: FilledButton.icon(onPressed: () => showDebtSheet(context), icon: const Icon(Icons.add), label: const Text('Add debt')),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        AppCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('I owe', style: Theme.of(context).textTheme.labelMedium),
                MoneyText(repo.iOwe, color: expenseColor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Owed to me', style: Theme.of(context).textTheme.labelMedium),
                MoneyText(repo.owedToMe, color: incomeColor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        for (final d in open) _DebtTile(debt: d),
        if (settled.isNotEmpty) ...[
          const SectionHeader('Settled'),
          for (final d in settled) _DebtTile(debt: d),
        ],
      ],
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt});
  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final d = debt;
    final color = d.direction == DebtDirection.iOwe ? expenseColor : incomeColor;
    final overdue = !d.settled && d.dueDate != null && d.dueDate!.isBefore(DateTime.now());
    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: d.id!))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Text(d.person.isEmpty ? '?' : d.person[0].toUpperCase(), style: TextStyle(color: color))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.person, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                [d.direction.label, if (d.dueDate != null) 'due ${DateFormat('d MMM yyyy').format(d.dueDate!)}', if (overdue) 'OVERDUE']
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: overdue ? expenseColor : null),
              ),
            ]),
          ),
          MoneyText(d.remaining, color: d.settled ? null : color, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        if (!d.settled && d.paid > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: d.paid / d.amount, color: color, borderRadius: BorderRadius.circular(4)),
        ],
      ]),
    );
  }
}

class DebtDetailScreen extends StatelessWidget {
  const DebtDetailScreen({super.key, required this.debtId});
  final int debtId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final d = repo.debts.where((x) => x.id == debtId).firstOrNull;
    if (d == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(
        title: Text(d.person),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showDebtSheet(context, existing: d)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDialog(context, 'Delete debt?', 'Payments history will be removed.')) {
                await repo.deleteDebt(d.id!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d.direction.label} · remaining', style: Theme.of(context).textTheme.labelLarge),
            MoneyText(d.remaining, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            Row(children: [
              const Text('of '),
              MoneyText(d.amount),
            ]),
            if (d.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(d.note)),
            const SizedBox(height: 12),
            if (!d.settled)
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record payment'),
                  onPressed: () => _pay(context, d, null),
                ),
                OutlinedButton(
                  child: const Text('Mark settled'),
                  onPressed: () => _pay(context, d, d.remaining),
                ),
              ]),
          ]),
        ),
        const SectionHeader('Payments'),
        if (d.payments.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('No payments yet.'))
        else
          for (final p in d.payments.reversed)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: MoneyText(p.amount),
              subtitle: Text(dayLabel(p.date)),
            ),
      ]),
    );
  }

  Future<void> _pay(BuildContext context, Debt d, double? amount) async {
    final repo = context.read<FinanceRepository>();
    final v = amount ?? await askAmount(context, title: 'Payment amount', initial: d.remaining);
    if (v == null || v <= 0 || !context.mounted) return;
    final accountId = await _pickAccount(context,
        d.direction == DebtDirection.iOwe ? 'Paid from which account?' : 'Received into which account?');
    await repo.addDebtPayment(d, v, accountId: accountId);
  }
}

/// Optional account picker; returns null for "don't touch my accounts".
Future<int?> _pickAccount(BuildContext context, String title) {
  final repo = context.read<FinanceRepository>();
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) => ListView(shrinkWrap: true, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(title, style: Theme.of(c).textTheme.titleMedium)),
      for (final a in repo.activeAccounts)
        ListTile(leading: Icon(a.type.icon, color: Color(a.color)), title: Text(a.name), onTap: () => Navigator.pop(c, a.id)),
      ListTile(leading: const Icon(Icons.block), title: const Text("Don't record in an account"), onTap: () => Navigator.pop(c)),
    ]),
  );
}

Future<void> showDebtSheet(BuildContext context, {Debt? existing}) {
  final repo = context.read<FinanceRepository>();
  final person = TextEditingController(text: existing?.person ?? '');
  final amount = TextEditingController(text: existing == null ? '' : Money.plain(existing.amount));
  final note = TextEditingController(text: existing?.note ?? '');
  var direction = existing?.direction ?? DebtDirection.iOwe;
  DateTime? due = existing?.dueDate;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(existing == null ? 'New debt' : 'Edit debt', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<DebtDirection>(
              segments: [for (final d in DebtDirection.values) ButtonSegment(value: d, label: Text(d.label))],
              selected: {direction},
              onSelectionChanged: (s) => setState(() => direction = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: person,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Who', hintText: 'Person, bank, or loan name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount', prefixText: '${Money.config.symbol} '),
            ),
            const SizedBox(height: 12),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(due == null ? 'No due date' : 'Due ${DateFormat('d MMM yyyy').format(due!)}'),
              trailing: due == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => due = null)),
              onTap: () async {
                final d = await showDatePicker(
                    context: c, initialDate: due ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => due = d);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                final v = parseAmountInput(amount.text);
                if (person.text.trim().isEmpty || v == null || v <= 0) return;
                int? accountId;
                if (existing == null) {
                  accountId = await _pickAccount(
                      c, direction == DebtDirection.iOwe ? 'Money went into which account?' : 'Money came from which account?');
                }
                await repo.saveDebt(
                  Debt(
                    id: existing?.id,
                    person: person.text.trim(),
                    direction: direction,
                    amount: v,
                    note: note.text.trim(),
                    dueDate: due,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                  accountId: accountId,
                );
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    ),
  );
}
