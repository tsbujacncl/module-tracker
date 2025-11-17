class DateUtils {
  /// Calculate week number from semester start date
  static int getWeekNumber(DateTime date, DateTime semesterStart) {
    final startOfWeek = _getStartOfWeek(semesterStart);
    final currentWeekStart = _getStartOfWeek(date);
    final difference = currentWeekStart.difference(startOfWeek).inDays;
    return (difference / 7).floor() + 1;
  }

  /// Check if a date falls within any of the given breaks
  static bool isDateInBreak(DateTime date, List<dynamic> breaks) {
    if (breaks.isEmpty) return false;

    final dateOnly = DateTime(date.year, date.month, date.day);

    for (final breakItem in breaks) {
      // Handle both SemesterBreak objects and maps
      final DateTime breakStart;
      final DateTime breakEnd;

      if (breakItem is Map) {
        breakStart = breakItem['startDate'] is DateTime
            ? breakItem['startDate']
            : DateTime.parse(breakItem['startDate']);
        breakEnd = breakItem['endDate'] is DateTime
            ? breakItem['endDate']
            : DateTime.parse(breakItem['endDate']);
      } else {
        // Assume it's a SemesterBreak object with startDate and endDate properties
        breakStart = (breakItem as dynamic).startDate;
        breakEnd = (breakItem as dynamic).endDate;
      }

      final startOnly = DateTime(breakStart.year, breakStart.month, breakStart.day);
      final endOnly = DateTime(breakEnd.year, breakEnd.month, breakEnd.day);

      if ((dateOnly.isAtSameMomentAs(startOnly) || dateOnly.isAfter(startOnly)) &&
          (dateOnly.isAtSameMomentAs(endOnly) || dateOnly.isBefore(endOnly))) {
        return true;
      }
    }

    return false;
  }

  /// Check if a given week number falls within any break
  static bool isWeekInBreak(int weekNumber, DateTime semesterStart, List<dynamic> breaks) {
    if (breaks.isEmpty) return false;

    final weekStart = getDateForWeek(weekNumber, semesterStart);
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Check if any day of the week falls within a break
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (isDateInBreak(day, breaks)) {
        return true;
      }
    }

    return false;
  }

  /// Get the Monday of the current week for a given date
  static DateTime _getStartOfWeek(DateTime date) {
    final dayOfWeek = date.weekday; // Monday = 1, Sunday = 7
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: dayOfWeek - 1));
  }

  /// Get start of week (Monday) for a given date
  static DateTime getMonday(DateTime date) {
    return _getStartOfWeek(date);
  }

  /// Get end of week (Sunday) for a given date
  static DateTime getSunday(DateTime date) {
    return _getStartOfWeek(date).add(const Duration(days: 6));
  }

  /// Get Saturday of the week for a given date
  static DateTime getSaturday(DateTime date) {
    return _getStartOfWeek(date).add(const Duration(days: 5));
  }

  /// Get date for a specific week number in a semester
  static DateTime getDateForWeek(int weekNumber, DateTime semesterStart) {
    final startOfWeek = _getStartOfWeek(semesterStart);
    return startOfWeek.add(Duration(days: (weekNumber - 1) * 7));
  }

  /// Check if a date falls within a semester
  static bool isDateInSemester(
      DateTime date, DateTime semesterStart, DateTime semesterEnd) {
    return date.isAfter(semesterStart.subtract(const Duration(days: 1))) &&
        date.isBefore(semesterEnd.add(const Duration(days: 1)));
  }

  /// Calculate number of weeks between two dates
  static int calculateWeeksBetween(DateTime start, DateTime end) {
    final startOfFirstWeek = _getStartOfWeek(start);
    final endOfLastWeek = getSunday(end);
    final difference = endOfLastWeek.difference(startOfFirstWeek).inDays;
    return (difference / 7).ceil();
  }

  /// Get all dates for a specific week
  static List<DateTime> getDatesForWeek(DateTime weekStart) {
    final monday = _getStartOfWeek(weekStart);
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if two dates are in the same week
  static bool isSameWeek(DateTime date1, DateTime date2) {
    return _getStartOfWeek(date1) == _getStartOfWeek(date2);
  }

  /// Format date as "Mon 22nd" (day name + ordinal date)
  static String formatDayWithOrdinal(DateTime date) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[date.weekday - 1];
    final day = date.day;
    final ordinal = _getOrdinalSuffix(day);
    return '$dayName $day$ordinal';
  }

  /// Get ordinal suffix for a day (1st, 2nd, 3rd, 4th, etc.)
  static String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}