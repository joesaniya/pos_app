// 🔥 KOT OFFLINE SYNC SERVICE - Offline-First Support
// lib/services/kot_offline_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/kot_models.dart';
import 'kot_service.dart';

typedef OnSyncProgress = void Function(int completed, int total);
typedef OnConflict =
    void Function(String itemId, dynamic localChange, dynamic cloudChange);

class KOTOfflineSyncService {
  static final KOTOfflineSyncService _instance =
      KOTOfflineSyncService._internal();

  factory KOTOfflineSyncService() => _instance;

  KOTOfflineSyncService._internal();

  final supabase = Supabase.instance.client;
  late KOTService kotService;

  late Box<Map> _offlineSyncQueue;

  final List<OnSyncProgress> _syncProgressCallbacks = [];

  /// Initialize offline sync
  Future<void> initialize() async {
    try {
      kotService = KOTService();

      _offlineSyncQueue = await Hive.openBox<Map>('kot_offline_queue');

      debugPrint('✅ Offline sync initialized');

      // Start monitoring connection for auto-sync
      _monitorConnectionForSync();
    } catch (e) {
      debugPrint('❌ Error initializing offline sync: $e');
    }
  }

  /// Record an offline change (when network is unavailable)
  ///
  /// This stores the change locally and will sync when connection is restored
  Future<void> recordItemStatusUpdate({
    required String kotId,
    required String itemId,
    required KOTItemStatus newStatus,
    required String businessId,
    String? updatedByUid,
    String? updatedByName,
  }) async {
    try {
      final changeId = '${itemId}_${DateTime.now().millisecondsSinceEpoch}';

      final changeData = {
        'id': changeId,
        'type': 'item_status_update',
        'kot_id': kotId,
        'item_id': itemId,
        'business_id': businessId,
        'new_status': newStatus.toString().split('.').last,
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'recorded_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
        'attempt_count': 0,
      };

      await _offlineSyncQueue.put(changeId, changeData);

      debugPrint('💾 Recorded offline item status change: $changeId');
    } catch (e) {
      debugPrint('❌ Error recording offline change: $e');
    }
  }

  /// Record batch addition (when adding items offline)
  Future<void> recordBatchAddition({
    required String kotId,
    required String businessId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final batchId = '${kotId}_batch_${DateTime.now().millisecondsSinceEpoch}';

      final changeData = {
        'id': batchId,
        'type': 'batch_addition',
        'kot_id': kotId,
        'business_id': businessId,
        'items': items,
        'recorded_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
        'attempt_count': 0,
      };

      await _offlineSyncQueue.put(batchId, changeData);

      debugPrint('💾 Recorded offline batch addition: $batchId');
    } catch (e) {
      debugPrint('❌ Error recording batch addition: $e');
    }
  }

