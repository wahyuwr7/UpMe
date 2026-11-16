import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../brain/merchant_hints.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../platform/capture_bridge.dart';
import '../widgets/common.dart';
import '../widgets/amount_formatter.dart';

class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({super.key, this.account});
  final Account? account;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _balance = TextEditingController(
      text: widget.account == null
          ? ''
          : Money.input(widget.account!.isCreditCard ? -widget.account!.initialBalance : widget.account!.initialBalance));
  late final _limit = TextEditingController(
      text: (widget.account?.creditLimit ?? 0) == 0 ? '' : Money.input(widget.account!.creditLimit));
  late final _last4 = TextEditingController(text: widget.account?.last4 ?? '');
  late final _keywords = TextEditingController(text: widget.account?.keywords.join(', ') ?? '');
  late AccountType _type = widget.account?.type ?? AccountType.bank;
  late int _color = widget.account?.color ?? accountColors[1];
  late final Set<String> _packages = {...?widget.account?.packages};
  List<SeenApp> _seen = [];

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    CaptureBridge.seenApps().then((v) {
      if (mounted) setState(() => _seen = v);
    }).catchError((_) {});
  }

  Future<void> _save() async {
    final repo = context.read<FinanceRepository>();
    if (_name.text.trim().isEmpty) return;
    final entered = parseAmountField(_balance.text) ?? 0;
    await repo.saveAccount(Account(
      id: widget.account?.id,
      name: _name.text.trim(),
      type: _type,
      initialBalance: _type == AccountType.creditCard ? -entered.abs() : entered,
      creditLimit: _type == AccountType.creditCard ? (parseAmountField(_limit.text) ?? 0) : 0,
      last4: _last4.text.trim(),
      color: _color,
      packages: _packages.toList(),
      keywords: _keywords.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      archived: widget.account?.archived ?? false,
      sort: widget.account?.sort ?? repo.accounts.length,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();
    final appOptions = <String, String>{
      for (final s in _seen) s.packageName: s.label,
      for (final p in _packages) p: _seen.where((s) => s.packageName == p).firstOrNull?.label ?? p,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit account' : 'New account'),
        actions: [
          if (_editing)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final a = widget.account!;
                if (v == 'archive') {
                  await repo.saveAccount(a.copyWith(archived: !a.archived));
                  if (context.mounted) Navigator.pop(context);
                } else if (v == 'delete' &&
                    await confirmDialog(context, 'Delete ${a.name}?',
                        'All transactions of this account will be deleted too. Archive it instead to keep history.')) {
                  await repo.deleteAccount(a.id!);
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'archive', child: Text(widget.account!.archived ? 'Unarchive' : 'Archive')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. BCA, GoPay, Visa Platinum'),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in AccountType.values)
              ChoiceChip(
                avatar: Icon(t.icon, size: 18),
                label: Text(t.label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [AmountInputFormatter()],
            decoration: InputDecoration(
              labelText: _type == AccountType.creditCard ? 'Current outstanding (what you owe)' : 'Starting balance',
              helperText: _editing ? 'Tip: use "Set actual balance" on the account page instead.' : null,
              prefixText: '${Money.config.symbol} ',
            ),
          ),
          if (_type == AccountType.creditCard) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AmountInputFormatter()],
              decoration: InputDecoration(labelText: 'Credit limit', prefixText: '${Money.config.symbol} '),
            ),
          ],
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in accountColors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(c),
                  child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              ),
          ]),
          const Divider(height: 40),
          Row(children: [
            Icon(Icons.psychology, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Help the brain recognise this account', style: Theme.of(context).textTheme.titleSmall),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _last4,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Last 4 digits of card / account (optional)', counterText: ''),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywords,
            decoration: const InputDecoration(
              labelText: 'Keywords in notifications (comma separated)',
              hintText: 'e.g. BCA, KlikBCA',
            ),
          ),
          const SizedBox(height: 16),
          Text('Notifications from these apps belong to this account',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (appOptions.isEmpty)
            Text(
              CaptureBridge.supported
                  ? 'Apps appear here once they send a transaction notification (enable Auto-capture in Settings).'
                  : 'Automatic capture from other apps is Android-only. Use Shortcuts on iOS (see Settings).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in appOptions.entries)
              FilterChip(
                label: Text(e.value),
                selected: _packages.contains(e.key),
                onSelected: (v) => setState(() => v ? _packages.add(e.key) : _packages.remove(e.key)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Known app'),
              onPressed: () async {
                final pkg = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (c) => ListView(children: [
                    for (final e in knownFinanceApps.entries)
                      ListTile(title: Text(e.value.first.toUpperCase()), subtitle: Text(e.key), onTap: () => Navigator.pop(c, e.key)),
                  ]),
                );
                if (pkg != null) setState(() => _packages.add(pkg));
              },
            ),
          ]),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Save account'),
          ),
        ],
      ),
    );
  }
}
