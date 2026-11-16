import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/settings.dart';
import '../../data/backup.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

String _n(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  BackupService _service() =>
      BackupService(context.read<FinanceRepository>().database, context.read<AppSettings>());

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _snack(e is BackupException ? e.message : 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<(String, Uint8List)> _build() async {
    final json = await _service().exportJson();
    return (backupFileName(), Uint8List.fromList(utf8.encode(json)));
  }

  Future<void> _save() => _run(() async {
        final (name, bytes) = await _build();
        final uri = await FilePicker.saveFile(
          fileName: name,
          bytes: bytes,
          mimeType: 'application/json',
          dialogTitle: 'Save UpMe backup',
        );
        if (uri == null) return; // cancelled
        if (!mounted) return;
        context.read<AppSettings>().lastBackupAt = DateTime.now();
        _snack('Backup saved: $name');
      });

  Future<void> _share() => _run(() async {
        final (name, bytes) = await _build();
        final result = await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
          fileNameOverrides: [name],
          subject: 'UpMe backup',
        ));
        if (result.status == ShareResultStatus.dismissed || !mounted) return;
        context.read<AppSettings>().lastBackupAt = DateTime.now();
      });

  Future<void> _restore() => _run(() async {
        final files = await FilePicker.pickFiles(dialogTitle: 'Choose a UpMe backup');
        if (files.isEmpty || !mounted) return;
        final json = utf8.decode(await files.first.readAsBytes(), allowMalformed: true);
        final summary = BackupService.inspect(json); // validates before asking
        if (!mounted) return;
        final when = summary.exportedAt == null
            ? ''
            : ' from ${DateFormat('d MMM yyyy, HH:mm').format(summary.exportedAt!.toLocal())}';
        final ok = await confirmDialog(
          context,
          'Restore backup?',
          'Backup$when contains ${summary.transactions} transactions and ${summary.accounts} accounts.\n\n'
              'Everything currently in UpMe will be REPLACED by this backup.',
          ok: 'Replace & restore',
        );
        if (!ok || !mounted) return;
        final repo = context.read<FinanceRepository>();
        final result = await _service().restore(json);
        await repo.load();
        _snack('Restored ${result.transactions} transactions and ${result.accounts} accounts.');
      });

  @override
  Widget build(BuildContext context) {
    final last = context.watch<AppSettings>().lastBackupAt;
    final repo = context.watch<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(children: [
          if (_busy) const LinearProgressIndicator(),
          AppCard(
            child: Row(children: [
              Icon(last == null ? Icons.warning_amber_rounded : Icons.cloud_done_outlined,
                  color: last == null ? Colors.orange : Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    last == null
                        ? 'No backup yet'
                        : 'Last backup ${DateFormat('d MMM yyyy, HH:mm').format(last)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your data only lives on this phone. Uninstalling UpMe or changing phones deletes it '
                    'unless you keep a backup file somewhere safe.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
              ),
            ]),
          ),
          const SectionHeader('Back up'),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Save backup file'),
            subtitle: const Text('Pick a folder: Downloads, Google Drive, …'),
            onTap: _save,
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share backup'),
            subtitle: const Text('Send it to Drive, email, Telegram "Saved Messages", …'),
            onTap: _share,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 20, 8),
            child: Text(
              'Includes ${_n(repo.transactions.length, 'transaction')}, ${_n(repo.accounts.length, 'account')}, '
              '${_n(repo.investments.length, 'investment')}, ${_n(repo.debts.length, 'debt')}, categories, '
              'what the brain learned and your settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SectionHeader('Restore'),
          ListTile(
            leading: Icon(Icons.settings_backup_restore, color: cs.error),
            title: const Text('Restore from file'),
            subtitle: const Text('Replaces all current data with the backup'),
            onTap: _restore,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'The backup is a plain JSON file and is not encrypted. Keep it somewhere private.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ]),
      ),
    );
  }
}
