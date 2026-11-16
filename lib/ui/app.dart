import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/settings.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'capture/inbox_screen.dart';
import 'capture/inbox_sync.dart';
import 'nav.dart';
import 'dashboard/dashboard_screen.dart';
import 'settings/settings_screen.dart';
import 'theme.dart';
import 'transactions/transactions_screen.dart';
import 'transactions/txn_editor.dart';
import 'wallet/wallet_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class UpMeApp extends StatelessWidget {
  const UpMeApp({super.key, required this.repo, required this.settings});
  final FinanceRepository repo;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: Consumer<AppSettings>(
        builder: (_, s, _) => MaterialApp(
          title: 'UpMe',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: s.themeMode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
    StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
    _listenDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The floating dialog writes to the same DB from another engine; refresh on return.
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    final repo = context.read<FinanceRepository>();
    await syncInbox(repo);
    await repo.load();
  }

  /// `upme://capture?text=...&title=...&app=...` — used by iOS Shortcuts automations
  /// (e.g. "When I receive a message from my bank" / Wallet transaction trigger).
  void _listenDeepLinks() {
    final links = AppLinks();
    _links = links.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.host != 'capture') return;
    final q = uri.queryParameters;
    final text = q['text'] ?? '';
    if (text.trim().isEmpty && (q['amount'] ?? '').isEmpty) return;
    final item = InboxItem(
      id: 'link-${DateTime.now().microsecondsSinceEpoch}',
      packageName: 'shortcut',
      appName: q['app'] ?? 'Shortcut',
      title: q['title'] ?? '',
      text: [text, if (q['amount'] != null) '${Money.config.symbol} ${q['amount']}'].join(' ').trim(),
      postedAt: DateTime.now(),
    );
    final repo = context.read<FinanceRepository>();
    await repo.addToInbox([item]);
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) await openReview(ctx, item);
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [DashboardScreen(), TransactionsScreen(), WalletScreen(), SettingsScreen()];
    return ValueListenableBuilder<int>(
      valueListenable: homeTab,
      builder: (context, tab, _) => _scaffold(context, pages, tab),
    );
  }

  Widget _scaffold(BuildContext context, List<Widget> pages, int tab) {
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: tab <= 1
          ? FloatingActionButton.extended(
              onPressed: () => showTxnSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => homeTab.value = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
