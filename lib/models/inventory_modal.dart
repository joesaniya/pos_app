// lib/models/inventory_modal.dart

enum StockStatus { inStock, lowStock, critical, outOfStock }

enum StockUnit { kg, g, litre, ml, pieces, dozen, packet, bottle }

enum TransactionType { stockIn, stockOut, adjustment, waste }

enum NotificationSeverity { info, warning, critical }

enum StockNotificationType { lowStock, critical, outOfStock, restock }

// ─────────────────────────────────────────────────────────────────────────────
extension StockNotificationTypeExt on StockNotificationType {
  String get emoji {
    switch (this) {
      case StockNotificationType.lowStock:
        return '⚠️';
      case StockNotificationType.critical:
        return '🔴';
      case StockNotificationType.outOfStock:
        return '❌';
      case StockNotificationType.restock:
        return '✅';
    }
  }

  String get label {
    switch (this) {
      case StockNotificationType.lowStock:
        return 'Low Stock';
      case StockNotificationType.critical:
        return 'Critical';
      case StockNotificationType.outOfStock:
        return 'Out of Stock';
      case StockNotificationType.restock:
        return 'Restocked';
    }
  }

  String get dbValue {
    switch (this) {
      case StockNotificationType.lowStock:
        return 'low_stock';
      case StockNotificationType.critical:
        return 'critical';
      case StockNotificationType.outOfStock:
        return 'out_of_stock';
      case StockNotificationType.restock:
        return 'restock';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
extension StockStatusExt on StockStatus {
  String get label {
    switch (this) {
      case StockStatus.inStock:
        return 'In Stock';
      case StockStatus.lowStock:
        return 'Low Stock';
      case StockStatus.critical:
        return 'Critical';
      case StockStatus.outOfStock:
        return 'Out of Stock';
    }
  }

  String get dbValue {
    switch (this) {
      case StockStatus.inStock:
        return 'in_stock';
      case StockStatus.lowStock:
        return 'low_stock';
      case StockStatus.critical:
        return 'critical';
      case StockStatus.outOfStock:
        return 'out_of_stock';
    }
  }

  static StockStatus fromString(String s) {
    switch (s) {
      case 'low_stock':
        return StockStatus.lowStock;
      case 'critical':
        return StockStatus.critical;
      case 'out_of_stock':
        return StockStatus.outOfStock;
      default:
        return StockStatus.inStock;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
extension StockUnitExt on StockUnit {
  String get label {
    switch (this) {
      case StockUnit.kg:
        return 'kg';
      case StockUnit.g:
        return 'g';
      case StockUnit.litre:
        return 'L';
      case StockUnit.ml:
        return 'ml';
      case StockUnit.pieces:
        return 'pcs';
      case StockUnit.dozen:
        return 'doz';
      case StockUnit.packet:
        return 'pkt';
      case StockUnit.bottle:
        return 'btl';
    }
  }

  String get dbValue {
    switch (this) {
      case StockUnit.kg:
        return 'kg';
      case StockUnit.g:
        return 'g';
      case StockUnit.litre:
        return 'litre';
      case StockUnit.ml:
        return 'ml';
      case StockUnit.pieces:
        return 'pieces';
      case StockUnit.dozen:
        return 'dozen';
      case StockUnit.packet:
        return 'packet';
      case StockUnit.bottle:
        return 'bottle';
    }
  }

  static StockUnit fromString(String s) {
    switch (s.toLowerCase()) {
      case 'g':
        return StockUnit.g;
      case 'l':
      case 'litre':
      case 'liter':
        return StockUnit.litre;
      case 'ml':
        return StockUnit.ml;
      case 'pcs':
      case 'pieces':
      case 'piece':
        return StockUnit.pieces;
      case 'doz':
      case 'dozen':
        return StockUnit.dozen;
      case 'pkt':
      case 'packet':
        return StockUnit.packet;
      case 'btl':
      case 'bottle':
        return StockUnit.bottle;
      default:
        return StockUnit.kg;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
extension TransactionTypeExt on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.stockIn:
        return 'Stock In';
      case TransactionType.stockOut:
        return 'Stock Out';
      case TransactionType.adjustment:
        return 'Adjustment';
      case TransactionType.waste:
        return 'Waste';
    }
  }

  String get emoji {
    switch (this) {
      case TransactionType.stockIn:
        return '📥';
      case TransactionType.stockOut:
        return '📤';
      case TransactionType.adjustment:
        return '🔧';
      case TransactionType.waste:
        return '🗑️';
    }
  }

  String get dbValue {
    switch (this) {
      case TransactionType.stockIn:
        return 'stock_in';
      case TransactionType.stockOut:
        return 'stock_out';
      case TransactionType.adjustment:
        return 'adjustment';
      case TransactionType.waste:
        return 'waste';
    }
  }

  bool get isPositive {
    switch (this) {
      case TransactionType.stockIn:
      case TransactionType.adjustment:
        return true;
      default:
        return false;
    }
  }

  static TransactionType fromString(String s) {
    switch (s) {
      case 'stock_out':
        return TransactionType.stockOut;
      case 'adjustment':
        return TransactionType.adjustment;
      case 'waste':
        return TransactionType.waste;
      default:
        return TransactionType.stockIn;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  StockTransaction
// ─────────────────────────────────────────────────────────────────────────────
class StockTransaction {
  final String id;
  final TransactionType type;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final StockUnit unit;
  final DateTime date;
  final String note;
  final String updatedBy;
  final String updatedByRole;

  const StockTransaction({
    required this.id,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.unit,
    required this.date,
    required this.note,
    required this.updatedBy,
    this.updatedByRole = '',
  });

  factory StockTransaction.fromJson(Map<String, dynamic> j) => StockTransaction(
        id: j['id'] as String,
        type: TransactionTypeExt.fromString(
            j['transaction_type'] ?? 'stock_in'),
        quantity: (j['quantity'] as num).toDouble(),
        stockBefore: (j['stock_before'] as num).toDouble(),
        stockAfter: (j['stock_after'] as num).toDouble(),
        unit: StockUnitExt.fromString(j['unit'] ?? 'kg'),
        date: DateTime.parse(j['created_at'] as String),
        note: j['note'] as String? ?? '—',
        updatedBy: j['updated_by_name'] as String? ?? 'Unknown',
        updatedByRole: j['updated_by_role'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  UUID validation helper (module-private)
//
//  Returns true only for a well-formed UUID string.
//  Sentinel strings ("other", "unknown", etc.) and blank values → false.
// ─────────────────────────────────────────────────────────────────────────────
bool isValidSupplierId(String? id) {
  if (id == null || id.trim().isEmpty) return false;

  const _sentinels = {
    'other',
    'unknown',
    'unknown supplier',
    'none',
    'null',
    'undefined',
    'na',
    'n/a',
  };
  if (_sentinels.contains(id.trim().toLowerCase())) return false;

  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(id.trim());
}

// ─────────────────────────────────────────────────────────────────────────────
//  InventoryItem
// ─────────────────────────────────────────────────────────────────────────────
class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String emoji;
  final double currentStock;
  final double minThreshold;
  final double maxCapacity;
  final StockUnit unit;
  final double costPerUnit;
  final String supplier; // display name
  final String? supplierId; // FK to suppliers table — always a UUID or null
  final DateTime lastUpdated;
  final List<StockTransaction> transactions;
  final String? notes;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.currentStock,
    required this.minThreshold,
    required this.maxCapacity,
    required this.unit,
    required this.costPerUnit,
    required this.supplier,
    this.supplierId,
    required this.lastUpdated,
    this.transactions = const [],
    this.notes,
  });

  // ── Derived ────────────────────────────────────────────────────────────────

  StockStatus get status {
    if (currentStock <= 0) return StockStatus.outOfStock;
    if (maxCapacity > 0 && currentStock / maxCapacity <= 0.10) {
      return StockStatus.critical;
    }
    if (currentStock <= minThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  double get stockPercent =>
      maxCapacity > 0 ? (currentStock / maxCapacity).clamp(0.0, 1.0) : 0;

  double get totalValue => currentStock * costPerUnit;

  String get stockDisplay => '${currentStock.toInt()} ${unit.label}';

  String get lastUpdatedLabel {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// True only when supplierId is a real UUID.
  bool get hasLinkedSupplier => isValidSupplierId(supplierId);

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory InventoryItem.fromJson(Map<String, dynamic> j) {
    final txList = (j['stock_transactions'] as List<dynamic>? ?? [])
        .map((t) => StockTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
    txList.sort((a, b) => b.date.compareTo(a.date));

    return InventoryItem(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String? ?? 'Other',
      emoji: j['emoji'] as String? ?? '📦',
      currentStock: (j['current_stock'] as num? ?? 0).toDouble(),
      minThreshold: (j['min_threshold'] as num? ?? 0).toDouble(),
      maxCapacity: (j['max_capacity'] as num? ?? 100).toDouble(),
      unit: StockUnitExt.fromString(j['unit'] ?? 'kg'),
      costPerUnit: (j['cost_per_unit'] as num? ?? 0).toDouble(),
      supplier: j['supplier_name'] as String? ?? 'Unknown Supplier',
      supplierId: j['supplier_id'] as String?,
      lastUpdated: j['last_updated'] != null
          ? DateTime.parse(j['last_updated'] as String)
          : DateTime.now(),
      transactions: txList,
      notes: j['notes'] as String?,
    );
  }

  /// Serialises for Supabase INSERT / UPDATE.
  ///
  /// [supplier_id] is always sent as NULL when it is not a valid UUID — this
  /// prevents "invalid input syntax for type uuid" Postgres errors that happen
  /// when sentinel strings like "other" are stored in a UUID column.
  Map<String, dynamic> toJson(String businessId) => {
        'business_id': businessId,
        'name': name,
        'category': category,
        'emoji': emoji,
        'current_stock': currentStock,
        'min_threshold': minThreshold,
        'max_capacity': maxCapacity,
        'unit': unit.dbValue,
        'cost_per_unit': costPerUnit,
        'supplier_name': supplier,
        'supplier_id': isValidSupplierId(supplierId) ? supplierId : null,
        'last_updated': lastUpdated.toIso8601String(),
        'notes': notes,
        'is_active': true,
      };

  InventoryItem copyWith({
    double? currentStock,
    DateTime? lastUpdated,
    List<StockTransaction>? transactions,
    String? notes,
    String? supplier,
    String? supplierId,
  }) =>
      InventoryItem(
        id: id,
        name: name,
        category: category,
        emoji: emoji,
        currentStock: currentStock ?? this.currentStock,
        minThreshold: minThreshold,
        maxCapacity: maxCapacity,
        unit: unit,
        costPerUnit: costPerUnit,
        supplier: supplier ?? this.supplier,
        supplierId: supplierId ?? this.supplierId,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        transactions: transactions ?? this.transactions,
        notes: notes ?? this.notes,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  StockNotificationRecord
// ─────────────────────────────────────────────────────────────────────────────
class StockNotificationRecord {
  final String id;
  final String businessId;
  final String? itemId;
  final String itemName;
  final StockNotificationType type;
  final String title;
  final String body;
  final double currentStock;
  final double minThreshold;
  final String unit;
  final NotificationSeverity severity;
  final bool isRead;
  final DateTime sentAt;

  const StockNotificationRecord({
    required this.id,
    required this.businessId,
    this.itemId,
    required this.itemName,
    required this.type,
    required this.title,
    required this.body,
    required this.currentStock,
    required this.minThreshold,
    required this.unit,
    required this.severity,
    required this.isRead,
    required this.sentAt,
  });

  factory StockNotificationRecord.fromJson(Map<String, dynamic> j) =>
      StockNotificationRecord(
        id: j['id'] as String,
        businessId: j['business_id'] as String,
        itemId: j['item_id'] as String?,
        itemName: j['item_name'] as String? ?? '',
        type: _typeFromString(j['notification_type'] ?? 'low_stock'),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        currentStock: (j['current_stock'] as num? ?? 0).toDouble(),
        minThreshold: (j['min_threshold'] as num? ?? 0).toDouble(),
        unit: j['unit'] as String? ?? 'kg',
        severity: _severityFromString(j['severity'] ?? 'info'),
        isRead: j['is_read'] as bool? ?? false,
        sentAt: DateTime.parse(j['sent_at'] as String),
      );

  static StockNotificationType _typeFromString(String s) {
    switch (s) {
      case 'critical':
        return StockNotificationType.critical;
      case 'out_of_stock':
        return StockNotificationType.outOfStock;
      case 'restock':
        return StockNotificationType.restock;
      default:
        return StockNotificationType.lowStock;
    }
  }

  static NotificationSeverity _severityFromString(String s) {
    switch (s) {
      case 'critical':
        return NotificationSeverity.critical;
      case 'warning':
        return NotificationSeverity.warning;
      default:
        return NotificationSeverity.info;
    }
  }
}

