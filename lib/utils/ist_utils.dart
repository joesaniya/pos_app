// lib/utils/ist_utils.dart
const _kIST = Duration(hours: 5, minutes: 30);

DateTime parseToIST(String raw) {
  String s = raw.trim().replaceFirst(' ', 'T');
  if (!s.contains('+') && !s.toUpperCase().endsWith('Z')) s = '${s}Z';
  return DateTime.parse(s).toUtc().add(_kIST);
}

DateTime nowIST() => DateTime.now().toUtc().add(_kIST);

String fmtTimeIST(DateTime ist) {
  final h = ist.hour;
  final m = ist.minute.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$h12:$m $suffix';
}

Duration elapsedIST(DateTime sinceIST) {
  final diff = nowIST().difference(sinceIST);
  return diff.isNegative ? Duration.zero : diff;
}

String durationLabel(DateTime sinceIST) {
  final d = elapsedIST(sinceIST);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${d.inMinutes}m';
}

bool isSameDayIST(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String toUTCString(DateTime dt) => dt.toUtc().toIso8601String();
