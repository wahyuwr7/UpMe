import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models.dart';

class CaptureStatus {
  CaptureStatus({
    this.supported = false,
    this.notificationAccess = false,
    this.overlay = false,
    this.postNotifications = false,
    this.enabled = false,
    this.popup = true,
    this.muted = const [],
  });

  final bool supported;
  final bool notificationAccess;
  final bool overlay;
  final bool postNotifications;
  final bool enabled;
  final bool popup;
  final List<String> muted;

  bool get ready => supported && notificationAccess && enabled && (overlay || !popup);
}

class SeenApp {
  SeenApp(this.packageName, this.label, this.count, this.lastSeen);
  final String packageName;
  final String label;
  final int count;
  final DateTime lastSeen;
}

/// Dart side of the `upme/capture` channel (Android only; iOS uses deep links).
class CaptureBridge {
  CaptureBridge._();
  static const _ch = MethodChannel('upme/capture');
  static bool get supported => Platform.isAndroid;

  /// Called by the floating dialog when another notification arrives.
  static void onRefresh(Future<void> Function() handler) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'refresh') await handler();
    });
  }

  static Future<CaptureStatus> status() async {
    if (!supported) return CaptureStatus();
    final m = await _ch.invokeMapMethod<String, dynamic>('status') ?? {};
    return CaptureStatus(
      supported: true,
      notificationAccess: m['notificationAccess'] == true,
      overlay: m['overlay'] == true,
      postNotifications: m['postNotifications'] == true,
      enabled: m['enabled'] == true,
      popup: m['popup'] != false,
      muted: (m['muted'] as List?)?.cast<String>() ?? const [],
    );
  }

  static Future<void> openNotificationAccess() => _ch.invokeMethod('openNotificationAccess');
  static Future<void> openOverlaySettings() => _ch.invokeMethod('openOverlaySettings');
  static Future<void> requestPostNotifications() => _ch.invokeMethod('requestPostNotifications');
  static Future<void> setEnabled(bool v) => _ch.invokeMethod('setEnabled', v);
  static Future<void> setPopup(bool v) => _ch.invokeMethod('setPopup', v);
  static Future<void> setMuted(List<String> pkgs) => _ch.invokeMethod('setMuted', pkgs);

  /// Close the floating dialog activity.
  static Future<void> close() => _ch.invokeMethod('close');

  /// Notifications queued natively, not yet moved into the SQLite inbox.
  static Future<List<InboxItem>> takePending() async {
    if (!supported) return [];
    try {
      final raw = await _ch.invokeMethod<String>('getPending') ?? '[]';
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(InboxItem.fromNative).toList();
    } on MissingPluginException {
      return [];
    }
  }

  static Future<void> ackPending(List<String> ids) async {
    if (!supported || ids.isEmpty) return;
    await _ch.invokeMethod('removePending', ids);
  }

  static Future<List<SeenApp>> seenApps() async {
    if (!supported) return [];
    final raw = await _ch.invokeMethod<String>('seenApps') ?? '{}';
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final apps = m.entries.map((e) {
      final v = e.value as Map<String, dynamic>;
      return SeenApp(e.key, v['label'] as String? ?? e.key, v['count'] as int? ?? 0,
          DateTime.fromMillisecondsSinceEpoch((v['lastSeen'] as num?)?.toInt() ?? 0));
    }).toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return apps;
  }
}
