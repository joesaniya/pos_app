// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kot_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KitchenStation _$KitchenStationFromJson(Map<String, dynamic> json) =>
    KitchenStation(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      displayOrder: (json['displayOrder'] as num).toInt(),
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      keywords:
          (json['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      avgPrepTimeSeconds: (json['avgPrepTimeSeconds'] as num?)?.toInt() ?? 900,
      maxConcurrentOrders: (json['maxConcurrentOrders'] as num?)?.toInt() ?? 10,
      isActive: json['isActive'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? true,
      lastHeartbeat: json['lastHeartbeat'] == null
          ? null
          : DateTime.parse(json['lastHeartbeat'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$KitchenStationToJson(KitchenStation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'businessId': instance.businessId,
      'name': instance.name,
      'displayName': instance.displayName,
      'displayOrder': instance.displayOrder,
      'categories': instance.categories,
      'keywords': instance.keywords,
      'avgPrepTimeSeconds': instance.avgPrepTimeSeconds,
      'maxConcurrentOrders': instance.maxConcurrentOrders,
      'isActive': instance.isActive,
      'isOnline': instance.isOnline,
      'lastHeartbeat': instance.lastHeartbeat?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

KOTItem _$KOTItemFromJson(Map<String, dynamic> json) => KOTItem(
  id: json['id'] as String,
  kotId: json['kotId'] as String,
  batchId: json['batchId'] as String,
  businessId: json['businessId'] as String,
  itemId: json['itemId'] as String?,
  itemName: json['itemName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  itemPrice: (json['itemPrice'] as num?)?.toDouble(),
  category: json['category'] as String?,
  isVeg: json['isVeg'] as bool,
  assignedKitchenId: json['assignedKitchenId'] as String?,
  status:
      $enumDecodeNullable(_$KOTItemStatusEnumMap, json['status']) ??
      KOTItemStatus.pending,
  createdAt: DateTime.parse(json['createdAt'] as String),
  startedPreparingAt: json['startedPreparingAt'] == null
      ? null
      : DateTime.parse(json['startedPreparingAt'] as String),
  readyAt: json['readyAt'] == null
      ? null
      : DateTime.parse(json['readyAt'] as String),
  servedAt: json['servedAt'] == null
      ? null
      : DateTime.parse(json['servedAt'] as String),
  prepTimeSeconds: (json['prepTimeSeconds'] as num?)?.toInt(),
  slaSeconds: (json['slaSeconds'] as num?)?.toInt() ?? 900,
  isSlaViolated: json['isSlaViolated'] as bool? ?? false,
  delaySeconds: (json['delaySeconds'] as num?)?.toInt(),
  specialInstructions: json['specialInstructions'] as String?,
  isVegBadge: json['isVegBadge'] as bool? ?? false,
  hasAllergens: json['hasAllergens'] as bool? ?? false,
  allergens: json['allergens'] as String?,
  isSyncedToCloud: json['isSyncedToCloud'] as bool? ?? false,
  syncedAt: json['syncedAt'] == null
      ? null
      : DateTime.parse(json['syncedAt'] as String),
  updatedByUid: json['updatedByUid'] as String?,
  updatedByName: json['updatedByName'] as String?,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$KOTItemToJson(KOTItem instance) => <String, dynamic>{
  'id': instance.id,
  'kotId': instance.kotId,
  'batchId': instance.batchId,
  'businessId': instance.businessId,
  'itemId': instance.itemId,
  'itemName': instance.itemName,
  'quantity': instance.quantity,
  'itemPrice': instance.itemPrice,
  'category': instance.category,
  'isVeg': instance.isVeg,
  'assignedKitchenId': instance.assignedKitchenId,
  'status': _$KOTItemStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'startedPreparingAt': instance.startedPreparingAt?.toIso8601String(),
  'readyAt': instance.readyAt?.toIso8601String(),
  'servedAt': instance.servedAt?.toIso8601String(),
  'prepTimeSeconds': instance.prepTimeSeconds,
  'slaSeconds': instance.slaSeconds,
  'isSlaViolated': instance.isSlaViolated,
  'delaySeconds': instance.delaySeconds,
  'specialInstructions': instance.specialInstructions,
  'isVegBadge': instance.isVegBadge,
  'hasAllergens': instance.hasAllergens,
  'allergens': instance.allergens,
  'isSyncedToCloud': instance.isSyncedToCloud,
  'syncedAt': instance.syncedAt?.toIso8601String(),
  'updatedByUid': instance.updatedByUid,
  'updatedByName': instance.updatedByName,
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$KOTItemStatusEnumMap = {
  KOTItemStatus.pending: 'pending',
  KOTItemStatus.preparing: 'preparing',
  KOTItemStatus.ready: 'ready',
  KOTItemStatus.served: 'served',
  KOTItemStatus.cancelled: 'cancelled',
};

KOTBatch _$KOTBatchFromJson(Map<String, dynamic> json) => KOTBatch(
  id: json['id'] as String,
  kotId: json['kotId'] as String,
  businessId: json['businessId'] as String,
  batchNumber: (json['batchNumber'] as num).toInt(),
  status:
      $enumDecodeNullable(_$KOTBatchStatusEnumMap, json['status']) ??
      KOTBatchStatus.active,
  isNewItemBatch: json['isNewItemBatch'] as bool,
  batchAddedAt: DateTime.parse(json['batchAddedAt'] as String),
  itemCount: (json['itemCount'] as num).toInt(),
  preparedCount: (json['preparedCount'] as num).toInt(),
  completionPercentage: (json['completionPercentage'] as num).toInt(),
  expectedCompletionAt: json['expectedCompletionAt'] == null
      ? null
      : DateTime.parse(json['expectedCompletionAt'] as String),
  batchStartedAt: json['batchStartedAt'] == null
      ? null
      : DateTime.parse(json['batchStartedAt'] as String),
  batchCompletedAt: json['batchCompletedAt'] == null
      ? null
      : DateTime.parse(json['batchCompletedAt'] as String),
  notes: json['notes'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => KOTItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$KOTBatchToJson(KOTBatch instance) => <String, dynamic>{
  'id': instance.id,
  'kotId': instance.kotId,
  'businessId': instance.businessId,
  'batchNumber': instance.batchNumber,
  'status': _$KOTBatchStatusEnumMap[instance.status]!,
  'isNewItemBatch': instance.isNewItemBatch,
  'batchAddedAt': instance.batchAddedAt.toIso8601String(),
  'itemCount': instance.itemCount,
  'preparedCount': instance.preparedCount,
  'completionPercentage': instance.completionPercentage,
  'expectedCompletionAt': instance.expectedCompletionAt?.toIso8601String(),
  'batchStartedAt': instance.batchStartedAt?.toIso8601String(),
  'batchCompletedAt': instance.batchCompletedAt?.toIso8601String(),
  'notes': instance.notes,
  'items': instance.items,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$KOTBatchStatusEnumMap = {
  KOTBatchStatus.active: 'active',
  KOTBatchStatus.paused: 'paused',
  KOTBatchStatus.completed: 'completed',
  KOTBatchStatus.cancelled: 'cancelled',
};

KOTOrder _$KOTOrderFromJson(Map<String, dynamic> json) => KOTOrder(
  id: json['id'] as String,
  businessId: json['businessId'] as String,
  orderId: json['orderId'] as String?,
  kotNumber: json['kotNumber'] as String,
  status:
      $enumDecodeNullable(_$KOTOrderStatusEnumMap, json['status']) ??
      KOTOrderStatus.pending,
  priority:
      $enumDecodeNullable(_$KOTPriorityEnumMap, json['priority']) ??
      KOTPriority.normal,
  totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
  preparedItems: (json['preparedItems'] as num?)?.toInt() ?? 0,
  servedItems: (json['servedItems'] as num?)?.toInt() ?? 0,
  cancelledItems: (json['cancelledItems'] as num?)?.toInt() ?? 0,
  primaryKitchenId: json['primaryKitchenId'] as String?,
  assignedKitchens: (json['assignedKitchens'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  kotCreatedAt: DateTime.parse(json['kotCreatedAt'] as String),
  sentToKitchenAt: json['sentToKitchenAt'] == null
      ? null
      : DateTime.parse(json['sentToKitchenAt'] as String),
  startedPreparingAt: json['startedPreparingAt'] == null
      ? null
      : DateTime.parse(json['startedPreparingAt'] as String),
  firstReadyAt: json['firstReadyAt'] == null
      ? null
      : DateTime.parse(json['firstReadyAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  totalPrepTimeSeconds: (json['totalPrepTimeSeconds'] as num?)?.toInt(),
  slaSeconds: (json['slaSeconds'] as num?)?.toInt() ?? 900,
  slaTier:
      $enumDecodeNullable(_$SLATierEnumMap, json['slaTier']) ??
      SLATier.standard,
  isDelayed: json['isDelayed'] as bool? ?? false,
  itemSummary: json['itemSummary'] as Map<String, dynamic>?,
  batchCount: (json['batchCount'] as num?)?.toInt() ?? 1,
  currentBatchNumber: (json['currentBatchNumber'] as num?)?.toInt() ?? 1,
  notes: json['notes'] as String?,
  specialInstructions: json['specialInstructions'] as String?,
  tableNumber: (json['tableNumber'] as num?)?.toInt(),
  customerName: json['customerName'] as String?,
  isSyncedToCloud: json['isSyncedToCloud'] as bool? ?? false,
  isOfflineCreated: json['isOfflineCreated'] as bool? ?? false,
  syncedAt: json['syncedAt'] == null
      ? null
      : DateTime.parse(json['syncedAt'] as String),
  lastSyncAttempt: json['lastSyncAttempt'] == null
      ? null
      : DateTime.parse(json['lastSyncAttempt'] as String),
  syncAttemptCount: (json['syncAttemptCount'] as num?)?.toInt() ?? 0,
  createdByUid: json['createdByUid'] as String?,
  createdByName: json['createdByName'] as String?,
  batches:
      (json['batches'] as List<dynamic>?)
          ?.map((e) => KOTBatch.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$KOTOrderToJson(KOTOrder instance) => <String, dynamic>{
  'id': instance.id,
  'businessId': instance.businessId,
  'orderId': instance.orderId,
  'kotNumber': instance.kotNumber,
  'status': _$KOTOrderStatusEnumMap[instance.status]!,
  'priority': _$KOTPriorityEnumMap[instance.priority]!,
  'totalItems': instance.totalItems,
  'preparedItems': instance.preparedItems,
  'servedItems': instance.servedItems,
  'cancelledItems': instance.cancelledItems,
  'primaryKitchenId': instance.primaryKitchenId,
  'assignedKitchens': instance.assignedKitchens,
  'kotCreatedAt': instance.kotCreatedAt.toIso8601String(),
  'sentToKitchenAt': instance.sentToKitchenAt?.toIso8601String(),
  'startedPreparingAt': instance.startedPreparingAt?.toIso8601String(),
  'firstReadyAt': instance.firstReadyAt?.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'totalPrepTimeSeconds': instance.totalPrepTimeSeconds,
  'slaSeconds': instance.slaSeconds,
  'slaTier': _$SLATierEnumMap[instance.slaTier]!,
  'isDelayed': instance.isDelayed,
  'itemSummary': instance.itemSummary,
  'batchCount': instance.batchCount,
  'currentBatchNumber': instance.currentBatchNumber,
  'notes': instance.notes,
  'specialInstructions': instance.specialInstructions,
  'tableNumber': instance.tableNumber,
  'customerName': instance.customerName,
  'isSyncedToCloud': instance.isSyncedToCloud,
  'isOfflineCreated': instance.isOfflineCreated,
  'syncedAt': instance.syncedAt?.toIso8601String(),
  'lastSyncAttempt': instance.lastSyncAttempt?.toIso8601String(),
  'syncAttemptCount': instance.syncAttemptCount,
  'createdByUid': instance.createdByUid,
  'createdByName': instance.createdByName,
  'batches': instance.batches,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$KOTOrderStatusEnumMap = {
  KOTOrderStatus.pending: 'pending',
  KOTOrderStatus.inProgress: 'in_progress',
  KOTOrderStatus.ready: 'ready',
  KOTOrderStatus.served: 'served',
  KOTOrderStatus.cancelled: 'cancelled',
  KOTOrderStatus.paused: 'paused',
};

const _$KOTPriorityEnumMap = {
  KOTPriority.urgent: 'urgent',
  KOTPriority.high: 'high',
  KOTPriority.normal: 'normal',
  KOTPriority.low: 'low',
};

const _$SLATierEnumMap = {
  SLATier.standard: 'standard',
  SLATier.express: 'express',
  SLATier.urgent: 'urgent',
};

KOTDelayAlert _$KOTDelayAlertFromJson(Map<String, dynamic> json) =>
    KOTDelayAlert(
      id: json['id'] as String,
      kotId: json['kotId'] as String,
      itemId: json['itemId'] as String?,
      businessId: json['businessId'] as String,
      kitchenId: json['kitchenId'] as String?,
      alertType: $enumDecode(_$DelayAlertTypeEnumMap, json['alertType']),
      slaDeadline: DateTime.parse(json['slaDeadline'] as String),
      exceededBySeconds: (json['exceededBySeconds'] as num).toInt(),
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      acknowledgedAt: json['acknowledgedAt'] == null
          ? null
          : DateTime.parse(json['acknowledgedAt'] as String),
      acknowledgedByUid: json['acknowledgedByUid'] as String?,
      acknowledgedByName: json['acknowledgedByName'] as String?,
      isResolved: json['isResolved'] as bool? ?? false,
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
      resolutionNotes: json['resolutionNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$KOTDelayAlertToJson(KOTDelayAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kotId': instance.kotId,
      'itemId': instance.itemId,
      'businessId': instance.businessId,
      'kitchenId': instance.kitchenId,
      'alertType': _$DelayAlertTypeEnumMap[instance.alertType]!,
      'slaDeadline': instance.slaDeadline.toIso8601String(),
      'exceededBySeconds': instance.exceededBySeconds,
      'isAcknowledged': instance.isAcknowledged,
      'acknowledgedAt': instance.acknowledgedAt?.toIso8601String(),
      'acknowledgedByUid': instance.acknowledgedByUid,
      'acknowledgedByName': instance.acknowledgedByName,
      'isResolved': instance.isResolved,
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
      'resolutionNotes': instance.resolutionNotes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$DelayAlertTypeEnumMap = {
  DelayAlertType.warning: 'warning',
  DelayAlertType.critical: 'critical',
  DelayAlertType.urgent: 'urgent',
};

KitchenMetrics _$KitchenMetricsFromJson(Map<String, dynamic> json) =>
    KitchenMetrics(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      kitchenId: json['kitchenId'] as String,
      activeOrders: (json['activeOrders'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completedOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (json['cancelledOrders'] as num?)?.toInt() ?? 0,
      delayedOrders: (json['delayedOrders'] as num?)?.toInt() ?? 0,
      avgPrepTimeSeconds: (json['avgPrepTimeSeconds'] as num?)?.toInt(),
      maxPrepTimeSeconds: (json['maxPrepTimeSeconds'] as num?)?.toInt(),
      minPrepTimeSeconds: (json['minPrepTimeSeconds'] as num?)?.toInt(),
      slaCompliancePercentage:
          (json['slaCompliancePercentage'] as num?)?.toDouble() ?? 100,
      totalItemsDelayed: (json['totalItemsDelayed'] as num?)?.toInt() ?? 0,
      efficiencyScore: (json['efficiencyScore'] as num?)?.toDouble() ?? 100,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      periodStart: json['periodStart'] == null
          ? null
          : DateTime.parse(json['periodStart'] as String),
      periodEnd: json['periodEnd'] == null
          ? null
          : DateTime.parse(json['periodEnd'] as String),
      performanceStats: json['performanceStats'] as Map<String, dynamic>?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$KitchenMetricsToJson(KitchenMetrics instance) =>
    <String, dynamic>{
      'id': instance.id,
      'businessId': instance.businessId,
      'kitchenId': instance.kitchenId,
      'activeOrders': instance.activeOrders,
      'completedOrders': instance.completedOrders,
      'cancelledOrders': instance.cancelledOrders,
      'delayedOrders': instance.delayedOrders,
      'avgPrepTimeSeconds': instance.avgPrepTimeSeconds,
      'maxPrepTimeSeconds': instance.maxPrepTimeSeconds,
      'minPrepTimeSeconds': instance.minPrepTimeSeconds,
      'slaCompliancePercentage': instance.slaCompliancePercentage,
      'totalItemsDelayed': instance.totalItemsDelayed,
      'efficiencyScore': instance.efficiencyScore,
      'measuredAt': instance.measuredAt.toIso8601String(),
      'periodStart': instance.periodStart?.toIso8601String(),
      'periodEnd': instance.periodEnd?.toIso8601String(),
      'performanceStats': instance.performanceStats,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

KOTAuditLog _$KOTAuditLogFromJson(Map<String, dynamic> json) => KOTAuditLog(
  id: json['id'] as String,
  kotId: json['kotId'] as String?,
  businessId: json['businessId'] as String,
  action: json['action'] as String,
  details: json['details'] as String?,
  changes: json['changes'] as Map<String, dynamic>?,
  userId: json['userId'] as String?,
  userName: json['userName'] as String?,
  deviceId: json['deviceId'] as String?,
  actionAt: DateTime.parse(json['actionAt'] as String),
  isSyncedToCloud: json['isSyncedToCloud'] as bool? ?? false,
  syncedAt: json['syncedAt'] == null
      ? null
      : DateTime.parse(json['syncedAt'] as String),
);

Map<String, dynamic> _$KOTAuditLogToJson(KOTAuditLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kotId': instance.kotId,
      'businessId': instance.businessId,
      'action': instance.action,
      'details': instance.details,
      'changes': instance.changes,
      'userId': instance.userId,
      'userName': instance.userName,
      'deviceId': instance.deviceId,
      'actionAt': instance.actionAt.toIso8601String(),
      'isSyncedToCloud': instance.isSyncedToCloud,
      'syncedAt': instance.syncedAt?.toIso8601String(),
    };
