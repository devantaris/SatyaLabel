import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:satyalabel_frontend/core/api_client.dart';
import 'package:satyalabel_frontend/services/offline_queue.dart';

Uint8List _fakeImage([int size = 2048]) => Uint8List.fromList(
      List<int>.generate(size, (i) => i % 251),
    );

Future<(OfflineQueue, Directory, SharedPreferences)> _makeQueue() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dir = await Directory.systemTemp.createTemp('satyalabel_queue');
  return (OfflineQueue(prefs: prefs, queueDir: dir), dir, prefs);
}

void main() {
  tearDown(() async {
    final tmp = Directory.systemTemp;
    await for (final entry in tmp.list()) {
      if (entry is Directory && entry.path.contains('satyalabel_queue')) {
        await entry.delete(recursive: true);
      }
    }
  });

  test('enqueue stores the image on disk and metadata in prefs', () async {
    final (queue, dir, prefs) = await _makeQueue();
    final entry = await queue.enqueue(
      _fakeImage(),
      mimeType: 'image/jpeg',
      latitude: 28.6,
      longitude: 77.2,
      sessionId: 'raid-01',
    );

    expect(queue.length, 1);
    expect(File(entry.filePath).existsSync(), isTrue);
    expect(File(entry.filePath).lengthSync(), 2048);
    expect(entry.sessionId, 'raid-01');
    expect(entry.mimeType, 'image/jpeg');

    // Metadata survives a new queue instance over the same prefs.
    final reloaded = OfflineQueue(prefs: prefs, queueDir: dir);
    expect(reloaded.length, 1);
    expect(reloaded.items.single.sessionId, 'raid-01');
  });

  test('sync uploads queued scans and clears the queue', () async {
    final (queue, dir, _) = await _makeQueue();
    await queue.enqueue(_fakeImage(), mimeType: 'image/jpeg');
    await queue.enqueue(_fakeImage(), mimeType: 'image/jpeg');

    var uploads = 0;
    final client = ApiClient(
      baseUrl: 'http://test:8000',
      client: MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        uploads++;
        return http.Response(
          '{"scan_id":"s$uploads","status":"COMPLETED","verdict":"COMPLIANT",'
          '"compliance":{"critical_violations":[],"warnings":[]},'
          '"extracted_fields":{}}',
          200,
        );
      }),
    );

    final synced = await queue.sync(client);
    expect(synced, 2);
    expect(uploads, 2);
    expect(queue.length, 0);
    // Image files are cleaned up after successful upload.
    expect(dir.listSync(), isEmpty);
  });

  test('sync keeps entries and stops when the backend is unreachable',
      () async {
    final (queue, dir, _) = await _makeQueue();
    await queue.enqueue(_fakeImage(), mimeType: 'image/jpeg');

    final client = ApiClient(
      baseUrl: 'http://test:8000',
      client: MockClient(
        (r) async => throw Exception('connection refused'),
      ),
    );

    expect(await queue.sync(client), 0);
    expect(queue.length, 1); // queue preserved for retry
    expect(queue.lastSyncError, 'Backend unreachable');
  });

  test('sync drops scans rejected with 4xx but keeps them on 5xx', () async {
    final (queue, _, _) = await _makeQueue();
    await queue.enqueue(_fakeImage(), mimeType: 'image/jpeg'); // -> 415
    await queue.enqueue(_fakeImage(), mimeType: 'image/jpeg'); // -> 500

    var uploads = 0;
    final client = ApiClient(
      baseUrl: 'http://test:8000',
      client: MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        uploads++;
        return uploads == 1
            ? http.Response('{"detail":"unsupported format"}', 415)
            : http.Response('{"detail":"internal"}', 500);
      }),
    );

    await queue.sync(client);
    expect(uploads, 2);
    // Only the 5xx entry remains queued for retry.
    expect(queue.length, 1);
  });

  test('sync preserves session/location metadata on upload', () async {
    final (queue, _, _) = await _makeQueue();
    await queue.enqueue(
      _fakeImage(),
      mimeType: 'image/jpeg',
      latitude: 28.6139,
      longitude: 77.209,
      sessionId: 'raid-99',
    );

    String? seenBody;
    final client = ApiClient(
      baseUrl: 'http://test:8000',
      client: MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        // Binary image bytes are not valid UTF-8 — inspect the raw stream.
        seenBody = latin1.decode(request.bodyBytes);
        return http.Response(
          '{"scan_id":"s","status":"COMPLETED","verdict":"COMPLIANT",'
          '"compliance":{"critical_violations":[],"warnings":[]},'
          '"extracted_fields":{}}',
          200,
        );
      }),
    );

    await queue.sync(client);
    expect(seenBody, contains('name="latitude"'));
    expect(seenBody, contains('28.6139'));
    expect(seenBody, contains('name="session_id"'));
    expect(seenBody, contains('raid-99'));
  });
}
