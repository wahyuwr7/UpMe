import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../platform/capture_bridge.dart';
import '../theme.dart';
import 'capture_review.dart';
import 'inbox_sync.dart';

/// The floating dialog shown over other apps (Android `CaptureActivity`).
class CaptureApp extends StatelessWidget {
  const CaptureApp({super.key, required this.repo, required this.settings});
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
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: s.themeMode,
          color: Colors.transparent,
          home: const _CaptureScreen(),
        ),
      ),
    );
  }
}

class _CaptureScreen extends StatefulWidget {
  const _CaptureScreen();

  @override
  State<_CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<_CaptureScreen> {
  List<InboxItem> _queue = [];
  int _index = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    CaptureBridge.onRefresh(_refresh);
    _refresh();
  }

  Future<void> _refresh() async {
    final repo = context.read<FinanceRepository>();
    await syncInbox(repo);
    await repo.load();
    // Silently drop things the brain is confident aren't transactions (promos etc).
    final brain = repo.brain;
    for (final item in List.of(repo.inbox)) {
      final s = brain.analyze(text: item.fullText, packageName: item.packageName);
      if (!s.isTransaction) await repo.removeFromInbox(item.id);
    }
    if (!mounted) return;
    setState(() {
      // Newest first: the one that just popped up is what the user expects to see.
      _queue = repo.inbox.reversed.toList();
      _index = 0;
      _ready = true;
    });
    if (_queue.isEmpty) await CaptureBridge.close();
  }

  Future<void> _next() async {
    if (_index + 1 < _queue.length) {
      setState(() => _index++);
    } else {
      await CaptureBridge.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _queue.isEmpty) {
      return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox.shrink());
    }
    final item = _queue[_index];
    return Scaffold(
      backgroundColor: Colors.black45,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => CaptureBridge.close(), // tap outside = "later"
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // swallow taps on the card
              child: Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: CaptureReview(
                      key: ValueKey(item.id),
                      item: item,
                      position: _queue.length > 1 ? '${_index + 1} of ${_queue.length}' : null,
                      onDone: (_) => _next(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
