// 🔥 KITCHEN ORDER TOKEN (KOT) MODELS - Complete Definition
// lib/models/kot_models.dart
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'kot_models.g.dart';

// ═════════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═════════════════════════════════════════════════════════════════════════════════

enum KOTItemStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('preparing')
  preparing,
  @JsonValue('ready')
  ready,
  @JsonValue('served')
  served,
  @JsonValue('cancelled')
  cancelled,
}

enum KOTOrderStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('ready')
  ready,
  @JsonValue('served')
  served,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('paused')
  paused,
}

enum KOTPriority {
  @JsonValue('urgent')
  urgent,
  @JsonValue('high')
  high,
  @JsonValue('normal')
  normal,
  @JsonValue('low')
  low,
}

enum SLATier {
  @JsonValue('standard')
  standard, // 15 min
  @JsonValue('express')
  express, // 10 min
  @JsonValue('urgent')
  urgent, // 5 min
}

enum KOTBatchStatus {
  @JsonValue('active')
  active,
  @JsonValue('paused')
  paused,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

enum DelayAlertType {
  @JsonValue('warning')
  warning,
  @JsonValue('critical')
  critical,
  @JsonValue('urgent')
  urgent,
}

enum ConflictResolutionStrategy {
  @JsonValue('use_cloud')
  useCloud,
  @JsonValue('use_local')
  useLocal,
  @JsonValue('merge')
  merge,
}

// ═════════════════════════════════════════════════════════════════════════════════
// KITCHEN STATION MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KitchenStation {
  final String id;
  final String businessId;
  final String name; // 'grill', 'beverages', etc.
  final String displayName;
  final int displayOrder;

  final List<String> categories;
  final List<String> keywords;

  final int avgPrepTimeSeconds;
  final int maxConcurrentOrders;

  final bool isActive;
  final bool isOnline;
  final DateTime? lastHeartbeat;

  final DateTime createdAt;
  final DateTime updatedAt;

