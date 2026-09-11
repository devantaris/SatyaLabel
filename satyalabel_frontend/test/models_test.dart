import 'package:flutter_test/flutter_test.dart';
import 'package:satyalabel_frontend/models/auth_models.dart';
import 'package:satyalabel_frontend/models/scan_models.dart';

/// The full sync scan response from `POST /api/v1/scans/` (docs/api.md).
const syncResponse = {
  'scan_id': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  'verdict': 'NON_COMPLIANT',
  'summary': '❌ NON-COMPLIANT — MISSING: Best Before...',
  'needs_manual_review': false,
  'status': 'COMPLETED',
  'ocr': {
    'engine_used': 'tesseract',
    'mean_confidence': 0.92,
    'raw_text': 'BRITANNIA Marie Gold Biscuits\nNet Qty: 200g\nMRP Rs. 25.00',
  },
  'extracted_fields': {
    'mrp': {
      'found': true,
      'value': '25.00',
      'confidence': 0.92,
      'snippet': 'MRP Rs. 25.00',
    },
    'best_before_date': {'found': false, 'value': null, 'confidence': 0.0},
  },
  'compliance': {
    'verdict': 'NON_COMPLIANT',
    'critical_violations': [
      {
        'field': 'best_before_date',
        'severity': 'CRITICAL',
        'message': 'MISSING: Best Before / Expiry date not found on label.',
        'rule': 'Rule 6(1)(g), LM(PC) Rules 2011',
        'found_value': null,
        'confidence': 0.0,
      }
    ],
    'warnings': [
      {
        'field': 'manufacturer',
        'message': 'Manufacturer name has low confidence.',
        'found_value': 'Britannia',
        'confidence': 0.3,
      }
    ],
    'needs_manual_review': false,
    'checked_at': '2026-09-11T12:00:00+00:00',
    'extracted_fields': {},
  },
  'preprocess_diagnostics': {
    'skew_angle': -1.25,
    'glare_detected': false,
    'perspective_corrected': false,
    'warnings': [],
  },
  'location': {'latitude': 28.6139, 'longitude': 77.209},
  'session_id': 'raid-2026-09-11-01',
  'image_url': '/uploads/7c9e6679.jpg',
  'created_at': '2026-09-11T12:00:00+00:00',
};

/// A persisted record from `GET /api/v1/scans/{id}` (scan_to_dict).
const persistedResponse = {
  'scan_id': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  'status': 'COMPLETED',
  'verdict': 'NEEDS_VERIFICATION',
  'violation_count': 1,
  'ocr_engine': 'easyocr',
  'ocr_confidence': 0.745,
  'extracted_fields': {
    'mrp': {'found': true, 'value': '25.00', 'confidence': 0.9},
  },
  'compliance': {
    'verdict': 'NEEDS_VERIFICATION',
    'critical_violations': [],
    'warnings': [
      {
        'field': 'manufacturer',
        'severity': 'WARNING',
        'message': 'Low confidence',
        'rule': 'Rule 6(1)(d), LM(PC) Rules 2011',
        'found_value': 'Britannia',
        'confidence': 0.4,
      }
    ],
    'needs_manual_review': true,
  },
  'preprocess_diagnostics': {},
  'session_id': null,
  'needs_review': true,
  'report_generated': false,
  'image_url': '/uploads/7c9e6679.jpg',
  'created_at': '2026-09-11T12:00:00+00:00',
};

void main() {
  group('ScanResult.fromJson — sync response', () {
    final result = ScanResult.fromJson(syncResponse);

    test('parses identity fields', () {
      expect(result.scanId, '7c9e6679-7425-40de-944b-e07fc1f90ae7');
      expect(result.status, 'COMPLETED');
      expect(result.verdict, Verdict.nonCompliant);
      expect(result.sessionId, 'raid-2026-09-11-01');
    });

    test('parses OCR from the nested ocr object', () {
      expect(result.ocrEngine, 'tesseract');
      expect(result.ocrConfidence, 0.92);
      expect(result.ocrRawText, contains('Marie Gold'));
    });

    test('merges critical violations and warnings', () {
      expect(result.violations, hasLength(2));
      expect(result.criticalCount, 1);
      expect(result.warningCount, 1);
      final critical = result.violations.first;
      expect(critical.field, 'best_before_date');
      expect(critical.rule, 'Rule 6(1)(g), LM(PC) Rules 2011');
      expect(critical.isCritical, isTrue);
    });

    test('warnings without severity/rule keys default correctly', () {
      final warning = result.violations.last;
      expect(warning.isCritical, isFalse);
      expect(warning.severity, 'WARNING');
      expect(warning.rule, isNull);
    });

    test('parses extracted fields and location', () {
      expect(result.extractedFields, hasLength(2));
      final mrp =
          result.extractedFields.firstWhere((f) => f.name == 'mrp');
      expect(mrp.found, isTrue);
      expect(mrp.value, '25.00');
      expect(result.location?.latitude, 28.6139);
      expect(result.location?.longitude, 77.209);
    });
  });

  group('ScanResult.fromJson — persisted record', () {
    final result = ScanResult.fromJson(persistedResponse);

    test('parses flat ocr fields', () {
      expect(result.ocrEngine, 'easyocr');
      expect(result.ocrConfidence, 0.745);
      expect(result.verdict, Verdict.needsVerification);
    });

    test('reads needs_review flag', () {
      expect(result.needsReview, isTrue);
    });

    test('empty critical list yields zero critical count', () {
      expect(result.criticalCount, 0);
      expect(result.warningCount, 1);
    });
  });

  group('ScanList', () {
    test('parses pagination envelope', () {
      final list = ScanList.fromJson({
        'items': [syncResponse, persistedResponse],
        'total': 42,
        'limit': 50,
        'offset': 0,
      });
      expect(list.items, hasLength(2));
      expect(list.total, 42);
    });
  });

  group('AuthToken / User', () {
    test('parses login response', () {
      final auth = AuthToken.fromJson({
        'access_token': 'eyJhbGciOi...',
        'token_type': 'bearer',
        'expires_in': 28800,
        'user': {
          'id': 'b3a1c2d4-0000-0000-0000-000000000000',
          'email': 'inspector@gov.in',
          'full_name': 'R. Kumar',
          'role': 'inspector',
          'badge_number': 'INSP-DL-2026-084',
          'district': 'New Delhi',
          'created_at': '2026-09-01T10:00:00+00:00',
        },
      });
      expect(auth.user.isInspector, isTrue);
      expect(auth.user.displayName, 'R. Kumar');
      expect(auth.user.badgeNumber, 'INSP-DL-2026-084');
      expect(auth.expiresIn, 28800);
    });

    test('citizen role is not inspector', () {
      final user = User.fromJson({
        'id': 'x',
        'email': 'a@b.c',
        'role': 'citizen',
      });
      expect(user.isInspector, isFalse);
      expect(user.displayName, 'a@b.c'); // falls back to email
    });
  });
}
