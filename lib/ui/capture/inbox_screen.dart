import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';
import 'capture_review.dart';

/// Detected transactions you postponed (or that arrived while popups were off).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final items = repo.inbox.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                if (await confirmDialog(context, 'Clear inbox?', 'Ignore all ${items.length} detected items.',
                    ok: 'Clear')) {
                  for (final i in items) {
                    await repo.removeFromInbox(i.id);
                  }
                }
              },
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'All caught up',
              subtitle: 'Transactions detected from your notifications show up here until you confirm them.',
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) {
                final item = items[i];
                final s = repo.brain.analyze(text: item.fullText, packageName: item.packageName);
                return AppCard(
                  onTap: () => openReview(context, item),
                  child: Row(children: [
                    CategoryAvatar(category: repo.category(s.categoryId), type: s.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.merchant.isNotEmpty ? s.merchant : item.appName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(item.fullText, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(c).textTheme.bodySmall),
                        Text('${item.appName} · ${dayLabel(item.postedAt)} ${timeLabel(item.postedAt)}',
                            style: Theme.of(c).textTheme.labelSmall),
                      ]),
                    ),
                    if (s.amount != null)
                      MoneyText(s.amount!, color: typeColor(s.type), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                );
              },
            ),
    );
  }
}

Future<void> openReview(BuildContext context, InboxItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: CaptureReview(item: item, onDone: (_) => Navigator.pop(c)),
      ),
    ),
  );
}
