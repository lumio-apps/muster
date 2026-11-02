import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../calc.dart';
import '../models.dart';
import '../salary.dart';
import '../salary_lines.dart';
import '../state.dart';
import 'pdf_fonts.dart';

const PdfColor _navy = PdfColor.fromInt(0xFF17406B);
const PdfColor _amber = PdfColor.fromInt(0xFFF0A93A);
const PdfColor _soft = PdfColor.fromInt(0xFFE6EEF6);
const PdfColor _grey = PdfColor.fromInt(0xFF6B6B6B);
const PdfColor _line = PdfColor.fromInt(0xFFD0D0D0);
const PdfColor _green = PdfColor.fromInt(0xFF1E8E4E);
const PdfColor _red = PdfColor.fromInt(0xFFC42B1C);
const PdfColor _orange = PdfColor.fromInt(0xFFB86E00);
const PdfColor _blue = PdfColor.fromInt(0xFF2563A8);

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

pw.TextStyle _style({
  double size = 10,
  bool bold = false,
  PdfColor color = PdfColors.black,
}) {
  return pw.TextStyle(
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color,
  );
}

// ---------------------------------------------------------------------------
// Salary slips: one A4 page per worker.
// ---------------------------------------------------------------------------

Future<Uint8List> buildSalarySlipsPdf({
  required AppState state,
  required List<SalaryLine> lines,
}) async {
  final doc = pw.Document(
    theme: loadPdfTheme(),
    title: 'Salary slips',
    author: state.companyName,
    creator: 'Muster',
  );
  final cur = reportCurrency(state);
  final monthLabel = DateFormat('MMMM yyyy').format(state.salaryMonth);

  for (final l in lines) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => _slip(state, l, cur, monthLabel),
      ),
    );
  }
  return doc.save();
}

pw.Widget _kv(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(label, style: _style(size: 9, color: _grey)),
        ),
        pw.Expanded(child: pw.Text(value, style: _style(bold: true))),
      ],
    ),
  );
}

pw.Widget _statBox(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _soft,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: _style(size: 8, color: _grey)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: _style(size: 14, bold: true, color: _navy)),
        ],
      ),
    ),
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  bool right = false,
  PdfColor color = PdfColors.black,
  double size = 10,
}) {
  return pw.Container(
    alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(text, style: _style(size: size, bold: bold, color: color)),
  );
}

pw.Widget _slip(
  AppState state,
  SalaryLine l,
  String cur,
  String monthLabel,
) {
  final r = l.result;
  final w = r.worker;
  final contact = [state.address, state.phone]
      .where((e) => e.trim().isNotEmpty)
      .join('  •  ');

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _navy),
      children: [
        _cell('Description', bold: true, color: PdfColors.white, size: 9),
        _cell('Details', bold: true, color: PdfColors.white, size: 9),
        _cell(
          'Amount',
          bold: true,
          right: true,
          color: PdfColors.white,
          size: 9,
        ),
      ],
    ),
    pw.TableRow(
      children: [
        _cell('Base pay'),
        _cell(salaryRuleText(r, cur), color: _grey, size: 9),
        _cell(reportMoney(r.basePay, cur), right: true),
      ],
    ),
    pw.TableRow(
      children: [
        _cell('Overtime'),
        _cell(overtimeRuleText(r, cur), color: _grey, size: 9),
        _cell(reportMoney(r.otPay, cur), right: true),
      ],
    ),
    if (r.holidayDays > 0)
      pw.TableRow(
        children: [
          _cell('Paid holidays'),
          _cell('Included in base pay', color: _grey, size: 9),
          _cell('${r.holidayDays} days', right: true),
        ],
      ),
    if (r.bonus > 0)
      pw.TableRow(
        children: [
          _cell('Bonus'),
          _cell('', color: _grey, size: 9),
          _cell('+ ${reportMoney(r.bonus, cur)}', right: true),
        ],
      ),
    if (r.fine > 0)
      pw.TableRow(
        children: [
          _cell('Fines'),
          _cell('', color: _grey, size: 9),
          _cell('- ${reportMoney(r.fine, cur)}', right: true),
        ],
      ),
    if (r.lateFine > 0)
      pw.TableRow(
        children: [
          _cell('Late fine'),
          _cell('${r.lateCount} late arrivals', color: _grey, size: 9),
          _cell('- ${reportMoney(r.lateFine, cur)}', right: true),
        ],
      ),
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _soft),
      children: [
        _cell('Gross salary', bold: true),
        _cell(''),
        _cell(reportMoney(l.gross, cur), bold: true, right: true),
      ],
    ),
    pw.TableRow(
      children: [
        _cell('Advance deducted'),
        _cell(
          l.paid ? 'Recovered from this salary' : 'Pending advance recovery',
          color: _grey,
          size: 9,
        ),
        _cell(
          l.deduct > 0 ? '- ${reportMoney(l.deduct, cur)}' : '-',
          right: true,
        ),
      ],
    ),
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _navy),
      children: [
        _cell('NET PAY', bold: true, color: PdfColors.white, size: 12),
        _cell(''),
        _cell(
          reportMoney(l.net, cur),
          bold: true,
          right: true,
          color: PdfColors.white,
          size: 12,
        ),
      ],
    ),
  ];

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        color: _navy,
        padding: const pw.EdgeInsets.all(16),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    state.companyName.isEmpty ? 'Company' : state.companyName,
                    style: _style(
                      size: 18,
                      bold: true,
                      color: PdfColors.white,
                    ),
                  ),
                  if (contact.isNotEmpty)
                    pw.Text(
                      contact,
                      style: _style(size: 9, color: PdfColors.white),
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'SALARY SLIP',
                  style: _style(size: 14, bold: true, color: _amber),
                ),
                pw.Text(
                  monthLabel,
                  style: _style(size: 10, color: PdfColors.white),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              children: [
                _kv('Employee', w.name),
                _kv('Employee ID', w.code),
                _kv('Role', w.role.isEmpty ? '-' : w.role),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              children: [
                _kv('Pay type', w.payType.label),
                _kv('Rate', '${reportMoney(w.rate, cur)} ${w.payType.suffix}'),
                _kv(
                  'Joined on',
                  DateFormat('d MMM yyyy').format(w.joinedOn),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text('Attendance', style: _style(size: 11, bold: true)),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          _statBox('Present', '${r.present}'),
          _statBox('Half day', '${r.half}'),
          _statBox('Leave', '${r.leave}'),
          _statBox('Absent', '${r.absent}'),
          _statBox('Overtime', '${_num(r.otHours)} h'),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Text('Earnings and deductions', style: _style(size: 11, bold: true)),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(5),
          2: pw.FlexColumnWidth(3),
        },
        children: rows,
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        l.paid
            ? 'Status: Paid on ${l.run!.paidOn}'
            : 'Status: Not yet marked as paid',
        style: _style(size: 9, color: l.paid ? _green : _orange),
      ),
      if (r.unmarked > 0)
        pw.Text(
          '${r.unmarked} working days were not marked in attendance.',
          style: _style(size: 9, color: _orange),
        ),
      pw.Spacer(),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _signature('Employer signature'),
          _signature('Employee signature'),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Text(
        'Generated by Muster on '
        '${DateFormat('d MMM yyyy').format(DateTime.now())}',
        style: _style(size: 8, color: _grey),
      ),
    ],
  );
}