  KitchenStation({
    required this.id,
    required this.businessId,
    required this.name,
    required this.displayName,
    required this.displayOrder,
    this.categories = const [],
    this.keywords = const [],
    this.avgPrepTimeSeconds = 900,
    this.maxConcurrentOrders = 10,
    this.isActive = true,
    this.isOnline = true,
    this.lastHeartbeat,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KitchenStation.fromJson(Map<String, dynamic> json) =>
      _$KitchenStationFromJson(json);

  Map<String, dynamic> toJson() => _$KitchenStationToJson(this);

  KitchenStation copyWith({
    String? displayName,
    bool? isOnline,
    DateTime? lastHeartbeat,
  }) => KitchenStation(
    id: id,
    businessId: businessId,
    name: name,
    displayName: displayName ?? this.displayName,
    displayOrder: displayOrder,
    categories: categories,
    keywords: keywords,
    avgPrepTimeSeconds: avgPrepTimeSeconds,
    maxConcurrentOrders: maxConcurrentOrders,
    isActive: isActive,
    isOnline: isOnline ?? this.isOnline,
    lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

// ═════════════════════════════════════════════════════════════════════════════════
// KOT ITEM MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KOTItem {
  final String id;
  final String kotId;
  final String batchId;
  final String businessId;

  final String? itemId;
  final String itemName;
  final int quantity;
  final double? itemPrice;

  final String? category;
  final bool isVeg;

  final String? assignedKitchenId;

  final KOTItemStatus status;

  final DateTime createdAt;
  final DateTime? startedPreparingAt;
  final DateTime? readyAt;
  final DateTime? servedAt;

  final int? prepTimeSeconds;
  final int slaSeconds;
  final bool isSlaViolated;
  final int? delaySeconds;

  final String? specialInstructions;
  final bool isVegBadge;
  final bool hasAllergens;
  final String? allergens;

  final bool isSyncedToCloud;
  final DateTime? syncedAt;

  final String? updatedByUid;
  final String? updatedByName;
  final DateTime updatedAt;

  KOTItem({
    required this.id,
    required this.kotId,
    required this.batchId,
    required this.businessId,
    this.itemId,
    required this.itemName,
    required this.quantity,
    this.itemPrice,
    this.category,
    required this.isVeg,
    this.assignedKitchenId,
    this.status = KOTItemStatus.pending,
    required this.createdAt,
    this.startedPreparingAt,
    this.readyAt,
    this.servedAt,
    this.prepTimeSeconds,
    this.slaSeconds = 900,
    this.isSlaViolated = false,
    this.delaySeconds,
    this.specialInstructions,
    this.isVegBadge = false,
    this.hasAllergens = false,
    this.allergens,
    this.isSyncedToCloud = false,
    this.syncedAt,
    this.updatedByUid,
    this.updatedByName,
    required this.updatedAt,
  });

  factory KOTItem.fromJson(Map<String, dynamic> json) =>
      _$KOTItemFromJson(json);

  Map<String, dynamic> toJson() => _$KOTItemToJson(this);

  int get elapsedSeconds {
    final start = startedPreparingAt ?? createdAt;
    return DateTime.now().difference(start).inSeconds;
  }

  bool get isExpired => isSlaViolated || (delaySeconds ?? 0) > 0;

  KOTItem copyWith({
    KOTItemStatus? status,
    DateTime? startedPreparingAt,
    DateTime? readyAt,
    DateTime? servedAt,
    bool? isSlaViolated,
    int? delaySeconds,
    String? assignedKitchenId,
    bool? isSyncedToCloud,
    DateTime? syncedAt,
    String? updatedByUid,
    String? updatedByName,
    DateTime? updatedAt,
  }) => KOTItem(
    id: id,
    kotId: kotId,
    batchId: batchId,
    businessId: businessId,
    itemId: itemId,
    itemName: itemName,
    quantity: quantity,
    itemPrice: itemPrice,
    category: category,
    isVeg: isVeg,
    assignedKitchenId: assignedKitchenId ?? this.assignedKitchenId,
    status: status ?? this.status,
    createdAt: createdAt,
    startedPreparingAt: startedPreparingAt ?? this.startedPreparingAt,
    readyAt: readyAt ?? this.readyAt,
    servedAt: servedAt ?? this.servedAt,
    prepTimeSeconds: prepTimeSeconds,
    slaSeconds: slaSeconds,
    isSlaViolated: isSlaViolated ?? this.isSlaViolated,
    delaySeconds: delaySeconds ?? this.delaySeconds,
    specialInstructions: specialInstructions,
    isVegBadge: isVegBadge,
    hasAllergens: hasAllergens,
    allergens: allergens,
    isSyncedToCloud: isSyncedToCloud ?? this.isSyncedToCloud,
    syncedAt: syncedAt ?? this.syncedAt,
    updatedByUid: updatedByUid ?? this.updatedByUid,
    updatedByName: updatedByName ?? this.updatedByName,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

// ═════════════════════════════════════════════════════════════════════════════════
// KOT BATCH MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KOTBatch {
  final String id;
  final String kotId;
  final String businessId;

  final int batchNumber; // 1 = original, 2+ = added items
  final KOTBatchStatus status;

  final bool isNewItemBatch;
  final DateTime batchAddedAt;

  final int itemCount;
  final int preparedCount;

  final int completionPercentage;
  final DateTime? expectedCompletionAt;

  final DateTime? batchStartedAt;
  final DateTime? batchCompletedAt;

  final String? notes;

  final List<KOTItem> items;

  final DateTime createdAt;
  final DateTime updatedAt;

  KOTBatch({
    required this.id,
    required this.kotId,
    required this.businessId,
    required this.batchNumber,
    this.status = KOTBatchStatus.active,
    required this.isNewItemBatch,
    required this.batchAddedAt,
    required this.itemCount,
    required this.preparedCount,
    required this.completionPercentage,
    this.expectedCompletionAt,
    this.batchStartedAt,
    this.batchCompletedAt,
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory KOTBatch.fromJson(Map<String, dynamic> json) =>
      _$KOTBatchFromJson(json);

  Map<String, dynamic> toJson() => _$KOTBatchToJson(this);

  int get pendingItems =>
      items.where((i) => i.status == KOTItemStatus.pending).length;
  int get preparingItems =>
      items.where((i) => i.status == KOTItemStatus.preparing).length;
  int get readyItems =>
      items.where((i) => i.status == KOTItemStatus.ready).length;
  int get servedItems =>
      items.where((i) => i.status == KOTItemStatus.served).length;

  KOTBatch copyWith({
    KOTBatchStatus? status,
    int? completionPercentage,
    List<KOTItem>? items,
    DateTime? batchCompletedAt,
  }) => KOTBatch(
    id: id,
    kotId: kotId,
    businessId: businessId,
    batchNumber: batchNumber,
    status: status ?? this.status,
    isNewItemBatch: isNewItemBatch,
    batchAddedAt: batchAddedAt,
    itemCount: itemCount,
    preparedCount: preparedCount,
    completionPercentage: completionPercentage ?? this.completionPercentage,
    expectedCompletionAt: expectedCompletionAt,
    batchStartedAt: batchStartedAt,
    batchCompletedAt: batchCompletedAt ?? this.batchCompletedAt,
    notes: notes,
    items: items ?? this.items,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

// ═════════════════════════════════════════════════════════════════════════════════
// KOT ORDER MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KOTOrder {
  final String id;
  final String businessId;
  final String? orderId;

  final String kotNumber;
  final KOTOrderStatus status;
  final KOTPriority priority;

  final int totalItems;
  final int preparedItems;
  final int servedItems;
  final int cancelledItems;

  final String? primaryKitchenId;
  final List<String>? assignedKitchens;

  final DateTime kotCreatedAt;
  final DateTime? sentToKitchenAt;
  final DateTime? startedPreparingAt;
  final DateTime? firstReadyAt;
  final DateTime? completedAt;

  final int? totalPrepTimeSeconds;
  final int slaSeconds;
  final SLATier slaTier;
  final bool isDelayed;

  final Map<String, dynamic>? itemSummary;
  final int batchCount;
  final int currentBatchNumber;

  final String? notes;
  final String? specialInstructions;
  final int? tableNumber;
  final String? customerName;

  final bool isSyncedToCloud;
  final bool isOfflineCreated;
  final DateTime? syncedAt;
  final DateTime? lastSyncAttempt;
  final int syncAttemptCount;

  final String? createdByUid;
  final String? createdByName;

  final List<KOTBatch> batches;

  final DateTime createdAt;
  final DateTime updatedAt;

  KOTOrder({
    required this.id,
    required this.businessId,
    this.orderId,
    required this.kotNumber,
    this.status = KOTOrderStatus.pending,
    this.priority = KOTPriority.normal,
    this.totalItems = 0,
    this.preparedItems = 0,
    this.servedItems = 0,
    this.cancelledItems = 0,
    this.primaryKitchenId,
    this.assignedKitchens,
    required this.kotCreatedAt,
    this.sentToKitchenAt,
    this.startedPreparingAt,
    this.firstReadyAt,
    this.completedAt,
    this.totalPrepTimeSeconds,
    this.slaSeconds = 900,
    this.slaTier = SLATier.standard,
    this.isDelayed = false,
    this.itemSummary,
    this.batchCount = 1,
    this.currentBatchNumber = 1,
    this.notes,
    this.specialInstructions,
    this.tableNumber,
    this.customerName,
    this.isSyncedToCloud = false,
    this.isOfflineCreated = false,
    this.syncedAt,
    this.lastSyncAttempt,
    this.syncAttemptCount = 0,
    this.createdByUid,
    this.createdByName,
    this.batches = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory KOTOrder.fromJson(Map<String, dynamic> json) =>
      _$KOTOrderFromJson(json);

  Map<String, dynamic> toJson() => _$KOTOrderToJson(this);

  int get elapsedSeconds => DateTime.now().difference(kotCreatedAt).inSeconds;
  int get remainingSlaSeconds => slaSeconds - elapsedSeconds;
  double get completionPercentage =>
      totalItems > 0 ? (100.0 * (servedItems + preparedItems) / totalItems) : 0;

  List<KOTItem> get allItems => batches.expand((b) => b.items).toList();

  KOTOrder copyWith({
    KOTOrderStatus? status,
    int? preparedItems,
    int? servedItems,
    bool? isDelayed,
    List<KOTBatch>? batches,
    int? currentBatchNumber,
    bool? isSyncedToCloud,
    DateTime? syncedAt,
    DateTime? completedAt,
  }) => KOTOrder(
    id: id,
    businessId: businessId,
    orderId: orderId,
    kotNumber: kotNumber,
    status: status ?? this.status,
    priority: priority,
    totalItems: totalItems,
    preparedItems: preparedItems ?? this.preparedItems,
    servedItems: servedItems ?? this.servedItems,
    cancelledItems: cancelledItems,
    primaryKitchenId: primaryKitchenId,
    assignedKitchens: assignedKitchens,
    kotCreatedAt: kotCreatedAt,
    sentToKitchenAt: sentToKitchenAt,
    startedPreparingAt: startedPreparingAt,
    firstReadyAt: firstReadyAt,
    completedAt: completedAt ?? this.completedAt,
    totalPrepTimeSeconds: totalPrepTimeSeconds,
    slaSeconds: slaSeconds,
    slaTier: slaTier,
    isDelayed: isDelayed ?? this.isDelayed,
    itemSummary: itemSummary,
    batchCount: batchCount,
    currentBatchNumber: currentBatchNumber ?? this.currentBatchNumber,
    notes: notes,
    specialInstructions: specialInstructions,
    tableNumber: tableNumber,
    customerName: customerName,
    isSyncedToCloud: isSyncedToCloud ?? this.isSyncedToCloud,
    isOfflineCreated: isOfflineCreated,
    syncedAt: syncedAt ?? this.syncedAt,
    lastSyncAttempt: lastSyncAttempt,
    syncAttemptCount: syncAttemptCount,
    createdByUid: createdByUid,
    createdByName: createdByName,
    batches: batches ?? this.batches,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

// ═════════════════════════════════════════════════════════════════════════════════
// KOT DELAY ALERT MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KOTDelayAlert {
  final String id;
  final String kotId;
  final String? itemId;
  final String businessId;
  final String? kitchenId;

  final DelayAlertType alertType;

  final DateTime slaDeadline;
  final int exceededBySeconds;

  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByUid;
  final String? acknowledgedByName;

  final bool isResolved;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  KOTDelayAlert({
    required this.id,
    required this.kotId,
    this.itemId,
    required this.businessId,
    this.kitchenId,
    required this.alertType,
    required this.slaDeadline,
    required this.exceededBySeconds,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    this.acknowledgedByUid,
    this.acknowledgedByName,
    this.isResolved = false,
    this.resolvedAt,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KOTDelayAlert.fromJson(Map<String, dynamic> json) =>
      _$KOTDelayAlertFromJson(json);

  Map<String, dynamic> toJson() => _$KOTDelayAlertToJson(this);

  KOTDelayAlert copyWith({
    bool? isAcknowledged,
    DateTime? acknowledgedAt,
    String? acknowledgedByUid,
    String? acknowledgedByName,
    bool? isResolved,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) => KOTDelayAlert(
    id: id,
    kotId: kotId,
    itemId: itemId,
    businessId: businessId,
    kitchenId: kitchenId,
    alertType: alertType,
    slaDeadline: slaDeadline,
    exceededBySeconds: exceededBySeconds,
    isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    acknowledgedByUid: acknowledgedByUid ?? this.acknowledgedByUid,
    acknowledgedByName: acknowledgedByName ?? this.acknowledgedByName,
    isResolved: isResolved ?? this.isResolved,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

// ═════════════════════════════════════════════════════════════════════════════════
// KITCHEN METRICS MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KitchenMetrics {
  final String id;
  final String businessId;
  final String kitchenId;

  final int activeOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int delayedOrders;

  final int? avgPrepTimeSeconds;
  final int? maxPrepTimeSeconds;
  final int? minPrepTimeSeconds;

  final double slaCompliancePercentage;
  final int totalItemsDelayed;

  final double efficiencyScore; // 0-100

  final DateTime measuredAt;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  final Map<String, dynamic>? performanceStats;

  final DateTime updatedAt;

  KitchenMetrics({
    required this.id,
    required this.businessId,
    required this.kitchenId,
    this.activeOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.delayedOrders = 0,
    this.avgPrepTimeSeconds,
    this.maxPrepTimeSeconds,
    this.minPrepTimeSeconds,
    this.slaCompliancePercentage = 100,
    this.totalItemsDelayed = 0,
    this.efficiencyScore = 100,
    required this.measuredAt,
    this.periodStart,
    this.periodEnd,
    this.performanceStats,
    required this.updatedAt,
  });

  factory KitchenMetrics.fromJson(Map<String, dynamic> json) =>
      _$KitchenMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$KitchenMetricsToJson(this);
}

// ═════════════════════════════════════════════════════════════════════════════════
// AUDIT LOG MODEL
// ═════════════════════════════════════════════════════════════════════════════════

@JsonSerializable()
class KOTAuditLog {
  final String id;
  final String? kotId;
  final String businessId;

  final String action;
  final String? details;
  final Map<String, dynamic>? changes;

  final String? userId;
  final String? userName;
  final String? deviceId;

  final DateTime actionAt;

  final bool isSyncedToCloud;
  final DateTime? syncedAt;

  KOTAuditLog({
    required this.id,
    this.kotId,
    required this.businessId,
    required this.action,
    this.details,
    this.changes,
    this.userId,
    this.userName,
    this.deviceId,
    required this.actionAt,
    this.isSyncedToCloud = false,
    this.syncedAt,
  });

  factory KOTAuditLog.fromJson(Map<String, dynamic> json) =>
      _$KOTAuditLogFromJson(json);

  Map<String, dynamic> toJson() => _$KOTAuditLogToJson(this);
}
