// lib/models/seat_history_model.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SEAT HISTORY MODEL
//  Tracks complete history of guest sessions for each seat including
//  walk-in time, duration, checkout time, and visit analytics.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:pos_app/utils/ist_utils.dart';

/// Single guest session record for a specific seat
class SeatSessionHistory {
  final String id;
  final String businessId;
  final String tableId;
  final int tableNumber;
  final String section;
  final String seatLabel;
  final String sessionId; // Unique identifier for this session
  final String? customerName;
  final int guestCount;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final Duration? duration;
  final String status; // 'active', 'checked-out', 'abandoned'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SeatSessionHistory({
    required this.id,
    required this.businessId,
    required this.tableId,
    required this.tableNumber,
    required this.section,
    required this.seatLabel,
    required this.sessionId,
    this.customerName,
    this.guestCount = 1,
    required this.checkInTime,
    this.checkOutTime,
    this.duration,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory SeatSessionHistory.fromJson(Map<String, dynamic> json) {
    return SeatSessionHistory(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      tableId: json['table_id'] ?? '',
      tableNumber: json['table_number'] ?? 0,
      section: json['section'] ?? '',
      seatLabel: json['seat_label'] ?? '',
      sessionId: json['session_id'] ?? '',
      customerName: json['customer_name'],
      guestCount: json['guest_count'] ?? 1,
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time']).toLocal()
          : DateTime.now(),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time']).toLocal()
          : null,
      duration: json['duration_seconds'] != null
          ? Duration(seconds: json['duration_seconds'] as int)
          : null,
      status: json['status'] ?? 'active',
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'table_id': tableId,
      'table_number': tableNumber,
      'section': section,
      'seat_label': seatLabel,
      'session_id': sessionId,
      'customer_name': customerName,
      'guest_count': guestCount,
      'check_in_time': checkInTime.toUtc().toIso8601String(),
      'check_out_time': checkOutTime?.toUtc().toIso8601String(),
      'duration_seconds': duration?.inSeconds,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  SeatSessionHistory copyWith({
    String? id,
    String? businessId,
    String? tableId,
    int? tableNumber,
    String? section,
    String? seatLabel,
    String? sessionId,
    String? customerName,
    int? guestCount,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    Duration? duration,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SeatSessionHistory(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      section: section ?? this.section,
      seatLabel: seatLabel ?? this.seatLabel,
      sessionId: sessionId ?? this.sessionId,
      customerName: customerName ?? this.customerName,
      guestCount: guestCount ?? this.guestCount,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Computed properties ───────────────────────────────────────────────────

  /// Current or final duration of the session
  Duration get currentDuration {
    if (duration != null) {
      return duration!;
    }

    if (checkOutTime != null) {
      return checkOutTime!.difference(checkInTime);
    }

    // Active session - calculate from now
    return nowIST().difference(checkInTime);
  }

  /// Formatted duration string (e.g., "1h 45m" or "45m")
  String get formattedDuration {
    final d = currentDuration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${d.inMinutes}m';
  }

  /// Formatted check-in time (e.g., "10:30 AM")
  String get checkInTimeFormatted {
    return _formatTime(checkInTime);
  }

  /// Formatted check-out time (e.g., "11:45 AM")
  String get checkOutTimeFormatted {
    if (checkOutTime == null) return '—';
    return _formatTime(checkOutTime!);
  }

  /// Formatted date (e.g., "Today", "Yesterday", "Mar 24")
  String get dateFormatted {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
    );

    if (sessionDate == today) return 'Today';
    if (sessionDate == today.subtract(const Duration(days: 1)))
      return 'Yesterday';

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
    return '${months[checkInTime.month - 1]} ${checkInTime.day}';
  }

  /// Display label for session details (e.g., "Guest Name (45 min)")
  String get displayLabel {
    final name = customerName ?? 'Guest';
    final dur = formattedDuration;
    return '$name ($dur)';
  }

  /// Is this session currently active?
  bool get isActive => status == 'active' && checkOutTime == null;

  /// Is this session completed (checked out)?
  bool get isCheckedOut => status == 'checked-out' && checkOutTime != null;

  /// Days since this session occurred
  int get daysSinceSession {
    return nowIST().difference(checkInTime).inDays;
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $suffix';
  }
}

/// Aggregated seat history analytics
class SeatHistorySummary {
  final String seatLabel;
  final List<SeatSessionHistory> sessions;

  const SeatHistorySummary({required this.seatLabel, required this.sessions});

  /// Total number of sessions for this seat
  int get totalSessions => sessions.length;

  /// Total combined duration across all sessions
  Duration get totalDuration {
    Duration total = Duration.zero;
    for (final session in sessions) {
      total += session.currentDuration;
    }
    return total;
  }

  /// Average session duration
  Duration get averageDuration {
    if (sessions.isEmpty) return Duration.zero;
    return Duration(
      seconds: (totalDuration.inSeconds / sessions.length).round(),
    );
  }

  /// Total guests served (sum of guest counts)
  int get totalGuests {
    return sessions.fold<int>(0, (sum, s) => sum + s.guestCount);
  }

  /// Most recent session
  SeatSessionHistory? get lastSession {
    if (sessions.isEmpty) return null;
    return sessions.reduce(
      (a, b) => a.checkInTime.isAfter(b.checkInTime) ? a : b,
    );
  }

  /// Formatted summary string
  String get summary {
    return '$totalSessions visits • ${(totalDuration.inHours)}h total';
  }
}
