// lib/models/table_modal.dart
// v2: Added sessionId to RestaurantTable for session-scoped order filtering

import 'package:pos_app/utils/ist_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum TableStatus { available, occupied, reserved, cleaning }

extension TableStatusExt on TableStatus {
  String get label {
    switch (this) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.reserved:
        return 'Reserved';
      case TableStatus.cleaning:
        return 'Cleaning';
    }
  }

  String get emoji {
    switch (this) {
      case TableStatus.available:
        return '✅';
      case TableStatus.occupied:
        return '🍽️';
      case TableStatus.reserved:
        return '📅';
      case TableStatus.cleaning:
        return '🧹';
    }
  }
}

enum TableSection { ac, nonAc, rooftop, garden, privateRoom }

extension TableSectionExt on TableSection {
  String get label {
    switch (this) {
      case TableSection.ac:
        return 'AC Hall';
      case TableSection.nonAc:
        return 'Non-AC';
      case TableSection.rooftop:
        return 'Rooftop';
      case TableSection.garden:
        return 'Garden';
      case TableSection.privateRoom:
        return 'Private';
    }
  }

  String get emoji {
    switch (this) {
      case TableSection.ac:
        return '❄️';
      case TableSection.nonAc:
        return '🌀';
      case TableSection.rooftop:
        return '🌇';
      case TableSection.garden:
        return '🌿';
      case TableSection.privateRoom:
        return '🔒';
    }
  }

  String get floor {
    switch (this) {
      case TableSection.ac:
        return 'G Floor';
      case TableSection.nonAc:
        return 'G Floor';
      case TableSection.rooftop:
        return '3rd Floor';
      case TableSection.garden:
        return 'G Floor';
      case TableSection.privateRoom:
        return '2nd Floor';
    }
  }
}

enum TableShape { square, round, rectangle }

// ─────────────────────────────────────────────────────────────────────────────
//  TABLE SEAT
// ─────────────────────────────────────────────────────────────────────────────

class TableSeat {
  final String id;
  final String tableId;
  final String seatLabel;
  final TableStatus status;
  final String? sessionId;
  final String? customerName;
  final DateTime? occupiedSince;

  const TableSeat({
    required this.id,
    required this.tableId,
    required this.seatLabel,
    this.status = TableStatus.available,
    this.sessionId,
    this.customerName,
    this.occupiedSince,
  });

  factory TableSeat.fromJson(Map<String, dynamic> j) {
    return TableSeat(
      id: j['id'] ?? '',
      tableId: j['table_id'] ?? '',
      seatLabel: j['seat_label'] ?? '',
      status: j['status'] == 'occupied'
          ? TableStatus.occupied
          : TableStatus.available,
      sessionId:
          j['session_id'] is String && (j['session_id'] as String).isNotEmpty
          ? j['session_id'] as String
          : null,
      customerName: j['customer_name'],
      occupiedSince: j['occupied_since'] != null
          ? parseToIST(j['occupied_since'].toString())
          : null,
    );
  }

  TableSeat copyWith({
    TableStatus? status,
    String? sessionId,
    String? customerName,
    DateTime? occupiedSince,
    bool clearOccupied = false,
  }) {
    return TableSeat(
      id: id,
      tableId: tableId,
      seatLabel: seatLabel,
      status: clearOccupied ? TableStatus.available : status ?? this.status,
      sessionId: clearOccupied ? null : sessionId ?? this.sessionId,
      customerName: clearOccupied ? null : customerName ?? this.customerName,
      occupiedSince: clearOccupied ? null : occupiedSince ?? this.occupiedSince,
    );
  }

  bool get isAvailable => status == TableStatus.available;
  bool get isOccupied => status == TableStatus.occupied;

