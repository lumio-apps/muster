import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../models.dart';
import '../salary_lines.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// First screen: today at a glance, this month's money, and what needs care.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.state, required this.onGo});

  final AppState state;

  /// Opens another page of the app by its sidebar index.
  final void Function(int index) onGo;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Today's records come from the current month's records.
    final now = DateTime.now();
    widget.state.setSalaryMonth(DateTime(now.year, now.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final today = s.today;
        final todayKey = dateKey(today);
        final isCurrentMonth = s.salaryMonth.year == today.year &&
            s.salaryMonth.month == today.month;

        final records = <int, Attendance>{};
        if (isCurrentMonth) {
          for (final r in s.monthRecords) {
            if (r.date == todayKey) records[r.workerId] = r;
          }
        }
        final active = s.workers
            .where((w) =>
                w.active &&
                !DateTime(w.joinedOn.year, w.joinedOn.month, w.joinedOn.day)
                    .isAfter(today))
            .toList();

        final names = <String, List<String>>{
          'P': [],
          'A': [],
          'H': [],
          'L': [],
          'late': [],
          'none': [],
        };
        for (final w in active) {
          final r = records[w.id];
          if (r == null) {
            names['none']!.add(w.name);
            continue;
          }
          names[r.status]?.add(w.name);
          final t = s.timingFor(w);
          if (r.status == 'P' &&
              isLateArrival(
                checkIn: r.checkIn,
                start: t.start,
                graceMinutes: t.lateGrace,
              )) {
            names['late']!.add(w.name);
          }
        }

        final lines = isCurrentMonth ? buildSalaryLines(s) : <SalaryLine>[];
        var net = 0.0;
        var gross = 0.0;
        var paid = 0;
        for (final l in lines) {
          net += l.net;
          gross += l.gross;
          if (l.paid) paid++;
        }
        var advance = 0.0;
        for (final w in s.workers) {
          if (w.active) advance += s.balanceOf(w.id!);
        }

        final holiday = s.holidayOn(today);
        final off = s.weeklyOff.contains(today.weekday);
        final noWorkers = s.workers.where((w) => w.active).isEmpty;

        final last = s.lastBackup;
        final backupAge = last == null
            ? null
            : today.difference(parseDateKey(last)).inDays;

        final todos = <Widget>[
          if (noWorkers)
            _Todo(
              icon: Icons.person_add_alt_1,
              text: 'Add your first worker to begin.',
              action: 'Add workers',
              onTap: () => widget.onGo(3),
            ),
          if (!noWorkers &&
              names['none']!.isNotEmpty &&
              holiday == null &&
              !off)
            _Todo(
              icon: Icons.fact_check_outlined,
              text: 'Attendance is not marked for '
                  '${names['none']!.length} worker(s) today.',
              action: 'Mark now',
              onTap: () => widget.onGo(1),
            ),
          if (lines.isNotEmpty && paid < lines.length)
            _Todo(
              icon: Icons.payments_outlined,
              text: '${lines.length - paid} salary(ies) not paid yet this '
                  'month.',
              action: 'Open salary',
              onTap: () => widget.onGo(4),
            ),
          if (!noWorkers && (backupAge == null || backupAge > 30))
            _Todo(
              icon: Icons.save_alt,
              text: backupAge == null
                  ? 'No backup has been made yet.'
                  : 'Last backup was $backupAge days ago.',
              action: 'Back up',
              onTap: () => widget.onGo(7),
            ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Dashboard', style: kTitle),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(today),
                    style: kSubtle,
                  ),
                ],
              ),
              if (holiday != null || off) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Pill(
                      text: holiday != null ? 'Company holiday' : 'Weekly off',
                      color: holiday != null ? kBlue : kMuted,
                      background: holiday != null ? kBlueSoft : kGreySoft,
                    ),
                    if (holiday != null && holiday.name.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(holiday.name, style: kSubtle),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Today',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Card('Workers', '${active.length}', kNavy, kNavySoft),
                  _Card('Present', '${names['P']!.length}', kGreen, kGreenSoft),
                  _Card('Absent', '${names['A']!.length}', kRed, kRedSoft),
                  _Card(
                    'Half day',
                    '${names['H']!.length}',
                    kOrange,
                    kOrangeSoft,
                  ),
                  _Card('Leave', '${names['L']!.length}', kBlue, kBlueSoft),
                  _Card(
                    'Not marked',
                    '${names['none']!.length}',
                    kMuted,
                    kGreySoft,
                  ),
                  _Card(
                    'Late',
                    '${names['late']!.length}',
                    kRed,
                    kRedSoft,
                  ),
                ],
              ),
              if (names['A']!.isNotEmpty ||
                  names['L']!.isNotEmpty ||
                  names['H']!.isNotEmpty ||
                  names['late']!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Names('Absent', names['A']!, kRed),
                      _Names('Half day', names['H']!, kOrange),
                      _Names('On leave', names['L']!, kBlue),
                      _Names('Late', names['late']!, kRed),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                DateFormat('MMMM yyyy').format(today),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Card(
                    'Net payable',
                    fmtMoney(net, s.currency),
                    kNavy,
                    kNavySoft,
                  ),
                  _Card(
                    'Gross salary',
                    fmtMoney(gross, s.currency),
                    kGreen,
                    kGreenSoft,
                  ),
                  _Card(
                    'Salaries paid',
                    '$paid of ${lines.length}',
                    kBlue,
                    kBlueSoft,
                  ),
                  _Card(
                    'Advance pending',
                    fmtMoney(advance, s.currency),
                    kOrange,
                    kOrangeSoft,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Needs attention',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (todos.isEmpty)
                const Panel(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: kGreen),
                      SizedBox(width: 10),
                      Text('All good. Nothing needs your attention.'),
                    ],
                  ),
                )
              else
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < todos.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: kBorder),
                        todos[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value, this.color, this.background);

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Names extends StatelessWidget {
  const _Names(this.label, this.names, this.color);

  final String label;
  final List<String> names;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(names.join(', '))),
        ],
      ),
    );
  }
}

class _Todo extends StatelessWidget {
  const _Todo({
    required this.icon,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kOrange),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
