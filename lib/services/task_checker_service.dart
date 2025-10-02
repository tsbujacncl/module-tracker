import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/repositories/firestore_repository.dart';
import 'package:module_tracker/utils/date_utils.dart' as utils;

// Import TaskStatus enum
import 'package:module_tracker/models/task_completion.dart' show TaskStatus;

class TaskCheckerService {
  final FirestoreRepository _repository = FirestoreRepository();

  /// Check for incomplete tasks for a given user
  /// Returns (incompleteToday, overdue)
  Future<(int, int)> checkIncompleteTasks(String userId) async {
    try {
      print('DEBUG TASK CHECKER: Checking incomplete tasks for user: $userId');

      // Get current semester
      final semesters = await _repository.getUserSemesters(userId).first;
      if (semesters.isEmpty) {
        print('DEBUG TASK CHECKER: No semesters found');
        return (0, 0);
      }

      final currentSemester = semesters.firstWhere(
        (s) => !s.isArchived,
        orElse: () => semesters.first,
      );

      print('DEBUG TASK CHECKER: Current semester: ${currentSemester.name}');

      // Get all active modules for current semester
      final modules = await _repository
          .getModulesBySemester(userId, currentSemester.id, activeOnly: true)
          .first;

      if (modules.isEmpty) {
        print('DEBUG TASK CHECKER: No active modules found');
        return (0, 0);
      }

      print('DEBUG TASK CHECKER: Found ${modules.length} active modules');

      // Calculate current week number
      final now = DateTime.now();
      final currentWeek = utils.DateUtils.getWeekNumber(now, currentSemester.startDate);

      print('DEBUG TASK CHECKER: Current week: $currentWeek');

      int incompleteTodayCount = 0;
      int overdueCount = 0;

      // Check each module for incomplete tasks
      for (final module in modules) {
        // Get all recurring tasks for this module
        final recurringTasks = await _repository.getRecurringTasks(userId, module.id).first;

        // Get tasks for today (current week)
        final todayTasks = _getTasksForWeek(recurringTasks, currentWeek, now.weekday);

        // Get all task completions for this module
        final allCompletions = await _repository.getAllTaskCompletions(userId, module.id).first;

        // Check today's tasks
        for (final task in todayTasks) {
          final isCompleted = allCompletions.any(
            (c) => c.taskId == task.id && c.weekNumber == currentWeek && c.status == TaskStatus.complete,
          );

          if (!isCompleted) {
            incompleteTodayCount++;
          }
        }

        // Check overdue tasks (previous weeks)
        for (int week = 1; week < currentWeek; week++) {
          final weekTasks = _getTasksForWeek(recurringTasks, week, null);

          for (final task in weekTasks) {
            final isCompleted = allCompletions.any(
              (c) => c.taskId == task.id && c.weekNumber == week && c.status == TaskStatus.complete,
            );

            if (!isCompleted) {
              overdueCount++;
            }
          }
        }
      }

      print('DEBUG TASK CHECKER: Incomplete today: $incompleteTodayCount, Overdue: $overdueCount');

      return (incompleteTodayCount, overdueCount);
    } catch (e) {
      print('DEBUG TASK CHECKER: Error checking tasks - $e');
      return (0, 0);
    }
  }

  /// Get tasks for a specific week and optionally filter by day of week
  List<RecurringTask> _getTasksForWeek(
    List<RecurringTask> allTasks,
    int weekNumber,
    int? dayOfWeek,
  ) {
    return allTasks.where((task) {
      // Only include scheduled items (lectures/labs/tutorials)
      if (task.parentTaskId != null) return false;
      if (task.time == null) return false;

      // Filter by day of week if specified
      if (dayOfWeek != null && task.dayOfWeek != dayOfWeek) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get custom tasks (linked to scheduled items) for a specific week and day
  List<RecurringTask> _getCustomTasksForWeek(
    List<RecurringTask> allTasks,
    int weekNumber,
    int dayOfWeek,
  ) {
    // Get all scheduled items for this day
    final scheduledItems = allTasks.where((task) {
      return task.parentTaskId == null &&
             task.time != null &&
             task.dayOfWeek == dayOfWeek;
    }).toList();

    // Get custom tasks linked to these scheduled items
    final customTasks = <RecurringTask>[];
    for (final scheduledItem in scheduledItems) {
      final linkedTasks = allTasks.where((task) {
        return task.parentTaskId == scheduledItem.id;
      });
      customTasks.addAll(linkedTasks);
    }

    return customTasks;
  }
}
