// lib/utils/ist_utils.dart
// ═══════════════════════════════════════════════════════
//  IST TIME UTILITIES  (UTC+5:30, hardcoded — no device timezone dependency)
// ═══════════════════════════════════════════════════════

const _kIST = Duration(hours: 5, minutes: 30);

/// Parses ANY Supabase timestamp string → IST DateTime.
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
  return DateTime.parse(s).toUtc().add(_kIST);
}

/// Current time in IST (hardcoded offset — not device-dependent).
DateTime nowIST() => DateTime.now().toUtc().add(_kIST);

/// Format an IST DateTime as "9:13 PM"
String fmtTimeIST(DateTime ist) {
  final h      = ist.hour;
  final m      = ist.minute.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12    = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$h12:$m $suffix';
}

/// Safe elapsed duration: never returns negative.
Duration elapsedIST(DateTime sinceIST) {
  final diff = nowIST().difference(sinceIST);
  return diff.isNegative ? Duration.zero : diff;
}

/// Human-readable duration label: "23m", "1h 05m"
String durationLabel(DateTime sinceIST) {
  final d = elapsedIST(sinceIST);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m';
}

/*
DateTime parseToIST(String raw) {
  // Normalize: replace space with T if needed
  String s = raw.trim().replaceFirst(' ', 'T');

  // If no timezone suffix, treat as UTC by appending Z
  if (!s.contains('+') && !s.toUpperCase().endsWith('Z')) {
    s = '${s}Z';
  }

  final utc = DateTime.parse(s).toUtc();
  return utc.add(const Duration(hours: 5, minutes: 30));
}

/// Current time in IST.
DateTime nowIST() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

/// Format a DateTime (already in IST) as "9:13 PM"
String fmtTimeIST(DateTime ist) {
  final h = ist.hour;
  final m = ist.minute.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$h12:$m $suffix';
}

/// Human-readable elapsed duration from [since] (IST) to now (IST).
/// Returns e.g. "23m", "1h 05m", "2h 30m"
String elapsedLabel(DateTime sinceIST) {
  final elapsed = nowIST().difference(sinceIST);
  final h = elapsed.inHours;
  final m = elapsed.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m';
}*/