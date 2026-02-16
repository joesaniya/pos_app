// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum TableStatus { available, occupied, reserved, cleaning }

extension TableStatusExt on TableStatus {
  String get label {
    switch (this) {
      case TableStatus.available: return 'Available';
      case TableStatus.occupied:  return 'Occupied';
      case TableStatus.reserved:  return 'Reserved';
      case TableStatus.cleaning:  return 'Cleaning';
    }
  }
  String get emoji {
    switch (this) {
      case TableStatus.available: return '✅';
      case TableStatus.occupied:  return '🍽️';
      case TableStatus.reserved:  return '📅';
      case TableStatus.cleaning:  return '🧹';
    }
  }
}

enum TableSection { ac, nonAc, rooftop, garden, privateRoom }

extension TableSectionExt on TableSection {
  String get label {
    switch (this) {
      case TableSection.ac:          return 'AC Hall';
      case TableSection.nonAc:       return 'Non-AC';
      case TableSection.rooftop:     return 'Rooftop';
      case TableSection.garden:      return 'Garden';
      case TableSection.privateRoom: return 'Private';
    }
  }
  String get emoji {
    switch (this) {
      case TableSection.ac:          return '❄️';
      case TableSection.nonAc:       return '🌀';
      case TableSection.rooftop:     return '🌇';
      case TableSection.garden:      return '🌿';
      case TableSection.privateRoom: return '🔒';
    }
  }
  String get floor {
    switch (this) {
      case TableSection.ac:          return 'G Floor';
      case TableSection.nonAc:       return 'G Floor';
      case TableSection.rooftop:     return '3rd Floor';
      case TableSection.garden:      return 'G Floor';
      case TableSection.privateRoom: return '2nd Floor';
    }
  }
}

enum TableShape { square, round, rectangle }

// ─────────────────────────────────────────────────────────────────────────────
//  RESERVATION
// ─────────────────────────────────────────────────────────────────────────────

class Reservation {
  final String id;
  final String customerName;
  final String? phone;
  final int guestCount;
  final DateTime reservedFor;
  final String? notes;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.customerName,
    this.phone,
    required this.guestCount,
    required this.reservedFor,
    this.notes,
    required this.createdAt,
  });

  Reservation copyWith({
    String? customerName,
    String? phone,
    int? guestCount,
    DateTime? reservedFor,
    String? notes,
  }) =>
      Reservation(
        id: id,
        customerName: customerName ?? this.customerName,
        phone: phone ?? this.phone,
        guestCount: guestCount ?? this.guestCount,
        reservedFor: reservedFor ?? this.reservedFor,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  String get timeLabel {
    final h = reservedFor.hour;
    final m = reservedFor.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $suffix';
  }

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rDate = DateTime(reservedFor.year, reservedFor.month, reservedFor.day);
    if (rDate == today) return 'Today';
    if (rDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[reservedFor.month - 1]} ${reservedFor.day}';
  }

  String get countdownLabel {
    final diff = reservedFor.difference(DateTime.now());
    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TABLE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class RestaurantTable {
  final String id;
  final int tableNumber;
  final int capacity;
  final TableStatus status;
  final TableSection section;
  final TableShape shape;
  final String? currentCustomerName;
  final String? currentOrderId;
  final double? currentOrderTotal;
  final DateTime? occupiedSince;
  final Reservation? reservation;
  final bool hasWindow;
  final bool isPremium;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    required this.status,
    required this.section,
    this.shape = TableShape.square,
    this.currentCustomerName,
    this.currentOrderId,
    this.currentOrderTotal,
    this.occupiedSince,
    this.reservation,
    this.hasWindow = false,
    this.isPremium = false,
  });

  RestaurantTable copyWith({
    TableStatus? status,
    String? currentCustomerName,
    String? currentOrderId,
    double? currentOrderTotal,
    DateTime? occupiedSince,
    Reservation? reservation,
    bool clearReservation = false,
    bool clearOccupied = false,
  }) =>
      RestaurantTable(
        id: id,
        tableNumber: tableNumber,
        capacity: capacity,
        status: status ?? this.status,
        section: section,
        shape: shape,
        currentCustomerName:
            clearOccupied ? null : currentCustomerName ?? this.currentCustomerName,
        currentOrderId:
            clearOccupied ? null : currentOrderId ?? this.currentOrderId,
        currentOrderTotal:
            clearOccupied ? null : currentOrderTotal ?? this.currentOrderTotal,
        occupiedSince:
            clearOccupied ? null : occupiedSince ?? this.occupiedSince,
        reservation: clearReservation ? null : reservation ?? this.reservation,
        hasWindow: hasWindow,
        isPremium: isPremium,
      );

  String get occupiedDuration {
    if (occupiedSince == null) return '';
    final diff = DateTime.now().difference(occupiedSince!);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    return '${diff.inMinutes}m';
  }

  String get tableName => 'T${tableNumber.toString().padLeft(2, '0')}';
}

// enum TableStatus { available, occupied, reserved, cleaning }
// enum TableZone   { ac, nonAc }
// enum TableShape  { square, round, rectangle }

// extension TableStatusExt on TableStatus {
//   String get label {
//     switch (this) {
//       case TableStatus.available: return 'Available';
//       case TableStatus.occupied:  return 'Occupied';
//       case TableStatus.reserved:  return 'Reserved';
//       case TableStatus.cleaning:  return 'Cleaning';
//     }
//   }
//   String get emoji {
//     switch (this) {
//       case TableStatus.available: return '🟢';
//       case TableStatus.occupied:  return '🔴';
//       case TableStatus.reserved:  return '🟡';
//       case TableStatus.cleaning:  return '🧹';
//     }
//   }
// }

