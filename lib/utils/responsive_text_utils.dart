import 'package:flutter/material.dart';

/// Utility class for responsive text sizing based on screen width
class ResponsiveText {
  /// Calculate responsive font size multiplier based on screen width
  /// For larger screens (desktop), text should scale up proportionally
  ///
  /// Width ranges:
  /// - < 600px: Mobile (1.0x base)
  /// - 600-900px: Tablet (1.0-1.1x)
  /// - 900-1200px: Small Desktop (1.1-1.25x)
  /// - 1200-1600px: Medium Desktop (1.25-1.4x)
  /// - 1600-2000px: Large Desktop (1.4-1.55x)
  /// - > 2000px: Ultra-wide (1.55-1.7x)
  static double getFontScale(double screenWidth) {
    if (screenWidth < 600) {
      return 1.0; // Mobile - base size
    } else if (screenWidth < 900) {
      // Tablet: 1.0x → 1.1x
      final progress = (screenWidth - 600) / 300;
      return 1.0 + (0.1 * progress);
    } else if (screenWidth < 1200) {
      // Small Desktop: 1.1x → 1.25x
      final progress = (screenWidth - 900) / 300;
      return 1.1 + (0.15 * progress);
    } else if (screenWidth < 1600) {
      // Medium Desktop: 1.25x → 1.4x
      final progress = (screenWidth - 1200) / 400;
      return 1.25 + (0.15 * progress);
    } else if (screenWidth < 2000) {
      // Large Desktop: 1.4x → 1.55x
      final progress = (screenWidth - 1600) / 400;
      return 1.4 + (0.15 * progress);
    } else {
      // Ultra-wide: 1.55x → 1.7x (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 1.55 + (0.15 * progress);
    }
  }

  /// Get responsive font size for titles (e.g., "Module Tracker")
  /// Base size is 28-40, scaled up more aggressively for large screens
  static double getTitleFontSize(double screenWidth) {
    if (screenWidth < 600) {
      return 28.0;
    } else if (screenWidth < 900) {
      // 28 → 32
      final progress = (screenWidth - 600) / 300;
      return 28.0 + (4.0 * progress);
    } else if (screenWidth < 1200) {
      // 32 → 38
      final progress = (screenWidth - 900) / 300;
      return 32.0 + (6.0 * progress);
    } else if (screenWidth < 1600) {
      // 38 → 46
      final progress = (screenWidth - 1200) / 400;
      return 38.0 + (8.0 * progress);
    } else if (screenWidth < 2000) {
      // 46 → 52
      final progress = (screenWidth - 1600) / 400;
      return 46.0 + (6.0 * progress);
    } else {
      // 52 → 56 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 52.0 + (4.0 * progress);
    }
  }

  /// Get responsive font size for subtitles (e.g., week info, semester name)
  /// Base size is 13-16, scaled up for large screens
  static double getSubtitleFontSize(double screenWidth) {
    if (screenWidth < 600) {
      return 13.0;
    } else if (screenWidth < 900) {
      // 13 → 15
      final progress = (screenWidth - 600) / 300;
      return 13.0 + (2.0 * progress);
    } else if (screenWidth < 1200) {
      // 15 → 18
      final progress = (screenWidth - 900) / 300;
      return 15.0 + (3.0 * progress);
    } else if (screenWidth < 1600) {
      // 18 → 21
      final progress = (screenWidth - 1200) / 400;
      return 18.0 + (3.0 * progress);
    } else if (screenWidth < 2000) {
      // 21 → 24
      final progress = (screenWidth - 1600) / 400;
      return 21.0 + (3.0 * progress);
    } else {
      // 24 → 26 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 24.0 + (2.0 * progress);
    }
  }

  /// Get responsive font size for week navigation subtitle (semester name)
  /// Slightly more conservative than general subtitle to prevent overflow
  static double getWeekNavigationSubtitleFontSize(double screenWidth) {
    if (screenWidth < 600) {
      return 11.0; // Slightly smaller base
    } else if (screenWidth < 900) {
      // 11 → 13
      final progress = (screenWidth - 600) / 300;
      return 11.0 + (2.0 * progress);
    } else if (screenWidth < 1200) {
      // 13 → 15
      final progress = (screenWidth - 900) / 300;
      return 13.0 + (2.0 * progress);
    } else if (screenWidth < 1600) {
      // 15 → 17
      final progress = (screenWidth - 1200) / 400;
      return 15.0 + (2.0 * progress);
    } else if (screenWidth < 2000) {
      // 17 → 19
      final progress = (screenWidth - 1600) / 400;
      return 17.0 + (2.0 * progress);
    } else {
      // 19 → 20 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 19.0 + (1.0 * progress);
    }
  }

  /// Get responsive font size for section headers (e.g., "This Week's Tasks")
  /// Base size is 18-20, scaled up for large screens
  static double getSectionHeaderFontSize(double screenWidth) {
    final baseFontSize = screenWidth < 400
        ? 15.0
        : screenWidth < 600
            ? 18.0
            : 20.0;

    // Apply additional scaling for larger screens
    final scale = getFontScale(screenWidth);

    // Add 10% as requested by user
    return baseFontSize * scale * 1.1;
  }

  /// Get font weight for section headers
  /// Returns a slightly bolder weight for larger screens
  /// User requested 10% bolder
  static FontWeight getSectionHeaderFontWeight(double screenWidth) {
    // Base is w600 (600), increase to w700 (700) - approximately 17% increase
    // which is more than the requested 10% to ensure visibility
    return FontWeight.w700;
  }

