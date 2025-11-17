import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/cancelled_event.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/lecture_numbering_provider.dart' as lecture_numbering;
import 'package:module_tracker/theme/design_tokens.dart';
import 'package:module_tracker/utils/date_utils.dart' as date_utils;

/// Widget to display lecture/lab/tutorial history for a module
/// Shows all instances with numbers, dates, and attendance status
class LectureHistoryList extends ConsumerWidget {
  final Module module;
  final RecurringTaskType taskType;

  const LectureHistoryList({
    super.key,
    required this.module,
    required this.taskType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final semester = ref.watch(currentSemesterProvider);
    final tasksAsync = ref.watch(recurringTasksProvider(module.id));
    final allCompletionsAsync = ref.watch(allTaskCompletionsProvider(module.id));
    final allCancelledAsync = ref.watch(lecture_numbering.allCancelledEventsProvider(module.id));

    if (semester == null) {
      return const SizedBox.shrink();
    }

    return tasksAsync.when(
      data: (tasks) {
        // Filter tasks by type
        final filteredTasks = tasks.where((t) => t.type == taskType).toList();

        if (filteredTasks.isEmpty) {
          return _EmptyState(
            taskType: taskType,
            isDarkMode: isDarkMode,
          );
        }

        return allCompletionsAsync.when(
          data: (completions) {
            return allCancelledAsync.when(
              data: (cancelledEvents) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with task type name
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            _getTaskIcon(taskType),
                            color: _getTaskColor(taskType),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _getTaskTypePlural(taskType),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of instances
                    ...filteredTasks.expand((task) {
                      return _buildTaskInstances(
                        task: task,
                        semester: semester,
                        completions: completions,
                        cancelledEvents: cancelledEvents,
                        isDarkMode: isDarkMode,
                        ref: ref,
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<Widget> _buildTaskInstances({
    required RecurringTask task,
    required Semester semester,
    required List<TaskCompletion> completions,
    required List<CancelledEvent> cancelledEvents,
    required bool isDarkMode,
    required WidgetRef ref,
  }) {
    final instances = <Widget>[];
    final currentWeek = ref.watch(selectedWeekNumberProvider);

    // Generate instance for each week
    final instanceNumbers = lecture_numbering.LectureNumberingHelper.getAllInstanceNumbers(
      task: task,
      startWeek: 1,
      endWeek: semester.numberOfWeeks,
      cancelledEvents: cancelledEvents,
      semester: semester,
    );

    instanceNumbers.forEach((weekNumber, instanceNumber) {
      // Get completion for this week
      final completion = completions.firstWhere(
        (c) => c.taskId == task.id && c.weekNumber == weekNumber,
        orElse: () => TaskCompletion(
          id: '',
          moduleId: module.id,
          taskId: task.id,
          weekNumber: weekNumber,
          status: TaskStatus.notStarted,
        ),
      );

      // Calculate date
      final weekStart = date_utils.DateUtils.getDateForWeek(
        weekNumber,
        semester.startDate,
      );
      final taskDate = weekStart.add(Duration(days: task.dayOfWeek - 1));
      final dateLabel = date_utils.DateUtils.formatDayWithOrdinal(taskDate);

      // Determine if this is upcoming, current, or past
      final isUpcoming = weekNumber > currentWeek;
      final isCurrent = weekNumber == currentWeek;
      final isCancelled = instanceNumber == 0;

      instances.add(
        _TaskInstanceTile(
          instanceNumber: instanceNumber,
          dateLabel: dateLabel,
          weekNumber: weekNumber,
          status: completion.status,
          isUpcoming: isUpcoming,
          isCurrent: isCurrent,
          isCancelled: isCancelled,
          taskColor: _getTaskColor(taskType),
          isDarkMode: isDarkMode,
          onTap: () {
            // Quick toggle attendance - to be implemented
          },
        ),
      );
    });

    return instances;
  }

  IconData _getTaskIcon(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return Icons.school_outlined;
      case RecurringTaskType.lab:
        return Icons.science_outlined;
      case RecurringTaskType.tutorial:
        return Icons.groups_outlined;
      default:
        return Icons.event;
    }
  }

  Color _getTaskColor(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return const Color(0xFF3B82F6);
      case RecurringTaskType.lab:
        return const Color(0xFF10B981);
      case RecurringTaskType.tutorial:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getTaskTypePlural(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return 'Lectures';
      case RecurringTaskType.lab:
        return 'Labs';
      case RecurringTaskType.tutorial:
        return 'Tutorials';
      default:
        return 'Tasks';
    }
  }
}

class _TaskInstanceTile extends StatelessWidget {
  final int instanceNumber;
  final String dateLabel;
  final int weekNumber;
  final TaskStatus status;
  final bool isUpcoming;
  final bool isCurrent;
  final bool isCancelled;
  final Color taskColor;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _TaskInstanceTile({
    required this.instanceNumber,
    required this.dateLabel,
    required this.weekNumber,
    required this.status,
    required this.isUpcoming,
    required this.isCurrent,
    required this.isCancelled,
    required this.taskColor,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusIcon = _getStatusIcon();
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border.all(
          color: isCurrent
              ? taskColor
              : (isDarkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isUpcoming || isCancelled ? null : onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Status icon
              Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),

              // Instance label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCancelled
                          ? 'Cancelled'
                          : 'Lecture $instanceNumber',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCancelled
                            ? (isDarkMode
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8))
                            : (isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '$dateLabel • Week $weekNumber',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDarkMode
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              // Current week badge
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: taskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: Text(
                    'This Week',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: taskColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (isCancelled) return Icons.cancel_outlined;
    if (isUpcoming) return Icons.schedule_outlined;

    switch (status) {
      case TaskStatus.complete:
        return Icons.check_circle;
      case TaskStatus.inProgress:
        return Icons.access_time;
      case TaskStatus.notStarted:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getStatusColor() {
    if (isCancelled) {
      return isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }
    if (isUpcoming) {
      return isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }

    switch (status) {
      case TaskStatus.complete:
        return const Color(0xFF10B981);
      case TaskStatus.inProgress:
        return const Color(0xFFF59E0B);
      case TaskStatus.notStarted:
        return isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final RecurringTaskType taskType;
  final bool isDarkMode;

  const _EmptyState({
    required this.taskType,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDarkMode
                ? const Color(0xFF64748B)
                : const Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'No ${_getTaskTypePlural(taskType).toLowerCase()} scheduled',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDarkMode
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTaskTypePlural(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return 'Lectures';
      case RecurringTaskType.lab:
        return 'Labs';
      case RecurringTaskType.tutorial:
        return 'Tutorials';
      default:
        return 'Tasks';
    }
  }
}
