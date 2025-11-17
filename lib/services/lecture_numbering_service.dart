import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/cancelled_event.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/utils/date_utils.dart' as date_utils;

/// Service for calculating lecture/lab/tutorial instance numbers
/// Handles sequential numbering across weeks, accounting for cancellations
class LectureNumberingService {
  /// Calculate the instance number for a recurring task in a specific week
  ///
  /// For example, if a lecture occurs on Monday every week:
  /// - Week 1: Lecture 1
  /// - Week 2: Lecture 2
  /// - Week 3 (cancelled): skipped
  /// - Week 4: Lecture 3
  ///
  /// Returns the instance number (1, 2, 3, etc.) or 0 if cancelled
  /// Counts across ALL tasks of the same type, not per-task
  static int calculateInstanceNumber({
    required RecurringTask task,
    required int targetWeekNumber,
    required List<CancelledEvent> allCancelledEvents,
    required Semester semester,
    List<RecurringTask>? allTasksOfSameType,
  }) {
    // Filter cancelled events for this specific task
    final taskCancellations = allCancelledEvents
        .where((e) => e.eventId == task.id && e.eventType == EventType.recurringTask)
        .map((e) => e.weekNumber)
        .toSet();

    // Check if the target week itself is cancelled
    if (taskCancellations.contains(targetWeekNumber)) {
      return 0; // Cancelled event
    }

    // If no list of tasks provided, fall back to old behavior (count per-task)
    if (allTasksOfSameType == null || allTasksOfSameType.isEmpty) {
      int instanceCount = 0;
      for (int week = 1; week <= targetWeekNumber; week++) {
        if (taskCancellations.contains(week)) continue;
        if (date_utils.DateUtils.isWeekInBreak(week, semester.startDate, semester.breaks)) continue;
        instanceCount++;
      }
      return instanceCount;
    }

    // Sort all tasks of same type by day of week and time
    final sortedTasks = List<RecurringTask>.from(allTasksOfSameType);
    sortedTasks.sort((a, b) {
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      return (a.time ?? '').compareTo(b.time ?? '');
    });

    // Count instances across all tasks of same type up to and including target week
    int instanceCount = 0;

    for (int week = 1; week <= targetWeekNumber; week++) {
      // Skip if week is in a break
      if (date_utils.DateUtils.isWeekInBreak(week, semester.startDate, semester.breaks)) {
        continue;
      }

      for (final t in sortedTasks) {
        // Check if this task is cancelled in this week
        final tCancellations = allCancelledEvents
            .where((e) => e.eventId == t.id && e.eventType == EventType.recurringTask)
            .map((e) => e.weekNumber)
            .toSet();

        if (tCancellations.contains(week)) {
          continue; // Skip cancelled instances
        }

        // If we're in the target week and this is our target task, return the count + 1
        if (week == targetWeekNumber && t.id == task.id) {
          return instanceCount + 1;
        }

        // Otherwise, increment the count
        instanceCount++;
      }
    }

    return instanceCount;
  }

  /// Get a formatted label for a recurring task with instance number
  ///
  /// Examples:
  /// - "Lecture 3"
  /// - "Lab 2"
  /// - "Tutorial 1"
  static String getTaskLabel({
    required RecurringTask task,
    required int instanceNumber,
  }) {
    if (instanceNumber == 0) {
      return '${_getTaskTypeName(task.type)} (Cancelled)';
    }

    final typeName = _getTaskTypeName(task.type);
    return '$typeName $instanceNumber';
  }

  /// Get a full formatted label with date
  ///
  /// Examples:
  /// - "Lecture 3 (Mon 22nd)"
  /// - "Lab 2 (Tue 23rd)"
  static String getFullTaskLabel({
    required RecurringTask task,
    required int instanceNumber,
    required DateTime date,
  }) {
    final label = getTaskLabel(task: task, instanceNumber: instanceNumber);
    final dateStr = date_utils.DateUtils.formatDayWithOrdinal(date);
    return '$label ($dateStr)';
  }

  /// Get the task type name for display
  static String _getTaskTypeName(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return 'Lecture';
      case RecurringTaskType.lab:
        return 'Lab';
      case RecurringTaskType.tutorial:
        return 'Tutorial';
      case RecurringTaskType.flashcards:
        return 'Flashcards';
      case RecurringTaskType.custom:
        return 'Task';
    }
  }

  /// Calculate total number of instances for a task across all weeks
  /// Useful for showing progress like "5/12 lectures attended"
  static int calculateTotalInstances({
    required RecurringTask task,
    required int totalWeeks,
    required List<CancelledEvent> allCancelledEvents,
    required Semester semester,
  }) {
    final taskCancellations = allCancelledEvents
        .where((e) => e.eventId == task.id && e.eventType == EventType.recurringTask)
        .map((e) => e.weekNumber)
        .toSet();

    int totalCount = 0;

    for (int week = 1; week <= totalWeeks; week++) {
      // Skip cancelled weeks
      if (taskCancellations.contains(week)) {
        continue;
      }

      // Skip weeks in breaks
      if (date_utils.DateUtils.isWeekInBreak(week, semester.startDate, semester.breaks)) {
        continue;
      }

      totalCount++;
    }

    return totalCount;
  }

  /// Get all instance numbers for a task across a range of weeks
  /// Returns a map of weekNumber -> instanceNumber
  static Map<int, int> getAllInstanceNumbers({
    required RecurringTask task,
    required int startWeek,
    required int endWeek,
    required List<CancelledEvent> allCancelledEvents,
    required Semester semester,
  }) {
    final result = <int, int>{};
    final taskCancellations = allCancelledEvents
        .where((e) => e.eventId == task.id && e.eventType == EventType.recurringTask)
        .map((e) => e.weekNumber)
        .toSet();

    int instanceCount = 0;

    for (int week = startWeek; week <= endWeek; week++) {
      // Check if cancelled
      if (taskCancellations.contains(week)) {
        result[week] = 0; // 0 indicates cancelled
        continue;
      }

      // Check if in break
      if (date_utils.DateUtils.isWeekInBreak(week, semester.startDate, semester.breaks)) {
        continue; // Don't add to map - week doesn't exist
      }

      // Valid instance
      instanceCount++;
      result[week] = instanceCount;
    }

    return result;
  }
}
