// lib/utils/ist_utils.dart
// ═══════════════════════════════════════════════════════
//  TIME UTILITIES  — uses device local timezone automatically
// ═══════════════════════════════════════════════════════

/// Parses ANY Supabase timestamp string → local DateTime.
/// Handles:
///   "2026-03-01 15:34:05.840001+00"
///   "2026-03-01T15:34:05.840001+00:00"
///   "2026-03-01T15:34:05.840001Z"
///   "2026-03-01T15:34:05.840001"   ← no suffix → treated as UTC
DateTime parseToIST(String raw) {
  String s = raw.trim().replaceFirst(' ', 'T');
  // If no timezone suffix at all, assume UTC
  if (!s.contains('+') && !s.toUpperCase().endsWith('Z')) {
    s = '${s}Z';
  }
  // .toLocal() uses the device's own timezone — no hardcoded offset needed
  return DateTime.parse(s).toLocal();
}

/// Current local time (device timezone).
DateTime nowIST() => DateTime.now().toLocal();

/// Format a local DateTime as "9:13 PM"
String fmtTimeIST(DateTime local) {
  final h = local.hour;
  final m = local.minute.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$h12:$m $suffix';
}

/// Safe elapsed duration: never returns negative.
Duration elapsedIST(DateTime sinceLocal) {
  final diff = nowIST().difference(sinceLocal);
  return diff.isNegative ? Duration.zero : diff;
}

/// Human-readable duration label: "23m", "1h 05m"
String durationLabel(DateTime sinceLocal) {
  final d = elapsedIST(sinceLocal);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m';
}
