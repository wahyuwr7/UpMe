import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(tabs: [Tab(text: 'Expense'), Tab(text: 'Income')]),
        ),
        body: TabBarView(children: [
          for (final type in [TxnType.expense, TxnType.income])
            ListView(children: [
              for (final c in repo.categoriesFor(type))
                ListTile(
                  leading: CategoryAvatar(category: c),
                  title: Text(c.name),
                  subtitle: c.excludeFromStats ? const Text('Not counted in charts') : null,
                  onTap: () => _edit(context, type, c),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add category'),
                onTap: () => _edit(context, type, null),
              ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context, TxnType type, Category? existing) {
    final repo = context.read<FinanceRepository>();
    final name = TextEditingController(text: existing?.name ?? '');
    var icon = existing?.icon ?? Icons.more_horiz.codePoint;
    var color = existing?.color ?? accountColors.first;
    var exclude = existing?.excludeFromStats ?? false;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final i in categoryIcons)
                  IconButton(
                    isSelected: icon == i.codePoint,
                    style: IconButton.styleFrom(
                      backgroundColor: icon == i.codePoint ? Color(color).withValues(alpha: 0.2) : null,
                    ),
                    icon: Icon(i, color: icon == i.codePoint ? Color(color) : null),
                    onPressed: () => setState(() => icon = i.codePoint),
                  ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final col in accountColors)
                  GestureDetector(
                    onTap: () => setState(() => color = col),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(col),
                      child: color == col ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exclude from charts'),
                subtitle: const Text('For money movements that aren\'t real spending/income'),
                value: exclude,
                onChanged: (v) => setState(() => exclude = v),
              ),
              Row(children: [
                if (existing != null)
                  IconButton.outlined(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirmDialog(c, 'Delete ${existing.name}?', 'Transactions keep existing but become uncategorized.')) {
                        await repo.deleteCategory(existing.id!);
                        if (c.mounted) Navigator.pop(c);
                      }
                    },
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      await repo.saveCategory(Category(
                          id: existing?.id, name: name.text.trim(), type: type, icon: icon, color: color, excludeFromStats: exclude));
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
}