pw.Widget _signature(String label) {
  return pw.SizedBox(
    width: 180,
    child: pw.Column(
      children: [
        pw.Divider(color: _grey, thickness: 0.6),
        pw.Text(label, style: _style(size: 9, color: _grey)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Monthly attendance: one landscape table, a row per worker.
// ---------------------------------------------------------------------------

PdfColor _statusColor(String s) {
  switch (s) {
    case 'P':
      return _green;
    case 'A':
      return _red;
    case 'H':
      return _orange;
    case 'L':
      return _blue;
    default:
      return _grey;
  }
}

pw.Widget _grid(
  String text, {
  bool bold = false,
  PdfColor color = PdfColors.black,
  pw.Alignment align = pw.Alignment.center,
}) {
  return pw.Container(
    alignment: align,
    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    child: pw.Text(text, style: _style(size: 7, bold: bold, color: color)),
  );
}

Future<Uint8List> buildAttendancePdf({
  required AppState state,
  required List<SalaryLine> lines,
}) async {
  final doc = pw.Document(
    theme: loadPdfTheme(),
    title: 'Monthly attendance',
    author: state.companyName,
    creator: 'Muster',
  );
  final month = state.salaryMonth;
  final days = DateTime(month.year, month.month + 1, 0).day;
  final monthLabel = DateFormat('MMMM yyyy').format(month);

  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(110),
    for (var d = 1; d <= days; d++) d: const pw.FixedColumnWidth(16),
    for (var k = 0; k < 5; k++) days + 1 + k: const pw.FixedColumnWidth(28),
  };

  final rows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: _navy),
      children: [
        _grid(
          'Worker',
          bold: true,
          color: PdfColors.white,
          align: pw.Alignment.centerLeft,
        ),
        for (var d = 1; d <= days; d++)
          _grid('$d', bold: true, color: PdfColors.white),
        _grid('P', bold: true, color: PdfColors.white),
        _grid('H', bold: true, color: PdfColors.white),
        _grid('L', bold: true, color: PdfColors.white),
        _grid('A', bold: true, color: PdfColors.white),
        _grid('OT h', bold: true, color: PdfColors.white),
      ],
    ),
  ];

  for (final l in lines) {
    final r = l.result;
    final byDate = {for (final x in r.records) x.date: x};
    rows.add(
      pw.TableRow(
        children: [
          _grid(
            r.worker.name,
            bold: true,
            align: pw.Alignment.centerLeft,
          ),
          for (var d = 1; d <= days; d++)
            _dayCell(r, byDate, DateTime(month.year, month.month, d)),
          _grid('${r.present}', color: _green),
          _grid('${r.half}', color: _orange),
          _grid('${r.leave}', color: _blue),
          _grid('${r.absent}', color: _red),
          _grid(_num(r.otHours)),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(30),
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              state.companyName.isEmpty ? 'Company' : state.companyName,
              style: _style(size: 14, bold: true, color: _navy),
            ),
            pw.Text(
              'Monthly attendance – $monthLabel',
              style: _style(size: 12, bold: true),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}  •  '
          'Generated by Muster',
          style: _style(size: 8, color: _grey),
        ),
      ),
      build: (context) => [
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.4),
          columnWidths: widths,
          children: rows,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'P Present   H Half day   L Leave   A Absent   '
          'W Weekly off   blank = not marked',
          style: _style(size: 8, color: _grey),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _dayCell(
  SalaryResult r,
  Map<String, Attendance> byDate,
  DateTime date,
) {
  final rec = byDate[dateKey(date)];
  if (rec != null) {
    return _grid(rec.status, bold: true, color: _statusColor(rec.status));
  }
  if (date.day >= r.startDay && r.worker.weeklyOff.contains(date.weekday)) {
    return _grid('W', color: _grey);
  }
  return _grid('');
}
