import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Daily attendance (hajiri): mark every worker for the selected day.
class AttendancePage extends StatelessWidget {
  const AttendancePage({
    super.key,
    required this.state,
    required this.onGoWorkers,
  });

  final AppState state;
  final VoidCallback onGoWorkers;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.day,
      firstDate: DateTime(2020),
      lastDate: state.today,
    );
    if (picked != null) {
      await state.setDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = state.workersForDay();
        int count(String s) =>
            list.where((w) => state.attendance[w.id]?.status == s).length;
        final unmarked =
            list.where((w) => state.attendance[w.id] == null).length;
        final isToday = state.day == state.today;
        final off = state.weeklyOff.contains(state.day.weekday);
        final holiday = state.holidayOn(state.day);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Attendance', style: kTitle),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () => state.setDay(
                      DateTime(
                        state.day.year,
                        state.day.month,
                        state.day.day - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(DateFormat('EEE, d MMM yyyy').format(state.day)),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: isToday
                        ? null
                        : () => state.setDay(
                              DateTime(
                                state.day.year,
                                state.day.month,
                                state.day.day + 1,
                              ),
                            ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (!isToday)
                    TextButton(
                      onPressed: () => state.setDay(state.today),
                      child: const Text('Today'),
                    ),
                ],
              ),
              if (off)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('This day is a weekly off.', style: kSubtle),
                ),
              if (holiday != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Pill(
                        text: 'Company holiday',
                        color: kBlue,
                        background: kBlueSoft,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          holiday.name.isEmpty
                              ? 'Workers not marked today are not counted '
                                  'absent.'
                              : '${holiday.name}. Workers not marked today '
                                  'are not counted absent.',
                          style: kSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat('Present', count('P'), kGreen, kGreenSoft),
                  const SizedBox(width: 10),
                  _Stat('Absent', count('A'), kRed, kRedSoft),
                  const SizedBox(width: 10),
                  _Stat('Half day', count('H'), kOrange, kOrangeSoft),
                  const SizedBox(width: 10),
                  _Stat('Leave', count('L'), kBlue, kBlueSoft),
                  const SizedBox(width: 10),
                  _Stat('Not marked', unmarked, kMuted, kGreySoft),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: unmarked == 0 ? null : state.markAllPresent,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Mark all present'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: list.isEmpty
                    ? _Empty(onGoWorkers: onGoWorkers)
                    : Panel(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, i) =>
                              const Divider(height: 1, color: kBorder),
                          itemBuilder: (context, i) {
                            final w = list[i];
                            return _AttendanceRow(
                              state: state,
                              worker: w,
                              record: state.attendance[w.id],
                            );
                          },
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color, this.background);

  final String label;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onGoWorkers});

  final VoidCallback onGoWorkers;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 44, color: kMuted),
            const SizedBox(height: 10),
            const Text(
              'No workers for this day',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add your workers first, then mark their attendance here.',
              style: kSubtle,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onGoWorkers,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Go to Workers'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.state,
    required this.worker,
    required this.record,
  });

  final AppState state;
  final Worker worker;
  final Attendance? record;

  Future<void> _editTimes(BuildContext context, Attendance rec) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _TimesDialog(
        worker: worker,
        timing: state.timingFor(worker),
        checkIn: rec.checkIn ?? state.timingFor(worker).start,
        checkOut: rec.checkOut ?? state.timingFor(worker).end,
      ),
    );
    if (result != null) {
      await state.setTimes(worker, result.$1, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = state.timingFor(worker);
    final rec = record;
    final sub = worker.role.isEmpty ? worker.code : worker.role;

    Widget info;
    if (rec == null) {
      info = const SizedBox.shrink();
    } else if (rec.status == 'P') {
      info = Row(
        children: [
          Text('${rec.checkIn ?? '--'} – ${rec.checkOut ?? '--'}'),
          if (rec.otHours > 0) ...[
            const SizedBox(width: 8),
            Pill(
              text: 'OT ${fmtNum(rec.otHours)} h',
              color: kOrange,
              background: kOrangeSoft,
            ),
          ],
          if (isLateArrival(
            checkIn: rec.checkIn,
            start: t.start,
            graceMinutes: t.lateGrace,
          )) ...[
            const SizedBox(width: 8),
            const Pill(text: 'Late', color: kRed, background: kRedSoft),
          ],
          IconButton(
            tooltip: 'Edit in / out time',
            visualDensity: VisualDensity.compact,
            onPressed: () => _editTimes(context, rec),
            icon: const Icon(Icons.schedule, size: 18),
          ),
        ],
      );
    } else {
      info = Align(
        alignment: Alignment.centerLeft,
        child: Pill(
          text: statusName(rec.status),
          color: statusColor(rec.status),
          background: statusSoft(rec.status),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          WorkerAvatar(worker: worker, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('$sub · ${t.label}', style: kSubtle),
              ],
            ),
          ),
          SizedBox(width: 290, child: info),
          SegmentedButton<String>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: kNavySoft,
              selectedForegroundColor: kNavy,
            ),
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: 'P',
                label: Text('P'),
                tooltip: 'Present',
              ),
              ButtonSegment<String>(
                value: 'A',
                label: Text('A'),
                tooltip: 'Absent',
              ),
              ButtonSegment<String>(
                value: 'H',
                label: Text('H'),
                tooltip: 'Half day',
              ),
              ButtonSegment<String>(
                value: 'L',
                label: Text('L'),
                tooltip: 'Leave',
              ),
            ],
            selected: rec == null ? <String>{} : <String>{rec.status},
            onSelectionChanged: (s) {
              if (s.isEmpty) {
                state.clearMark(worker);
              } else {
                state.mark(worker, s.first);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TimesDialog extends StatefulWidget {
  const _TimesDialog({
    required this.worker,
    required this.timing,
    required this.checkIn,
    required this.checkOut,
  });

  final Worker worker;
  final WorkTiming timing;
  final String checkIn;
  final String checkOut;

  @override
  State<_TimesDialog> createState() => _TimesDialogState();
}

class _TimesDialogState extends State<_TimesDialog> {
  late final TextEditingController _in =
      TextEditingController(text: widget.checkIn);
  late final TextEditingController _out =
      TextEditingController(text: widget.checkOut);
  String? _error;

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  String get _preview {
    final a = parseHm(_in.text);
    final b = parseHm(_out.text);
    if (a == null || b == null) return '';
    final worked = workedHours(
      inMin: a,
      outMin: b,
      breakMin: widget.timing.breakMinutes,
    );
    final ot = overtimeHours(
      worked: worked,
      standard: widget.timing.standardHours,
    );
    return 'Worked ${fmtHours(worked)} · Overtime ${fmtHours(ot)}';
  }

  void _save() {
    if (parseHm(_in.text) == null || parseHm(_out.text) == null) {
      setState(() => _error = 'Use the HH:mm format, for example 08:00.');
      return;
    }
    Navigator.of(context).pop((_in.text.trim(), _out.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.worker.name} – in / out time'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _in,
                    decoration: fieldDec('In time', hint: 'HH:mm'),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _out,
                    decoration: fieldDec('Out time', hint: 'HH:mm'),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_preview, style: kSubtle),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
