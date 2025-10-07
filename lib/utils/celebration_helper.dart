import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/widgets/weekly_completion_dialog.dart';

/// Check if all tasks for the week are completed and show celebration if true
Future<void> checkAndShowWeeklyCelebration(
  BuildContext context,
  WidgetRef ref,
  int weekNumber,
) async {
  if (!context.mounted) return;

  final user = ref.read(currentUserProvider);
  if (user == null) return;

  // Get all modules for selected semester
  final modulesAsync = ref.read(selectedSemesterModulesProvider);
  final modules = modulesAsync.value;
  if (modules == null || modules.isEmpty) return;

  // Get all tasks and completions for all modules
  int totalTasks = 0;
  int completedTasks = 0;

  for (final module in modules) {
    // Get all recurring tasks for this module
    final tasksAsync = ref.read(recurringTasksProvider(module.id));
    final tasks = tasksAsync.value ?? [];

    // Get task completions for this module and week
    final completionsAsync = ref.read(
      taskCompletionsProvider((moduleId: module.id, weekNumber: weekNumber)),
    );
    final completions = completionsAsync.value ?? [];

    // Count tasks (only parent tasks, exclude sub-tasks)
    final parentTasks = tasks.where((t) => t.parentTaskId == null).toList();
    totalTasks += parentTasks.length;

    // Count completed tasks
    for (final task in parentTasks) {
      final completion = completions.firstWhere(
        (c) => c.taskId == task.id,
        orElse: () => TaskCompletion(
          id: '',
          moduleId: module.id,
          taskId: task.id,
          weekNumber: weekNumber,
          status: TaskStatus.notStarted,
        ),
      );

      if (completion.status == TaskStatus.complete) {
        completedTasks++;
      }
    }
  }

  // Show celebration if all tasks are completed
  final allTasksCompleted = totalTasks > 0 && completedTasks == totalTasks;

  if (allTasksCompleted && context.mounted) {
    final userName = ref.read(userPreferencesProvider).userName ?? 'there';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WeeklyCompletionDialog(
        userName: userName,
      ),
    );
  }
}
