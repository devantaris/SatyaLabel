/// Data models mirroring the SatyaLabel backend API responses.
///
/// Shapes follow `docs/api.md` and `app/services/scan_repository.py:scan_to_dict`.
/// Two response shapes exist and are unified here:
///  1. Sync scan response (`POST /api/v1/scans/`) — `ocr` object + `summary`
///  2. Persisted record (`GET /api/v1/scans/{id}`, list items) — flat ocr fields
library;

/// A single compliance violation / warning with its legal citation.
class Violation {
  const Violation({
    required this.field,
    required this.severity,
    required this.message,
    this.rule,
    this.foundValue,
    this.confidence,
  });

  factory Violation.fromJson(Map<String, dynamic> json) => Violation(
        field: json['field'] as String? ?? 'unknown',
        severity: json['severity'] as String? ?? 'WARNING',
        message: json['message'] as String? ?? '',
        rule: json['rule'] as String?,
        foundValue: json['found_value'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );

  final String field;
  final String severity; // CRITICAL | WARNING
  final String message;
  final String? rule; // e.g. "Rule 6(1)(f), LM(PC) Rules 2011"
  final String? foundValue;
  final double? confidence;

  bool get isCritical => severity == 'CRITICAL';
}

/// One of the 10 mandatory declarations extracted from the label.
class ExtractedField {
  const ExtractedField({
    required this.name,
    required this.found,
    this.value,
    this.confidence,
    this.snippet,
  });

  factory ExtractedField.fromJson(String name, Map<String, dynamic> json) =>
      ExtractedField(
        name: name,
        found: json['found'] as bool? ?? false,
        value: json['value'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        snippet: json['snippet'] as String?,
      );

  final String name;
  final bool found;
  final String? value;
  final double? confidence;
  final String? snippet;
}

enum Verdict { compliant, nonCompliant, needsVerification, unknown }

/// Unified scan result covering both the sync-response and persisted shapes.
class ScanResult {
  const ScanResult({
    required this.scanId,
    required this.status,
    this.verdict = Verdict.unknown,
    this.summary,
    this.ocrEngine,
    this.ocrConfidence,
    this.ocrRawText,
    this.violations = const [],
    this.extractedFields = const [],
    this.needsReview = false,
    this.location,
    this.sessionId,
    this.imageUrl,
    this.createdAt,
  });

  /// Parses either the sync scan response or a persisted scan record.
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final compliance = (json['compliance'] as Map<String, dynamic>?) ?? {};
    final ocr = (json['ocr'] as Map<String, dynamic>?) ?? {};

    final violations = <Violation>[
      for (final v in (compliance['critical_violations'] as List? ?? []))
        Violation.fromJson(v as Map<String, dynamic>),
      for (final v in (compliance['warnings'] as List? ?? []))
        Violation.fromJson(v as Map<String, dynamic>),
    ];

    final extracted = <ExtractedField>[];
    final rawFields = (json['extracted_fields'] as Map<String, dynamic>?) ??
        (compliance['extracted_fields'] as Map<String, dynamic>?) ??
        {};
    for (final entry in rawFields.entries) {
      if (entry.value is Map<String, dynamic>) {
        extracted.add(
          ExtractedField.fromJson(entry.key, entry.value as Map<String, dynamic>),
        );
      }
    }

    return ScanResult(
      scanId: json['scan_id'] as String,
      status: json['status'] as String? ?? 'COMPLETED',
      verdict: _parseVerdict(
        json['verdict'] as String? ?? compliance['verdict'] as String?,
      ),
      summary: json['summary'] as String?,
      ocrEngine: ocr['engine_used'] as String? ?? json['ocr_engine'] as String?,
      ocrConfidence: (ocr['mean_confidence'] as num?)?.toDouble() ??
          (json['ocr_confidence'] as num?)?.toDouble(),
      ocrRawText: ocr['raw_text'] as String?,
      violations: violations,
      extractedFields: extracted,
      needsReview: (json['needs_manual_review'] as bool? ??
          json['needs_review'] as bool? ??
          compliance['needs_manual_review'] as bool? ??
          false),
      location: json['location'] == null
          ? null
          : GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      sessionId: json['session_id'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final String scanId;
  final String status; // PENDING | PROCESSING | COMPLETED | FAILED
  final Verdict verdict;
  final String? summary;
  final String? ocrEngine;
  final double? ocrConfidence;
  final String? ocrRawText;
  final List<Violation> violations;
  final List<ExtractedField> extractedFields;
  final bool needsReview;
  final GeoPoint? location;
  final String? sessionId;
  final String? imageUrl;
  final String? createdAt;

  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';

  int get criticalCount =>
      violations.where((v) => v.isCritical).length;
  int get warningCount => violations.where((v) => !v.isCritical).length;

  static Verdict _parseVerdict(String? value) => switch (value) {
        'COMPLIANT' => Verdict.compliant,
        'NON_COMPLIANT' => Verdict.nonCompliant,
        'NEEDS_VERIFICATION' => Verdict.needsVerification,
        _ => Verdict.unknown,
      };
}

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  final double latitude;
  final double longitude;
}

/// A paginated list response from `GET /api/v1/scans/`.
class ScanList {
  const ScanList({required this.items, required this.total});

  factory ScanList.fromJson(Map<String, dynamic> json) => ScanList(
        items: [
          for (final item in (json['items'] as List? ?? []))
            ScanResult.fromJson(item as Map<String, dynamic>),
        ],
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  final List<ScanResult> items;
  final int total;
}
