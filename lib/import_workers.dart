import 'models.dart';

/// Header row of the sample file offered in the import dialog.
const String kSampleWorkersCsv = 'Name,Role,Phone,Pay type,Rate,Joined on,'
    'Overtime rate\r\n'
    'Rahul Sharma,Helper,+91 90000 00001,daily,600,2026-01-15,1.5\r\n'
    'Anna Petrosyan,Cashier,+374 99 000000,monthly,150000,2026-02-01,\r\n'
    'Karen Hakobyan,Driver,,hourly,1200,2026-03-10,2\r\n';

/// Splits CSV text into rows. Handles quotes, commas, semicolons, a BOM and
/// Windows line endings.
List<List<String>> parseCsv(String input) {
  var text = input;
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split(RegExp(r'\r?\n')).first;
  final commas = ','.allMatches(firstLine).length;
  final semis = ';'.allMatches(firstLine).length;
  final tabs = '\t'.allMatches(firstLine).length;
  var sep = ',';
  if (semis > commas && semis >= tabs) sep = ';';
  if (tabs > commas && tabs > semis) sep = '\t';

  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == sep) {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c == '\r') {
      // Ignored. The following \n ends the row.
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

class ImportRowError {
  const ImportRowError(this.line, this.message);

  /// Row number in the file (the header is row 1).
  final int line;
  final String message;
}

class ImportPreview {
  const ImportPreview({
    required this.workers,
    required this.errors,
    this.headerProblem,
  });

  /// Workers that will be added.
  final List<Worker> workers;

  /// Rows that will be skipped, with the reason.
  final List<ImportRowError> errors;

  /// Set when the file cannot be read at all, for example a missing column.
  final String? headerProblem;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

const Map<String, List<String>> _aliases = {
  'name': ['name', 'workername', 'fullname', 'employee', 'employeename'],
  'role': ['role', 'job', 'position', 'designation', 'title'],
  'phone': ['phone', 'mobile', 'phonenumber', 'contact', 'tel'],
  'paytype': ['paytype', 'type', 'payment', 'salarytype', 'wagetype'],
  'rate': ['rate', 'salary', 'wage', 'pay', 'amount', 'dailyrate'],
  'joined': [
    'joinedon',
    'joined',
    'joiningdate',
    'joindate',
    'dateofjoining',
    'startdate',
    'doj',
  ],
  'ot': ['overtimerate', 'otrate', 'otmultiplier', 'overtime', 'ot'],
};

PayType? _parsePayType(String s) {
  switch (_norm(s)) {
    case '':
    case 'daily':
    case 'day':
    case 'd':
    case 'perday':
      return PayType.daily;
    case 'monthly':
    case 'month':
    case 'm':
    case 'permonth':
      return PayType.monthly;
    case 'hourly':
    case 'hour':
    case 'h':
    case 'perhour':
      return PayType.hourly;
  }
  return null;
}

/// Reads a number such as "600", "12,000" or "1 500.50".
double? parseImportNumber(String s) {
  final t = s.trim().replaceAll(RegExp(r'[\s,]'), '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Reads a date written as yyyy-MM-dd, dd.MM.yyyy, dd/MM/yyyy, dd-MM-yyyy
/// or as an Excel date number. Returns null when it is not a valid date.
DateTime? parseImportDate(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;

  DateTime? make(int y, int m, int d) {
    if (y < 1990 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    final date = DateTime(y, m, d);
    if (date.month != m || date.day != d) return null;
    return date;
  }

  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) {
    return make(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  m = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(s);
  if (m != null) {
    return make(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }
  final serial = double.tryParse(s);
  if (serial != null && serial >= 30000 && serial <= 80000) {
    final d = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    return DateTime(d.year, d.month, d.day);
  }
  return null;
}

/// Turns the rows of a CSV or Excel file into workers.
///
/// The first row must be a header with at least a Name and a Rate column.
/// Other columns are optional. [existingNames] are skipped, so importing the
/// same file twice does not create duplicates.
ImportPreview buildImportPreview(
  List<List<String>> rows, {
  required Iterable<String> existingNames,
  required DateTime today,
  double defaultOvertime = 1.5,
}) {
  final nonEmpty = <int>[
    for (var i = 0; i < rows.length; i++)
      if (rows[i].any((c) => c.trim().isNotEmpty)) i,
  ];
  if (nonEmpty.isEmpty) {
    return const ImportPreview(
      workers: [],
      errors: [],
      headerProblem: 'The file is empty.',
    );
  }

  final header = rows[nonEmpty.first].map(_norm).toList();
  int? col(String key) {
    for (var i = 0; i < header.length; i++) {
      if (_aliases[key]!.contains(header[i])) return i;
    }
    return null;
  }

  final cName = col('name');
  final cRate = col('rate');
  if (cName == null || cRate == null) {
    return const ImportPreview(
      workers: [],
      errors: [],
      headerProblem: 'The first row must have the columns "Name" and "Rate". '
          'Use the sample file as a guide.',
    );
  }
  final cRole = col('role');
  final cPhone = col('phone');
  final cType = col('paytype');
  final cJoined = col('joined');
  final cOt = col('ot');

  String at(List<String> r, int? c) =>
      (c == null || c >= r.length) ? '' : r[c].trim();

  final seen = <String>{for (final n in existingNames) n.trim().toLowerCase()};
  final workers = <Worker>[];
  final errors = <ImportRowError>[];

  for (final i in nonEmpty.skip(1)) {
    final r = rows[i];
    final line = i + 1;
    final name = at(r, cName);
    if (name.isEmpty) {
      errors.add(ImportRowError(line, 'Name is empty.'));
      continue;
    }
    final key = name.toLowerCase();
    if (seen.contains(key)) {
      errors.add(ImportRowError(line, '"$name" already exists.'));
      continue;
    }
    final rate = parseImportNumber(at(r, cRate));
    if (rate == null || rate <= 0) {
      errors.add(ImportRowError(line, '"$name": rate must be a number above 0.'));
      continue;
    }
    final type = _parsePayType(at(r, cType));
    if (type == null) {
      errors.add(
        ImportRowError(
          line,
          '"$name": pay type must be daily, monthly or hourly.',
        ),
      );
      continue;
    }
    DateTime joined = DateTime(today.year, today.month, today.day);
    final joinedText = at(r, cJoined);
    if (joinedText.isNotEmpty) {
      final d = parseImportDate(joinedText);
      if (d == null) {
        errors.add(
          ImportRowError(
            line,
            '"$name": date "$joinedText" is not valid. Use yyyy-mm-dd.',
          ),
        );
        continue;
      }
      joined = d;
    }
    var ot = defaultOvertime;
    final otText = at(r, cOt);
    if (otText.isNotEmpty) {
      final v = parseImportNumber(otText);
      if (v == null || v < 1) {
        errors.add(
          ImportRowError(
            line,
            '"$name": overtime rate must be 1 or more (for example 1.5).',
          ),
        );
        continue;
      }
      ot = v;
    }

    seen.add(key);
    workers.add(
      Worker(
        name: name,
        role: at(r, cRole),
        phone: at(r, cPhone),
        joinedOn: joined,
        payType: type,
        rate: rate,
        otMultiplier: ot,
      ),
    );
  }

  return ImportPreview(workers: workers, errors: errors);
}
