/// Global app state: auth, backend connectivity, offline-queue orchestration.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/session_store.dart';
import '../models/auth_models.dart';
import '../services/offline_queue.dart';

enum AppPersona {
  consumer,
  citizen,
  inspector,
}

class AppState extends ChangeNotifier {
  AppState._(this.store, this.queue, this._connectivity);

  /// Initializes state from disk and starts connectivity monitoring.
  static Future<AppState> create({
  Connectivity? connectivity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final appDir = await getApplicationDocumentsDirectory();
    final queue = OfflineQueue(
      prefs: prefs,
      queueDir: Directory('${appDir.path}/queued_scans'),
    );
    final state = AppState._(SessionStore(prefs), queue, connectivity ?? Connectivity());
    state._init();
    return state;
  }

  final SessionStore store;
  final OfflineQueue queue;
  final Connectivity _connectivity;

  late final ApiClient api = ApiClient(
    baseUrl: store.baseUrl,
    tokenProvider: () => token,
  );

  User? get user => store.user;
  String? get token => store.token;
  bool get isLoggedIn => token != null;
  bool get isInspector => user?.isInspector ?? false;

  AppPersona _activePersona = AppPersona.consumer;
  AppPersona get activePersona => _activePersona;

  void setActivePersona(AppPersona persona) {
    if (_activePersona == persona) return;
    _activePersona = persona;
    notifyListeners();
  }

  /// Last known network interface state (wifi/cellular/none).
  bool hasNetwork = true;

  /// Last known backend reachability (GET /health).
  bool backendReachable = true;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _healthPoll;

  void _init() {
    if (user?.isInspector == true) {
      _activePersona = AppPersona.inspector;
    } else if (user != null) {
      _activePersona = AppPersona.citizen;
    } else {
      _activePersona = AppPersona.consumer;
    }
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      hasNetwork = !results.contains(ConnectivityResult.none);
      notifyListeners();
      _checkBackendAndSync();
    });
    _checkBackendAndSync();
    // Poll backend health periodically so citizen mode can warn early and
    // the queue syncs even if the OS connectivity stream misses a change.
    // NOTE: polled unconditionally — connectivity_plus cannot see adb
    // reverse tunnels (USB-only setups report `none`), and the tunnel can
    // come and go with USB replugs without any connectivity event firing.
    _healthPoll = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkBackendAndSync();
    });
  }

  Future<void> _checkBackendAndSync() async {
    final reachable = await api.healthCheck();
    if (reachable != backendReachable) {
      backendReachable = reachable;
      notifyListeners();
    }
    if (reachable && queue.isNotEmpty && !queue.syncing) {
      await queue.sync(api);
      notifyListeners();
    }
  }

  /// Forces a connectivity + health re-check (pull-to-refresh, screen entry).
  Future<void> refreshConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    hasNetwork = !results.contains(ConnectivityResult.none);
    await _checkBackendAndSync();
    notifyListeners();
  }

  // -------------------------------------------------------------- auth

  Future<void> login(String email, String password) async {
    final auth = await api.login(email, password);
    await store.saveAuth(auth);
    _activePersona = auth.user.isInspector ? AppPersona.inspector : AppPersona.citizen;
    notifyListeners();
  }

  Future<User> register(String email, String password, {String? fullName}) {
    return api.register(email, password, fullName: fullName);
  }

  Future<void> logout() async {
    await store.clearAuth();
    _activePersona = AppPersona.consumer;
    notifyListeners();
  }

  // ------------------------------------------------------------ config

  Future<void> setBaseUrl(String url) async {
    await store.setBaseUrl(url);
    // ApiClient is final/late — rebuild is not possible; simplest correct
    // approach: require an app restart for a base-URL change. Until then,
    // keep serving the old client (documented in the settings UI).
  }

  /// Generates a fresh raid session id, e.g. `raid-20260911-1432`.
  String newSessionId() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final id = 'raid-$stamp';
    store.addSessionId(id);
    return id;
  }

  List<String> get sessionIds => store.sessionIds;

  List<String> get localScanIds => store.localScanIds;
  Future<void> rememberScan(String scanId) async {
    await store.addLocalScanId(scanId);
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _healthPoll?.cancel();
    super.dispose();
  }
}
