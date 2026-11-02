import 'package:flutter_test/flutter_test.dart';
import 'package:muster/calc.dart';
import 'package:muster/currencies.dart';
import 'package:muster/models.dart';
import 'package:muster/ui/common.dart';

Advance adv(int worker, double amount) =>
    Advance(workerId: worker, date: '2026-04-02', amount: amount);

SalaryRun run(int worker, String month, double deducted) => SalaryRun(
      workerId: worker,
      month: month,
      gross: 10000,
      deducted: deducted,
      paidOn: '2026-05-01',
    );

void main() {
  group('currencies', () {
    test('Armenian dram is available and listed first', () {
      expect(kCurrencies.first.code, 'AMD');
      expect(currencyByCode('AMD').symbol, '֏');
    });

    test('codes are unique', () {
      final codes = kCurrencies.map((c) => c.code).toSet();
      expect(codes.length, kCurrencies.length);
    });

    test('unknown code falls back to the default', () {
      expect(currencyByCode('XXX').code, kDefaultCurrencyCode);
    });

    test('symbol prefix adds a space only for letters', () {
      expect(symbolPrefix('₹'), '₹');
      expect(symbolPrefix('AED'), 'AED ');
      expect(fmtMoney(1500, '֏'), '֏1,500');
      expect(fmtMoney(1500, 'AED'), 'AED 1,500');
      expect(fmtMoney(99.5, r'$'), r'$99.50');
    });
  });

  group('advances', () {
    test('balance is given minus deducted', () {
      final advances = [adv(1, 5000), adv(1, 2000), adv(2, 900)];
      final runs = [run(1, '2026-04', 3000)];
      expect(outstandingAdvance(advances, runs, 1), 4000);
      expect(outstandingAdvance(advances, runs, 2), 900);
      expect(outstandingAdvance(advances, runs, 3), 0);
    });

    test('balance never goes below zero', () {
      final advances = [adv(1, 1000)];
      final runs = [run(1, '2026-04', 1000)];
      expect(outstandingAdvance(advances, runs, 1), 0);
    });

    test('undoing a payment restores the balance', () {
      final advances = [adv(1, 1000)];
      expect(outstandingAdvance(advances, [run(1, '2026-04', 400)], 1), 600);
      expect(outstandingAdvance(advances, const <SalaryRun>[], 1), 1000);
    });
  });

  test('monthKey pads the month', () {
    expect(monthKey(DateTime(2026, 4, 9)), '2026-04');
    expect(monthKey(DateTime(2026, 12, 1)), '2026-12');
  });
}
