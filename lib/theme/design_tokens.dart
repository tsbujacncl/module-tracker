import 'package:flutter/material.dart';

/// Design tokens for consistent styling across the app
class DesignTokens {
  // Prevent instantiation
  DesignTokens._();

  // ==================== COLORS ====================

  /// Brand gradient colors
  static const Color primaryBlue = Color(0xFF0EA5E9);
  static const Color secondaryCyan = Color(0xFF06B6D4);
  static const Color tertiaryGreen = Color(0xFF10B981);

  /// Dark mode brand colors
  static const Color primaryBlueDark = Color(0xFF38BDF8);
  static const Color secondaryCyanDark = Color(0xFF22D3EE);
  static const Color tertiaryGreenDark = Color(0xFF34D399);

  /// Accent colors
  static const Color purple = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color pink = Color(0xFFEC4899);
  static const Color orange = Color(0xFFF97316);

  /// Task type colors
  static const Color lectureBlue = Color(0xFF3B82F6);
  static const Color labGreen = Color(0xFF10B981);
  static const Color tutorialGreen = Color(0xFF10B981);
  static const Color flashcardPurple = Color(0xFF8B5CF6);
  static const Color assessmentRed = Color(0xFFEF4444);

  /// Background colors - Light mode
  static const Color backgroundLight = Color(0xFFF0F9FF);
  static const Color surfaceLight = Colors.white;
  static const Color cardLight = Colors.white;
  static const Color headerBackgroundLight = Color(0xFFF0F9FF);

  /// Background colors - Dark mode
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color headerBackgroundDark = Color(0xFF334155);

  /// Border colors
  static const Color borderLight = Color(0xFFE0F2FE);
  static const Color borderDark = Color(0xFF334155);

  /// Text colors - Light mode
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  /// Text colors - Dark mode
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // ==================== GRADIENTS ====================

  /// Primary brand gradient (Blue → Cyan)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, secondaryCyan],
  );

  /// Full brand gradient (Blue → Cyan → Green)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryBlue, secondaryCyan, tertiaryGreen],
  );

  /// Subtle gradient for backgrounds
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== SPACING ====================

  /// Extra small spacing (4px)
  static const double spaceXS = 4.0;

  /// Small spacing (8px)
  static const double spaceS = 8.0;

  /// Medium spacing (12px)
  static const double spaceM = 12.0;

  /// Large spacing (16px)
  static const double spaceL = 16.0;

  /// Extra large spacing (24px)
  static const double spaceXL = 24.0;

  /// Extra extra large spacing (32px)
  static const double spaceXXL = 32.0;

  /// Huge spacing (48px)
  static const double spaceHuge = 48.0;

  // ==================== BORDER RADIUS ====================

  /// Small radius (4px) - for chips, tags
  static const double radiusXS = 4.0;

  /// Small radius (6px) - for small buttons
  static const double radiusS = 6.0;

  /// Medium radius (8px) - for inputs, tiles
  static const double radiusM = 8.0;

  /// Large radius (12px) - for buttons, cards
  static const double radiusL = 12.0;

  /// Extra large radius (16px) - for major cards
  static const double radiusXL = 16.0;

  /// Extra extra large radius (24px) - for prominent elements
  static const double radiusXXL = 24.0;

  // ==================== SHADOWS ====================

  /// Subtle shadow for light mode
  static List<BoxShadow> shadowLight = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  /// Medium shadow for light mode
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Strong shadow for light mode (buttons, prominent cards)
  static List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: primaryBlue.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  /// Subtle shadow for dark mode
  static List<BoxShadow> shadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  /// Medium shadow for dark mode
  static List<BoxShadow> shadowMediumDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ==================== ICON SIZES ====================

  /// Small icon (16px)
  static const double iconS = 16.0;

  /// Medium icon (20px)
  static const double iconM = 20.0;

  /// Large icon (24px)
  static const double iconL = 24.0;

  /// Extra large icon (32px)
  static const double iconXL = 32.0;

  /// Huge icon (64px)
  static const double iconHuge = 64.0;

  // ==================== HELPER METHODS ====================

  /// Get shadow based on theme brightness
  static List<BoxShadow> getShadow(Brightness brightness, {bool medium = false}) {
    if (brightness == Brightness.dark) {
      return medium ? shadowMediumDark : shadowDark;
    }
    return medium ? shadowMedium : shadowLight;
  }

  /// Get border color based on theme brightness
  static Color getBorderColor(Brightness brightness) {
    return brightness == Brightness.dark ? borderDark : borderLight;
  }

  /// Get background color based on theme brightness
  static Color getBackgroundColor(Brightness brightness) {
    return brightness == Brightness.dark ? backgroundDark : backgroundLight;
  }

  /// Get card color based on theme brightness
  static Color getCardColor(Brightness brightness) {
    return brightness == Brightness.dark ? cardDark : cardLight;
  }

  /// Get text primary color based on theme brightness
  static Color getTextPrimaryColor(Brightness brightness) {
    return brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }

  /// Get text secondary color based on theme brightness
  static Color getTextSecondaryColor(Brightness brightness) {
    return brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  }
}
