import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../calc.dart';
import '../reports/excel_report.dart';
import '../reports/pdf_reports.dart';
import '../salary_lines.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

enum _Kind { slip, attendance, excel }

/// Create PDF salary slips, PDF attendance sheets and Excel salary sheets
/// for all workers, one worker, or any chosen workers.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.state});

  final AppState state;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  _Kind _kind = _Kind.slip;
  bool _all = true;
  final Set<int> _picked = {};
  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.state.loadSalaryMonth();
  }

  void _shift(int delta) {
    final m = widget.state.salaryMonth;
    widget.state.setSalaryMonth(DateTime(m.year, m.month + delta, 1));
  }

  String get _ext => _kind == _Kind.excel ? 'xlsx' : 'pdf';

  String get _buttonLabel => switch (_kind) {
        _Kind.slip => 'Create PDF salary slips',
        _Kind.attendance => 'Create PDF attendance report',
        _Kind.excel => 'Create Excel salary sheet',
      };

  String _fileName(List<SalaryLine> lines) {
    final month = monthKey(widget.state.salaryMonth);
    final base = switch (_kind) {
      _Kind.slip => 'Muster_Salary-Slip',
      _Kind.attendance => 'Muster_Attendance',
      _Kind.excel => 'Muster_Salary-Sheet',
    };
    var who = '';
    if (lines.length == 1) {
      final clean = lines.first.worker.name
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      if (clean.isNotEmpty) who = '_$clean';
    }
    return '$base${who}_$month.$_ext';
  }

  Future<void> _generate() async {
    final s = widget.state;
    final lines = buildSalaryLines(s, only: _all ? null : _picked);
    if (lines.isEmpty) {
      showMsg(context, 'Choose at least one worker.');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = switch (_kind) {
        _Kind.slip => await buildSalarySlipsPdf(state: s, lines: lines),
        _Kind.attendance => await buildAttendancePdf(state: s, lines: lines),
        _Kind.excel => buildSalaryWorkbook(state: s, lines: lines),
      };
      final name = _fileName(lines);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save report',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [_ext],
      );
      if (!mounted) return;
      if (path == null) {
        setState(() => _busy = false);
        return;
      }
      final fixed = path.toLowerCase().endsWith('.$_ext') ? path : '$path.$_ext';
      await File(fixed).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $fixed'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => launchUrl(Uri.file(fixed)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMsg(context, 'Could not create the report: $e');
    }
  }

  Widget _kindCard(_Kind kind, IconData icon, String title, String sub) {
    final selected = _kind == kind;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? kNavySoft : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? kNavy : kBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _kind = kind),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: selected ? kNavy : kMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(sub, style: kSubtle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        final all = buildSalaryLines(s);
        final q = _query.trim().toLowerCase();
        final shown = all.where((l) {
          if (q.isEmpty) return true;
          return l.worker.name.toLowerCase().contains(q) ||
              l.worker.code.toLowerCase().contains(q);
        }).toList();
        final count = _all ? all.length : _picked.length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Reports', style: kTitle),
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
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PanelTitle('1. Choose a report'),
                            _kindCard(
                              _Kind.slip,
                              Icons.receipt_long_outlined,
                              'Salary slip (PDF)',
                              'One page for each worker',
                            ),
                            _kindCard(
                              _Kind.attendance,
                              Icons.calendar_month_outlined,
                              'Monthly attendance (PDF)',
                              'Day-by-day table for the month',
                            ),
                            _kindCard(
                              _Kind.excel,
                              Icons.table_chart_outlined,
                              'Salary sheet (Excel)',
                              'Salary and attendance sheets',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PanelTitle('2. Choose workers'),
                            SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const <ButtonSegment<bool>>[
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('All workers'),
                                ),
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('Choose workers'),
                                ),
                              ],
                              selected: <bool>{_all},
                              onSelectionChanged: (v) =>
                                  setState(() => _all = v.first),
                            ),
                            const SizedBox(height: 12),
                            if (_all)
                              Text(
                                all.isEmpty
                                    ? 'No workers for this month.'
                                    : 'All ${all.length} workers will be '
                                        'included.',
                                style: kSubtle,
                              )
                            else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: fieldDec('Search worker')
                                          .copyWith(
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _query = v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _picked
                                        ..clear()
                                        ..addAll(
                                          all.map((l) => l.worker.id!),
                                        );
                                    }),
                                    child: const Text('Select all'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _picked.clear()),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: shown.length,
                                  itemBuilder: (context, i) {
                                    final w = shown[i].worker;
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: _picked.contains(w.id),
                                      onChanged: (v) => setState(() {
                                        if (v ?? false) {
                                          _picked.add(w.id!);
                                        } else {
                                          _picked.remove(w.id);
                                        }
                                      }),
                                      secondary:
                                          WorkerAvatar(worker: w, size: 30),
                                      title: Text(w.name),
                                      subtitle: Text(w.code, style: kSubtle),
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (_all) const Spacer(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  '$count worker${count == 1 ? '' : 's'} '
                                  'selected',
                                  style: kSubtle,
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: (_busy || count == 0)
                                      ? null
                                      : _generate,
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_outlined,
                                          size: 18,
                                        ),
                                  label: Text(_buttonLabel),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reports use the salary rules and attendance of the chosen '
                'month. Worker names print best in English letters.',
                style: kSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}
