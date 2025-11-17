import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/cancelled_event.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/services/lecture_numbering_service.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/utils/date_utils.dart' as date_utils;

/// Provider to get all cancelled events for a module (not just for one week)
final allCancelledEventsProvider =
    StreamProvider.family<List<CancelledEvent>, String>((ref, moduleId) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null || moduleId.isEmpty) {
    return Stream.value([]);
  }

  return repository.getAllCancelledEvents(user.uid, moduleId);
});

/// Helper class to calculate lecture numbers synchronously
class LectureNumberingHelper {
  /// Calculate instance number for a task in a given week
  /// Pass allTasksOfSameType to number across all tasks of the same type
  static int calculateInstanceNumber({
    required RecurringTask task,
    required int weekNumber,
    required List<CancelledEvent> cancelledEvents,
    required Semester semester,
    List<RecurringTask>? allTasksOfSameType,
  }) {
    return LectureNumberingService.calculateInstanceNumber(
      task: task,
      targetWeekNumber: weekNumber,
      allCancelledEvents: cancelledEvents,
      semester: semester,
      allTasksOfSameType: allTasksOfSameType,
    );
  }

  /// Get formatted label for a task
  static String getTaskLabel({
    required RecurringTask task,
    required int instanceNumber,
  }) {
    return LectureNumberingService.getTaskLabel(
      task: task,
      instanceNumber: instanceNumber,
    );
  }

  /// Get full formatted label with date
  static String getFullTaskLabel({
    required RecurringTask task,
    required int instanceNumber,
    required int weekNumber,
    required Semester semester,
  }) {
    final weekStart = date_utils.DateUtils.getDateForWeek(
      weekNumber,
      semester.startDate,
    );
    final taskDate = weekStart.add(Duration(days: task.dayOfWeek - 1));

    return LectureNumberingService.getFullTaskLabel(
      task: task,
      instanceNumber: instanceNumber,
      date: taskDate,
    );
  }

  /// Calculate total instances for a task
  static int calculateTotalInstances({
    required RecurringTask task,
    required List<CancelledEvent> cancelledEvents,
    required Semester semester,
  }) {
    return LectureNumberingService.calculateTotalInstances(
      task: task,
      totalWeeks: semester.numberOfWeeks,
      allCancelledEvents: cancelledEvents,
      semester: semester,
    );
  }

  /// Get all instance numbers for a task across weeks
  static Map<int, int> getAllInstanceNumbers({
    required RecurringTask task,
    required int startWeek,
    required int endWeek,
    required List<CancelledEvent> cancelledEvents,
    required Semester semester,
  }) {
    return LectureNumberingService.getAllInstanceNumbers(
      task: task,
      startWeek: startWeek,
      endWeek: endWeek,
      allCancelledEvents: cancelledEvents,
      semester: semester,
    );
  }
}
