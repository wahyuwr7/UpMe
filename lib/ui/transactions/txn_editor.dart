import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/settings.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

/// Mutable form state for a transaction being created/edited/confirmed.
class TxnDraft {
  TxnDraft({
    this.id,
    this.type = TxnType.expense,
    this.amount,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.merchant = '',
    this.note = '',
    DateTime? date,
    this.source = 'manual',
    this.rawText = '',
  }) : date = date ?? DateTime.now();

  factory TxnDraft.fromTxn(Txn t) => TxnDraft(
        id: t.id,
        type: t.type,
        amount: t.amount,
        accountId: t.accountId,
        toAccountId: t.toAccountId,
        categoryId: t.categoryId,
        merchant: t.merchant,
        note: t.note,
        date: t.date,
        source: t.source,
        rawText: t.rawText,
      );

  int? id;
  TxnType type;
  double? amount;
  int? accountId;
  int? toAccountId;
  int? categoryId;
  String merchant;
  String note;
  DateTime date;
  String source;
  String rawText;

  String? validate() {
    if (amount == null || amount! <= 0) return 'Enter an amount';
    if (accountId == null) return 'Pick an account';
    if (type == TxnType.transfer && (toAccountId == null || toAccountId == accountId)) {
      return 'Pick a different destination account';
    }
    return null;
  }

  Txn toTxn() => Txn(
        id: id,
        type: type,
        amount: amount!,
        accountId: accountId!,
        toAccountId: type == TxnType.transfer ? toAccountId : null,
        categoryId: type == TxnType.transfer ? null : categoryId,
        merchant: merchant.trim(),
        note: note.trim(),
        date: date,
        source: source,
        rawText: rawText,
      );
}

/// The one form used everywhere: manual add, edit, and notification confirm.
class TxnEditor extends StatefulWidget {
  const TxnEditor({
    super.key,
    required this.draft,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.secondaryActions = const [],
    this.autofocusAmount = false,
  });

  final TxnDraft draft;
  final Future<void> Function(Txn txn) onSubmit;
  final String submitLabel;
  final List<Widget> secondaryActions;
  final bool autofocusAmount;

  @override
  State<TxnEditor> createState() => _TxnEditorState();
}

