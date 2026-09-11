import "dart:convert";
import "dart:typed_data";

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:satyalabel_frontend/core/api_client.dart';
import 'package:satyalabel_frontend/models/scan_models.dart';

void main() {
  group('ApiClient.healthCheck', () {
    test('returns true on 200', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((r) async => http.Response('{"status":"ok"}', 200)),
      );
      expect(await client.healthCheck(), isTrue);
    });

    test('returns false on connection error', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((r) async => throw Exception('boom')),
      );
      expect(await client.healthCheck(), isFalse);
    });
  });

  group('ApiClient.login', () {
    test('parses the token response', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/login');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'i@gov.in');
          return http.Response(
            jsonEncode({
              'access_token': 'tok',
              'token_type': 'bearer',
              'expires_in': 28800,
              'user': {
                'id': 'u1',
                'email': 'i@gov.in',
                'role': 'inspector',
              },
            }),
            200,
          );
        }),
      );
      final auth = await client.login('i@gov.in', 'password1');
      expect(auth.accessToken, 'tok');
      expect(auth.user.role, 'inspector');
    });

    test('throws ApiException with detail on 401', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'detail': 'Incorrect email or password.'}),
            401,
          ),
        ),
      );
      await expectLater(
        client.login('i@gov.in', 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.message, 'message', 'Incorrect email or password.'),
        ),
      );
    });
  });

  group('ApiClient.submitScan', () {
    test('sends multipart with optional fields and Bearer token', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        tokenProvider: () => 'secret-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/scans/');
          expect(request.headers['Authorization'], 'Bearer secret-token');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          final body = request.body;
          expect(body, contains('name="image"'));
          expect(body, contains('name="latitude"\r\n\r\n28.6139'));
          expect(body, contains('name="session_id"\r\n\r\nraid-01'));
          return http.Response(
            jsonEncode({
              'scan_id': 'abc',
              'status': 'COMPLETED',
              'verdict': 'COMPLIANT',
              'ocr': {'engine_used': 'tesseract', 'mean_confidence': 0.9},
              'compliance': {
                'critical_violations': [],
                'warnings': [],
              },
              'extracted_fields': {},
            }),
            200,
          );
        }),
      );
      final result = await client.submitScan(
        Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'image/jpeg',
        latitude: 28.6139,
        longitude: 77.209,
        sessionId: 'raid-01',
      );
      expect(result.scanId, 'abc');
      expect(result.verdict, Verdict.compliant);
      expect(result.violations, isEmpty);
    });

    test('surfaces 415 for unsupported media types', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'detail': "Unsupported image format 'image/tiff'."}),
            415,
          ),
        ),
      );
      await expectLater(
        client.submitScan(Uint8List.fromList([1, 2, 3]), mimeType: 'image/tiff'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 415),
        ),
      );
    });
  });

  group('ApiClient.getScan / listScans', () {
    test('404 becomes ApiException', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient(
          (r) async => http.Response(jsonEncode({'detail': 'not found'}), 404),
        ),
      );
      await expectLater(
        client.getScan('missing'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    test('listScans sends filters and parses the envelope', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.queryParameters['session_id'], 'raid-01');
          expect(request.url.queryParameters['verdict'], 'NON_COMPLIANT');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'scan_id': 's1',
                  'status': 'COMPLETED',
                  'verdict': 'NON_COMPLIANT',
                  'compliance': {
                    'critical_violations': [
                      {
                        'field': 'mrp',
                        'severity': 'CRITICAL',
                        'message': 'MISSING: MRP.',
                        'rule': 'Rule 6(1)(f), LM(PC) Rules 2011',
                      }
                    ],
                    'warnings': [],
                  },
                },
              ],
              'total': 1,
            }),
            200,
          );
        }),
      );
      final list = await client.listScans(
        sessionId: 'raid-01',
        verdict: 'NON_COMPLIANT',
      );
      expect(list.total, 1);
      expect(list.items.single.criticalCount, 1);
    });
  });

  group('ApiClient.requestPdfReport', () {
    test('returns PDF bytes on 200', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/scans/report');
          return http.Response.bytes([0x25, 0x50, 0x44, 0x46], 200); // %PDF
        }),
      );
      final bytes = await client.requestPdfReport(Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg', inspectorBadge: 'INSP-1');
      expect(bytes[0], 0x25); // %
    });
  });
}
