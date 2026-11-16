import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/settings.dart';
import '../../data/repository.dart';
import '../../platform/capture_bridge.dart';
import '../capture/inbox_screen.dart';
import '../widgets/common.dart';
import 'automation_screen.dart';
import 'brain_playground.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final repo = context.watch<FinanceRepository>();
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        const SectionHeader('Automation'),
        ListTile(
          leading: const Icon(Icons.bolt),
          title: const Text('Auto-capture'),
          subtitle: Text(CaptureBridge.supported
              ? 'Read bank & e-wallet notifications, confirm with one tap'
              : 'Use iOS Shortcuts to send bank messages to UpMe'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const AutomationScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.inbox_outlined),
          title: const Text('Inbox'),
          trailing: repo.inbox.isEmpty ? const Icon(Icons.chevron_right) : Badge(label: Text('${repo.inbox.length}')),
          onTap: () => push(const InboxScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.psychology_outlined),
          title: const Text('Brain playground'),
          subtitle: Text('Test a notification · ${repo.rules.length} things learned'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const BrainPlayground()),
        ),
        const SectionHeader('General'),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const CategoriesScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.currency_exchange),
          title: const Text('Currency'),
          subtitle: Text('${s.currency.code} (${s.currency.symbol})'),
          onTap: () async {
            final c = await showModalBottomSheet<CurrencyConfig>(
              context: context,
              showDragHandle: true,
              builder: (c) => ListView(children: [
                for (final p in CurrencyConfig.presets)
                  ListTile(
                    title: Text('${p.code}  ${p.symbol}'),
                    trailing: p.code == s.currency.code ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(c, p),
                  ),
              ]),
            );
            if (c != null) s.currency = c;
          },
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Theme'),
          trailing: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.themeMode = v.first,
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off_outlined),
          title: const Text('Hide amounts'),
          subtitle: const Text('For checking the app in public'),
          value: s.hideAmounts,
          onChanged: (v) => s.hideAmounts = v,
        ),
        const SectionHeader('About'),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Your data stays on this phone'),
          subtitle: Text('No account, no cloud, no tracking. The brain runs fully on-device.'),
        ),
      ]),
    );
  }
}
