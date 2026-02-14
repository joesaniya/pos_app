enum TableStatus { available, occupied, reserved }

class TableModel {
  final int tableNumber;
  final int capacity;
  final TableStatus status;
  final String? orderId;
  final String? customerName;
  final double? orderTotal;
  final DateTime? occupiedTime;
  final DateTime? reservationTime;
  final String? section;

  TableModel({
    required this.tableNumber,
    required this.capacity,
    required this.status,
    this.orderId,
    this.customerName,
    this.orderTotal,
    this.occupiedTime,
    this.reservationTime,
    this.section,
  });

  TableModel copyWith({
    TableStatus? status,
    String? orderId,
    String? customerName,
    double? orderTotal,
    DateTime? occupiedTime,
    DateTime? reservationTime,
  }) {
    return TableModel(
      tableNumber: tableNumber,
      capacity: capacity,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      orderTotal: orderTotal ?? this.orderTotal,
      occupiedTime: occupiedTime ?? this.occupiedTime,
      reservationTime: reservationTime ?? this.reservationTime,
      section: section ?? this.section,
    );
  }

  String get statusLabel {
    switch (status) {
      case TableStatus.available: return 'Available';
      case TableStatus.occupied: return 'Occupied';
      case TableStatus.reserved: return 'Reserved';
    }
  }

  String get formattedDuration {
    if (occupiedTime == null) return '';
    final diff = DateTime.now().difference(occupiedTime!);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    return '${diff.inMinutes}m';
  }

  String get formattedReservation {
    if (reservationTime == null) return '';
    final diff = reservationTime!.difference(DateTime.now());
    if (diff.inHours > 0) return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    return 'in ${diff.inMinutes}m';
  }
}

// MenuCategory has been moved to models/menu_item.dart