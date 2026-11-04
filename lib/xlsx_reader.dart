import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads the first sheet of an .xlsx file as rows of text.
/// Handles shared strings, inline strings, numbers and booleans. Dates come
/// back as Excel date numbers, which the worker import understands.
List<List<String>> readXlsxFirstSheet(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  String? textOf(String path) {
    for (final f in archive) {
      if (f.isFile && f.name == path) {
        return utf8.decode(f.content as List<int>, allowMalformed: true);
      }
    }
    return null;
  }

  final shared = <String>[];
  final ss = textOf('xl/sharedStrings.xml');
  if (ss != null) {
    for (final m in RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true)
        .allMatches(ss)) {
      shared.add(_joinText(m.group(1)!));
    }
  }

  var sheetPath = 'xl/worksheets/sheet1.xml';
  if (textOf(sheetPath) == null) {
    final names = <String>[
      for (final f in archive)
        if (f.isFile &&
            f.name.startsWith('xl/worksheets/sheet') &&
            f.name.endsWith('.xml'))
          f.name,
    ]..sort();
    if (names.isEmpty) return <List<String>>[];
    sheetPath = names.first;
  }
  final sheet = textOf(sheetPath) ?? '';

  final rows = <List<String>>[];
  for (final rm
      in RegExp(r'<row\b[^>]*?(?:/>|>(.*?)</row>)', dotAll: true)
          .allMatches(sheet)) {
    final body = rm.group(1) ?? '';
    final cells = <int, String>{};
    var next = 0;
    for (final cm in RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true)
        .allMatches(body)) {
      final attrs = cm.group(1) ?? '';
      final inner = cm.group(2) ?? '';
      final ref = RegExp(r'\br="([A-Z]+)\d+"').firstMatch(attrs);
      final index = ref == null ? next : _columnIndex(ref.group(1)!);
      next = index + 1;
      final type = RegExp(r'\bt="(\w+)"').firstMatch(attrs)?.group(1);

      String value = '';
      if (type == 'inlineStr') {
        value = _joinText(inner);
      } else {
        final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(inner);
        final raw = v == null ? '' : _unescape(v.group(1)!);
        if (type == 's') {
          final i = int.tryParse(raw.trim());
          value = (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
        } else if (type == 'b') {
          value = raw.trim() == '1' ? 'TRUE' : 'FALSE';
        } else {
          value = _cleanNumber(raw);
        }
      }
      cells[index] = value;
    }
    if (cells.isEmpty) {
      rows.add(<String>[]);
      continue;
    }
    final width = cells.keys.reduce((a, b) => a > b ? a : b) + 1;
    rows.add(<String>[for (var i = 0; i < width; i++) cells[i] ?? '']);
  }
  return rows;
}

int _columnIndex(String letters) {
  var n = 0;
  for (final c in letters.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

String _joinText(String xml) {
  final b = StringBuffer();
  for (final m in RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(xml)) {
    b.write(_unescape(m.group(1)!));
  }
  return b.toString();
}

/// "600.0" becomes "600". Long decimals and exponents are left alone.
String _cleanNumber(String raw) {
  final s = raw.trim();
  if (RegExp(r'^-?\d+\.0+$').hasMatch(s)) {
    return s.substring(0, s.indexOf('.'));
  }
  return s;
}

String _unescape(String s) {
  return s
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        return String.fromCharCode(int.parse(m.group(1)!));
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
      })
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
