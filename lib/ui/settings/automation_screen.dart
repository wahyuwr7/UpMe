import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../platform/capture_bridge.dart';
import '../widgets/common.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> with WidgetsBindingObserver {
  CaptureStatus? _status;
  List<SeenApp> _seen = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system permission screens.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!CaptureBridge.supported) return;
    final st = await CaptureBridge.status();
    final seen = await CaptureBridge.seenApps();
    if (!mounted) return;
    setState(() {
      _status = st;
      _seen = seen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-capture')),
      body: CaptureBridge.supported ? _android(context) : const _IosGuide(),
    );
  }

  Widget _android(BuildContext context) {
    final st = _status;
    if (st == null) return const Center(child: CircularProgressIndicator());
    final cs = Theme.of(context).colorScheme;
    Widget step(int n, String title, String sub, bool done, VoidCallback onTap) => ListTile(
          leading: CircleAvatar(
            backgroundColor: done ? Colors.green : cs.surfaceContainerHighest,
            child: done ? const Icon(Icons.check, color: Colors.white) : Text('$n'),
          ),
          title: Text(title),
          subtitle: Text(sub),
          trailing: done ? null : FilledButton.tonal(onPressed: onTap, child: const Text('Allow')),
        );

    return ListView(children: [
      AppCard(
        child: Row(children: [
          Icon(st.ready ? Icons.check_circle : Icons.info_outline, color: st.ready ? Colors.green : cs.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              st.ready
                  ? 'All set. When your bank or e-wallet sends a payment notification, UpMe pops up so you can confirm in one tap.'
                  : 'Two permissions and you never have to type a transaction again.',
            ),
          ),
        ]),
      ),
      const SectionHeader('Permissions'),
      step(1, 'Notification access', 'Lets UpMe read transaction notifications. Nothing leaves your phone.',
          st.notificationAccess, CaptureBridge.openNotificationAccess),
      if (!st.notificationAccess)
        const Padding(
          padding: EdgeInsets.fromLTRB(72, 0, 20, 8),
          child: Text(
            'Greyed out / "Restricted setting"? Installed outside Play Store: open Settings → Apps → UpMe → '
            '⋮ (top right) → Allow restricted settings, then try again.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      step(2, 'Display over other apps', 'Shows the confirm popup right where you are.', st.overlay,
          CaptureBridge.openOverlaySettings),
      step(3, 'Notifications (optional)', 'Fallback "tap to log" notification when the popup is off.',
          st.postNotifications, () async {
        await CaptureBridge.requestPostNotifications();
        await Future<void>.delayed(const Duration(seconds: 1));
        _refresh();
      }),
      const SectionHeader('Behaviour'),
      SwitchListTile(
        title: const Text('Capture transactions'),
        value: st.enabled,
        onChanged: (v) async {
          await CaptureBridge.setEnabled(v);
          _refresh();
        },
      ),
      SwitchListTile(
        title: const Text('Pop up immediately'),
        subtitle: const Text('Off = quietly collect in Inbox and post a notification'),
        value: st.popup,
        onChanged: (v) async {
          await CaptureBridge.setPopup(v);
          _refresh();
        },
      ),
      const SectionHeader('Apps that sent transactions'),
      if (_seen.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Nothing yet. UpMe listens to every app and only reacts to money-looking notifications. '
              'Apps show up here so you can mute noisy ones.'),
        ),
      for (final app in _seen)
        SwitchListTile(
          title: Text(app.label),
          subtitle: Text('${app.packageName} · ${app.count}×'),
          value: !st.muted.contains(app.packageName),
          onChanged: (listen) async {
            final muted = {...st.muted};
            listen ? muted.remove(app.packageName) : muted.add(app.packageName);
            await CaptureBridge.setMuted(muted.toList());
            _refresh();
          },
        ),
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Tip: some phones (Vivo, Xiaomi, Oppo, Samsung) kill background services. If capture stops working, '
          'allow UpMe background power use / "Unrestricted" battery, turn on Auto-start, and lock it in recents.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      const SizedBox(height: 32),
    ]);
  }
}

class _IosGuide extends StatelessWidget {
  const _IosGuide();

  static const _url = 'upme://capture?app=Bank&text=';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('iOS does not let any app read other apps\' notifications.', style: t.titleMedium),
      const SizedBox(height: 8),
      const Text('But Shortcuts can forward bank SMS and Apple Pay payments to UpMe automatically:'),
      const SizedBox(height: 16),
      Text('Bank SMS', style: t.titleSmall),
      const Text('1. Shortcuts → Automation → New → Message\n'
          '2. Sender: your bank, "Run Immediately"\n'
          '3. Action: URL → paste the link below, then insert the "Message" variable at the end\n'
          '4. Action: Open URLs'),
      const SizedBox(height: 16),
      Text('Apple Pay / Wallet', style: t.titleSmall),
      const Text('1. Automation → New → Transaction (Wallet)\n'
          '2. Same URL, insert "Merchant" and "Amount" variables:\n'
          '   ...&text=Paid {Amount} at {Merchant}'),
      const SizedBox(height: 16),
      SelectableText(_url, style: t.bodyLarge?.copyWith(fontFamily: 'monospace')),
      TextButton.icon(
        onPressed: () => Clipboard.setData(const ClipboardData(text: _url)),
        icon: const Icon(Icons.copy),
        label: const Text('Copy link'),
      ),
      const SizedBox(height: 8),
      const Text('UpMe opens with the confirm sheet already filled in by the brain.'),
    ]);
  }
}
