import 'package:flutter_test/flutter_test.dart';
import 'package:muster/calc.dart';
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
final may = DateTime(2026, 5, 1);

Attendance present(int day, {String i = '08:00', String o = '17:00'}) {
  return Attendance(
    workerId: 1,
    date: '2026-04-${day.toString().padLeft(2, '0')}',
    status: 'P',
    checkIn: i,
    checkOut: o,
  );
}

Worker worker(PayType type, double rate) {
  return Worker(
    id: 1,
    name: 'Test Worker',
    payType: type,
    rate: rate,
    joinedOn: DateTime(2026, 1, 1),
  );
}

SalaryResult calc(
  Worker w,
  List<Attendance> records, {
  Set<String> holidays = const <String>{},
  bool holidayPaid = true,
  double lateFineEach = 0,
  double bonus = 0,
  double fine = 0,
}) {
  return calculateSalary(
    worker: w,
    timing: timing,
    records: records,
    month: april,
    paidLeave: true,
    today: may,
    holidays: holidays,
    holidayPaid: holidayPaid,
    lateFineEach: lateFineEach,
    bonus: bonus,
    fine: fine,
  );
}

void main() {
  group('late arrival', () {
    test('after start plus grace is late', () {
      bool isLate(String t) =>
          isLateArrival(checkIn: t, start: '08:00', graceMinutes: 10);
      expect(isLate('08:00'), isFalse);
      expect(isLate('08:10'), isFalse);
      expect(isLate('08:11'), isTrue);
      expect(isLate('09:30'), isTrue);
    });

    test('missing or invalid time is never late', () {
      expect(
        isLateArrival(checkIn: null, start: '08:00', graceMinutes: 10),
        isFalse,
      );
      expect(
        isLateArrival(checkIn: 'abc', start: '08:00', graceMinutes: 10),
        isFalse,
      );
    });

    test('late days are counted and fined', () {
      final r = calc(
        worker(PayType.daily, 600),
        [
          present(1, i: '08:30'),
          present(2, i: '08:10'),
          present(3, i: '08:11'),
          present(4),
        ],
        lateFineEach: 50,
      );
      expect(r.lateCount, 2);
      expect(r.lateFine, 100);
      expect(r.basePay, 2400);
      expect(r.gross, 2300);
    });
  });

  group('company holidays', () {
    final days = [for (var d = 1; d <= 10; d++) present(d)];
    // 3 Apr: worker was present. 12 Apr: Sunday (weekly off). 13 Apr: counts.
    const holidays = {'2026-04-03', '2026-04-12', '2026-04-13'};

    test('daily worker gets one paid day for a free holiday', () {
      final r = calc(worker(PayType.daily, 600), days, holidays: holidays);
      expect(r.holidayDays, 1);
      expect(r.payableUnits, 11);
      expect(r.basePay, 6600);
    });

    test('holidays can be switched to unpaid', () {
      final r = calc(
        worker(PayType.daily, 600),
        days,
        holidays: holidays,
        holidayPaid: false,
      );
      expect(r.holidayDays, 0);
      expect(r.payableUnits, 10);
    });

    test('monthly worker is not changed by holidays', () {
      final w = worker(PayType.monthly, 30000);
      final a = calc(w, days);
      final b = calc(w, days, holidays: holidays);
      expect(b.holidayDays, 0);
      expect(b.basePay, a.basePay);
    });

    test('hourly worker gets a standard day of hours', () {
      final r = calc(
        worker(PayType.hourly, 100),
        [present(1), present(2)],
        holidays: {'2026-04-13'},
      );
      expect(r.payableUnits, 24);
      expect(r.basePay, 2400);
    });

    test('a holiday is not counted as an unmarked day', () {
      final w = worker(PayType.daily, 600);
      final a = calc(w, days);
      final b = calc(w, days, holidays: holidays);
      expect(b.unmarked, a.unmarked - 1);
    });
  });

  group('bonus and fine', () {
    final four = [for (var d = 1; d <= 4; d++) present(d)];

    test('bonus is added and fines are taken', () {
      final r = calc(
        worker(PayType.daily, 600),
        [present(1, i: '08:30'), present(2, i: '08:40'), present(3), present(4)],
        lateFineEach: 50,
        bonus: 500,
        fine: 200,
      );
      expect(r.basePay, 2400);
      expect(r.gross, 2600);
    });

    test('salary never goes below zero', () {
      final r = calc(worker(PayType.daily, 100), [present(1)], fine: 1000);
      expect(r.gross, 0);
    });

    test('no bonus or fine changes nothing', () {
      final r = calc(worker(PayType.daily, 600), four);
      expect(r.gross, r.basePay + r.otPay);
    });
  });

  group('saved records', () {
    test('adjustment keeps kind and amount', () {
      final a = Adjustment(
        workerId: 3,
        date: '2026-04-20',
        isBonus: false,
        amount: 150.5,
        note: 'Damaged tool',
      );
      final back = Adjustment.fromMap({...a.toMap(), 'id': 7});
      expect(back.id, 7);
      expect(back.isBonus, isFalse);
      expect(back.amount, 150.5);
      expect(back.note, 'Damaged tool');
    });

    test('holiday keeps date and name', () {
      const h = Holiday(date: '2026-01-01', name: 'New Year');
      final back = Holiday.fromMap(h.toMap());
      expect(back.date, '2026-01-01');
      expect(back.name, 'New Year');
    });
  });
}
