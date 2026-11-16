import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../brain/transaction_brain.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../transactions/txn_editor.dart';

TxnDraft draftFromSuggestion(Suggestion s, InboxItem item) => TxnDraft(
      type: s.type,
      amount: s.amount,
      accountId: s.accountId,
      toAccountId: s.toAccountId,
      categoryId: s.categoryId,
      merchant: s.merchant,
      date: item.postedAt.millisecondsSinceEpoch > 0 ? item.postedAt : DateTime.now(),
      source: item.packageName == 'shortcut' ? 'shortcut' : 'notification',
      rawText: item.fullText,
    );

/// Shows what the brain understood from a notification and lets the user
/// confirm, edit, ignore or postpone it.
class CaptureReview extends StatefulWidget {
  const CaptureReview({super.key, required this.item, required this.onDone, this.position});
  final InboxItem item;

  /// Called after save / ignore / later. `saved` is true when a transaction was stored.
  final void Function(bool saved) onDone;

  /// e.g. "1 of 3"
  final String? position;

  @override
  State<CaptureReview> createState() => _CaptureReviewState();
}

class _CaptureReviewState extends State<CaptureReview> {
  late Suggestion _s;
  late TxnDraft _draft;
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<FinanceRepository>();
    _s = repo.brain.analyze(
      text: widget.item.fullText,
      packageName: widget.item.packageName,
      appName: widget.item.appName,
    );
    _draft = draftFromSuggestion(_s, widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    final conf = (_s.confidence * 100).round();
    final confColor = conf >= 75 ? Colors.green : (conf >= 50 ? Colors.orange : cs.error);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.auto_awesome, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New transaction detected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                [widget.item.appName.isEmpty ? widget.item.packageName : widget.item.appName, ?widget.position]
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
          Tooltip(
            message: _s.reasons.join('\n'),
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 8),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.psychology, size: 16, color: confColor),
              label: Text(_s.isTransaction ? '$conf% sure' : 'Unsure'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _showRaw = !_showRaw),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Text(
              widget.item.fullText,
              maxLines: _showRaw ? 20 : 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        if (!_s.isTransaction)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text("Brain doesn't think this is a transaction (${_s.reasons.lastOrNull ?? ''}).",
                style: TextStyle(color: cs.error, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        TxnEditor(
          draft: _draft,
          submitLabel: 'Save',
          onSubmit: (t) async {
            await repo.confirmInbox(widget.item, t);
            widget.onDone(true);
          },
          secondaryActions: [
            OutlinedButton(
              onPressed: () async {
                await repo.removeFromInbox(widget.item.id);
                widget.onDone(false);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Ignore'),
            ),
            OutlinedButton(
              onPressed: () => widget.onDone(false),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Later'),
            ),
          ],
        ),
      ],
    );
  }
}
