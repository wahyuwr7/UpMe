import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/settings.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'amount_formatter.dart';

const incomeColor = Color(0xFF1E9E5A);
const expenseColor = Color(0xFFE5484D);
const transferColor = Color(0xFF3E7BFA);

Color typeColor(TxnType t) => switch (t) {
      TxnType.income => incomeColor,
      TxnType.expense => expenseColor,
      TxnType.transfer => transferColor,
    };

/// Money text that honours the "hide amounts" privacy toggle.
class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.style, this.signed = false, this.color, this.compact = false});
  final double value;
  final TextStyle? style;
  final bool signed;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final hide = context.select<AppSettings, bool>((s) => s.hideAmounts);
    final text = hide ? '${Money.config.symbol} ••••' : Money.format(value, signed: signed, compact: compact);
    return Text(text,
        style: (style ?? const TextStyle()).copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis);
  }
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, this.category, this.type, this.size = 40});
  final Category? category;
  final TxnType? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = category != null
        ? Color(category!.color)
        : (type == TxnType.transfer ? transferColor : Colors.grey);
    final icon = category?.iconData ?? (type == TxnType.transfer ? Icons.swap_horiz : Icons.help_outline);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(size / 3)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, this.onTap, this.showDate = false});
  final Txn txn;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final cat = repo.category(txn.categoryId);
    final acc = repo.account(txn.accountId);
    final to = repo.account(txn.toAccountId);
    final title = txn.type == TxnType.transfer
        ? (txn.title.isNotEmpty ? txn.title : 'Transfer')
        : (txn.title.isNotEmpty ? txn.title : (cat?.name ?? 'Uncategorized'));
    final sub = [
      if (txn.type == TxnType.transfer) '${acc?.name ?? '?'} → ${to?.name ?? '?'}' else ...[
        if (txn.title.isNotEmpty && cat != null) cat.name,
        acc?.name ?? '?',
      ],
      if (showDate) dayLabel(txn.date) else timeLabel(txn.date),
    ].join(' · ');
    final sign = txn.type == TxnType.income ? 1 : (txn.type == TxnType.expense ? -1 : 0);
    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(category: txn.type == TxnType.transfer ? null : cat, type: txn.type),
      title: Row(children: [
        Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (txn.source != 'manual') ...[
          const SizedBox(width: 6),
          Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
        ],
      ]),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(
        sign == 0 ? txn.amount : sign * txn.amount,
        signed: sign != 0,
        color: typeColor(txn.type),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 6),
      child: Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: cs.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

const accountColors = <int>[
  0xFF0F9D7A, 0xFF1565C0, 0xFF6A1B9A, 0xFFE65100, 0xFFC62828, 0xFF2E7D32,
  0xFF00838F, 0xFF4E342E, 0xFF37474F, 0xFFAD1457, 0xFFF9A825, 0xFF283593,
];

Future<bool> confirmDialog(BuildContext context, String title, String message, {String ok = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

/// Bottom sheet with a money field, used for "update value", "adjust balance", "add payment".
Future<double?> askAmount(BuildContext context, {required String title, double? initial, String? hint}) {
  final ctrl = TextEditingController(text: initial == null ? '' : Money.input(initial));
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(c).textTheme.titleLarge),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [AmountInputFormatter()],
          decoration: InputDecoration(prefixText: '${Money.config.symbol} ', border: const OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(c, parseAmountField(v)),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.pop(c, parseAmountField(ctrl.text)), child: const Text('Save')),
      ]),
    ),
  );
}
