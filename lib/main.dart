import 'package:material_ui/material_ui.dart';

import 'core/settings.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'ui/app.dart';
import 'ui/capture/capture_app.dart';

Future<(FinanceRepository, AppSettings)> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final repo = FinanceRepository(await AppDatabase.open());
  await repo.load();
  return (repo, settings);
}

Future<void> main() async {
  final (repo, settings) = await _bootstrap();
  runApp(UpMeApp(repo: repo, settings: settings));
}

/// Entry point of the floating "confirm transaction" dialog (Android CaptureActivity).
@pragma('vm:entry-point')
Future<void> captureMain() async {
  final (repo, settings) = await _bootstrap();
  runApp(CaptureApp(repo: repo, settings: settings));
}
