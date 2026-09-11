/// HTTP client for the SatyaLabel backend.
///
/// Base URL is configurable (Android emulator needs 10.0.2.2, not localhost).
/// An [http.Client] can be injected for testing (see `http/testing.dart`).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/auth_models.dart';
import '../models/scan_models.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    String? Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? (() => null);

  final String baseUrl;
  final http.Client _client;
  final String? Function() _tokenProvider;

  Map<String, String> get _headers {
    final token = _tokenProvider();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Never _throwError(http.Response response) {
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
    } catch (_) {
      // body was not JSON — keep raw
    }
    throw ApiException(response.statusCode, detail);
  }

  // ------------------------------------------------------------- health

  /// Returns true when the backend answers `GET /health` with 200.
  Future<bool> healthCheck({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final response = await _client
          .get(_uri('/health'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------- auth

  Future<AuthToken> login(String email, String password) async {
    http.Response response;
    try {
      response = await _client.post(
        _uri('/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    if (response.statusCode == 200) {
      return AuthToken.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    _throwError(response);
  }

  Future<User> register(
    String email,
    String password, {
    String? fullName,
    String role = 'citizen',
  }) async {
    http.Response response;
    try {
      response = await _client.post(
        _uri('/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          if (fullName != null) 'full_name': fullName,
          'role': role,
        }),
      );
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    if (response.statusCode == 201) {
      return User.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    _throwError(response);
  }

  // -------------------------------------------------------------- scans

  /// Submits a label image for synchronous scanning.
  ///
  /// When [sessionId] is set the scan joins an inspector batch session;
  /// a Bearer token (if logged in) binds the scan to the account.
  Future<ScanResult> submitScan(
    Uint8List imageBytes, {
    required String mimeType,
    double? latitude,
    double? longitude,
    String? sessionId,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/v1/scans/'))
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        contentType: MediaType.parse(mimeType),
      ));
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    if (sessionId != null) request.fields['session_id'] = sessionId;
    request.headers.addAll(_headers);

    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return ScanResult.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    _throwError(response);
  }

  Future<ScanResult> getScan(String scanId) async {
    http.Response response;
    try {
      response = await _client.get(
        _uri('/api/v1/scans/$scanId'),
        headers: _headers,
      );
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    if (response.statusCode == 200) {
      return ScanResult.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    _throwError(response);
  }

  Future<ScanList> listScans({
    String? sessionId,
    String? verdict,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (sessionId != null) 'session_id': sessionId,
      if (verdict != null) 'verdict': verdict,
    };
    http.Response response;
    try {
      response = await _client.get(
        _uri('/api/v1/scans/', query),
        headers: _headers,
      );
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    if (response.statusCode == 200) {
      return ScanList.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    _throwError(response);
  }

  /// Scans + returns the court-ready PDF evidence report bytes.
  Future<Uint8List> requestPdfReport(
    Uint8List imageBytes, {
    required String mimeType,
    String? inspectorBadge,
    String? inspectorName,
    String? locationHint,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/v1/scans/report'))
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        contentType: MediaType.parse(mimeType),
      ));
    if (inspectorBadge != null) request.fields['inspector_badge'] = inspectorBadge;
    if (inspectorName != null) request.fields['inspector_name'] = inspectorName;
    if (locationHint != null) request.fields['location_hint'] = locationHint;

    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    _throwError(response);
  }

  // ---------------------------------------------------------- analytics

  Future<Map<String, dynamic>> analyticsOverview({int? days}) async =>
      _getJsonMap('/api/v1/analytics/overview', days);

  Future<Map<String, dynamic>> analyticsHeatmap({
    double gridSize = 0.05,
    int minScans = 1,
    int? days,
  }) async {
    final data = await _getJsonMap(
      '/api/v1/analytics/heatmap',
      days,
      extra: {
        'grid_size': gridSize.toString(),
        'min_scans': minScans.toString(),
      },
    );
    return {
      'points': data['points'],
      'grid_size': data['grid_size'],
      'count': data['count'],
    };
  }

  Future<Map<String, dynamic>> analyticsManufacturers({
    int minScans = 2,
    int? days,
  }) async =>
      _getJsonMap('/api/v1/analytics/manufacturers', days, extra: {
        'min_scans': minScans.toString(),
      });

  Future<Map<String, dynamic>> analyticsDistricts({int? days}) async =>
      _getJsonMap('/api/v1/analytics/districts', days);

  /// CSV evidence export (inspector/admin only) as text.
  Future<String> analyticsExportCsv({int? days}) async {
    final response = await _client.get(
      _uri('/api/v1/analytics/export', _queryParams(days)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    }
    _throwError(response);
  }

  Future<Map<String, dynamic>> _getJsonMap(
    String path,
    int? days, {
    Map<String, String> extra = const {},
  }) async {
    http.Response response;
    try {
      response = await _client.get(
        _uri(path, {..._queryParams(days), ...extra}),
        headers: _headers,
      );
    } on SocketException catch (e) {
      throw NetworkException('Cannot reach server: $e');
    }
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    _throwError(response);
  }

  Map<String, String> _queryParams(int? days) => {
        if (days != null) 'days': days.toString(),
      };
}