  /// Get responsive font size for calendar day headers (Mon, Tue, etc.)
  static double getCalendarDayHeaderFontSize(double screenWidth) {
    if (screenWidth < 600) {
      return 12.0;
    } else if (screenWidth < 900) {
      // 12 → 14
      final progress = (screenWidth - 600) / 300;
      return 12.0 + (2.0 * progress);
    } else if (screenWidth < 1200) {
      // 14 → 16
      final progress = (screenWidth - 900) / 300;
      return 14.0 + (2.0 * progress);
    } else if (screenWidth < 1600) {
      // 16 → 18
      final progress = (screenWidth - 1200) / 400;
      return 16.0 + (2.0 * progress);
    } else {
      // 18 → 20 (capped at 2000px)
      final progress = ((screenWidth - 1600) / 400).clamp(0.0, 1.0);
      return 18.0 + (2.0 * progress);
    }
  }

  /// Get responsive font size for calendar event module codes
  /// More conservative scaling to prevent overflow in calendar boxes
  static double getCalendarModuleCodeFontSize(double screenWidth) {
    if (screenWidth < 600) {
      return 9.0; // Smaller base for mobile
    } else if (screenWidth < 900) {
      // 9 → 10
      final progress = (screenWidth - 600) / 300;
      return 9.0 + (1.0 * progress);
    } else if (screenWidth < 1200) {
      // 10 → 12
      final progress = (screenWidth - 900) / 300;
      return 10.0 + (2.0 * progress);
    } else if (screenWidth < 1600) {
      // 12 → 14
      final progress = (screenWidth - 1200) / 400;
      return 12.0 + (2.0 * progress);
    } else if (screenWidth < 2000) {
      // 14 → 15
      final progress = (screenWidth - 1600) / 400;
      return 14.0 + (1.0 * progress);
    } else {
      // 15 → 16 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 15.0 + (1.0 * progress);
    }
  }

  /// Get responsive font size for calendar event type (Lecture, Lab, etc.)
  /// More conservative scaling to prevent overflow in calendar boxes
  static double getCalendarEventTypeFontSize(double screenWidth) {
    if (screenWidth < 600) {
      return 10.0; // Slightly larger than module code for readability
    } else if (screenWidth < 900) {
      // 10 → 11
      final progress = (screenWidth - 600) / 300;
      return 10.0 + (1.0 * progress);
    } else if (screenWidth < 1200) {
      // 11 → 13
      final progress = (screenWidth - 900) / 300;
      return 11.0 + (2.0 * progress);
    } else if (screenWidth < 1600) {
      // 13 → 14
      final progress = (screenWidth - 1200) / 400;
      return 13.0 + (1.0 * progress);
    } else if (screenWidth < 2000) {
      // 14 → 15
      final progress = (screenWidth - 1600) / 400;
      return 14.0 + (1.0 * progress);
    } else {
      // 15 → 16 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 15.0 + (1.0 * progress);
    }
  }

  /// Get responsive font size for task items in module cards
  /// Includes 10% increase as requested
  static double getTaskItemFontSize(double screenWidth, double? baseFontSize) {
    final base = baseFontSize ?? 16.0;
    final scale = getFontScale(screenWidth);

    // Add 10% as requested by user
    return base * scale * 1.1;
  }

  /// Get responsive checkbox size for calendar events
  /// Scales aggressively from small on mobile to much larger on desktop
  static double getCalendarCheckboxSize(double screenWidth) {
    if (screenWidth < 600) {
      return 10.0; // Mobile
    } else if (screenWidth < 900) {
      // 10 → 14
      final progress = (screenWidth - 600) / 300;
      return 10.0 + (4.0 * progress);
    } else if (screenWidth < 1200) {
      // 14 → 18
      final progress = (screenWidth - 900) / 300;
      return 14.0 + (4.0 * progress);
    } else if (screenWidth < 1600) {
      // 18 → 24
      final progress = (screenWidth - 1200) / 400;
      return 18.0 + (6.0 * progress);
    } else if (screenWidth < 2000) {
      // 24 → 28
      final progress = (screenWidth - 1600) / 400;
      return 24.0 + (4.0 * progress);
    } else {
      // 28 → 32 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 28.0 + (4.0 * progress);
    }
  }

  /// Get responsive checkbox size for task items
  /// Scales aggressively from medium on mobile to much larger on desktop
  static double getTaskCheckboxSize(double screenWidth) {
    if (screenWidth < 600) {
      return 18.0; // Mobile - larger than calendar for easier tapping
    } else if (screenWidth < 900) {
      // 18 → 22
      final progress = (screenWidth - 600) / 300;
      return 18.0 + (4.0 * progress);
    } else if (screenWidth < 1200) {
      // 22 → 26
      final progress = (screenWidth - 900) / 300;
      return 22.0 + (4.0 * progress);
    } else if (screenWidth < 1600) {
      // 26 → 32
      final progress = (screenWidth - 1200) / 400;
      return 26.0 + (6.0 * progress);
    } else if (screenWidth < 2000) {
      // 32 → 36
      final progress = (screenWidth - 1600) / 400;
      return 32.0 + (4.0 * progress);
    } else {
      // 36 → 40 (capped at 2400px)
      final progress = ((screenWidth - 2000) / 400).clamp(0.0, 1.0);
      return 36.0 + (4.0 * progress);
    }
  }
}
