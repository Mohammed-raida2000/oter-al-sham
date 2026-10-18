import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary = Color(0xFF4B3A5A);

ThemeData buildTheme(Brightness b) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, brightness: b),
  );
  return base.copyWith(
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF17131B) : const Color(0xFFF8F6F3),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    cardTheme: CardThemeData(elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: base.colorScheme.outlineVariant))),
  );
}
