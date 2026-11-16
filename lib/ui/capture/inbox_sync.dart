import '../../data/repository.dart';
import '../../platform/capture_bridge.dart';

/// Moves notifications queued by the native listener into the SQLite inbox.
Future<void> syncInbox(FinanceRepository repo) async {
  final pending = await CaptureBridge.takePending();
  if (pending.isEmpty) return;
  await repo.addToInbox(pending);
  await CaptureBridge.ackPending(pending.map((e) => e.id).toList());
}
