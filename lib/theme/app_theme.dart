import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primaryLight = Color(0xFF0EA5E9); // Vibrant cyan/sky blue
  static const Color secondaryLight = Color(0xFF06B6D4);
  static const Color tertiaryLight = Color(0xFF10B981);

  static const Color primaryDark = Color(0xFF38BDF8);
  static const Color secondaryDark = Color(0xFF22D3EE);
  static const Color tertiaryDark = Color(0xFF34D399);

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.light,
        primary: primaryLight,
        secondary: secondaryLight,
        tertiary: tertiaryLight,
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFE0F2FE),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0F2FE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0F2FE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        primary: primaryDark,
        secondary: secondaryDark,
        tertiary: tertiaryDark,
        surface: const Color(0xFF1E293B),
        background: const Color(0xFF0F172A),
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF0F172A),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFF1F5F9),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF1F5F9),
        ),
      ),
    );
  }
}
