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
  final _checker = InternetConnectionChecker.createInstance(
    checkInterval: const Duration(seconds: 10),
    checkTimeout: const Duration(seconds: 5),
  );

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
  Timer? _periodicValidationTimer;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Determine initial state
    _status = await _checkRealConnectivity();
    log('[Connectivity] Initial status: ${_status.name}');

    // Listen to platform connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Start periodic validation to catch stuck states (every 30 seconds)
    _periodicValidationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _validateCurrentStatus(),
    );
  }

  // ── Handle connectivity change event ─────────────────────────────────────
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    // If still shows no real interfaces, we're definitely offline
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _updateStatus(NetworkStatus.offline, 'No interfaces available');
      return;
    }

    // Otherwise, verify actual internet access with retries
    final connected = await _checkRealConnectivityWithRetry();
    _updateStatus(
      connected ? NetworkStatus.online : NetworkStatus.offline,
      'Connectivity change detected',
    );
  }

  // ── Periodic validation to catch stuck states ───────────────────────────
  Future<void> _validateCurrentStatus() async {
    final shouldBeOnline = await _checkRealConnectivityWithRetry();
    final actualOnline = _status == NetworkStatus.online;

    if (shouldBeOnline && !actualOnline) {
      log('[Connectivity] ⚠️ STUCK IN OFFLINE! Correcting to ONLINE');
      _updateStatus(NetworkStatus.online, 'Stuck state detected and fixed');
    } else if (!shouldBeOnline && actualOnline) {
      log('[Connectivity] ⚠️ STUCK IN ONLINE! Correcting to OFFLINE');
      _updateStatus(NetworkStatus.offline, 'Stuck state detected and fixed');
    }
  }

  // ── Real connectivity check with retry logic ─────────────────────────────
  Future<bool> _checkRealConnectivityWithRetry({
    int maxRetries = 3,
    Duration delayBetweenRetries = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final connected = await _checker.hasConnection;
        log('[Connectivity] Attempt $attempt/$maxRetries: $connected');
        if (connected) {
          return true; // Success on this attempt
        }
      } catch (e) {
        log('[Connectivity] Attempt $attempt/$maxRetries failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(delayBetweenRetries);
        }
      }
    }

    // All retries exhausted, assume offline
    log('[Connectivity] All $maxRetries retry attempts failed → offline');
    return false;
  }

  // ── Real connectivity check (simple version) ────────────────────────────
  Future<NetworkStatus> _checkRealConnectivity() async {
    final connected = await _checkRealConnectivityWithRetry();
    return connected ? NetworkStatus.online : NetworkStatus.offline;
  }

  // ── Helper to update status consistently ─────────────────────────────────
  void _updateStatus(NetworkStatus newStatus, String reason) {
    final wasOnline = _status == NetworkStatus.online;
    _status = newStatus;
    final isNowOnline = _status == NetworkStatus.online;

    log('[Connectivity] Status → ${_status.name} ($reason)');
    _statusController.add(_status);

    // Emit onConnected only on offline → online transition
    if (!wasOnline && isNowOnline) {
      log('[Connectivity] 🟢 Back online — triggering sync');
      _connectedController.add(null);
    }
  }

  /// Force-check current connectivity status with retries (e.g., before initiating a sync).
  Future<bool> checkNow() async {
    final connected = await _checkRealConnectivityWithRetry();
    final newStatus = connected ? NetworkStatus.online : NetworkStatus.offline;
    _updateStatus(newStatus, 'Manual check');
    return connected;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _periodicValidationTimer?.cancel();
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
