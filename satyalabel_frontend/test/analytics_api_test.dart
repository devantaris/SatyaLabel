import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:satyalabel_frontend/core/api_client.dart';

void main() {
  group('ApiClient analytics methods', () {
    test('overview sends days filter and parses counts', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        tokenProvider: () => 'tok',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/analytics/overview');
          expect(request.url.queryParameters['days'], '7');
          expect(request.headers['Authorization'], 'Bearer tok');
          return http.Response(
            jsonEncode({
              'total_scans': 42,
              'non_compliant': 10,
              'needs_verification': 5,
              'compliant': 27,
              'needs_review': 3,
              'sessions': 4,
              'scans_24h': 12,
            }),
            200,
          );
        }),
      );
      final overview = await client.analyticsOverview(days: 7);
      expect(overview['total_scans'], 42);
      expect(overview['non_compliant'], 10);
    });

    test('heatmap parses points envelope', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.queryParameters['min_scans'], '2');
          return http.Response(
            jsonEncode({
              'points': [
                {
                  'latitude': 28.6,
                  'longitude': 77.2,
                  'total_scans': 8,
                  'violations': 6,
                  'needs_verification': 1,
                  'violation_rate': 0.75,
                }
              ],
              'grid_size': 0.05,
              'count': 1,
            }),
            200,
          );
        }),
      );
      final data = await client.analyticsHeatmap(minScans: 2);
      expect(data['count'], 1);
      expect((data['points'] as List).single['violation_rate'], 0.75);
    });

    test('manufacturers parses items', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/analytics/manufacturers');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'manufacturer': 'Britannia',
                  'total_scans': 5,
                  'non_compliant': 3,
                  'needs_verification': 1,
                  'compliant': 1,
                  'last_seen': null,
                }
              ],
              'count': 1,
            }),
            200,
          );
        }),
      );
      final data = await client.analyticsManufacturers();
      expect((data['items'] as List).single['manufacturer'], 'Britannia');
    });

    test('districts parses items', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/analytics/districts');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'district': 'New Delhi',
                  'total_scans': 15,
                  'non_compliant': 4,
                  'needs_verification': 2,
                  'contributors': 3,
                }
              ],
              'count': 1,
            }),
            200,
          );
        }),
      );
      final data = await client.analyticsDistricts();
      expect((data['items'] as List).single['district'], 'New Delhi');
    });

    test('export returns CSV text', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/analytics/export');
          return http.Response(
            'scan_id,created_at,verdict\nabc,2026-09-11,NON_COMPLIANT\n',
            200,
            headers: {'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );
      final csv = await client.analyticsExportCsv();
      expect(csv, startsWith('scan_id'));
      expect(csv, contains('NON_COMPLIANT'));
    });

    test('403 on analytics surfaces ApiException', () async {
      final client = ApiClient(
        baseUrl: 'http://test:8000',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'detail': 'Not enough permissions'}),
            403,
          ),
        ),
      );
      await expectLater(
        client.analyticsOverview(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.isAuthError, 'authError', isTrue),
        ),
      );
    });
  });
}
