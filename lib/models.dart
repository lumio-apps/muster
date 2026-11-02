import 'calc.dart';

enum PayType { daily, monthly, hourly }

extension PayTypeInfo on PayType {
  String get label => switch (this) {
        PayType.daily => 'Daily wage',
        PayType.monthly => 'Monthly salary',
        PayType.hourly => 'Hourly',
      };

  String get rateLabel => switch (this) {
        PayType.daily => 'Rate per day',
        PayType.monthly => 'Monthly salary',
        PayType.hourly => 'Rate per hour',
      };

  String get suffix => switch (this) {
        PayType.daily => '/ day',
        PayType.monthly => '/ month',
        PayType.hourly => '/ hour',
      };
}

PayType payTypeFromName(String s) =>
    PayType.values.firstWhere((e) => e.name == s, orElse: () => PayType.daily);

String _weeklyOffToText(Set<int> days) {
  final list = days.toList()..sort();
  return list.join(',');
}

Set<int> _weeklyOffFromText(String s) => s
    .split(',')
    .where((e) => e.trim().isNotEmpty)
    .map((e) => int.parse(e.trim()))
    .toSet();

class Worker {
  Worker({
    this.id,
    required this.name,
    this.role = '',
    this.phone = '',
    DateTime? joinedOn,
    this.payType = PayType.daily,
    this.rate = 0,
    this.otMultiplier = 1.5,
    this.useCompanyTiming = true,
    this.shiftStart = '08:00',
    this.shiftEnd = '17:00',
    this.breakMinutes = 60,
    this.lateGrace = 10,
    Set<int>? weeklyOff,
    this.photoPath,
    this.active = true,
  })  : joinedOn = joinedOn ?? DateTime.now(),
        weeklyOff = weeklyOff ?? {7};

  int? id;
  String name;
  String role;
  String phone;
  DateTime joinedOn;
  PayType payType;
  double rate;
  double otMultiplier;
  bool useCompanyTiming;
  String shiftStart;
  String shiftEnd;
  int breakMinutes;
  int lateGrace;
  Set<int> weeklyOff;
  String? photoPath;
  bool active;

