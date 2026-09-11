/// Persistent auth session + app configuration (SharedPreferences-backed).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

class SessionStore {
  SessionStore(this._prefs);

  static const _kToken = 'auth.token';
  static const _kUser = 'auth.user';
  static const _kBaseUrl = 'app.base_url';
  static const _kLocalHistory = 'history.scan_ids';
  static const _kSessions = 'inspector.sessions';

  final SharedPreferences _prefs;

  /// Default targets the Android emulator host loopback.
  /// Physical-device builds must point at the dev machine's LAN IP.
  static const defaultBaseUrl = 'http://10.0.2.2:8000';

  String get baseUrl => _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
  Future<void> setBaseUrl(String url) => _prefs.setString(_kBaseUrl, url);

  String? get token => _prefs.getString(_kToken);

  User? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveAuth(AuthToken auth) async {
    await _prefs.setString(_kToken, auth.accessToken);
    await _prefs.setString(_kUser, jsonEncode(auth.user.toJson()));
  }

  Future<void> clearAuth() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
  }

  /// Local scan history for anonymous citizen mode (server is not queried
  /// by user, so recent scan ids are remembered locally).
  List<String> get localScanIds {
    final raw = _prefs.getString(_kLocalHistory);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> addLocalScanId(String scanId) async {
    final ids = [...localScanIds];
    if (ids.contains(scanId)) return;
    ids.insert(0, scanId);
    if (ids.length > 200) ids.removeLast();
    await _prefs.setString(_kLocalHistory, jsonEncode(ids));
  }

  /// Inspector batch sessions created on this device.
  List<String> get sessionIds {
    final raw = _prefs.getString(_kSessions);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> addSessionId(String sessionId) async {
    final ids = [...sessionIds];
    if (ids.contains(sessionId)) return;
    ids.insert(0, sessionId);
    if (ids.length > 50) ids.removeLast();
    await _prefs.setString(_kSessions, jsonEncode(ids));
  }
}

extension on User {
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'badge_number': badgeNumber,
        'district': district,
        'created_at': createdAt,
      };
}
