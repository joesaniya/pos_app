// lib/models/table_modal.dart
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
//  RESERVATION
// ─────────────────────────────────────────────────────────────────────────────
class Reservation {
  final String id;
  final String customerName;
  final String? phone;
  final int guestCount;
  final DateTime reservedFor; // planned start time (IST)
  final DateTime? checkIn; // ACTUAL arrival time (IST) — null until seated
  final DateTime?
  checkOut; // planned end time (IST) — set at creation for overlap check
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

  // ── Display helpers ──────────────────────────────────────────────────────
  String get timeLabel {
    final h = reservedFor.hour;
    final m = reservedFor.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suffix';
  }

  String get checkInTimeLabel {
    if (checkIn == null) return '—';
    return fmtTimeIST(checkIn!);
  }

  String get checkOutTimeLabel {
    if (checkOut == null) return '—';
    return fmtTimeIST(checkOut!);
  }

  String get dateLabel {
    final today = nowIST();
    final todayD = DateTime(today.year, today.month, today.day);
    final rDate = DateTime(
      reservedFor.year,
      reservedFor.month,
      reservedFor.day,
    );
    if (rDate == todayD) return 'Today';
    if (rDate == todayD.add(const Duration(days: 1))) return 'Tomorrow';
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
    return checkOut!.difference(nowIST()).inMinutes;
  }

  bool get isEndingSoon {
    final mins = minutesUntilCheckOut;
    if (mins == null) return false;
    return mins >= 0 && mins <= 15;
  }

  bool get isOverstaying {
    // Only overstaying if guest has actually checked in AND planned end passed
    if (checkIn == null || checkOut == null) return false;
    return nowIST().isAfter(checkOut!);
  }

  String get createdByLabel => createdByName ?? createdByRole ?? 'Staff';
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESERVATION HISTORY ITEM
// ─────────────────────────────────────────────────────────────────────────────
class ReservationHistoryItem {
  final String id;
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

  const ReservationHistoryItem({
    required this.id,
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
  });

  factory ReservationHistoryItem.fromMap(Map<String, dynamic> row) {
    final tableData = row['restaurant_tables'];
    return ReservationHistoryItem(
      id: row['id'] ?? '',
      tableNumber: tableData?['table_number'] ?? 0,
      section: tableData?['section'] ?? '',
      customerName: row['customer_name'] ?? '',
      phone: row['phone'],
      guestCount: row['guest_count'] ?? 0,
      // ✅ All timestamps parsed as IST — not device-local
      reservedFor: parseToIST(row['reserved_for'] as String),
      checkIn: row['check_in'] != null
          ? parseToIST(row['check_in'] as String)
          : null,
      checkOut: row['check_out'] != null
          ? parseToIST(row['check_out'] as String)
          : null,
      notes: row['notes'],
      status: row['status'] ?? 'active',
      createdByName: row['created_by_name'] ?? 'Staff',
      createdAt: parseToIST(row['created_at'] as String),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return '📅 Upcoming';
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESTAURANT TABLE MODEL
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
  final String? sessionId; // current guest session — orders filter by this

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
    this.sessionId,
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
    sessionId: sessionId,
  );

  String get tableName => 'T${tableNumber.toString().padLeft(2, '0')}';

  String get occupiedDuration {
    if (occupiedSince == null) return '—';
    return durationLabel(occupiedSince!);
  }

  int get occupiedMinutes {
    if (occupiedSince == null) return 0;
    return elapsedIST(occupiedSince!).inMinutes;
  }
}
