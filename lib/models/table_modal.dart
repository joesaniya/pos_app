// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS
// ─────────────────────────────────────────────────────────────────────────────

import 'package:pos_app/utils/ist_utils.dart';

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
  final DateTime reservedFor; // check-in / start time
  final DateTime? checkIn; // actual arrival (seated)
  final DateTime? checkOut; // planned / actual departure
  final String? notes;
  final String status; // active | seated | cancelled | no_show
  final bool warningSent;
  final DateTime createdAt;

  // ── Who created this reservation ─────────────────────
  final String? createdByName; // staff member's name
  final String? createdByRole; // staff member's role (admin/manager/staff)

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

  // ── Display helpers ──────────────────────────────────

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
    // final diff = reservedFor.difference(DateTime.now());
    final diff = reservedFor.difference(nowIST());
    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }

  /// Minutes remaining until check-out (null if no check-out time set)
  int? get minutesUntilCheckOut {
    if (checkOut == null) return null;
    return checkOut!.difference(DateTime.now()).inMinutes;
  }

  bool get isEndingSoon {
    final mins = minutesUntilCheckOut;
    if (mins == null) return false;
    return mins >= 0 && mins <= 15;
  }

  /// Who created the reservation — shows name if available, falls back to role
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

  // ── Audit / cancellation fields ───────────────────────
  /// Who last updated this reservation (name from updated_by_name column)
  final String? updatedByName;

  /// Name of the staff member who cancelled / marked no-show.
  /// Falls back to updatedByName when not explicitly recorded.
  final String? cancelledByName;

  /// Timestamp when the reservation was cancelled / no-showed.
  /// Populated from a `cancelled_at` column or derived from `updated_at`.
  final DateTime? cancelledAt;

  /// Optional free-text reason for cancellation (e.g. "guest request").
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
    // audit
    this.updatedByName,
    this.cancelledByName,
    this.cancelledAt,
    this.cancellationReason,
  });

  factory ReservationHistoryItem.fromMap(Map<String, dynamic> row) {
    final tableData = row['restaurant_tables'];

    // Determine cancelled_at: use explicit column if present,
    // otherwise fall back to updated_at (which Supabase updates on every write).
    DateTime? cancelledAt;
    if (row['cancelled_at'] != null) {
      cancelledAt = DateTime.parse(row['cancelled_at'] as String).toLocal();
    } else if (row['updated_at'] != null) {
      final status = row['status'] as String? ?? '';
      if (status == 'cancelled' || status == 'no_show') {
        cancelledAt = DateTime.parse(row['updated_at'] as String).toLocal();
      }
    }

    return ReservationHistoryItem(
      id: row['id'] ?? '',
      tableId: row['table_id'] ?? '',
      tableNumber: tableData?['table_number'] ?? 0,
      section: tableData?['section'] ?? '',
      customerName: row['customer_name'] ?? '',
      phone: row['phone'],
      guestCount: row['guest_count'] ?? 0,
      reservedFor: DateTime.parse(row['reserved_for']).toLocal(),
      checkIn: row['check_in'] != null
          ? DateTime.parse(row['check_in']).toLocal()
          : null,
      checkOut: row['check_out'] != null
          ? DateTime.parse(row['check_out']).toLocal()
          : null,
      notes: row['notes'],
      status: row['status'] ?? 'active',
      createdByName: row['created_by_name'] ?? 'Staff',
      createdAt: DateTime.parse(row['created_at']).toLocal(),
      // audit
      updatedByName: row['updated_by_name'] as String?,
      cancelledByName: row['updated_by_name'] as String?, // same column for now
      cancelledAt: cancelledAt,
      cancellationReason: row['cancellation_reason'] as String?,
    );
  }

  /// Human-readable status label with emoji
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
}


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
  );

  // ── Display helpers ──────────────────────────────────

  String get occupiedDuration {
    if (occupiedSince == null) return '—';
    final diff = elapsedIST(
      occupiedSince!,
    ); // ← uses nowIST() internally, never negative
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${diff.inMinutes}m';
  }

  // occupiedDuration1 can be deleted — it's now a duplicate
  // String get occupiedDuration1 { ... }   ← remove this

  int get occupiedMinutes {
    if (occupiedSince == null) return 0;
    return elapsedIST(
      occupiedSince!,
    ).inMinutes; // ← was DateTime.now(), now IST-safe
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

  /// Minutes the table has been occupied (0 if not occupied)
  int get occupiedMinutes1 {
    if (occupiedSince == null) return 0;
    return DateTime.now().difference(occupiedSince!).inMinutes;
  }
}
