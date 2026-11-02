import 'dart:math' as math;

import 'calc.dart';
import 'models.dart';
import 'state.dart';

DateTime _dateOnly(DateTime x) => DateTime(x.year, x.month, x.day);

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Salary of one worker for one month.
class SalaryResult {
  const SalaryResult({
    required this.worker,
    required this.month,
    required this.daysInMonth,
    required this.startDay,
    required this.eligibleDays,
    required this.present,
    required this.half,
    required this.leave,
    required this.absent,
    required this.unmarked,
    required this.payableUnits,
    required this.otHours,
    required this.basePay,
    required this.otPay,
    required this.hourlyBase,
    required this.records,
  });

  final Worker worker;

  /// First day of the month.
  final DateTime month;
  final int daysInMonth;

  /// First day of the month on which this worker counts (joining date).
  final int startDay;
  final int eligibleDays;
  final int present;
  final int half;
  final int leave;
  final int absent;

  /// Working days (not weekly off, not in the future) with no attendance.
  final int unmarked;

  /// Paid days (daily / monthly workers) or paid hours (hourly workers).
  final double payableUnits;
  final double otHours;
  final double basePay;
  final double otPay;

  /// Pay for one normal hour, used for overtime.
  final double hourlyBase;
  final List<Attendance> records;

  double get gross => _round2(basePay + otPay);
}

/// Calculates one worker's salary for [month].
///
/// Rules:
///  * Daily:   rate x (present + 0.5 x half day + paid leave days).
///  * Monthly: rate / days in month x (days since joining - absent
///             - 0.5 x half day - unpaid leave). Weekly offs are paid.
///  * Hourly:  rate x (hours worked + half days + paid leave days).
///  * Overtime: overtime hours x normal hourly pay x overtime multiplier.
SalaryResult calculateSalary({
  required Worker worker,
  required WorkTiming timing,
  required List<Attendance> records,
  required DateTime month,
  required bool paidLeave,
  required DateTime today,
}) {
  final y = month.year;
  final m = month.month;
  final dim = DateTime(y, m + 1, 0).day;
  final last = DateTime(y, m, dim);
  final joined = _dateOnly(worker.joinedOn);

  int startDay;
  if (joined.isAfter(last)) {
    startDay = dim + 1;
  } else if (joined.year == y && joined.month == m) {
    startDay = joined.day;
  } else {
    startDay = 1;
  }
  final eligible = dim - startDay + 1;

  final std = timing.standardHours > 0 ? timing.standardHours : 8.0;

  var p = 0;
  var h = 0;
  var l = 0;
  var a = 0;
  var ot = 0.0;
  var presentHours = 0.0;
  final seen = <String>{};

  for (final r in records) {
    seen.add(r.date);
    switch (r.status) {
      case 'P':
        p++;
        ot += r.otHours;
        final i = parseHm(r.checkIn ?? '');
        final o = parseHm(r.checkOut ?? '');
        final worked = (i == null || o == null)
            ? std
            : workedHours(inMin: i, outMin: o, breakMin: timing.breakMinutes);
        presentHours += math.max(0.0, worked - r.otHours);
      case 'H':
        h++;
      case 'L':
        l++;
      case 'A':
        a++;
    }
  }

  var unmarked = 0;
  final todayOnly = _dateOnly(today);
  for (var d = startDay; d <= dim; d++) {
    final date = DateTime(y, m, d);
    if (date.isAfter(todayOnly)) break;
    if (worker.weeklyOff.contains(date.weekday)) continue;
    if (!seen.contains(dateKey(date))) unmarked++;
  }

  double units;
  double base;
  double hourlyBase;
  switch (worker.payType) {
    case PayType.daily:
      units = p + 0.5 * h + (paidLeave ? l : 0);
      base = worker.rate * units;
      hourlyBase = worker.rate / std;
    case PayType.monthly:
      final perDay = worker.rate / dim;
      units = math.max(
        0.0,
        eligible - a - 0.5 * h - (paidLeave ? 0 : l),
      );
      base = perDay * units;
      hourlyBase = perDay / std;
    case PayType.hourly:
      units = presentHours + h * std / 2 + (paidLeave ? l * std : 0);
      base = worker.rate * units;
      hourlyBase = worker.rate;
  }

  final otPay = ot * hourlyBase * worker.otMultiplier;

  return SalaryResult(
    worker: worker,
    month: DateTime(y, m, 1),
    daysInMonth: dim,
    startDay: startDay,
    eligibleDays: eligible < 0 ? 0 : eligible,
    present: p,
    half: h,
    leave: l,
    absent: a,
    unmarked: unmarked,
    payableUnits: units,
    otHours: ot,
    basePay: _round2(base),
    otPay: _round2(otPay),
    hourlyBase: hourlyBase,
    records: records,
  );
}