  /// Get pending changes that need to be synced
  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    try {
      final pending = <Map<String, dynamic>>[];

      for (final key in _offlineSyncQueue.keys) {
        final change = _offlineSyncQueue.get(key) as Map<String, dynamic>?;
        if (change != null && change['sync_status'] == 'pending') {
          pending.add(change);
        }
      }

      return pending;
    } catch (e) {
      debugPrint('❌ Error getting pending changes: $e');
      return [];
    }
  }

  /**
   * Sync pending changes with cloud when connection is restored
   */
  Future<SyncResult> syncPendingChanges({
    required String businessId,
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.useCloud,
  }) async {
    try {
      final pendingChanges = await getPendingChanges();
      final syncResult = SyncResult();

      for (int i = 0; i < pendingChanges.length; i++) {
        final change = pendingChanges[i];

        try {
          // Notify progress
          _notifySyncProgress(i, pendingChanges.length);

          // Check for conflicts
          final hasConflict = await _detectConflict(change);

          if (hasConflict) {
            // Try to resolve conflict
            final resolved = await _resolveConflict(change, strategy);

            if (resolved) {
              await _markChangeSynced(change['id']);
              syncResult.succeededIds.add(change['id']);
            } else {
              syncResult.conflictIds.add(change['id']);
            }
          } else {
            // No conflict, apply change
            final applied = await _applyChange(change);

            if (applied) {
              await _markChangeSynced(change['id']);
              syncResult.succeededIds.add(change['id']);
            } else {
              syncResult.failedIds.add(change['id']);
            }
          }
        } catch (e) {
          debugPrint('❌ Error syncing change ${change['id']}: $e');
          syncResult.failedIds.add(change['id']);
          await _incrementAttempt(change['id']);
        }
      }

      debugPrint(
        '✅ Sync complete: ${syncResult.succeededIds.length}/${pendingChanges.length} successful',
      );
      return syncResult;
    } catch (e) {
      debugPrint('❌ Error syncing pending changes: $e');
      return SyncResult();
    }
  }

  /**
   * Detect if a change has conflicts with cloud version
   */
  Future<bool> _detectConflict(Map<String, dynamic> change) async {
    try {
      if (change['type'] == 'item_status_update') {
        // Check if item still exists and what's its current status
        final itemId = change['item_id'];

        final response = await supabase
            .from('kot_items')
            .select()
            .eq('id', itemId)
            .maybeSingle();

        if (response == null) {
          // Item doesn't exist - conflict
          return true;
        }

        final cloudItem = KOTItem.fromJson(response);
        final localStatus = KOTItemStatus.values.firstWhere(
          (e) => e.toString().split('.').last == change['new_status'],
        );

        // Conflict if cloud version is further along or already served
        if (cloudItem.status == KOTItemStatus.served &&
            localStatus != KOTItemStatus.served) {
          return true;
        }

        if (cloudItem.status == KOTItemStatus.cancelled) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Error detecting conflict: $e');
      return true; // Assume conflict on error
    }
  }

  /// Resolve conflicts based on strategy
  Future<bool> _resolveConflict(
    Map<String, dynamic> change,
    ConflictResolutionStrategy strategy,
  ) async {
    try {
      debugPrint('🔄 Resolving conflict for ${change['id']} using $strategy');

      if (strategy == ConflictResolutionStrategy.useCloud) {
        // Discard local change, keep cloud version
        debugPrint('  → Keeping cloud version');
        return true;
      } else if (strategy == ConflictResolutionStrategy.useLocal) {
        // Force local change
        debugPrint('  → Forcing local change');
        return await _applyChange(change);
      } else if (strategy == ConflictResolutionStrategy.merge) {
        // Try intelligent merge
        return await _mergeChanges(change);
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error resolving conflict: $e');
      return false;
    }
  }

  /// Intelligent merge strategy
  Future<bool> _mergeChanges(Map<String, dynamic> change) async {
    try {
      // For item status updates, if cloud is ready and local is preparing,
      // accept cloud (ready is further along)
      if (change['type'] == 'item_status_update') {
        final itemId = change['item_id'];

        final response = await supabase
            .from('kot_items')
            .select()
            .eq('id', itemId)
            .single();

        final cloudItem = KOTItem.fromJson(response);
        final statusPriority = <KOTItemStatus, int>{
          KOTItemStatus.pending: 0,
          KOTItemStatus.preparing: 1,
          KOTItemStatus.ready: 2,
          KOTItemStatus.served: 3,
          KOTItemStatus.cancelled: -1,
        };

        final localStatus = KOTItemStatus.values.firstWhere(
          (e) => e.toString().split('.').last == change['new_status'],
        );

        // Use whichever is further along
        if ((statusPriority[cloudItem.status] ?? 0) >=
            (statusPriority[localStatus] ?? 0)) {
          return true; // Keep cloud
        } else {
          return await _applyChange(change);
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error merging changes: $e');
      return false;
    }
  }

  /// Apply a change to the cloud database
  Future<bool> _applyChange(Map<String, dynamic> change) async {
    try {
      if (change['type'] == 'item_status_update') {
        await supabase
            .from('kot_items')
            .update({
              'status': change['new_status'],
              'updated_at': DateTime.now().toIso8601String(),
              'updated_by_uid': change['updated_by_uid'],
              'updated_by_name': change['updated_by_name'],
            })
            .eq('id', change['item_id']);

        return true;
      } else if (change['type'] == 'batch_addition') {
        // Batch addition already handled by CreateKOT, just mark as synced
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error applying change: $e');
      return false;
    }
  }

  /// Mark a change as synced
  Future<void> _markChangeSynced(String changeId) async {
    try {
      final change = _offlineSyncQueue.get(changeId) as Map?;
      if (change != null) {
        final updated = Map<String, dynamic>.from(change);
        updated['sync_status'] = 'synced';
        updated['synced_at'] = DateTime.now().toIso8601String();

        await _offlineSyncQueue.put(changeId, updated);
      }
    } catch (e) {
      debugPrint('❌ Error marking change synced: $e');
    }
  }

  /// Increment sync attempt count
  Future<void> _incrementAttempt(String changeId) async {
    try {
      final change = _offlineSyncQueue.get(changeId);
      if (change != null) {
        final updated = Map<String, dynamic>.from(change);
        updated['attempt_count'] = (updated['attempt_count'] ?? 0) + 1;
        updated['sync_status'] = 'failed';
        updated['last_error'] = 'Sync attempt failed';

        await _offlineSyncQueue.put(changeId, updated);
      }
    } catch (e) {
      debugPrint('❌ Error incrementing attempt: $e');
    }
  }

  /// Monitor connection and auto-sync when online
  void _monitorConnectionForSync() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Simple connection check
        final response = await supabase
            .from('kitchen_stations')
            .select()
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        // If we got here, we're connected
        final pending = await getPendingChanges();
        if (pending.isNotEmpty) {
          debugPrint('🔄 Auto-syncing ${pending.length} pending changes...');
          await syncPendingChanges(
            businessId: '', // Get from context
            strategy: ConflictResolutionStrategy.merge,
          );
        }
      } catch (e) {
        // Offline
        debugPrint('📴 Still offline, will retry sync later');
      }
    });
  }

  /// Callbacks
  void onSyncProgress(OnSyncProgress callback) {
    _syncProgressCallbacks.add(callback);
  }

  void _notifySyncProgress(int completed, int total) {
    for (final callback in _syncProgressCallbacks) {
      callback(completed, total);
    }
  }

  /// Get error for a change
  Future<String?> getChangeError(String changeId) async {
    try {
      final change = _offlineSyncQueue.get(changeId);
      return change?['last_error'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Clear completed syncs
  Future<void> clearSyncedChanges() async {
    try {
      final toRemove = <String>[];

      for (final key in _offlineSyncQueue.keys) {
        final change = _offlineSyncQueue.get(key);
        if (change != null && change['sync_status'] == 'synced') {
          toRemove.add(key);
        }
      }

      for (final key in toRemove) {
        await _offlineSyncQueue.delete(key);
      }

      debugPrint('🧹 Cleared ${toRemove.length} synced changes');
    } catch (e) {
      debugPrint('❌ Error clearing synced changes: $e');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════════
// SYNC RESULT
// ═════════════════════════════════════════════════════════════════════════════════

class SyncResult {
  final List<String> succeededIds = [];
  final List<String> failedIds = [];
  final List<String> conflictIds = [];

  bool get isSuccessful => failedIds.isEmpty && conflictIds.isEmpty;

  int get totalAttempted =>
      succeededIds.length + failedIds.length + conflictIds.length;

  @override
  String toString() =>
      'SyncResult(succeed=${succeededIds.length}, failed=${failedIds.length}, conflicts=${conflictIds.length})';
}
