import 'package:flutter_test/flutter_test.dart';
import 'package:muster/models.dart';
import 'package:muster/salary.dart';
import 'package:muster/state.dart';

const timing = WorkTiming(
  start: '08:00',
  end: '17:00',
  breakMinutes: 60,
  lateGrace: 10,
);

final april = DateTime(2026, 4, 1);
final afterApril = DateTime(2026, 5, 1);

Attendance rec(
  int day,
  String status, {
  String? i,
  String? o,
  double ot = 0,
}) {
  return Attendance(
    workerId: 1,
    date: '2026-04-${day.toString().padLeft(2, '0')}',
    status: status,
    checkIn: i,
    checkOut: o,
    otHours: ot,
  );
}

Worker worker(PayType type, double rate, {DateTime? joined}) {
  return Worker(
    id: 1,
    name: 'Test Worker',
    payType: type,
    rate: rate,
    joinedOn: joined ?? DateTime(2026, 1, 1),
  );
}

void main() {
  test('daily wage: present, half, paid leave and overtime', () {
    final records = <Attendance>[
      for (var d = 1; d <= 20; d++)
        rec(d, 'P', i: '08:00', o: '17:00', ot: d <= 3 ? 1.0 : 0),
      rec(21, 'H'),
      rec(22, 'H'),
      rec(23, 'L'),
      rec(24, 'A'),
    ];
    final r = calculateSalary(
      worker: worker(PayType.daily, 600),
      timing: timing,
      records: records,
      month: april,
      paidLeave: true,
      today: afterApril,
    );
    expect(r.present, 20);
    expect(r.half, 2);
    expect(r.leave, 1);
    expect(r.absent, 1);
    expect(r.payableUnits, 22);
    expect(r.basePay, 13200);
    expect(r.otHours, 3);
    expect(r.otPay, closeTo(337.5, 0.001));
    expect(r.gross, closeTo(13537.5, 0.001));
  });

  test('daily wage with unpaid leave', () {
    final r = calculateSalary(
      worker: worker(PayType.daily, 600),
      timing: timing,
      records: [
        for (var d = 1; d <= 20; d++) rec(d, 'P', i: '08:00', o: '17:00'),
        rec(21, 'H'),
        rec(22, 'H'),
        rec(23, 'L'),
      ],
      month: april,
      paidLeave: false,
      today: afterApril,
    );
    expect(r.payableUnits, 21);
    expect(r.basePay, 12600);
  });

  test('monthly salary deducts absent and half days', () {
    final r = calculateSalary(
      worker: worker(PayType.monthly, 30000),
      timing: timing,
      records: [rec(1, 'A'), rec(2, 'A'), rec(3, 'H')],
      month: april,
      paidLeave: true,
      today: afterApril,
    );
    expect(r.daysInMonth, 30);
    expect(r.payableUnits, 27.5);
    expect(r.basePay, 27500);
  });

  test('monthly salary is prorated from the joining date', () {
    final r = calculateSalary(
      worker: worker(PayType.monthly, 30000, joined: DateTime(2026, 4, 21)),
      timing: timing,
      records: const <Attendance>[],
      month: april,
      paidLeave: true,
      today: afterApril,
    );
    expect(r.eligibleDays, 10);
    expect(r.basePay, 10000);
  });

  test('worker who joins after the month gets nothing', () {
    final r = calculateSalary(
      worker: worker(PayType.monthly, 30000, joined: DateTime(2026, 5, 10)),
      timing: timing,
      records: const <Attendance>[],
      month: april,
      paidLeave: true,
      today: afterApril,
    );
    expect(r.eligibleDays, 0);
    expect(r.basePay, 0);
  });

  test('hourly worker is paid for hours and overtime', () {
    final r = calculateSalary(
      worker: worker(PayType.hourly, 100),
      timing: timing,
      records: [rec(1, 'P', i: '08:00', o: '19:00', ot: 2.0)],
      month: april,
      paidLeave: true,
      today: afterApril,
    );
    expect(r.payableUnits, 8);
    expect(r.basePay, 800);
    expect(r.otPay, 300);
  });

  test('unmarked working days skip weekly off and future days', () {
    final r = calculateSalary(
      worker: worker(PayType.daily, 600),
      timing: timing,
      records: [rec(1, 'P', i: '08:00', o: '17:00')],
      month: april,
      paidLeave: true,
      today: DateTime(2026, 4, 10),
    );
    // Days 1-10, minus Sunday the 5th, minus the marked 1st.
    expect(r.unmarked, 8);
  });
}
