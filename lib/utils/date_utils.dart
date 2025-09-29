class DateUtils {
  /// Calculate week number from semester start date
  static int getWeekNumber(DateTime date, DateTime semesterStart) {
    final startOfWeek = _getStartOfWeek(semesterStart);
    final currentWeekStart = _getStartOfWeek(date);
    final difference = currentWeekStart.difference(startOfWeek).inDays;
    return (difference / 7).floor() + 1;
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
}