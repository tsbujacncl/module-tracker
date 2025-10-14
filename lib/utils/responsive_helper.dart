import 'package:flutter/material.dart';

enum ScreenSize { extraSmall, small, medium, large }

class ResponsiveHelper {
  /// Detect screen size category based on height
  static ScreenSize getScreenSize(double height) {
    if (height < 700) return ScreenSize.extraSmall;
    if (height < 800) return ScreenSize.small;
    if (height < 850) return ScreenSize.medium;
    return ScreenSize.large;
  }

  /// Get logo size based on screen size
  static double getLogoSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 70.0;
      case ScreenSize.small:
        return 80.0;
      case ScreenSize.medium:
        return 90.0;
      case ScreenSize.large:
        return 120.0;
    }
  }

  /// Check if header should be horizontal (logo + title on same line)
  static bool useHorizontalHeader(ScreenSize size) {
    return false; // Always use vertical layout
  }

  /// Get title font size
  static double getTitleFontSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 28.0;
      case ScreenSize.small:
        return 30.0;
      case ScreenSize.medium:
        return 32.0;
      case ScreenSize.large:
        return 36.0;
    }
  }

  /// Get subtitle font size
  static double getSubtitleFontSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 12.0;
      case ScreenSize.small:
        return 13.0;
      case ScreenSize.medium:
        return 14.0;
      case ScreenSize.large:
        return 16.0;
    }
  }

  /// Get "Welcome Back!" title size
  static double getWelcomeTitleSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 18.0;
      case ScreenSize.small:
        return 19.0;
      case ScreenSize.medium:
        return 20.0;
      case ScreenSize.large:
        return 24.0;
    }
  }

  /// Get button vertical padding
  static double getButtonVerticalPadding(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 10.0;
      case ScreenSize.small:
        return 11.0;
      case ScreenSize.medium:
        return 12.0;
      case ScreenSize.large:
        return 16.0;
    }
  }

  /// Get button font size
  static double getButtonFontSize(ScreenSize size) {
    return (size == ScreenSize.extraSmall || size == ScreenSize.small || size == ScreenSize.medium) ? 15.0 : 16.0;
  }

  /// Get card padding
  static double getCardPadding(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 14.0;
      case ScreenSize.small:
        return 16.0;
      case ScreenSize.medium:
        return 18.0;
      case ScreenSize.large:
        return 28.0;
    }
  }

  /// Get outer padding
  static double getOuterPadding(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return 10.0;
      case ScreenSize.small:
        return 12.0;
      case ScreenSize.medium:
        return 14.0;
      case ScreenSize.large:
        return 24.0;
    }
  }

  /// Get spacing values for different contexts
  static double getSpacing(String type, ScreenSize size) {
    final Map<String, List<double>> spacingMap = {
      'logo_to_title': [8, 10, 12, 32],
      'title_to_subtitle': [4, 4, 6, 8],
      'subtitle_to_card': [16, 18, 20, 48],
      'welcome_to_form': [12, 14, 16, 24],
      'field_gap': [8, 9, 10, 16],
      'field_to_button': [12, 14, 16, 24],
      'button_gap': [6, 7, 8, 12],
      'divider_spacing': [12, 14, 16, 24],
      'social_button_gap': [6, 7, 8, 12],
    };

    final values = spacingMap[type] ?? [16, 16, 16, 16];
    return values[size.index];
  }

  /// Get text field content padding
  static EdgeInsets getTextFieldPadding(ScreenSize size) {
    switch (size) {
      case ScreenSize.extraSmall:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
      case ScreenSize.small:
        return const EdgeInsets.symmetric(horizontal: 13, vertical: 11);
      case ScreenSize.medium:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
      case ScreenSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    }
  }

  /// Get text field font size
  static double getTextFieldFontSize(ScreenSize size) {
    return (size == ScreenSize.extraSmall || size == ScreenSize.small || size == ScreenSize.medium) ? 15.0 : 16.0;
  }

  /// Get logo border radius for compact mode
  static double getLogoBorderRadius(ScreenSize size) {
    return useHorizontalHeader(size) ? 12.0 : 20.0;
  }

  /// Get icon size inside logo
  static double getLogoIconSize(ScreenSize size) {
    return getLogoSize(size) * 0.5;
  }
}
