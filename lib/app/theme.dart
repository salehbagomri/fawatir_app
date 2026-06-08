import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color accent = Color(0xFF1F3A5F);
  static const Color dark = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFF6B7280);
  static const Color line = Color(0xFFE6E8EB);
  static const Color zebra = Color(0xFFF7F8FA);
}

ThemeData getAppTheme() {
  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.dark,
    ),
    scaffoldBackgroundColor: Colors.white,
    dividerColor: AppColors.line,
  );

  return baseTheme.copyWith(
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(baseTheme.textTheme).copyWith(
      bodyLarge: GoogleFonts.ibmPlexSansArabic(textStyle: baseTheme.textTheme.bodyLarge?.copyWith(color: AppColors.dark)),
      bodyMedium: GoogleFonts.ibmPlexSansArabic(textStyle: baseTheme.textTheme.bodyMedium?.copyWith(color: AppColors.dark)),
      titleLarge: GoogleFonts.ibmPlexSansArabic(textStyle: baseTheme.textTheme.titleLarge?.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
    ),
  );
}
