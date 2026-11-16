import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../brain/transaction_brain.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../capture/inbox_screen.dart';
import '../widgets/common.dart';

/// Paste any notification text and see exactly what the brain decides and why.
class BrainPlayground extends StatefulWidget {
  const BrainPlayground({super.key});

  @override
  State<BrainPlayground> createState() => _BrainPlaygroundState();
}

class _BrainPlaygroundState extends State<BrainPlayground> {
  final _text = TextEditingController(text: 'Pembayaran QRIS Rp 35.000 ke KOPI KENANGAN berhasil');
  Suggestion? _s;

  static const _samples = [
    'Payment of Rp52.300 to Indomaret was successful',
    'Kamu menerima Rp250.000 dari BUDI SANTOSO',
    'Transaksi Kartu Kredit ****1234 sebesar Rp 1.250.000 di TOKOPEDIA berhasil',
    'You spent \$12.50 at Starbucks with card ending 4821',
    'Diskon 50% hingga Rp50.000! Buruan klaim',
  ];

  void _run() {
    final repo = context.read<FinanceRepository>();
    setState(() => _s = repo.brain.analyze(text: _text.text));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final s = _s;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain playground'),
        actions: [
          IconButton(
            tooltip: 'Forget everything learned',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              if (await confirmDialog(context, 'Forget learned rules?',
                  'The brain forgets the ${repo.rules.length} merchants/apps it learned from your confirmations.',
                  ok: 'Forget')) {
                await repo.forgetRules();
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _text,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notification text'),
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in _samples)
            ActionChip(
              label: Text(x.length > 28 ? '${x.substring(0, 28)}…' : x),
              onPressed: () {
                _text.text = x;
                _run();
              },
            ),
        ]),
        const SizedBox(height: 16),
        if (s != null)
          AppCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(s.isTransaction ? Icons.check_circle : Icons.cancel, color: s.isTransaction ? incomeColor : expenseColor),
                const SizedBox(width: 8),
                Text(s.isTransaction ? 'Transaction · ${(s.confidence * 100).round()}% sure' : 'Not a transaction',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              if (s.isTransaction) ...[
                const Divider(),
                _row('Type', s.type.name),
                _row('Amount', s.amount == null ? '-' : Money.format(s.amount!)),
                _row('Account', repo.account(s.accountId)?.name ?? '(ask)'),
                if (s.type == TxnType.transfer) _row('To', repo.account(s.toAccountId)?.name ?? '-'),
                _row('Merchant', s.merchant.isEmpty ? '-' : s.merchant),
                _row('Category', repo.category(s.categoryId)?.name ?? '-'),
              ],
              const Divider(),
              Text('Why', style: Theme.of(context).textTheme.labelLarge),
              for (final r in s.reasons) Text('• $r', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Send to confirm dialog'),
          onPressed: () async {
            final item = InboxItem(
              id: 'test-${DateTime.now().microsecondsSinceEpoch}',
              packageName: 'playground',
              appName: 'Playground',
              title: '',
              text: _text.text,
              postedAt: DateTime.now(),
            );
            await repo.addToInbox([item]);
            if (context.mounted) await openReview(context, item);
          },
        ),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 90, child: Text(k, style: Theme.of(context).textTheme.labelMedium)),
          Expanded(child: Text(v)),
        ]),
      );
}
