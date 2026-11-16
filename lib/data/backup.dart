import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/settings.dart';
import '../platform/capture_bridge.dart';
import 'database.dart';

/// Every table holding user data, parents before children (insert order).
const backupTables = [
  'accounts',
  'categories',
  'transactions',
  'debts',
  'debt_payments',
  'investments',
  'inbox',
  'learned_rules',
];

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupSummary {
  BackupSummary(this.counts, this.exportedAt);
  final Map<String, int> counts;
  final DateTime? exportedAt;

  int get transactions => counts['transactions'] ?? 0;
  int get accounts => counts['accounts'] ?? 0;
}

/// Full backup of everything the user entered, as one JSON document.
///
/// Format (v1):
/// ```json
/// { "app": "upme", "format": 1, "exportedAt": "...",
///   "tables": { "accounts": [ {row}, ... ], ... },
///   "settings": { "currency": "IDR", ... },
///   "capture": { "enabled": true, "popup": true, "muted": [...] } }
/// ```
class BackupService {
  BackupService(this._appDb, [this._settings]);
  final AppDatabase _appDb;
  final AppSettings? _settings;
  Database get _db => _appDb.db;

  static const format = 1;

  Future<Map<String, Object?>> export() async {
    final tables = <String, Object?>{};
    for (final t in backupTables) {
      tables[t] = await _db.query(t);
    }
    Map<String, Object?>? capture;
    try {
      if (CaptureBridge.supported) {
        final st = await CaptureBridge.status();
        capture = {'enabled': st.enabled, 'popup': st.popup, 'muted': st.muted};
      }
    } catch (_) {
      // Native side unavailable (tests, iOS): data still backs up fine.
    }
    return {
      'app': 'upme',
      'format': format,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'settings': ?_settings?.toBackup(),
      'capture': ?capture,
    };
  }

  Future<String> exportJson() async => const JsonEncoder.withIndent(' ').convert(await export());

  /// Reads a backup without touching the database (for the confirm dialog).
  static BackupSummary inspect(String json) {
    final m = _decode(json);
    final tables = m['tables'] as Map<String, dynamic>;
    return BackupSummary(
      {for (final t in backupTables) t: (tables[t] as List?)?.length ?? 0},
      DateTime.tryParse(m['exportedAt'] as String? ?? ''),
    );
  }

  /// Replaces ALL current data with the backup. Atomic: on any error nothing changes.
  Future<BackupSummary> restore(String json) async {
    final m = _decode(json);
    final tables = m['tables'] as Map<String, dynamic>;
    final counts = <String, int>{};

    await _db.transaction((txn) async {
      for (final t in backupTables.reversed) {
        await txn.delete(t);
      }
      for (final t in backupTables) {
        // Only copy columns this version knows; missing ones fall back to defaults.
        final cols = (await txn.rawQuery('PRAGMA table_info($t)')).map((c) => c['name'] as String).toSet();
        final rows = (tables[t] as List?) ?? const [];
        final batch = txn.batch();
        for (final r in rows) {
          final row = Map<String, Object?>.from(r as Map)..removeWhere((k, _) => !cols.contains(k));
          batch.insert(t, row);
        }
        await batch.commit(noResult: true);
        counts[t] = rows.length;
      }
    });

    final settings = m['settings'];
    if (settings is Map && _settings != null) _settings.restoreBackup(Map<String, dynamic>.from(settings));

    final capture = m['capture'];
    if (capture is Map && CaptureBridge.supported) {
      try {
        if (capture['enabled'] is bool) await CaptureBridge.setEnabled(capture['enabled'] as bool);
        if (capture['popup'] is bool) await CaptureBridge.setPopup(capture['popup'] as bool);
        if (capture['muted'] is List) await CaptureBridge.setMuted((capture['muted'] as List).cast<String>());
      } catch (_) {}
    }
    return BackupSummary(counts, DateTime.tryParse(m['exportedAt'] as String? ?? ''));
  }

  static Map<String, dynamic> _decode(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw BackupException("This file isn't a UpMe backup (not valid JSON).");
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'upme' || decoded['tables'] is! Map) {
      throw BackupException("This file isn't a UpMe backup.");
    }
    final f = decoded['format'];
    if (f is! int || f > format) {
      throw BackupException('This backup was made by a newer UpMe. Update the app first.');
    }
    return decoded;
  }
}

String backupFileName([DateTime? at]) {
  final d = at ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'upme-backup-${d.year}-${two(d.month)}-${two(d.day)}-${two(d.hour)}${two(d.minute)}.json';
}
