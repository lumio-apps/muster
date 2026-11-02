import 'package:flutter/foundation.dart';

import 'calc.dart';
import 'currencies.dart';
import 'db.dart';
import 'models.dart';
import 'security.dart';

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
    advances = await db.advances();
    runs = await db.salaryRuns();
    locked = pinEnabled;
    notifyListeners();
  }

  // ---- security (PIN lock) and backup ----

  /// True while the lock screen is showing.
  bool locked = false;

  bool get pinEnabled => (settings['pin_hash'] ?? '').isNotEmpty;

  /// Minutes of inactivity before locking. 0 means never.
  int get autoLockMinutes =>
      int.tryParse(settings['auto_lock_minutes'] ?? '') ?? 15;

  /// Date key (yyyy-MM-dd) of the last backup, if any.
  String? get lastBackup {
    final v = settings['last_backup'];
    return (v == null || v.isEmpty) ? null : v;
  }

  void lock() {
    if (!pinEnabled || locked) return;
    locked = true;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final salt = settings['pin_salt'] ?? '';
    final hash = settings['pin_hash'] ?? '';
    if (salt.isEmpty || hash.isEmpty) return false;
    return await hashSecret(pin, salt) == hash;
  }

  Future<bool> tryUnlock(String pin) async {
    if (!await verifyPin(pin)) return false;
    locked = false;
    notifyListeners();
    return true;
  }

  /// Sets a new PIN and returns the one-time recovery code.
  Future<String> setPin(String pin) async {
    final pinSalt = randomSalt();
    final recoverySalt = randomSalt();
    final code = generateRecoveryCode();
    final pinHash = await hashSecret(pin, pinSalt);
    final recoveryHash =
        await hashSecret(normalizeRecoveryCode(code), recoverySalt);
    await saveSettings({
      'pin_salt': pinSalt,
      'pin_hash': pinHash,
      'recovery_salt': recoverySalt,
      'recovery_hash': recoveryHash,
    });
    return code;
  }

  Future<void> removePin() async {
    await saveSettings({
      'pin_salt': '',
      'pin_hash': '',
      'recovery_salt': '',
      'recovery_hash': '',
    });
    locked = false;
    notifyListeners();
  }

  /// Forgot PIN: a correct recovery code turns the PIN lock off.
  Future<bool> resetWithRecovery(String code) async {
    final salt = settings['recovery_salt'] ?? '';
    final hash = settings['recovery_hash'] ?? '';
    if (salt.isEmpty || hash.isEmpty) return false;
    final given = await hashSecret(normalizeRecoveryCode(code), salt);
    if (given != hash) return false;
    await removePin();
    return true;
  }

  Future<void> setAutoLock(int minutes) =>
      saveSettings({'auto_lock_minutes': '$minutes'});

  Future<void> markBackupDone() =>
      saveSettings({'last_backup': dateKey(today)});

  DateTime get today => _dateOnly(DateTime.now());

  // ---- company settings ----

  bool get setupDone => settings['setup_done'] == '1';
  String get companyName => settings['company_name'] ?? '';
  String get ownerName => settings['owner_name'] ?? '';
  String get phone => settings['phone'] ?? '';
  String get address => settings['address'] ?? '';
  /// ISO code of the chosen currency, for example "AMD".
  String get currencyCode {
    final code = settings['currency_code'];
    if (code != null && isKnownCurrency(code)) return code;
    // Version 1.0 / 1.1 stored only a symbol.
    final legacy = settings['currency'];
    if (legacy != null) {
      for (final c in kCurrencies) {
        if (c.symbol == legacy) return c.code;
      }
    }
    return kDefaultCurrencyCode;
  }

  /// Symbol shown before amounts, for example "֏".
  String get currency {
    if (!settings.containsKey('currency_code')) {
      final legacy = settings['currency'];
      if (legacy != null && legacy.isNotEmpty) return legacy;
    }
    return currencyByCode(currencyCode).symbol;
  }
  String get shiftStart => settings['shift_start'] ?? '08:00';
  String get shiftEnd => settings['shift_end'] ?? '17:00';
  int get breakMinutes => int.tryParse(settings['break_minutes'] ?? '') ?? 60;
  int get lateGrace => int.tryParse(settings['late_grace'] ?? '') ?? 10;
  double get otMultiplier =>
      double.tryParse(settings['ot_multiplier'] ?? '') ?? 1.5;

  /// Whether leave (L) days are paid.
  bool get paidLeave => (settings['paid_leave'] ?? '1') == '1';

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

  // ---- advances and paid salaries ----

  List<Advance> advances = [];
  List<SalaryRun> runs = [];

  double balanceOf(int workerId) => outstandingAdvance(advances, runs, workerId);

  SalaryRun? runFor(int workerId, String month) {
    for (final r in runs) {
      if (r.workerId == workerId && r.month == month) return r;
    }
    return null;
  }

  Future<void> _reloadMoney() async {
    advances = await db.advances();
    runs = await db.salaryRuns();
    notifyListeners();
  }

  Future<void> giveAdvance(
    Worker w,
    double amount,
    DateTime date,
    String note,
  ) async {
    await db.insertAdvance(
      Advance(
        workerId: w.id!,
        date: dateKey(date),
        amount: amount,
        note: note,
      ),
    );
    await _reloadMoney();
  }

  Future<void> removeAdvance(Advance a) async {
    final id = a.id;
    if (id == null) return;
    await db.deleteAdvance(id);
    await _reloadMoney();
  }

  /// Marks a month's salary as paid and records how much advance was
  /// recovered from it.
  Future<void> markPaid(
    int workerId,
    String month,
    double gross,
    double deducted,
  ) async {
    await db.saveSalaryRun(
      SalaryRun(
        workerId: workerId,
        month: month,
        gross: gross,
        deducted: deducted,
        paidOn: dateKey(today),
      ),
    );
    await _reloadMoney();
  }

  Future<void> undoPaid(int workerId, String month) async {
    await db.deleteSalaryRun(workerId, month);
    await _reloadMoney();
  }

  // ---- salary ----

  DateTime salaryMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Attendance> monthRecords = [];

  Future<void> setSalaryMonth(DateTime m) async {
    salaryMonth = DateTime(m.year, m.month, 1);
    final last = DateTime(m.year, m.month + 1, 0);
    monthRecords = await db.attendanceBetween(
      dateKey(salaryMonth),
      dateKey(last),
    );
    notifyListeners();
  }

  Future<void> loadSalaryMonth() => setSalaryMonth(salaryMonth);

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
