import 'package:flutter_test/flutter_test.dart';
import 'package:muster/calc.dart';
import 'package:muster/models.dart';
import 'package:muster/updater.dart';

void main() {
  group('time helpers', () {
    test('parseHm accepts valid and rejects invalid', () {
      expect(parseHm('08:30'), 510);
      expect(parseHm('8:05'), 485);
      expect(parseHm('24:00'), isNull);
      expect(parseHm('abc'), isNull);
    });

    test('fmtHm pads', () {
      expect(fmtHm(485), '08:05');
    });

    test('workedHours subtracts break', () {
      final h = workedHours(inMin: 480, outMin: 1020, breakMin: 60);
      expect(h, 8.0);
    });

    test('workedHours handles night shift', () {
      final h = workedHours(inMin: 22 * 60, outMin: 6 * 60, breakMin: 0);
      expect(h, 8.0);
    });

    test('overtime rounds down to half hours', () {
      expect(overtimeHours(worked: 9.7, standard: 8), 1.5);
      expect(overtimeHours(worked: 8.4, standard: 8), 0);
      expect(overtimeHours(worked: 10, standard: 8), 2);
    });

    test('dateKey round trip', () {
      final d = DateTime(2026, 3, 5);
      expect(dateKey(d), '2026-03-05');
      expect(parseDateKey('2026-03-05'), d);
    });
  });

  group('Worker model', () {
    test('map round trip keeps data', () {
      final w = Worker(
        name: 'Ramesh Kumar',
        role: 'Mason',
        payType: PayType.monthly,
        rate: 18000,
        weeklyOff: {6, 7},
      );
      final map = Map<String, Object?>.from(w.toMap())..['id'] = 3;
      final back = Worker.fromMap(map);
      expect(back.id, 3);
      expect(back.code, 'W-003');
      expect(back.name, 'Ramesh Kumar');
      expect(back.payType, PayType.monthly);
      expect(back.weeklyOff, {6, 7});
      expect(back.initials, 'RK');
    });
  });

  group('Updater', () {
    test('version comparison', () {
      expect(Updater.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(Updater.isNewer('v1.1.0', '1.0.9'), isTrue);
      expect(Updater.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(Updater.isNewer('0.9.0', '1.0.0'), isFalse);
    });
  });
}
