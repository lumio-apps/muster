import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'calc.dart';
import 'models.dart';
import 'salary.dart';
import 'state.dart';

/// One worker's salary for the selected month, plus payment state.
class SalaryLine {
  const SalaryLine({
    required this.result,
    required this.run,
    required this.balance,
  });

  final SalaryResult result;
  final SalaryRun? run;

  /// Advance still owed by the worker before this salary is paid.
  final double balance;

  Worker get worker => result.worker;
  bool get paid => run != null;
  double get gross => run?.gross ?? result.gross;
  double get deduct =>
      run?.deducted ?? math.max(0.0, math.min(balance, result.gross));
  double get net => gross - deduct;
}

/// Salary lines for the month in [AppState.salaryMonth].
/// Pass [only] to limit the result to some worker ids.
List<SalaryLine> buildSalaryLines(AppState s, {Set<int>? only}) {
  final key = monthKey(s.salaryMonth);
  final byWorker = <int, List<Attendance>>{};
  for (final r in s.monthRecords) {
    byWorker.putIfAbsent(r.workerId, () => <Attendance>[]).add(r);
  }
  final out = <SalaryLine>[];
  for (final w in s.workers) {
    final id = w.id!;
    if (only != null && !only.contains(id)) continue;
    final recs = byWorker[id] ?? <Attendance>[];
    final run = s.runFor(id, key);
    if (!w.active && recs.isEmpty && run == null) continue;
    final r = calculateSalary(
      worker: w,
      timing: s.timingFor(w),
      records: recs,
      month: s.salaryMonth,
      paidLeave: s.paidLeave,
      today: s.today,
    );
    if (r.eligibleDays <= 0 && recs.isEmpty && run == null) continue;
    out.add(SalaryLine(result: r, run: run, balance: s.balanceOf(id)));
  }
  return out;
}

/// Currency text for reports. Uses the ISO code (for example "AMD") because
/// it prints correctly in every PDF font.
String reportCurrency(AppState s) {
  if (!s.settings.containsKey('currency_code')) {
    final legacy = s.settings['currency'];
    if (legacy != null && legacy.isNotEmpty) return legacy;
  }
  return s.currencyCode;
}

String reportMoney(double v, String currency) {
  final f = v == v.roundToDouble()
      ? NumberFormat('#,##0')
      : NumberFormat('#,##0.00');
  return '$currency ${f.format(v)}';
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Plain-language formula for the base pay line of a salary slip.
String salaryRuleText(SalaryResult r, String currency) {
  final w = r.worker;
  final u = r.payableUnits;
  switch (w.payType) {
    case PayType.daily:
      return '${reportMoney(w.rate, currency)} per day × ${_plain(u)} days';
    case PayType.monthly:
      return '${reportMoney(w.rate, currency)} ÷ ${r.daysInMonth} days × '
          '${_plain(u)} days';
    case PayType.hourly:
      return '${reportMoney(w.rate, currency)} per hour × '
          '${u.toStringAsFixed(1)} hours';
  }
}

String overtimeRuleText(SalaryResult r, String currency) {
  final w = r.worker;
  return '${_plain(r.otHours)} h × ${reportMoney(r.hourlyBase, currency)} × '
      '${_plain(w.otMultiplier)}';
}
