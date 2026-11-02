import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF17406B);
const Color kAmber = Color(0xFFF0A93A);
const Color kMica = Color(0xFFF3F3F3);
const Color kPanel = Color(0xFFFAFAFA);
const Color kCard = Color(0xFFFFFFFF);
const Color kBorder = Color(0xFFE2E2E2);
const Color kInk = Color(0xFF1B1B1B);
const Color kMuted = Color(0xFF6B6B6B);

const Color kGreen = Color(0xFF1E8E4E);
const Color kRed = Color(0xFFC42B1C);
const Color kOrange = Color(0xFFB86E00);
const Color kBlue = Color(0xFF2563A8);

const Color kNavySoft = Color(0xFFE6EEF6);
const Color kGreenSoft = Color(0xFFE3F4EA);
const Color kRedSoft = Color(0xFFFBE7E5);
const Color kOrangeSoft = Color(0xFFFCF0DC);
const Color kBlueSoft = Color(0xFFE3EDF8);
const Color kGreySoft = Color(0xFFEDEDED);

const TextStyle kTitle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: kInk,
);

const TextStyle kSubtle = TextStyle(fontSize: 13, color: kMuted);

Color statusColor(String s) => switch (s) {
      'P' => kGreen,
      'A' => kRed,
      'H' => kOrange,
      'L' => kBlue,
      _ => kMuted,
    };

Color statusSoft(String s) => switch (s) {
      'P' => kGreenSoft,
      'A' => kRedSoft,
      'H' => kOrangeSoft,
      'L' => kBlueSoft,
      _ => kGreySoft,
    };

String statusName(String s) => switch (s) {
      'P' => 'Present',
      'A' => 'Absent',
      'H' => 'Half day',
      'L' => 'Leave',
      _ => 'Not marked',
    };

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kNavy,
    brightness: Brightness.light,
  ).copyWith(
    primary: kNavy,
    onPrimary: Colors.white,
    secondary: kAmber,
    surface: kPanel,
    onSurface: kInk,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kMica,
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.compact,
  );
}
