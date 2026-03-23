// lib/providers/network_sync_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
//  NETWORK SYNC PROVIDER
//  Bridges ConnectivityService + OfflineSyncService into a single Provider
//  state object that drives the NetworkSyncTrackerBar widget.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';

enum TrackerState {
  hidden,     // Online, queue empty, no recent sync
  offline,    // No internet
  syncing,    // Online, sync in progress
  pending,    // Online, has pending items, not currently syncing
  synced,     // Just finished syncing — show confirmation briefly
}

class NetworkSyncProvider extends ChangeNotifier {
  // ── Services ────────────────────────────────────────────────────────────────
  final _connectivity = ConnectivityService.instance;
  final _syncService  = OfflineSyncService.instance;

  // ── Internal state ──────────────────────────────────────────────────────────
  bool _isOnline        = false;
  SyncPhase _syncPhase  = SyncPhase.idle;
  int _pendingCount     = 0;
  bool _showSynced      = false;
  Timer? _syncedTimer;

  StreamSubscription<NetworkStatus>? _networkSub;
  VoidCallback? _syncStateListener;

  // ── Public getters ──────────────────────────────────────────────────────────
  bool get isOnline      => _isOnline;
  int  get pendingCount  => _pendingCount;

  TrackerState get trackerState {
    if (!_isOnline)                         return TrackerState.offline;
    if (_syncPhase == SyncPhase.syncing)    return TrackerState.syncing;
    if (_pendingCount > 0)                  return TrackerState.pending;
    if (_showSynced)                        return TrackerState.synced;
    return TrackerState.hidden;
  }

  // ── Init ────────────────────────────────────────────────────────────────────
  NetworkSyncProvider() {
    // Seed with current values
    _isOnline     = _connectivity.isOnline;
    _syncPhase    = _syncService.syncState.value.phase;
    _pendingCount = _syncService.syncState.value.pendingCount;

    // Listen to connectivity changes
    _networkSub = _connectivity.onStatusChange.listen(_onNetworkChange);

    // Listen to sync state changes
    _syncStateListener = _onSyncStateChange;
    _syncService.syncState.addListener(_syncStateListener!);
  }

  // ── Handlers ────────────────────────────────────────────────────────────────
  void _onNetworkChange(NetworkStatus status) {
    final wasOffline = !_isOnline;
    _isOnline = status == NetworkStatus.online;

    // When back online, kick off a sync if not already syncing
    if (wasOffline && _isOnline) {
      _syncService.processPendingQueue();
    }

    notifyListeners();
  }

  void _onSyncStateChange() {
    final state       = _syncService.syncState.value;
    final wasIdle     = _syncPhase == SyncPhase.idle;
    final wasSyncing  = _syncPhase == SyncPhase.syncing;

    _syncPhase    = state.phase;
    _pendingCount = state.pendingCount;

    // Show "All synced!" confirmation when sync finishes with 0 remaining
    if (wasSyncing && _syncPhase == SyncPhase.idle && _pendingCount == 0) {
      _showSynced = true;
      _syncedTimer?.cancel();
      _syncedTimer = Timer(const Duration(seconds: 3), () {
        _showSynced = false;
        notifyListeners();
      });
    }

    // If we were idle and now have pending items (added while online), reset
    if (wasIdle && _pendingCount > 0 && _syncPhase == SyncPhase.idle) {
      _showSynced = false;
    }

    notifyListeners();
  }

  /// Manually trigger sync (called from "Sync now" button in tracker bar).
  void syncNow() => _syncService.processPendingQueue();

  // ── Dispose ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _networkSub?.cancel();
    if (_syncStateListener != null) {
      _syncService.syncState.removeListener(_syncStateListener!);
    }
    _syncedTimer?.cancel();
    super.dispose();
  }
}