// extension TableZoneExt on TableZone {
//   String get label => this == TableZone.ac ? 'AC' : 'Non-AC';
//   String get emoji => this == TableZone.ac ? '❄️' : '🌿';
// }

// class Reservation {
//   final String id;
//   final String customerName;
//   final String phone;
//   final int guestCount;
//   final DateTime scheduledAt;
//   final String? note;

//   const Reservation({
//     required this.id,
//     required this.customerName,
//     required this.phone,
//     required this.guestCount,
//     required this.scheduledAt,
//     this.note,
//   });

//   Reservation copyWith({
//     String? customerName,
//     String? phone,
//     int? guestCount,
//     DateTime? scheduledAt,
//     String? note,
//   }) =>
//       Reservation(
//         id: id,
//         customerName: customerName ?? this.customerName,
//         phone: phone ?? this.phone,
//         guestCount: guestCount ?? this.guestCount,
//         scheduledAt: scheduledAt ?? this.scheduledAt,
//         note: note ?? this.note,
//       );

//   String get timeLabel {
//     final diff = scheduledAt.difference(DateTime.now());
//     if (diff.isNegative) return 'Overdue';
//     if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
//     return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
//   }

//   String get formattedTime {
//     final h = scheduledAt.hour;
//     final m = scheduledAt.minute.toString().padLeft(2, '0');
//     final period = h >= 12 ? 'PM' : 'AM';
//     final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
//     return '$h12:$m $period';
//   }

//   bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
// }

// class RestaurantTable {
//   final String id;
//   final int number;
//   final int capacity;
//   final TableStatus status;
//   final TableZone zone;
//   final TableShape shape;
//   final int floor;
//   final Reservation? reservation;
//   final String? activeOrderId;
//   final String? occupiedBy;
//   final DateTime? occupiedSince;
//   final double? currentBill;

//   const RestaurantTable({
//     required this.id,
//     required this.number,
//     required this.capacity,
//     required this.status,
//     required this.zone,
//     required this.shape,
//     required this.floor,
//     this.reservation,
//     this.activeOrderId,
//     this.occupiedBy,
//     this.occupiedSince,
//     this.currentBill,
//   });

//   RestaurantTable copyWith({
//     int? capacity,
//     TableStatus? status,
//     TableZone? zone,
//     TableShape? shape,
//     int? floor,
//     Reservation? Function()? reservation,
//     String? activeOrderId,
//     String? occupiedBy,
//     DateTime? occupiedSince,
//     double? currentBill,
//   }) =>
//       RestaurantTable(
//         id: id,
//         number: number,
//         capacity: capacity ?? this.capacity,
//         status: status ?? this.status,
//         zone: zone ?? this.zone,
//         shape: shape ?? this.shape,
//         floor: floor ?? this.floor,
//         reservation: reservation != null ? reservation() : this.reservation,
//         activeOrderId: activeOrderId ?? this.activeOrderId,
//         occupiedBy: occupiedBy ?? this.occupiedBy,
//         occupiedSince: occupiedSince ?? this.occupiedSince,
//         currentBill: currentBill ?? this.currentBill,
//       );

//   String get occupiedDuration {
//     if (occupiedSince == null) return '';
//     final diff = DateTime.now().difference(occupiedSince!);
//     if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
//     return '${diff.inMinutes}m';
//   }

//   String get displayName => 'Table $number';
//   String get floorLabel  => floor == 0 ? 'Ground' : 'Floor $floor';
// }

// /*enum TableStatus { available, occupied, reserved }

// class TableModel {
//   final int tableNumber;
//   final int capacity;
//   final TableStatus status;
//   final String? orderId;
//   final String? customerName;
//   final double? orderTotal;
//   final DateTime? occupiedTime;
//   final DateTime? reservationTime;
//   final String? section;

//   TableModel({
//     required this.tableNumber,
//     required this.capacity,
//     required this.status,
//     this.orderId,
//     this.customerName,
//     this.orderTotal,
//     this.occupiedTime,
//     this.reservationTime,
//     this.section,
//   });

//   TableModel copyWith({
//     TableStatus? status,
//     String? orderId,
//     String? customerName,
//     double? orderTotal,
//     DateTime? occupiedTime,
//     DateTime? reservationTime,
//   }) {
//     return TableModel(
//       tableNumber: tableNumber,
//       capacity: capacity,
//       status: status ?? this.status,
//       orderId: orderId ?? this.orderId,
//       customerName: customerName ?? this.customerName,
//       orderTotal: orderTotal ?? this.orderTotal,
//       occupiedTime: occupiedTime ?? this.occupiedTime,
//       reservationTime: reservationTime ?? this.reservationTime,
//       section: section ?? this.section,
//     );
//   }

//   String get statusLabel {
//     switch (status) {
//       case TableStatus.available: return 'Available';
//       case TableStatus.occupied: return 'Occupied';
//       case TableStatus.reserved: return 'Reserved';
//     }
//   }

//   String get formattedDuration {
//     if (occupiedTime == null) return '';
//     final diff = DateTime.now().difference(occupiedTime!);
//     if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
//     return '${diff.inMinutes}m';
//   }

//   String get formattedReservation {
//     if (reservationTime == null) return '';
//     final diff = reservationTime!.difference(DateTime.now());
//     if (diff.inHours > 0) return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
//     return 'in ${diff.inMinutes}m';
//   }
// }
// */