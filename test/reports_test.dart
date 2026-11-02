import 'package:flutter_test/flutter_test.dart';
import 'package:muster/models.dart';
import 'package:muster/salary.dart';
import 'package:muster/salary_lines.dart';
import 'package:muster/state.dart';

const timing = WorkTiming(
  start: '08:00',
  end: '17:00',
  breakMinutes: 60,
  lateGrace: 10,
);

SalaryResult resultFor(Worker w) {
  return calculateSalary(
    worker: w,
    timing: timing,
    records: <Attendance>[
      for (var d = 1; d <= 10; d++)
        Attendance(
          workerId: 1,
          date: '2026-04-${d.toString().padLeft(2, '0')}',
          status: 'P',
          checkIn: '08:00',
          checkOut: '17:00',
        ),
    ],
    month: DateTime(2026, 4, 1),
    paidLeave: true,
    today: DateTime(2026, 5, 1),
  );
}

void main() {
  test('reportMoney uses the currency code and drops empty decimals', () {
    expect(reportMoney(12000, 'AMD'), 'AMD 12,000');
    expect(reportMoney(99.5, 'USD'), 'USD 99.50');
  });

  test('salary rule text for a daily worker', () {
    final w = Worker(id: 1, name: 'A', rate: 600, joinedOn: DateTime(2026, 1, 1));
    final r = resultFor(w);
    expect(salaryRuleText(r, 'AMD'), 'AMD 600 per day × 10 days');
    expect(overtimeRuleText(r, 'AMD'), startsWith('0 h ×'));
  });

  test('salary rule text for a monthly worker', () {
    final w = Worker(
      id: 1,
      name: 'B',
      payType: PayType.monthly,
      rate: 30000,
      joinedOn: DateTime(2026, 1, 1),
    );
    final r = resultFor(w);
    expect(salaryRuleText(r, 'INR'), contains('÷ 30 days'));
  });
}
