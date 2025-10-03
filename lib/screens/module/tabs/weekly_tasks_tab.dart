import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class WeeklyTasksTab extends ConsumerWidget {
  final Module module;

  const WeeklyTasksTab({
    super.key,
    required this.module,
  });

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  String _getTaskTypeName(RecurringTaskType type) {
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
        return 'Custom';
    }
  }

  Color _getTaskColor(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return const Color(0xFF3B82F6);
      case RecurringTaskType.lab:
      case RecurringTaskType.tutorial:
        return const Color(0xFF10B981);
      case RecurringTaskType.flashcards:
      case RecurringTaskType.custom:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(recurringTasksProvider(module.id));
    final selectedWeek = ref.watch(selectedWeekNumberProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No recurring tasks',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add tasks to this module',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        // Group tasks by day of week
        final tasksByDay = <int, List<RecurringTask>>{};
        for (final task in tasks.where((t) => t.parentTaskId == null)) {
          tasksByDay.putIfAbsent(task.dayOfWeek, () => []).add(task);
        }

        // Sort each day's tasks by time
        for (final dayTasks in tasksByDay.values) {
          dayTasks.sort((a, b) {
            if (a.time == null && b.time == null) return 0;
            if (a.time == null) return 1;
            if (b.time == null) return -1;
            return a.time!.compareTo(b.time!);
          });
        }

        // Sort days
        final sortedDays = tasksByDay.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final day = sortedDays[index];
            final dayTasks = tasksByDay[day]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    _getDayName(day),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                ...dayTasks.map((task) => _TaskCard(
                      task: task,
                      module: module,
                      weekNumber: selectedWeek,
                      getTaskTypeName: _getTaskTypeName,
                      getTaskColor: _getTaskColor,
                    )),
                const SizedBox(height: AppSpacing.lg),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading tasks: $error'),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final RecurringTask task;
  final Module module;
  final int weekNumber;
  final String Function(RecurringTaskType) getTaskTypeName;
  final Color Function(RecurringTaskType) getTaskColor;

  const _TaskCard({
    required this.task,
    required this.module,
    required this.weekNumber,
    required this.getTaskTypeName,
    required this.getTaskColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionsAsync = ref.watch(
      taskCompletionsProvider((moduleId: module.id, weekNumber: weekNumber)),
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final taskColor = getTaskColor(task.type);

    return completionsAsync.when(
      data: (completions) {
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

        final isCompleted = completion.status == TaskStatus.complete;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border(
              left: BorderSide(
                color: taskColor,
                width: 4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () async {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;

                  final repository = ref.read(firestoreRepositoryProvider);
                  final newStatus = !isCompleted
                      ? TaskStatus.complete
                      : TaskStatus.notStarted;

                  final newCompletion = TaskCompletion(
                    id: completion.id,
                    moduleId: module.id,
                    taskId: task.id,
                    weekNumber: weekNumber,
                    status: newStatus,
                    completedAt: newStatus == TaskStatus.complete
                        ? DateTime.now()
                        : null,
                  );

                  await repository.upsertTaskCompletion(
                    user.uid,
                    module.id,
                    newCompletion,
                  );
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? taskColor : Colors.transparent,
                    border: Border.all(
                      color: taskColor,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Task info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getTaskTypeName(task.type),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.time != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.endTime != null
                                ? '${task.time} - ${task.endTime}'
                                : task.time!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDarkMode
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (task.location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.location!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDarkMode
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
