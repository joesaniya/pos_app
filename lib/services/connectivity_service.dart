// lib/services/connectivity_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  CONNECTIVITY SERVICE
//  Monitors network state and emits events for offline→online transitions.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _checker = InternetConnectionChecker.createInstance();

  NetworkStatus _status = NetworkStatus.offline;
  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;

  // Broadcast stream so multiple listeners can subscribe.
  final _statusController = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get onStatusChange => _statusController.stream;

  // Fires only when we go online (offline → online transition).
  final _connectedController = StreamController<void>.broadcast();
  Stream<void> get onConnected => _connectedController.stream;

  StreamSubscription? _connectivitySub;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Determine initial state
    _status = await _checkRealConnectivity();
    log('[Connectivity] Initial status: ${_status.name}');

    // Listen to platform connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  // ── Handle connectivity change event ─────────────────────────────────────
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    // Connectivity plugin just tells us if there's a network interface —
    // we still need to verify actual internet access.
    final wasOnline = _status == NetworkStatus.online;
    _status = await _checkRealConnectivity();
    final isNowOnline = _status == NetworkStatus.online;

    log('[Connectivity] Change → ${_status.name} (was: ${wasOnline ? 'online' : 'offline'})');

    _statusController.add(_status);

    // Emit onConnected only on offline → online transition
    if (!wasOnline && isNowOnline) {
      log('[Connectivity] 🟢 Back online — triggering sync');
      _connectedController.add(null);
    }
  }

  // ── Real connectivity check (ping-based) ──────────────────────────────────
  Future<NetworkStatus> _checkRealConnectivity() async {
    try {
      final connected = await _checker.hasConnection;
      return connected ? NetworkStatus.online : NetworkStatus.offline;
    } catch (_) {
      return NetworkStatus.offline;
    }
  }

  /// Force-check current connectivity status (e.g., before initiating a sync).
  Future<bool> checkNow() async {
    _status = await _checkRealConnectivity();
    _statusController.add(_status);
    return _status == NetworkStatus.online;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
    _connectedController.close();
  }
}

// ── ValueNotifier wrapper for use in widgets ──────────────────────────────
class NetworkStatusNotifier extends ValueNotifier<NetworkStatus> {
  StreamSubscription? _sub;

  NetworkStatusNotifier() : super(ConnectivityService.instance.status) {
    _sub = ConnectivityService.instance.onStatusChange.listen((s) {
      value = s;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
