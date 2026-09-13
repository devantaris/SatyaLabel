/// Offline scan queue: captures taken without connectivity are stored on
/// disk and synced (via the synchronous scan endpoint) once the backend is
/// reachable again.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';

/// A scan waiting to be uploaded.
class QueuedScan {
  QueuedScan({
    required this.id,
    required this.filePath,
    required this.mimeType,
    this.latitude,
    this.longitude,
    this.sessionId,
    this.ocrText,
    required this.queuedAt,
  });

  factory QueuedScan.fromJson(Map<String, dynamic> json) => QueuedScan(
        id: json['id'] as String,
        filePath: json['file_path'] as String,
        mimeType: json['mime_type'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        sessionId: json['session_id'] as String?,
        ocrText: json['ocr_text'] as String?,
        queuedAt: DateTime.parse(json['queued_at'] as String),
      );

  final String id;
  final String filePath;
  final String mimeType; // image/jpeg | image/png | image/webp
  final double? latitude;
  final double? longitude;
  final String? sessionId;
  final String? ocrText; // on-device ML Kit OCR text (uploaded with image)
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_path': filePath,
        'mime_type': mimeType,
        'latitude': latitude,
        'longitude': longitude,
        'session_id': sessionId,
        'ocr_text': ocrText,
        'queued_at': queuedAt.toIso8601String(),
      };
}

/// Persists queued scans: image bytes as files under [queueDir], metadata
/// in SharedPreferences. [queueDir] is injected so tests can use a temp dir.
class OfflineQueue extends ChangeNotifier {
  OfflineQueue({required SharedPreferences prefs, required Directory queueDir})
      : _prefs = prefs,
        _queueDir = queueDir {
    _load();
  }

  static const _kQueue = 'offline_queue.items';

  final SharedPreferences _prefs;
  final Directory _queueDir;
  final _rand = Random();

  List<QueuedScan> _items = [];
  List<QueuedScan> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isNotEmpty => _items.isNotEmpty;

  bool _syncing = false;
  bool get syncing => _syncing;

  String _lastSyncError = '';
  String get lastSyncError => _lastSyncError;

  void _load() {
    final raw = _prefs.getString(_kQueue);
    if (raw == null) return;
    try {
      _items = [
        for (final e in (jsonDecode(raw) as List))
          QueuedScan.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      _items = [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _kQueue,
      jsonEncode([for (final q in _items) q.toJson()]),
    );
    notifyListeners();
  }

  /// Stores an image for later upload. Returns the queue entry.
  Future<QueuedScan> enqueue(
    Uint8List imageBytes, {
    required String mimeType,
    double? latitude,
    double? longitude,
    String? sessionId,
    String? ocrText,
  }) async {
    if (!_queueDir.existsSync()) {
      _queueDir.createSync(recursive: true);
    }
    // Microsecond timestamp + random suffix guards against collisions when
    // multiple photos are queued within the same microsecond (tests, burst).
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';
    final ext = switch (mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
    final file = File('${_queueDir.path}/$id$ext');
    await file.writeAsBytes(imageBytes);

    final entry = QueuedScan(
      id: id,
      filePath: file.path,
      mimeType: mimeType,
      latitude: latitude,
      longitude: longitude,
      sessionId: sessionId,
      ocrText: ocrText,
      queuedAt: DateTime.now(),
    );
    _items.add(entry);
    await _persist();
    return entry;
  }

  /// Uploads every queued scan using the synchronous scan endpoint.
  /// Entries are removed only after a successful upload; server-side
  /// validation errors (4xx) drop the item as unrecoverable.
  ///
  /// Returns the number of scans successfully synced.
  Future<int> sync(ApiClient client) async {
    if (_syncing || _items.isEmpty) return 0;
    _syncing = true;
    _lastSyncError = '';
    notifyListeners();

    var synced = 0;
    try {
      // Fail fast if the backend is unreachable — keep the queue intact.
      if (!await client.healthCheck()) {
        _lastSyncError = 'Backend unreachable';
        return 0;
      }
      final remaining = <QueuedScan>[];
      for (final entry in _items) {
        final file = File(entry.filePath);
        if (!await file.exists()) {
          continue; // image gone (e.g. cache cleared) — drop silently
        }
        try {
          await client.submitScan(
            await file.readAsBytes(),
            mimeType: entry.mimeType,
            latitude: entry.latitude,
            longitude: entry.longitude,
            sessionId: entry.sessionId,
            ocrText: entry.ocrText,
          );
          synced++;
          await file.delete();
        } on ApiException catch (e) {
          if (e.statusCode >= 400 && e.statusCode < 500) {
            // Rejected by the server (e.g. corrupt image) — will never
            // succeed on retry, so drop it but remember why.
            _lastSyncError = 'Dropped a scan: ${e.message}';
            await file.delete();
          } else {
            remaining.add(entry); // 5xx — retry later
          }
        } on NetworkException {
          remaining.add(entry); // connection lost mid-sync — retry later
          _lastSyncError = 'Connection lost during sync';
          break;
        }
      }
      _items = remaining;
      return synced;
    } finally {
      _syncing = false;
      await _persist();
    }
  }
}
