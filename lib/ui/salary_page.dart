import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../models.dart';
import '../salary.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Monthly salary of every worker, with a day-by-day breakdown.
class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key, required this.state});

  final AppState state;

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  @override
  void initState() {
    super.initState();
    widget.state.loadSalaryMonth();
  }

  List<SalaryResult> _results() {
    final s = widget.state;
    final byWorker = <int, List<Attendance>>{};
    for (final r in s.monthRecords) {
      byWorker.putIfAbsent(r.workerId, () => <Attendance>[]).add(r);
    }
    final out = <SalaryResult>[];
    for (final w in s.workers) {
      final recs = byWorker[w.id] ?? <Attendance>[];
      if (!w.active && recs.isEmpty) continue;
      final r = calculateSalary(
        worker: w,
        timing: s.timingFor(w),
        records: recs,
        month: s.salaryMonth,
        paidLeave: s.paidLeave,
        today: s.today,
      );
      if (r.eligibleDays <= 0 && recs.isEmpty) continue;
      out.add(r);
    }
    return out;
  }

  void _shift(int delta) {
    final m = widget.state.salaryMonth;
    widget.state.setSalaryMonth(DateTime(m.year, m.month + delta, 1));
  }

  void _openDetail(SalaryResult r) {
    final s = widget.state;
    showDialog<void>(
      context: context,
      builder: (_) => _DetailDialog(
        result: r,
        currency: s.currency,
        today: s.today,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final now = DateTime.now();
        final atCurrent =
            !s.salaryMonth.isBefore(DateTime(now.year, now.month, 1));
        final results = _results();

        var total = 0.0;
        var otTotal = 0.0;
        var unmarked = 0;
        for (final r in results) {
          total += r.gross;
          otTotal += r.otPay;
          unmarked += r.unmarked;
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Salary', style: kTitle),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  SizedBox(
                    width: 150,
                    child: Center(
                      child: Text(
                        DateFormat('MMMM yyyy').format(s.salaryMonth),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: atCurrent ? null : () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (!atCurrent)
                    TextButton(
                      onPressed: () => s.setSalaryMonth(now),
                      child: const Text('This month'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Tile(
                    'Total salary (gross)',
                    fmtMoney(total, s.currency),
                    kNavy,
                    kNavySoft,
                  ),
                  const SizedBox(width: 10),
                  _Tile(
                    'Overtime pay',
                    fmtMoney(otTotal, s.currency),
                    kOrange,
                    kOrangeSoft,
                  ),
                  const SizedBox(width: 10),
                  _Tile('Workers', '${results.length}', kGreen, kGreenSoft),
                  if (unmarked > 0) ...[
                    const SizedBox(width: 10),
                    _Tile('Days not marked', '$unmarked', kRed, kRedSoft),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: results.isEmpty
                    ? const Panel(
                        child: Center(
                          child: Text(
                            'No workers to show for this month.',
                            style: kSubtle,
                          ),
                        ),
                      )
                    : Panel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            const _HeaderRow(),
                            const Divider(height: 1, color: kBorder),
                            Expanded(
                              child: ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (context, i) =>
                                    const Divider(height: 1, color: kBorder),
                                itemBuilder: (context, i) => _SalaryRow(
                                  result: results[i],
                                  currency: s.currency,
                                  onTap: () => _openDetail(results[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gross = base pay + overtime pay. Advances and deductions '
                'will be added in a coming update.',
                style: kSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _cell(String text, {int flex = 1, bool bold = false, Color? color}) {
  return Expanded(
    flex: flex,
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.color, this.background);

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: kMuted,
    );
    Widget h(String t, {int flex = 1}) => Expanded(
          flex: flex,
          child: Text(t, textAlign: TextAlign.right, style: style),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(flex: 4, child: Text('WORKER', style: style)),
          h('PRESENT'),
          h('HALF'),
          h('LEAVE'),
          h('ABSENT'),
          h('OT HRS'),
          h('BASE PAY', flex: 2),
          h('OT PAY', flex: 2),
          h('GROSS', flex: 2),
        ],
      ),
    );
  }
}

class _SalaryRow extends StatelessWidget {
  const _SalaryRow({
    required this.result,
    required this.currency,
    required this.onTap,
  });

  final SalaryResult result;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final w = r.worker;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  WorkerAvatar(worker: w, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                w.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (r.unmarked > 0) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: '${r.unmarked} working days not marked',
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: kOrange,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text('${w.code} · ${w.payType.label}', style: kSubtle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _cell('${r.present}'),
            _cell('${r.half}'),
            _cell('${r.leave}'),
            _cell('${r.absent}'),
            _cell(fmtNum(r.otHours)),
            _cell(fmtMoney(r.basePay, currency), flex: 2),
            _cell(fmtMoney(r.otPay, currency), flex: 2),
            _cell(fmtMoney(r.gross, currency), flex: 2, bold: true),
          ],
        ),
      ),
    );
  }
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({
    required this.result,
    required this.currency,
    required this.today,
  });

  final SalaryResult result;
  final String currency;
  final DateTime today;

  String _rule() {
    final w = result.worker;
    final units = result.payableUnits;
    switch (w.payType) {
      case PayType.daily:
        return '${fmtMoney(w.rate, currency)} per day × '
            '${fmtNum(units)} paid days';
      case PayType.monthly:
        return '${fmtMoney(w.rate, currency)} ÷ ${result.daysInMonth} days × '
            '${fmtNum(units)} paid days';
      case PayType.hourly:
        return '${fmtMoney(w.rate, currency)} per hour × ${fmtHours(units)}';
    }
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: kSubtle)),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(int day, Map<String, Attendance> byDate) {
    final r = result;
    final date = DateTime(r.month.year, r.month.month, day);
    final rec = byDate[dateKey(date)];

    Widget tag;
    var detail = '';
    if (rec != null) {
      tag = Pill(
        text: statusName(rec.status),
        color: statusColor(rec.status),
        background: statusSoft(rec.status),
      );
      if (rec.status == 'P') {
        detail = '${rec.checkIn ?? '--'} – ${rec.checkOut ?? '--'}';
        if (rec.otHours > 0) detail = '$detail · OT ${fmtNum(rec.otHours)} h';
      }
    } else if (r.worker.weeklyOff.contains(date.weekday)) {
      tag = const Pill(text: 'Weekly off', color: kMuted, background: kGreySoft);
    } else if (date.isAfter(today)) {
      tag = const SizedBox.shrink();
    } else {
      tag = const Pill(
        text: 'Not marked',
        color: kOrange,
        background: kOrangeSoft,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(DateFormat('EEE, d MMM').format(date)),
          ),
          SizedBox(width: 100, child: Align(
            alignment: Alignment.centerLeft,
            child: tag,
          )),
          Expanded(child: Text(detail, style: kSubtle)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final w = r.worker;
    final byDate = {for (final x in r.records) x.date: x};
    final days = <Widget>[
      for (var d = r.startDay; d <= r.daysInMonth; d++) _dayRow(d, byDate),
    ];

    return AlertDialog(
      title: Text(
        '${w.name} – ${DateFormat('MMMM yyyy').format(r.month)}',
      ),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line('Pay type', '${w.payType.label}, '
                '${fmtMoney(w.rate, currency)} ${w.payType.suffix}'),
            _line('Base pay', fmtMoney(r.basePay, currency)),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_rule(), style: kSubtle),
            ),
            _line('Overtime pay', fmtMoney(r.otPay, currency)),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${fmtNum(r.otHours)} h × '
                '${fmtMoney(r.hourlyBase, currency)} × '
                '${fmtNum(w.otMultiplier)}',
                style: kSubtle,
              ),
            ),
            const Divider(color: kBorder),
            _line('Gross salary', fmtMoney(r.gross, currency), bold: true),
            if (r.unmarked > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${r.unmarked} working days are not marked yet. '
                'Mark them on the Attendance page for an exact salary.',
                style: const TextStyle(color: kOrange, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Day by day',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: days.isEmpty
                  ? const Text('Not joined in this month.', style: kSubtle)
                  : ListView(children: days),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
