import 'dart:math' as math;

/// Parses "HH:mm" into minutes since midnight. Returns null if invalid.
int? parseHm(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Formats minutes since midnight as "HH:mm".
String fmtHm(int minutes) {
  final m = ((minutes % 1440) + 1440) % 1440;
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:$mm';
}

/// Hours between check-in and check-out, minus the break.
double workedHours({
  required int inMin,
  required int outMin,
  required int breakMin,
}) {
  var diff = outMin - inMin;
  if (diff < 0) diff += 1440;
  diff -= breakMin;
  return math.max(0, diff) / 60.0;
}

/// Overtime in steps of 0.5 hours (rounded down). Less than 0.5 h is ignored.
double overtimeHours({required double worked, required double standard}) {
  final extra = worked - standard;
  if (extra < 0.5) return 0;
  return (extra * 2).floor() / 2;
}

String fmtHours(double h) => '${h.toStringAsFixed(1)} h';

String dateKey(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime parseDateKey(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