  String get code => 'W-${(id ?? 0).toString().padLeft(3, '0')}';

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'role': role,
        'phone': phone,
        'joined_on': dateKey(joinedOn),
        'pay_type': payType.name,
        'rate': rate,
        'ot_multiplier': otMultiplier,
        'use_company_timing': useCompanyTiming ? 1 : 0,
        'shift_start': shiftStart,
        'shift_end': shiftEnd,
        'break_minutes': breakMinutes,
        'late_grace': lateGrace,
        'weekly_off': _weeklyOffToText(weeklyOff),
        'photo_path': photoPath,
        'active': active ? 1 : 0,
      };

  factory Worker.fromMap(Map<String, Object?> m) => Worker(
        id: m['id'] as int,
        name: m['name'] as String,
        role: (m['role'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        joinedOn: parseDateKey(m['joined_on'] as String),
        payType: payTypeFromName(m['pay_type'] as String),
        rate: (m['rate'] as num).toDouble(),
        otMultiplier: (m['ot_multiplier'] as num).toDouble(),
        useCompanyTiming: (m['use_company_timing'] as int) == 1,
        shiftStart: m['shift_start'] as String,
        shiftEnd: m['shift_end'] as String,
        breakMinutes: m['break_minutes'] as int,
        lateGrace: m['late_grace'] as int,
        weeklyOff: _weeklyOffFromText((m['weekly_off'] as String?) ?? '7'),
        photoPath: m['photo_path'] as String?,
        active: (m['active'] as int) == 1,
      );
}

/// Money given to a worker in advance.
class Advance {
  Advance({
    this.id,
    required this.workerId,
    required this.date,
    required this.amount,
    this.note = '',
  });

  int? id;
  final int workerId;
  final String date;
  final double amount;
  final String note;

  Map<String, Object?> toMap() => {
        'worker_id': workerId,
        'date': date,
        'amount': amount,
        'note': note,
      };

  factory Advance.fromMap(Map<String, Object?> m) => Advance(
        id: m['id'] as int,
        workerId: m['worker_id'] as int,
        date: m['date'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: (m['note'] as String?) ?? '',
      );
}

/// A salary that was marked as paid for one worker and one month.
class SalaryRun {
  const SalaryRun({
    required this.workerId,
    required this.month,
    required this.gross,
    required this.deducted,
    required this.paidOn,
  });

  final int workerId;

  /// "yyyy-MM"
  final String month;
  final double gross;

  /// Advance recovered from this salary.
  final double deducted;
  final String paidOn;

  double get net => gross - deducted;

  Map<String, Object?> toMap() => {
        'worker_id': workerId,
        'month': month,
        'gross': gross,
        'advance_deducted': deducted,
        'paid_on': paidOn,
      };

  factory SalaryRun.fromMap(Map<String, Object?> m) => SalaryRun(
        workerId: m['worker_id'] as int,
        month: m['month'] as String,
        gross: (m['gross'] as num).toDouble(),
        deducted: (m['advance_deducted'] as num).toDouble(),
        paidOn: m['paid_on'] as String,
      );
}

/// Advance still to be recovered from a worker:
/// everything given minus everything already deducted from salaries.
double outstandingAdvance(
  Iterable<Advance> advances,
  Iterable<SalaryRun> runs,
  int workerId,
) {
  var given = 0.0;
  for (final a in advances) {
    if (a.workerId == workerId) given += a.amount;
  }
  var back = 0.0;
  for (final r in runs) {
    if (r.workerId == workerId) back += r.deducted;
  }
  final bal = given - back;
  if (bal < 0.005) return 0.0;
  return (bal * 100).roundToDouble() / 100;
}

/// One worker's attendance for one day. Status: P, A, H or L.
class Attendance {
  Attendance({
    required this.workerId,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.otHours = 0,
  });

  final int workerId;
  final String date;
  final String status;
  String? checkIn;
  String? checkOut;
  double otHours;

  Map<String, Object?> toMap() => {
        'worker_id': workerId,
        'date': date,
        'status': status,
        'check_in': checkIn,
        'check_out': checkOut,
        'ot_hours': otHours,
      };

  factory Attendance.fromMap(Map<String, Object?> m) => Attendance(
        workerId: m['worker_id'] as int,
        date: m['date'] as String,
        status: m['status'] as String,
        checkIn: m['check_in'] as String?,
        checkOut: m['check_out'] as String?,
        otHours: (m['ot_hours'] as num?)?.toDouble() ?? 0,
      );
}

/// A company holiday on one date.
class Holiday {
  const Holiday({required this.date, required this.name});

  /// "yyyy-MM-dd"
  final String date;
  final String name;

  Map<String, Object?> toMap() => {'date': date, 'name': name};

  factory Holiday.fromMap(Map<String, Object?> m) => Holiday(
        date: m['date'] as String,
        name: (m['name'] as String?) ?? '',
      );
}

/// A bonus (added to salary) or a fine (taken from salary) for one worker.
class Adjustment {
  Adjustment({
    this.id,
    required this.workerId,
    required this.date,
    required this.isBonus,
    required this.amount,
    this.note = '',
  });

  int? id;
  final int workerId;

  /// "yyyy-MM-dd". The salary month is taken from this date.
  final String date;
  final bool isBonus;
  final double amount;
  final String note;

  Map<String, Object?> toMap() => {
        'worker_id': workerId,
        'date': date,
        'kind': isBonus ? 'bonus' : 'fine',
        'amount': amount,
        'note': note,
      };

  factory Adjustment.fromMap(Map<String, Object?> m) => Adjustment(
        id: m['id'] as int,
        workerId: m['worker_id'] as int,
        date: m['date'] as String,
        isBonus: m['kind'] == 'bonus',
        amount: (m['amount'] as num).toDouble(),
        note: (m['note'] as String?) ?? '',
      );
}
