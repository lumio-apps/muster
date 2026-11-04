import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muster/import_workers.dart';
import 'package:muster/models.dart';
import 'package:muster/xlsx_reader.dart';

ImportPreview preview(
  List<List<String>> rows, {
  List<String> existing = const <String>[],
}) {
  return buildImportPreview(
    rows,
    existingNames: existing,
    today: DateTime(2026, 11, 2),
  );
}

void main() {
  group('CSV reading', () {
    test('commas, quotes and Windows line endings', () {
      final rows = parseCsv('Name,Role\r\n"Doe, John","say ""hi"""\r\n');
      expect(rows, [
        ['Name', 'Role'],
        ['Doe, John', 'say "hi"'],
      ]);
    });

    test('semicolon files and a BOM', () {
      final rows = parseCsv('﻿Name;Rate\nAnna;500\n');
      expect(rows, [
        ['Name', 'Rate'],
        ['Anna', '500'],
      ]);
    });

    test('last row without a line ending is kept', () {
      expect(parseCsv('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
  });

  group('dates and numbers', () {
    test('accepted date formats', () {
      expect(parseImportDate('2026-01-15'), DateTime(2026, 1, 15));
      expect(parseImportDate('15.01.2026'), DateTime(2026, 1, 15));
      expect(parseImportDate('15/01/2026'), DateTime(2026, 1, 15));
      expect(parseImportDate('15-01-2026'), DateTime(2026, 1, 15));
      expect(parseImportDate('46000'), DateTime(2025, 12, 9));
    });

    test('invalid dates are rejected', () {
      expect(parseImportDate('2026-02-30'), isNull);
      expect(parseImportDate('hello'), isNull);
      expect(parseImportDate(''), isNull);
    });

    test('numbers with separators', () {
      expect(parseImportNumber('1,200'), 1200);
      expect(parseImportNumber(' 1 500.5 '), 1500.5);
      expect(parseImportNumber('abc'), isNull);
    });
  });

  group('worker import', () {
    test('reads a full row', () {
      final p = preview(parseCsv(kSampleWorkersCsv));
      expect(p.errors, isEmpty);
      expect(p.workers.length, 3);
      final a = p.workers[0];
      expect(a.name, 'Rahul Sharma');
      expect(a.payType, PayType.daily);
      expect(a.rate, 600);
      expect(a.joinedOn, DateTime(2026, 1, 15));
      expect(a.otMultiplier, 1.5);
      expect(p.workers[1].payType, PayType.monthly);
      expect(p.workers[2].payType, PayType.hourly);
      expect(p.workers[2].otMultiplier, 2);
    });

    test('only Name and Rate are needed', () {
      final p = preview([
        ['name', 'RATE'],
        ['Sam', '450'],
      ]);
      final w = p.workers.single;
      expect(w.payType, PayType.daily);
      expect(w.joinedOn, DateTime(2026, 11, 2));
      expect(w.role, '');
    });

    test('missing Rate column gives a clear problem', () {
      final p = preview([
        ['Name', 'Role'],
        ['Sam', 'x'],
      ]);
      expect(p.headerProblem, isNotNull);
      expect(p.workers, isEmpty);
    });

    test('empty file', () {
      expect(preview(<List<String>>[]).headerProblem, isNotNull);
    });

    test('bad rows are skipped with a reason, good rows are kept', () {
      final p = preview([
        ['Name', 'Pay type', 'Rate', 'Joined on'],
        ['Good', 'daily', '500', ''],
        ['', 'daily', '500', ''],
        ['NoRate', 'daily', 'abc', ''],
        ['BadType', 'weekly', '500', ''],
        ['BadDate', 'daily', '500', '31.02.2026'],
      ]);
      expect(p.workers.map((w) => w.name), ['Good']);
      expect(p.errors.map((e) => e.line), [3, 4, 5, 6]);
    });

    test('duplicates in the file and in the app are skipped', () {
      final p = preview(
        [
          ['Name', 'Rate'],
          ['Anna', '100'],
          ['anna', '100'],
          ['Karen', '100'],
        ],
        existing: ['KAREN'],
      );
      expect(p.workers.map((w) => w.name), ['Anna']);
      expect(p.errors.length, 2);
    });
  });

  group('Excel reading', () {
    Uint8List xlsx() {
      const shared = '<sst><si><t>Name</t></si><si><t>Rate</t></si>'
          '<si><t>Role</t></si><si><t>Tom &amp; Jerry</t></si></sst>';
      const sheet = '<worksheet><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c>'
          '<c r="C1" t="s"><v>2</v></c></row>'
          '<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>600.0</v></c>'
          '<c r="D2"><v>46000</v></c></row>'
          '</sheetData></worksheet>';
      final a = Archive();
      final s1 = utf8.encode(shared);
      final s2 = utf8.encode(sheet);
      a.addFile(ArchiveFile('xl/sharedStrings.xml', s1.length, s1));
      a.addFile(ArchiveFile('xl/worksheets/sheet1.xml', s2.length, s2));
      return Uint8List.fromList(ZipEncoder().encode(a)!);
    }

    test('reads text, numbers and gaps', () {
      final rows = readXlsxFirstSheet(xlsx());
      expect(rows[0], ['Name', 'Rate', 'Role']);
      expect(rows[1], ['Tom & Jerry', '600', '', '46000']);
    });

    test('rows from Excel feed the import', () {
      final p = preview(readXlsxFirstSheet(xlsx()));
      expect(p.workers.single.name, 'Tom & Jerry');
      expect(p.workers.single.rate, 600);
    });
  });
}
