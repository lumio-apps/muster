import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../models.dart';
import '../salary_lines.dart';
import '../state.dart';

void _put(Sheet sheet, int col, int row, CellValue value, [CellStyle? style]) {
  final cell = sheet.cell(
    CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
  );
  cell.value = value;
  if (style != null) cell.cellStyle = style;
}

String _col(int index) => String.fromCharCode(65 + index);

/// Excel workbook with a "Salary" sheet and an "Attendance" sheet.
Uint8List buildSalaryWorkbook({
  required AppState state,
  required List<SalaryLine> lines,
}) {
  final excel = Excel.createExcel();
  final cur = reportCurrency(state);
  final month = state.salaryMonth;
  final monthLabel = DateFormat('MMMM yyyy').format(month);
  final company = state.companyName.isEmpty ? 'Company' : state.companyName;

  final titleStyle = CellStyle(bold: true, fontSize: 14);
  final headStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('#17406B'),
  );
  final boldStyle = CellStyle(bold: true);

  // ---- Salary sheet ----
  final first = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(first, 'Salary');
  final sheet = excel['Salary'];

  _put(sheet, 0, 0, TextCellValue('$company – Salary sheet – $monthLabel'),
      titleStyle);

  final headers = <String>[
    'ID',
    'Name',
    'Pay type',
    'Rate ($cur)',
    'Present',
    'Half day',
    'Leave',
    'Absent',
    'OT hours',
    'Base pay ($cur)',
    'OT pay ($cur)',
    'Bonus ($cur)',
    'Fines ($cur)',
    'Gross ($cur)',
    'Advance deducted ($cur)',
    'Net ($cur)',
    'Status',
    'Late days',
    'Paid holidays',
  ];
  for (var c = 0; c < headers.length; c++) {
    _put(sheet, c, 2, TextCellValue(headers[c]), headStyle);
  }

  var row = 3;
  for (final l in lines) {
    final r = l.result;
    final w = r.worker;
    _put(sheet, 0, row, TextCellValue(w.code));
    _put(sheet, 1, row, TextCellValue(w.name));
    _put(sheet, 2, row, TextCellValue(w.payType.label));
    _put(sheet, 3, row, DoubleCellValue(w.rate));
    _put(sheet, 4, row, IntCellValue(r.present));
    _put(sheet, 5, row, IntCellValue(r.half));
    _put(sheet, 6, row, IntCellValue(r.leave));
    _put(sheet, 7, row, IntCellValue(r.absent));
    _put(sheet, 8, row, DoubleCellValue(r.otHours));
    _put(sheet, 9, row, DoubleCellValue(r.basePay));
    _put(sheet, 10, row, DoubleCellValue(r.otPay));
    _put(sheet, 11, row, DoubleCellValue(r.bonus));
    _put(sheet, 12, row, DoubleCellValue(r.fine + r.lateFine));
    _put(sheet, 13, row, DoubleCellValue(l.gross));
    _put(sheet, 14, row, DoubleCellValue(l.deduct));
    _put(sheet, 15, row, DoubleCellValue(l.net));
    _put(sheet, 16, row, TextCellValue(l.paid ? 'Paid' : 'Unpaid'));
    _put(sheet, 17, row, IntCellValue(r.lateCount));
    _put(sheet, 18, row, IntCellValue(r.holidayDays));
    row++;
  }

  if (lines.isNotEmpty) {
    final firstRow = 4; // spreadsheet row number of the first worker
    final lastRow = row; // spreadsheet row number of the last worker
    _put(sheet, 1, row, TextCellValue('TOTAL'), boldStyle);
    for (final c in [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18]) {
      final letter = _col(c);
      _put(
        sheet,
        c,
        row,
        FormulaCellValue('SUM($letter$firstRow:$letter$lastRow)'),
        boldStyle,
      );
    }
  }

  for (var c = 0; c < headers.length; c++) {
    sheet.setColumnWidth(c, c == 1 ? 24 : 15);
  }

  // ---- Attendance sheet ----
  final att = excel['Attendance'];
  final days = DateTime(month.year, month.month + 1, 0).day;

  _put(att, 0, 0, TextCellValue('$company – Attendance – $monthLabel'),
      titleStyle);

  _put(att, 0, 2, TextCellValue('ID'), headStyle);
  _put(att, 1, 2, TextCellValue('Name'), headStyle);
  for (var d = 1; d <= days; d++) {
    _put(att, 1 + d, 2, IntCellValue(d), headStyle);
  }
  final totals = ['P', 'H', 'L', 'A', 'OT hours'];
  for (var k = 0; k < totals.length; k++) {
    _put(att, 2 + days + k, 2, TextCellValue(totals[k]), headStyle);
  }

  var arow = 3;
  for (final l in lines) {
    final r = l.result;
    final byDate = {for (final x in r.records) x.date: x};
    _put(att, 0, arow, TextCellValue(r.worker.code));
    _put(att, 1, arow, TextCellValue(r.worker.name));
    for (var d = 1; d <= days; d++) {
      final date = DateTime(month.year, month.month, d);
      final rec = byDate[dateKey(date)];
      String label = '';
      if (rec != null) {
        label = rec.status;
      } else if (d >= r.startDay && r.worker.weeklyOff.contains(date.weekday)) {
        label = 'W';
      } else if (d >= r.startDay && state.holidayOn(date) != null) {
        label = 'HD';
      }
      if (label.isNotEmpty) {
        _put(att, 1 + d, arow, TextCellValue(label));
      }
    }
    _put(att, 2 + days, arow, IntCellValue(r.present));
    _put(att, 3 + days, arow, IntCellValue(r.half));
    _put(att, 4 + days, arow, IntCellValue(r.leave));
    _put(att, 5 + days, arow, IntCellValue(r.absent));
    _put(att, 6 + days, arow, DoubleCellValue(r.otHours));
    arow++;
  }
  _put(att, 0, arow + 1,
      TextCellValue('P Present   H Half day   L Leave   A Absent   W Weekly off   '
          'HD Company holiday'));

  att.setColumnWidth(1, 24);

  excel.setDefaultSheet('Salary');
  final bytes = excel.save();
  if (bytes == null) {
    throw StateError('Could not create the Excel file.');
  }
  return Uint8List.fromList(bytes);
}
