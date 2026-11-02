import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

/// PDF theme using Windows fonts, so Latin, Cyrillic, Greek and Armenian
/// text print correctly. Falls back to the built-in font if none is found.
pw.ThemeData loadPdfTheme() {
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';

  pw.Font? load(String file) {
    final f = File('$windir\\Fonts\\$file');
    if (!f.existsSync()) return null;
    return pw.Font.ttf(ByteData.sublistView(f.readAsBytesSync()));
  }

  final base = load('segoeui.ttf') ?? load('arial.ttf');
  if (base == null) return pw.ThemeData.base();

  final bold = load('segoeuib.ttf') ?? load('arialbd.ttf') ?? base;
  final fallback = <pw.Font?>[
    load('seguisym.ttf'),
    load('arial.ttf'),
    load('nirmala.ttf'),
  ].whereType<pw.Font>().toList();
  return pw.ThemeData.withFont(
    base: base,
    bold: bold,
    fontFallback: fallback,
  );
}
