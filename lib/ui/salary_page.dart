import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../currencies.dart';
import '../models.dart';
import '../salary.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// One line of the salary table: the calculation plus payment state.
class _Line {
  const _Line({required this.result, required this.run, required this.balance});

  final SalaryResult result;
  final SalaryRun? run;

  /// Advance still owed by the worker before this salary is paid.
  final double balance;

  bool get paid => run != null;
  double get gross => run?.gross ?? result.gross;
  double get deduct =>
      run?.deducted ?? math.max(0.0, math.min(balance, result.gross));
  double get net => gross - deduct;
}

/// Monthly salary of every worker, advance deduction and paid status.
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

  List<_Line> _lines() {
    final s = widget.state;
    final key = monthKey(s.salaryMonth);
    final byWorker = <int, List<Attendance>>{};
    for (final r in s.monthRecords) {
      byWorker.putIfAbsent(r.workerId, () => <Attendance>[]).add(r);
    }
    final out = <_Line>[];
    for (final w in s.workers) {
      final recs = byWorker[w.id] ?? <Attendance>[];
      final run = s.runFor(w.id!, key);
      if (!w.active && recs.isEmpty && run == null) continue;
      final r = calculateSalary(
        worker: w,
        timing: s.timingFor(w),
        records: recs,
        month: s.salaryMonth,
        paidLeave: s.paidLeave,
        today: s.today,
      );
      if (r.eligibleDays <= 0 && recs.isEmpty && run == null) continue;
      out.add(_Line(result: r, run: run, balance: s.balanceOf(w.id!)));
    }
    return out;
  }

  void _shift(int delta) {
    final m = widget.state.salaryMonth;
    widget.state.setSalaryMonth(DateTime(m.year, m.month + delta, 1));
  }

  void _openDetail(_Line line) {
    showDialog<void>(
      context: context,
      builder: (_) => _DetailDialog(state: widget.state, line: line),
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
        final lines = _lines();

        var gross = 0.0;
        var deduct = 0.0;
        var net = 0.0;
        var paidCount = 0;
        var unmarked = 0;
        for (final l in lines) {
          gross += l.gross;
          deduct += l.deduct;
          net += l.net;
          if (l.paid) paidCount++;
          unmarked += l.result.unmarked;
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Tile(
                    'Net payable',
                    fmtMoney(net, s.currency),
                    kNavy,
                    kNavySoft,
                  ),
                  _Tile(
                    'Gross salary',
                    fmtMoney(gross, s.currency),
                    kGreen,
                    kGreenSoft,
                  ),
                  _Tile(
                    'Advance deducted',
                    fmtMoney(deduct, s.currency),
                    kOrange,
                    kOrangeSoft,
                  ),
                  _Tile(
                    'Paid',
                    '$paidCount of ${lines.length}',
                    kBlue,
                    kBlueSoft,
                  ),
                  if (unmarked > 0)
                    _Tile('Days not marked', '$unmarked', kRed, kRedSoft),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: lines.isEmpty
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
                                itemCount: lines.length,
                                separatorBuilder: (context, i) =>
                                    const Divider(height: 1, color: kBorder),
                                itemBuilder: (context, i) => _SalaryRow(
                                  line: lines[i],
                                  currency: s.currency,
                                  onTap: () => _openDetail(lines[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Click a worker to see the day-by-day details and to mark '
                'the salary as paid.',
                style: kSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
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
        mainAxisSize: MainAxisSize.min,
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
    Widget right(String t, {int flex = 2}) => Expanded(
          flex: flex,
          child: Text(t, textAlign: TextAlign.right, style: style),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(flex: 4, child: Text('WORKER', style: style)),
          const Expanded(flex: 4, child: Text('ATTENDANCE', style: style)),
          right('GROSS'),
          right('ADVANCE'),
          right('NET'),
          right('STATUS'),
        ],
      ),
    );
  }
}

class _SalaryRow extends StatelessWidget {
  const _SalaryRow({
    required this.line,
    required this.currency,
    required this.onTap,
  });

  final _Line line;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = line.result;
    final w = r.worker;
    final att = '${r.present}P · ${r.half}H · ${r.leave}L · ${r.absent}A'
        '${r.otHours > 0 ? ' · OT ${fmtNum(r.otHours)} h' : ''}';
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
            Expanded(flex: 4, child: Text(att, style: kSubtle)),
            _cell(fmtMoney(line.gross, currency)),
            _cell(
              line.deduct > 0 ? '− ${fmtMoney(line.deduct, currency)}' : '–',
              color: line.deduct > 0 ? kOrange : kMuted,
            ),
            _cell(fmtMoney(line.net, currency), bold: true),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: line.paid
                    ? const Pill(
                        text: 'Paid',
                        color: kGreen,
                        background: kGreenSoft,
                      )
                    : const Pill(
                        text: 'Unpaid',
                        color: kOrange,
                        background: kOrangeSoft,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _cell(String text, {bool bold = false, Color? color}) {
  return Expanded(
    flex: 2,
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

class _DetailDialog extends StatefulWidget {
  const _DetailDialog({required this.state, required this.line});

  final AppState state;
  final _Line line;

  @override
  State<_DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends State<_DetailDialog> {
  late final TextEditingController _deduct =
      TextEditingController(text: fmtNum(widget.line.deduct));
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _deduct.dispose();
    super.dispose();
  }

  SalaryResult get _r => widget.line.result;
  String get _cur => widget.state.currency;

  double get _typedDeduct => parseNum(_deduct.text) ?? 0;

  String _rule() {
    final w = _r.worker;
    final units = _r.payableUnits;
    switch (w.payType) {
      case PayType.daily:
        return '${fmtMoney(w.rate, _cur)} per day × ${fmtNum(units)} paid days';
      case PayType.monthly:
        return '${fmtMoney(w.rate, _cur)} ÷ ${_r.daysInMonth} days × '
            '${fmtNum(units)} paid days';
      case PayType.hourly:
        return '${fmtMoney(w.rate, _cur)} per hour × ${fmtHours(units)}';
    }
  }

  Future<void> _pay() async {
    final d = parseNum(_deduct.text);
    final gross = _r.gross;
    final balance = widget.line.balance;
    if (d == null || d < 0) {
      setState(() => _error = 'Enter the advance to deduct (0 for none).');
      return;
    }
    if (d > balance + 0.005) {
      setState(() => _error =
          'Only ${fmtMoney(balance, _cur)} advance is pending for this worker.');
      return;
    }
    if (d > gross + 0.005) {
      setState(() => _error = 'Deduction cannot be more than the salary.');
      return;
    }
    setState(() => _busy = true);
    await widget.state.markPaid(
      _r.worker.id!,
      monthKey(_r.month),
      gross,
      (d * 100).roundToDouble() / 100,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _undo() async {
    final ok = await confirm(
      context,
      title: 'Undo payment?',
      message: 'This marks the salary as unpaid again and puts the deducted '
          'advance back on the worker.',
      yes: 'Undo payment',
    );
    if (!ok || !mounted) return;
    await widget.state.undoPaid(_r.worker.id!, monthKey(_r.month));
    if (!mounted) return;
    Navigator.of(context).pop();
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

  Widget _note(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(text, style: kSubtle),
    );
  }

  Widget _dayRow(int day, Map<String, Attendance> byDate) {
    final r = _r;
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
    } else if (date.isAfter(widget.state.today)) {
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
          SizedBox(
            width: 100,
            child: Align(alignment: Alignment.centerLeft, child: tag),
          ),
          Expanded(child: Text(detail, style: kSubtle)),
        ],
      ),
    );
  }

  Widget _paymentSection() {
    final line = widget.line;
    final run = line.run;
    if (run != null) {
      final changed = (run.gross - _r.gross).abs() > 0.005;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('Paid on', run.paidOn),
          _line('Advance deducted', fmtMoney(run.deducted, _cur)),
          _line('Net paid', fmtMoney(run.net, _cur), bold: true),
          if (changed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Attendance changed after payment. New calculated salary is '
                '${fmtMoney(_r.gross, _cur)}. Undo the payment and pay again '
                'to update it.',
                style: const TextStyle(color: kOrange, fontSize: 12),
              ),
            ),
        ],
      );
    }
    final net = _r.gross - _typedDeduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('Advance pending', fmtMoney(line.balance, _cur)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                controller: _deduct,
                decoration: fieldDec(
                  'Deduct advance now',
                  prefix: symbolPrefix(_cur),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Net payable ${fmtMoney(net < 0 ? 0 : net, _cur)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: const TextStyle(color: kRed, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final w = r.worker;
    final paid = widget.line.paid;
    final byDate = {for (final x in r.records) x.date: x};
    final days = <Widget>[
      for (var d = r.startDay; d <= r.daysInMonth; d++) _dayRow(d, byDate),
    ];

    return AlertDialog(
      title: Text('${w.name} – ${DateFormat('MMMM yyyy').format(r.month)}'),
      content: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              'Pay type',
              '${w.payType.label}, ${fmtMoney(w.rate, _cur)} ${w.payType.suffix}',
            ),
            _line('Base pay', fmtMoney(r.basePay, _cur)),
            _note(_rule()),
            _line('Overtime pay', fmtMoney(r.otPay, _cur)),
            _note(
              '${fmtNum(r.otHours)} h × ${fmtMoney(r.hourlyBase, _cur)} × '
              '${fmtNum(w.otMultiplier)}',
            ),
            const Divider(color: kBorder),
            _line('Gross salary', fmtMoney(r.gross, _cur), bold: true),
            if (r.unmarked > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${r.unmarked} working days are not marked yet. '
                'Mark them on the Attendance page for an exact salary.',
                style: const TextStyle(color: kOrange, fontSize: 12),
              ),
            ],
            const Divider(color: kBorder),
            _paymentSection(),
            const Divider(color: kBorder),
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
        if (paid)
          TextButton(onPressed: _undo, child: const Text('Undo payment')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!paid)
          FilledButton(
            onPressed: _busy ? null : _pay,
            child: const Text('Mark as paid'),
          ),
      ],
    );
  }
}