  String get occupiedDuration {
    if (occupiedSince == null) return '—';
    final diff = elapsedIST(occupiedSince!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${diff.inMinutes}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESERVATION
// ─────────────────────────────────────────────────────────────────────────────

class Reservation {
  final String id;
  final String customerName;
  final String? phone;
  final int guestCount;
  final DateTime reservedFor;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? notes;
  final String status;
  final bool warningSent;
  final DateTime createdAt;
  final String? createdByName;
  final String? createdByRole;

  const Reservation({
    required this.id,
    required this.customerName,
    this.phone,
    required this.guestCount,
    required this.reservedFor,
    this.checkIn,
    this.checkOut,
    this.notes,
    this.status = 'active',
    this.warningSent = false,
    required this.createdAt,
    this.createdByName,
    this.createdByRole,
  });

  Reservation copyWith({
    String? customerName,
    String? phone,
    int? guestCount,
    DateTime? reservedFor,
    DateTime? checkIn,
    DateTime? checkOut,
    String? notes,
    String? status,
    bool? warningSent,
    String? createdByName,
    String? createdByRole,
    required String id,
  }) => Reservation(
    id: id,
    customerName: customerName ?? this.customerName,
    phone: phone ?? this.phone,
    guestCount: guestCount ?? this.guestCount,
    reservedFor: reservedFor ?? this.reservedFor,
    checkIn: checkIn ?? this.checkIn,
    checkOut: checkOut ?? this.checkOut,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    warningSent: warningSent ?? this.warningSent,
    createdAt: createdAt,
    createdByName: createdByName ?? this.createdByName,
    createdByRole: createdByRole ?? this.createdByRole,
  );

  factory Reservation.fromJson(Map<String, dynamic> j) {
    return Reservation(
      id: j['id'] ?? '',
      customerName: j['customer_name'] ?? '',
      phone: j['phone'],
      guestCount: j['guest_count'] ?? 1,
      reservedFor: j['reserved_for'] != null
          ? parseToIST(j['reserved_for'].toString())
          : nowIST(),
      checkIn: j['check_in'] != null
          ? parseToIST(j['check_in'].toString())
          : null,
      checkOut: j['check_out'] != null
          ? parseToIST(j['check_out'].toString())
          : null,
      notes: j['notes'],
      status: j['status'] ?? 'active',
      warningSent: false, // default
      createdAt: nowIST(), // default, use IST now
      createdByName: j['created_by_name'],
      createdByRole: null, // default
    );
  }

  String get timeLabel {
    final h = reservedFor.hour;
    final m = reservedFor.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $suffix';
  }

  String get checkOutTimeLabel {
    if (checkOut == null) return '—';
    final h = checkOut!.hour;
    final m = checkOut!.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $suffix';
  }

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rDate = DateTime(
      reservedFor.year,
      reservedFor.month,
      reservedFor.day,
    );
    if (rDate == today) return 'Today';
    if (rDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[reservedFor.month - 1]} ${reservedFor.day}';
  }

  String get countdownLabel {
    final diff = reservedFor.difference(nowIST());
    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }

  int? get minutesUntilCheckOut {
    if (checkOut == null) return null;
    return checkOut!.difference(DateTime.now()).inMinutes;
  }

  bool get isEndingSoon {
    final mins = minutesUntilCheckOut;
    if (mins == null) return false;
    return mins >= 0 && mins <= 15;
  }

  String get createdByLabel => createdByName ?? createdByRole ?? 'Staff';
}

class ReservationHistoryItem {
  final String id;
  final String tableId;
  final int tableNumber;
  final String section;
  final String customerName;
  final String? phone;
  final int guestCount;
  final DateTime reservedFor;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? notes;
  final String status;
  final String createdByName;
  final DateTime createdAt;
  final String? updatedByName;
  final String? cancelledByName;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  const ReservationHistoryItem({
    required this.id,
    required this.tableId,
    required this.tableNumber,
    required this.section,
    required this.customerName,
    this.phone,
    required this.guestCount,
    required this.reservedFor,
    this.checkIn,
    this.checkOut,
    this.notes,
    required this.status,
    required this.createdByName,
    required this.createdAt,
    this.updatedByName,
    this.cancelledByName,
    this.cancelledAt,
    this.cancellationReason,
  });

  factory ReservationHistoryItem.fromMap(Map<String, dynamic> row) {
    final tableData = row['restaurant_tables'];

    DateTime? cancelledAt;
    if (row['cancelled_at'] != null) {
      cancelledAt = parseToIST(row['cancelled_at'] as String);
    } else if (row['updated_at'] != null) {
      final status = row['status'] as String? ?? '';
      if (status == 'cancelled' || status == 'no_show') {
        cancelledAt = parseToIST(row['updated_at'] as String);
      }
    }

    return ReservationHistoryItem(
      id: row['id'] as String? ?? '',
      tableId: row['table_id'] as String? ?? '',
      tableNumber: tableData is Map<String, dynamic>
          ? (tableData['table_number'] as int? ?? 0)
          : 0,
      section: tableData is Map<String, dynamic>
          ? (tableData['section'] as String? ?? '')
          : '',
      customerName: row['customer_name'] as String? ?? '',
      phone: row['phone'] as String?,
      guestCount: row['guest_count'] as int? ?? 0,
      reservedFor: row['reserved_for'] != null
          ? parseToIST(row['reserved_for'] as String)
          : nowIST(),
      checkIn: row['check_in'] != null
          ? parseToIST(row['check_in'] as String)
          : null,
      checkOut: row['check_out'] != null
          ? parseToIST(row['check_out'] as String)
          : null,
      notes: row['notes'] as String?,
      status: row['status'] as String? ?? 'active',
      createdByName: row['created_by_name'] as String? ?? 'Staff',
      createdAt: row['created_at'] != null
          ? parseToIST(row['created_at'] as String)
          : nowIST(),
      updatedByName: row['updated_by_name'] as String?,
      cancelledByName: row['updated_by_name'] as String?,
      cancelledAt: cancelledAt,
      cancellationReason: row['cancellation_reason'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return '📅 Active';
      case 'seated':
        return '🍽️ Seated';
      case 'completed':
        return '✅ Completed';
      case 'cancelled':
        return '✖️ Cancelled';
      case 'no_show':
        return '👻 No Show';
      default:
        return status;
    }
  }

  ReservationHistoryItem copyWith({
    String? id,
    String? tableId,
    int? tableNumber,
    String? section,
    String? customerName,
    String? phone,
    int? guestCount,
    DateTime? reservedFor,
    DateTime? checkIn,
    DateTime? checkOut,
    String? notes,
    String? status,
    String? createdByName,
    DateTime? createdAt,
    String? updatedByName,
    String? cancelledByName,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) => ReservationHistoryItem(
    id: id ?? this.id,
    tableId: tableId ?? this.tableId,
    tableNumber: tableNumber ?? this.tableNumber,
    section: section ?? this.section,
    customerName: customerName ?? this.customerName,
    phone: phone ?? this.phone,
    guestCount: guestCount ?? this.guestCount,
    reservedFor: reservedFor ?? this.reservedFor,
    checkIn: checkIn ?? this.checkIn,
    checkOut: checkOut ?? this.checkOut,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdByName: createdByName ?? this.createdByName,
    createdAt: createdAt ?? this.createdAt,
    updatedByName: updatedByName ?? this.updatedByName,
    cancelledByName: cancelledByName ?? this.cancelledByName,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancellationReason: cancellationReason ?? this.cancellationReason,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESTAURANT TABLE
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
  final List<TableSeat> seats;

  // FIX: expose session_id for order-repository session filtering
  final String? sessionId;

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
    this.seats = const [],
    this.sessionId, // FIX: new field
  });

  RestaurantTable copyWith({
    TableStatus? status,
    String? currentCustomerName,
    String? currentOrderId,
    double? currentOrderTotal,
    DateTime? occupiedSince,
    Reservation? reservation,
    List<TableSeat>? seats,
    String? sessionId,
    bool clearReservation = false,
    bool clearOccupied = false,
  }) => RestaurantTable(
    id: id,
    tableNumber: tableNumber,
    capacity: capacity,
    status: status ?? this.status,
    section: section,
    shape: shape,
    currentCustomerName: clearOccupied
        ? null
        : currentCustomerName ?? this.currentCustomerName,
    currentOrderId: clearOccupied
        ? null
        : currentOrderId ?? this.currentOrderId,
    currentOrderTotal: clearOccupied
        ? null
        : currentOrderTotal ?? this.currentOrderTotal,
    occupiedSince: clearOccupied ? null : occupiedSince ?? this.occupiedSince,
    reservation: clearReservation ? null : reservation ?? this.reservation,
    hasWindow: hasWindow,
    isPremium: isPremium,
    seats: seats ?? this.seats,
    sessionId: clearOccupied ? null : sessionId ?? this.sessionId,
  );

  // ── Display helpers ──────────────────────────────────

  String get occupiedDuration {
    if (occupiedSince == null) return '—';
    final diff = elapsedIST(occupiedSince!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${diff.inMinutes}m';
  }

  int get occupiedMinutes {
    if (occupiedSince == null) return 0;
    return elapsedIST(occupiedSince!).inMinutes;
  }

  String get tableName => 'T${tableNumber.toString().padLeft(2, '0')}';

  String get occupiedDuration1 {
    if (occupiedSince == null) return '—';
    final diff = nowIST().difference(occupiedSince!);
    final mins = diff.isNegative ? 0 : diff.inMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  int get occupiedMinutes1 {
    if (occupiedSince == null) return 0;
    return DateTime.now().difference(occupiedSince!).inMinutes;
  }

  // ── Seat-level helpers ──────────────────────────────────

  int get occupiedSeatCount =>
      seats.where((s) => s.status == TableStatus.occupied).length;

  int get availableSeatCount =>
      seats.where((s) => s.status == TableStatus.available).length;

  bool get isPartiallyOccupied =>
      seats.isNotEmpty &&
      occupiedSeatCount > 0 &&
      occupiedSeatCount < seats.length;

  bool get isFullyOccupied =>
      seats.isNotEmpty && occupiedSeatCount == seats.length;

  List<TableSeat> get occupiedSeats =>
      seats.where((s) => s.status == TableStatus.occupied).toList();

  List<TableSeat> get availableSeats =>
      seats.where((s) => s.status == TableStatus.available).toList();

  /// COMPUTED STATUS based on seat occupancy:
  /// - If seats are defined, status is derived from seat state
  /// - Otherwise, fall back to the database status column
  TableStatus get computedStatus {
    // If no seats defined, use database status
    if (seats.isEmpty) return status;

    // If fully occupied, always show as occupied (unless cleaning/reserved)
    if (isFullyOccupied) {
      return status == TableStatus.cleaning
          ? TableStatus.cleaning
          : TableStatus.occupied;
    }

    // If partially occupied, override status to occupied (guests can still order)
    if (isPartiallyOccupied) {
      return status == TableStatus.cleaning
          ? TableStatus.cleaning
          : TableStatus.occupied;
    }

    // If all seats available, show as available
    if (occupiedSeatCount == 0) {
      return status == TableStatus.reserved
          ? TableStatus.reserved
          : TableStatus.available;
    }

    // Fallback to database status
    return status;
  }

  /// Display status for UI - same as computedStatus but may be used for styling
  TableStatus get displayStatus => computedStatus;

  /// Check if table can accept new orders
  bool get canAcceptOrders {
    final dStatus = displayStatus;
    return dStatus != TableStatus.cleaning &&
        (dStatus == TableStatus.available ||
            dStatus == TableStatus.occupied ||
            dStatus == TableStatus.reserved);
  }
}
