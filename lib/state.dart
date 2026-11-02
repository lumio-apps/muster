import 'package:flutter/foundation.dart';

import 'calc.dart';
import 'db.dart';
import 'models.dart';

/// Effective working hours for one worker.
class WorkTiming {
  const WorkTiming({
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.lateGrace,
  });

  final String start;
  final String end;
  final int breakMinutes;
  final int lateGrace;

  double get standardHours {
    final s = parseHm(start) ?? 480;
    final e = parseHm(end) ?? 1020;
    return workedHours(inMin: s, outMin: e, breakMin: breakMinutes);
  }

  String get label => '$start – $end';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class AppState extends ChangeNotifier {
  AppState(this.db) : day = _dateOnly(DateTime.now());

  final AppDb db;

  Map<String, String> settings = {};
  List<Worker> workers = [];
  DateTime day;
  Map<int, Attendance> attendance = {};

  Future<void> load() async {
    settings = await db.allSettings();
    workers = await db.workers();
    attendance = await db.attendanceOn(dateKey(day));
    notifyListeners();
  }

  DateTime get today => _dateOnly(DateTime.now());

  // ---- company settings ----

  bool get setupDone => settings['setup_done'] == '1';
  String get companyName => settings['company_name'] ?? '';
  String get ownerName => settings['owner_name'] ?? '';
  String get phone => settings['phone'] ?? '';
  String get address => settings['address'] ?? '';
  String get currency => settings['currency'] ?? '₹';
  String get shiftStart => settings['shift_start'] ?? '08:00';
  String get shiftEnd => settings['shift_end'] ?? '17:00';
  int get breakMinutes => int.tryParse(settings['break_minutes'] ?? '') ?? 60;
  int get lateGrace => int.tryParse(settings['late_grace'] ?? '') ?? 10;
  double get otMultiplier =>
      double.tryParse(settings['ot_multiplier'] ?? '') ?? 1.5;

  Set<int> get weeklyOff => (settings['weekly_off'] ?? '7')
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toSet();

  WorkTiming get companyTiming => WorkTiming(
        start: shiftStart,
        end: shiftEnd,
        breakMinutes: breakMinutes,
        lateGrace: lateGrace,
      );

  WorkTiming timingFor(Worker w) => w.useCompanyTiming
      ? companyTiming
      : WorkTiming(
          start: w.shiftStart,
          end: w.shiftEnd,
          breakMinutes: w.breakMinutes,
          lateGrace: w.lateGrace,
        );

  Future<void> saveSettings(Map<String, String> values) async {
    for (final e in values.entries) {
      await db.setSetting(e.key, e.value);
    }
    settings = {...settings, ...values};
    notifyListeners();
  }

  Future<void> completeSetup(Map<String, String> values) {
    return saveSettings({...values, 'setup_done': '1'});
  }

  // ---- workers ----

  Future<void> addWorker(Worker w) async {
    w.id = await db.insertWorker(w);
    workers = await db.workers();
    notifyListeners();
  }

  Future<void> updateWorker(Worker w) async {
    await db.updateWorker(w);
    workers = await db.workers();
    notifyListeners();
  }

  // ---- attendance ----

  Future<void> setDay(DateTime d) async {
    day = _dateOnly(d);
    attendance = await db.attendanceOn(dateKey(day));
    notifyListeners();
  }

  /// Active workers who had already joined on the selected day.
  List<Worker> workersForDay() => workers
      .where((w) => w.active && !_dateOnly(w.joinedOn).isAfter(day))
      .toList();

  Future<void> _put(Worker w, String status) async {
    final t = timingFor(w);
    final isPresent = status == 'P';
    final a = Attendance(
      workerId: w.id!,
      date: dateKey(day),
      status: status,
      checkIn: isPresent ? t.start : null,
      checkOut: isPresent ? t.end : null,
    );
    await db.saveAttendance(a);
    attendance = {...attendance, w.id!: a};
  }

  Future<void> mark(Worker w, String status) async {
    await _put(w, status);
    notifyListeners();
  }

  Future<void> clearMark(Worker w) async {
    await db.deleteAttendance(w.id!, dateKey(day));
    attendance = {...attendance}..remove(w.id);
    notifyListeners();
  }

  Future<void> markAllPresent() async {
    for (final w in workersForDay()) {
      if (attendance[w.id] == null) {
        await _put(w, 'P');
      }
    }
    notifyListeners();
  }

  /// Saves custom check-in / check-out times and recalculates overtime.
  Future<void> setTimes(Worker w, String checkIn, String checkOut) async {
    final t = timingFor(w);
    final inM = parseHm(checkIn);
    final outM = parseHm(checkOut);
    if (inM == null || outM == null) return;
    final worked =
        workedHours(inMin: inM, outMin: outM, breakMin: t.breakMinutes);
    final ot = overtimeHours(worked: worked, standard: t.standardHours);
    final a = Attendance(
      workerId: w.id!,
      date: dateKey(day),
      status: 'P',
      checkIn: checkIn,
      checkOut: checkOut,
      otHours: ot,
    );
    await db.saveAttendance(a);
    attendance = {...attendance, w.id!: a};
    notifyListeners();
  }
}