class _TxnEditorState extends State<TxnEditor> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  bool _saving = false;
  String? _error;

  /// Category suggested on open; shown first so it's visible without scrolling.
  int? _pinnedCategory;

  TxnDraft get d => widget.draft;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: d.amount == null ? '' : Money.plain(d.amount!));
    _merchant = TextEditingController(text: d.merchant);
    _note = TextEditingController(text: d.note);
    final repo = context.read<FinanceRepository>();
    final accounts = repo.activeAccounts;
    if (d.accountId == null && accounts.isNotEmpty) {
      final last = context.read<AppSettings>().lastAccountId;
      d.accountId = accounts.any((a) => a.id == last) ? last : accounts.first.id;
    }
    _ensureCategory(repo);
    _pinnedCategory = d.categoryId;
  }

  void _ensureCategory(FinanceRepository repo) {
    if (d.type == TxnType.transfer) return;
    final cats = repo.categoriesFor(d.type);
    if (!cats.any((c) => c.id == d.categoryId)) {
      d.categoryId = cats.where((c) => c.name == 'Other').firstOrNull?.id ?? cats.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    d.amount = parseAmountInput(_amount.text);
    d.merchant = _merchant.text;
    d.note = _note.text;
    final err = d.validate();
    setState(() => _error = err);
    if (err != null) return;
    setState(() => _saving = true);
    try {
      context.read<AppSettings>().lastAccountId = d.accountId;
      await widget.onSubmit(d.toTxn());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: d.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(d.date));
    setState(() {
      d.date = DateTime(date.year, date.month, date.day, time?.hour ?? d.date.hour, time?.minute ?? d.date.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    final accounts = repo.activeAccounts;
    final color = typeColor(d.type);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TxnType>(
          segments: const [
            ButtonSegment(value: TxnType.expense, label: Text('Expense'), icon: Icon(Icons.north_east, size: 16)),
            ButtonSegment(value: TxnType.income, label: Text('Income'), icon: Icon(Icons.south_west, size: 16)),
            ButtonSegment(value: TxnType.transfer, label: Text('Transfer'), icon: Icon(Icons.swap_horiz, size: 16)),
          ],
          selected: {d.type},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            d.type = s.first;
            _ensureCategory(repo);
            _pinnedCategory = d.categoryId;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          autofocus: widget.autofocusAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: color),
          decoration: InputDecoration(
            prefixText: '${Money.config.symbol} ',
            prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color),
            hintText: '0',
            border: InputBorder.none,
            helperText: 'Tip: 25k, 1.5jt, 12k+8k all work',
            helperStyle: TextStyle(color: cs.outline),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 4),
        _label(context, d.type == TxnType.transfer ? 'From' : 'Account'),
        _AccountChips(
          accounts: accounts,
          selected: d.accountId,
          onSelected: (id) => setState(() => d.accountId = id),
        ),
        if (d.type == TxnType.transfer) ...[
          _label(context, 'To'),
          _AccountChips(
            accounts: accounts.where((a) => a.id != d.accountId).toList(),
            selected: d.toAccountId,
            onSelected: (id) => setState(() => d.toAccountId = id),
          ),
        ] else ...[
          _label(context, 'Category'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in _orderedCategories(repo))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(c.iconData, size: 16, color: Color(c.color)),
                      label: Text(c.name),
                      selected: d.categoryId == c.id,
                      onSelected: (_) => setState(() => d.categoryId = c.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: d.type == TxnType.income ? 'From (payer)' : 'Merchant / to',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event, size: 18),
            label: Text('${dayLabel(d.date)}\n${timeLabel(d.date)}', style: const TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),
        const SizedBox(height: 16),
        Row(children: [
          ...widget.secondaryActions.map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(widget.submitLabel),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ]),
      ],
    );
  }

  /// Suggested category first; system categories (debt, adjustments) only if selected.
  List<Category> _orderedCategories(FinanceRepository repo) {
    final cats = repo
        .categoriesFor(d.type)
        .where((c) => !c.excludeFromStats || c.id == d.categoryId)
        .toList();
    final pinned = cats.where((c) => c.id == _pinnedCategory).toList();
    return [...pinned, ...cats.where((c) => c.id != _pinnedCategory)];
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _AccountChips extends StatelessWidget {
  const _AccountChips({required this.accounts, required this.selected, required this.onSelected});
  final List<Account> accounts;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const Text('Add an account in Wallet first');
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final a in accounts)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(a.type.icon, size: 16, color: Color(a.color)),
                label: Text(a.name),
                selected: selected == a.id,
                onSelected: (_) => onSelected(a.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the add/edit sheet. Returns true if something was saved/deleted.
Future<bool?> showTxnSheet(BuildContext context, {Txn? existing, TxnDraft? draft}) {
  final repo = context.read<FinanceRepository>();
  final d = draft ?? (existing != null ? TxnDraft.fromTxn(existing) : TxnDraft());
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(existing == null ? 'New transaction' : 'Edit transaction',
              style: Theme.of(c).textTheme.titleLarge, textAlign: TextAlign.center),
          if (existing?.rawText.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Captured: ${existing!.rawText}',
                  style: Theme.of(c).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 12),
          TxnEditor(
            draft: d,
            autofocusAmount: existing == null && draft == null,
            onSubmit: (t) async {
              await repo.saveTxn(t, learn: true);
              if (c.mounted) Navigator.pop(c, true);
            },
            secondaryActions: [
              if (existing != null)
                IconButton.outlined(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(c, 'Delete transaction?', 'This cannot be undone.')) {
                      await repo.deleteTxn(existing.id!);
                      if (c.mounted) Navigator.pop(c, true);
                    }
                  },
                ),
            ],
          ),
        ]),
      ),
    ),
  );
}
