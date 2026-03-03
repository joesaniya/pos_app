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

  // ── Scheduled times (set at booking — used for slot validation) ──
  final DateTime reservedFor; // planned check-in  (IST)
  final DateTime?
  scheduledCheckOut; // planned check-out (IST) → drives overlap checks

  // ── Actual times (recorded by staff actions — used for billing/analytics) ──
  final DateTime? checkIn; // actual arrival    → set by fn_checkin RPC
  final DateTime? checkOut; // actual departure  → set by fn_checkout RPC

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
    this.scheduledCheckOut,
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
    DateTime? scheduledCheckOut,
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
    scheduledCheckOut: scheduledCheckOut ?? this.scheduledCheckOut,
    checkIn: checkIn ?? this.checkIn,
    checkOut: checkOut ?? this.checkOut,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    warningSent: warningSent ?? this.warningSent,
    createdAt: createdAt,
    createdByName: createdByName ?? this.createdByName,
    createdByRole: createdByRole ?? this.createdByRole,
  );

  // ── Time label helpers ───────────────────────────────────────────────────

  String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suf = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $suf';
  }

  /// Planned check-in time label  e.g. "12:51 PM"
  String get timeLabel => _fmt(reservedFor);

  /// Planned check-out time label e.g. "1:51 PM"
  String get scheduledCheckOutLabel =>
      scheduledCheckOut != null ? _fmt(scheduledCheckOut!) : '—';

  /// Actual arrival time label    e.g. "12:55 PM"
  String get checkInTimeLabel => checkIn != null ? _fmt(checkIn!) : '—';

  /// Actual departure time label  e.g. "2:10 PM"
  String get checkOutTimeLabel => checkOut != null ? _fmt(checkOut!) : '—';

  String get dateLabel {
    final now = nowIST();
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

  /// Minutes until PLANNED check-out (for "ending soon" warnings)
  int? get minutesUntilScheduledCheckOut {
    if (scheduledCheckOut == null) return null;
    return scheduledCheckOut!.difference(nowIST()).inMinutes;
  }

  bool get isEndingSoon {
    final mins = minutesUntilScheduledCheckOut;
    if (mins == null) return false;
    return mins >= 0 && mins <= 15;
  }

  /// True when guest is seated but staff has not yet tapped "Mark Checked In"
  bool get needsCheckIn => checkIn == null && status == 'seated';

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
  final DateTime reservedFor; // planned check-in
  final DateTime? plannedCheckOut; // planned check-out
  final DateTime? actualCheckIn; // actual arrival
  final DateTime? actualCheckOut; // actual departure
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
    this.plannedCheckOut,
    this.actualCheckIn,
    this.actualCheckOut,
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
      reservedFor: DateTime.parse(row['reserved_for']).toLocal(),
      plannedCheckOut: row['check_out'] != null
          ? DateTime.parse(row['check_out'] as String).toLocal()
          : null,
      actualCheckIn: row['check_in'] != null
          ? DateTime.parse(row['check_in'] as String).toLocal()
          : null,
      actualCheckOut: row['actual_check_out'] != null
          ? DateTime.parse(row['actual_check_out'] as String).toLocal()
          : null,
      notes: row['notes'],
      status: row['status'] ?? 'active',
      createdByName: row['created_by_name'] ?? 'Staff',
      createdAt: DateTime.parse(row['created_at']).toLocal(),
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

  /// Actual duration in minutes (null if guest hasn't checked out yet)
  int? get actualDurationMinutes {
    if (actualCheckIn == null || actualCheckOut == null) return null;
    return actualCheckOut!.difference(actualCheckIn!).inMinutes;
  }

  String get actualDurationLabel {
    final mins = actualDurationMinutes;
    if (mins == null) return '—';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${mins}m';
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
    String? sessionId,
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
    sessionId: clearOccupied ? null : sessionId ?? this.sessionId,
  );

  String get tableName => 'T${tableNumber.toString().padLeft(2, '0')}';

  String get occupiedDuration {
    if (occupiedSince == null) return '—';
    final diff = nowIST().difference(occupiedSince!);
    final mins = diff.isNegative ? 0 : diff.inMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  int get occupiedMinutes {
    if (occupiedSince == null) return 0;
    return nowIST().difference(occupiedSince!).inMinutes.clamp(0, 99999);
  }
}
