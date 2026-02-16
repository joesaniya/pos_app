enum StockStatus { inStock, lowStock, critical, outOfStock }
enum StockUnit { kg, g, litre, ml, pieces, dozen, packet, bottle }
enum TransactionType { stockIn, stockOut, adjustment, waste }

extension StockStatusExt on StockStatus {
  String get label {
    switch (this) {
      case StockStatus.inStock:    return 'In Stock';
      case StockStatus.lowStock:   return 'Low Stock';
      case StockStatus.critical:   return 'Critical';
      case StockStatus.outOfStock: return 'Out of Stock';
    }
  }
  String get emoji {
    switch (this) {
      case StockStatus.inStock:    return '✅';
      case StockStatus.lowStock:   return '⚠️';
      case StockStatus.critical:   return '🔴';
      case StockStatus.outOfStock: return '❌';
    }
  }
}

extension StockUnitExt on StockUnit {
  String get label {
    switch (this) {
      case StockUnit.kg:     return 'kg';
      case StockUnit.g:      return 'g';
      case StockUnit.litre:  return 'L';
      case StockUnit.ml:     return 'ml';
      case StockUnit.pieces: return 'pcs';
      case StockUnit.dozen:  return 'doz';
      case StockUnit.packet: return 'pkt';
      case StockUnit.bottle: return 'btl';
    }
  }
}

extension TransactionTypeExt on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.stockIn:     return 'Stock In';
      case TransactionType.stockOut:    return 'Stock Out';
      case TransactionType.adjustment:  return 'Adjustment';
      case TransactionType.waste:       return 'Waste';
    }
  }
  String get emoji {
    switch (this) {
      case TransactionType.stockIn:     return '📥';
      case TransactionType.stockOut:    return '📤';
      case TransactionType.adjustment:  return '🔧';
      case TransactionType.waste:       return '🗑️';
    }
  }
  bool get isPositive => this == TransactionType.stockIn || this == TransactionType.adjustment;
}

class StockTransaction {
  final String id;
  final TransactionType type;
  final double quantity;
  final StockUnit unit;
  final DateTime date;
  final String note;
  final String updatedBy;

  const StockTransaction({
    required this.id,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.note,
    required this.updatedBy,
  });
}

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
  final String supplier;
  final DateTime lastUpdated;
  final List<StockTransaction> transactions;

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
    required this.lastUpdated,
    this.transactions = const [],
  });

  StockStatus get status {
    if (currentStock <= 0) return StockStatus.outOfStock;
    final pct = currentStock / maxCapacity;
    if (pct <= 0.10) return StockStatus.critical;
    if (currentStock <= minThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  double get stockPercent => (currentStock / maxCapacity).clamp(0.0, 1.0);

  String get stockDisplay =>
      '${currentStock % 1 == 0 ? currentStock.toInt() : currentStock.toStringAsFixed(1)} ${unit.label}';

  double get totalValue => currentStock * costPerUnit;

  InventoryItem copyWith({
    double? currentStock,
    String? name,
    String? category,
    double? minThreshold,
    double? maxCapacity,
    double? costPerUnit,
    String? supplier,
    DateTime? lastUpdated,
    List<StockTransaction>? transactions,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      emoji: emoji,
      currentStock: currentStock ?? this.currentStock,
      minThreshold: minThreshold ?? this.minThreshold,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      unit: unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplier: supplier ?? this.supplier,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      transactions: transactions ?? this.transactions,
    );
  }

  String get lastUpdatedLabel {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}