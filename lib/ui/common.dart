import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../models.dart';
import '../theme.dart';

const List<String> kWeekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> kWeekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String fmtNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String fmtMoney(double v, String currency) {
  final f = v == v.roundToDouble()
      ? NumberFormat('#,##0')
      : NumberFormat('#,##0.00');
  return '$currency${f.format(v)}';
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', ''));

String? requiredValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

String? timeValidator(String? v) =>
    parseHm(v ?? '') == null ? 'Use HH:mm (e.g. 08:00)' : null;

String? intValidator(String? v) {
  final n = int.tryParse((v ?? '').trim());
  if (n == null || n < 0) return 'Enter a whole number';
  return null;
}

String? numberValidator(String? v) {
  final n = parseNum(v ?? '');
  if (n == null || n < 0) return 'Enter a number';
  return null;
}

InputDecoration fieldDec(
  String label, {
  String? hint,
  String? prefix,
  String? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    suffixText: suffix,
    isDense: true,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// White rounded card used for every section.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

class PanelTitle extends StatelessWidget {
  const PanelTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: kSubtle),
          ],
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class WorkerAvatar extends StatelessWidget {
  const WorkerAvatar({super.key, required this.worker, this.size = 40});

  final Worker worker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = worker.photoPath;
    ImageProvider? img;
    if (path != null && File(path).existsSync()) {
      img = FileImage(File(path));
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: kNavySoft,
      foregroundImage: img,
      child: Text(
        worker.initials,
        style: TextStyle(
          color: kNavy,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class WeekdayChips extends StatelessWidget {
  const WeekdayChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var d = 1; d <= 7; d++)
          FilterChip(
            label: Text(kWeekdayShort[d - 1]),
            selected: selected.contains(d),
            onSelected: (v) {
              final next = {...selected};
              if (v) {
                next.add(d);
              } else {
                next.remove(d);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// The Muster logo: navy rounded square with a white "M" and amber stroke.
class MusterLogo extends StatelessWidget {
  const MusterLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 60, 60),
        const Radius.circular(14),
      ),
      Paint()..color = kNavy,
    );

    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = Path()
      ..moveTo(18, 47)
      ..lineTo(18, 18)
      ..lineTo(32, 38);
    final right = Path()
      ..moveTo(46, 47)
      ..lineTo(46, 18);
    final diagonal = Path()
      ..moveTo(32, 38)
      ..lineTo(46, 18);

    canvas.drawPath(left, stroke(Colors.white));
    canvas.drawPath(right, stroke(Colors.white));
    canvas.drawPath(diagonal, stroke(kAmber));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
