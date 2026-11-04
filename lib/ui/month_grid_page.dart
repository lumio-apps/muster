import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Whole month on one screen: a row per worker, a box per day.
/// Click a box to set Present, Absent, Half day or Leave.
class MonthGridPage extends StatefulWidget {
  const MonthGridPage({super.key, required this.state});

  final AppState state;

  @override
  State<MonthGridPage> createState() => _MonthGridPageState();
}

class _MonthGridPageState extends State<MonthGridPage> {
  static const double _nameW = 170;
  static const double _dayW = 34;
  static const double _totalW = 38;

  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.state.loadSalaryMonth();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  void _shift(int delta) {
    final m = widget.state.salaryMonth;
    widget.state.setSalaryMonth(DateTime(m.year, m.month + delta, 1));
  }

  Future<void> _pick(
    TapDownDetails at,
    Worker w,
    DateTime date,
    String? current,
  ) async {
    final pos = at.globalPosition;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(
            '${w.name} · ${DateFormat('d MMM').format(date)}',
            style: kSubtle,
          ),
        ),
        for (final s in const ['P', 'A', 'H', 'L'])
          PopupMenuItem<String>(
            value: s,
            height: 36,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    s,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: statusColor(s),
                    ),
                  ),
                ),
                Text(statusName(s)),
                if (current == s) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
        if (current != null)
          const PopupMenuItem<String>(
            value: '-',
            height: 36,
            child: Text('Clear'),
          ),
      ],
    );
    if (choice == null) return;
    await widget.state.markOn(w, date, choice == '-' ? null : choice);
  }

  Widget _headCell(String text, {double width = _dayW, bool dim = false}) {
    return SizedBox(
      width: width,
      height: 34,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: dim ? kMuted : kInk,
          ),
        ),
      ),
    );
  }

  Widget _dayCell(
    Worker w,
    DateTime date,
    Attendance? rec,
    DateTime today,
  ) {
    final joined = DateTime(w.joinedOn.year, w.joinedOn.month, w.joinedOn.day);
    final blocked = date.isBefore(joined) || date.isAfter(today);
    Widget inner;
    var clickable = !blocked;

    if (rec != null) {
      final isLate = rec.status == 'P' &&
          isLateArrival(
            checkIn: rec.checkIn,
            start: widget.state.timingFor(w).start,
            graceMinutes: widget.state.timingFor(w).lateGrace,
          );
      inner = Container(
        decoration: BoxDecoration(
          color: statusSoft(rec.status),
          borderRadius: BorderRadius.circular(4),
          border: isLate ? Border.all(color: kRed, width: 1.4) : null,
        ),
        child: Center(
          child: Text(
            rec.status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: statusColor(rec.status),
            ),
          ),
        ),
      );
      clickable = !date.isAfter(today);
    } else if (date.isBefore(joined)) {
      inner = const SizedBox.shrink();
    } else if (w.weeklyOff.contains(date.weekday)) {
      inner = const Center(
        child: Text('W', style: TextStyle(fontSize: 11, color: kMuted)),
      );
    } else if (widget.state.holidayOn(date) != null) {
      inner = Center(
        child: Text(
          'HD',
          style: TextStyle(fontSize: 11, color: kBlue),
        ),
      );
    } else if (date.isAfter(today)) {
      inner = const SizedBox.shrink();
    } else {
      inner = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder),
        ),
      );
    }

    return SizedBox(
      width: _dayW,
      height: 36,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: clickable
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _pick(d, w, date, rec?.status),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: inner,
                ),
              )
            : inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final month = s.salaryMonth;
        final dim = DateTime(month.year, month.month + 1, 0).day;
        final monthEnd = DateTime(month.year, month.month, dim);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final atCurrent = !month.isBefore(DateTime(now.year, now.month, 1));

        final byWorker = <int, Map<String, Attendance>>{};
        for (final r in s.monthRecords) {
          byWorker.putIfAbsent(r.workerId, () => {})[r.date] = r;
        }
        final workers = s.workers.where((w) {
          final joined =
              DateTime(w.joinedOn.year, w.joinedOn.month, w.joinedOn.day);
          if (joined.isAfter(monthEnd)) return false;
          return w.active || (byWorker[w.id]?.isNotEmpty ?? false);
        }).toList();

        final width = _nameW + dim * _dayW + 4 * _totalW;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Month grid', style: kTitle),
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
                        DateFormat('MMMM yyyy').format(month),
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
              const SizedBox(height: 6),
              const Text(
                'Click a box to mark Present, Absent, Half day or Leave. '
                'W = weekly off, HD = company holiday, red border = late.',
                style: kSubtle,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: workers.isEmpty
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
                        child: Scrollbar(
                          controller: _hScroll,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _hScroll,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: width,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: _nameW,
                                        height: 34,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 12),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Worker',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (var d = 1; d <= dim; d++)
                                        _headCell(
                                          '$d',
                                          dim: s.weeklyOff.contains(
                                            DateTime(month.year, month.month, d)
                                                .weekday,
                                          ),
                                        ),
                                      _headCell('P', width: _totalW),
                                      _headCell('A', width: _totalW),
                                      _headCell('H', width: _totalW),
                                      _headCell('L', width: _totalW),
                                    ],
                                  ),
                                  const Divider(height: 1, color: kBorder),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: workers.length,
                                      separatorBuilder: (context, i) =>
                                          const Divider(
                                        height: 1,
                                        color: kBorder,
                                      ),
                                      itemBuilder: (context, i) {
                                        final w = workers[i];
                                        final recs = byWorker[w.id] ??
                                            <String, Attendance>{};
                                        int count(String st) => recs.values
                                            .where((r) => r.status == st)
                                            .length;
                                        return Row(
                                          children: [
                                            SizedBox(
                                              width: _nameW,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                                child: Text(
                                                  w.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            for (var d = 1; d <= dim; d++)
                                              _dayCell(
                                                w,
                                                DateTime(
                                                  month.year,
                                                  month.month,
                                                  d,
                                                ),
                                                recs[dateKey(
                                                  DateTime(
                                                    month.year,
                                                    month.month,
                                                    d,
                                                  ),
                                                )],
                                                today,
                                              ),
                                            for (final st in const [
                                              'P',
                                              'A',
                                              'H',
                                              'L',
                                            ])
                                              SizedBox(
                                                width: _totalW,
                                                child: Center(
                                                  child: Text(
                                                    '${count(st)}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: statusColor(st),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
