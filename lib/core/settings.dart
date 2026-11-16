import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    Money.config = CurrencyConfig.byCode(_prefs.getString('currency'));
  }
  final SharedPreferences _prefs;

  static Future<AppSettings> load() async => AppSettings(await SharedPreferences.getInstance());

  CurrencyConfig get currency => Money.config;
  set currency(CurrencyConfig c) {
    Money.config = c;
    _prefs.setString('currency', c.code);
    notifyListeners();
  }

  ThemeMode get themeMode => ThemeMode.values.byName(_prefs.getString('theme') ?? 'system');
  set themeMode(ThemeMode m) {
    _prefs.setString('theme', m.name);
    notifyListeners();
  }

  bool get hideAmounts => _prefs.getBool('hide') ?? false;
  set hideAmounts(bool v) {
    _prefs.setBool('hide', v);
    notifyListeners();
  }

  DateTime? get lastBackupAt {
    final ms = _prefs.getInt('lastBackup');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  set lastBackupAt(DateTime? d) {
    d == null ? _prefs.remove('lastBackup') : _prefs.setInt('lastBackup', d.millisecondsSinceEpoch);
    notifyListeners();
  }

  Map<String, Object?> toBackup() => {
        'currency': currency.code,
        'theme': themeMode.name,
        'hideAmounts': hideAmounts,
        'lastAccountId': lastAccountId,
      };

  void restoreBackup(Map<String, dynamic> m) {
    if (m['currency'] is String) currency = CurrencyConfig.byCode(m['currency'] as String);
    if (m['theme'] is String && ThemeMode.values.any((t) => t.name == m['theme'])) {
      themeMode = ThemeMode.values.byName(m['theme'] as String);
    }
    if (m['hideAmounts'] is bool) hideAmounts = m['hideAmounts'] as bool;
    lastAccountId = m['lastAccountId'] as int?;
  }

  int? get lastAccountId => _prefs.getInt('lastAccount');
  set lastAccountId(int? id) => id == null ? _prefs.remove('lastAccount') : _prefs.setInt('lastAccount', id);
}
