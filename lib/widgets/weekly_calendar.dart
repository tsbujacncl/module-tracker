import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';

class WeeklyCalendar extends ConsumerWidget {
  final Semester semester;
  final int currentWeek;
  final List<Module> modules;
  final Map<String, List<RecurringTask>> tasksByModule;
  final Map<String, List<Assessment>> assessmentsByModule;

  const WeeklyCalendar({
    super.key,
    required this.semester,
    required this.currentWeek,
    required this.modules,
    required this.tasksByModule,
    required this.assessmentsByModule,
  });

  // Get the week start date (Monday)
  DateTime getWeekStartDate() {
    return semester.startDate.add(Duration(days: (currentWeek - 1) * 7));
  }

  // Get color for task type
  Color getTaskColor(RecurringTaskType type) {
    switch (type) {
      case RecurringTaskType.lecture:
        return const Color(0xFF3B82F6); // Blue
      case RecurringTaskType.lab:
      case RecurringTaskType.tutorial:
        return const Color(0xFF10B981); // Green for labs and tutorials
      case RecurringTaskType.flashcards:
      case RecurringTaskType.custom:
        return const Color(0xFF8B5CF6); // Purple for custom tasks
    }
  }

  // Get display name for task type
  String getTaskTypeName(RecurringTaskType type) {
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

  // Get module by ID
  Module? getModule(String moduleId) {
    try {
      return modules.firstWhere((m) => m.id == moduleId);
    } catch (e) {
      return null;
    }
  }

  // Get all tasks for a specific day
  List<TaskWithModule> getTasksForDay(int dayOfWeek) {
    final tasks = <TaskWithModule>[];

    for (final entry in tasksByModule.entries) {
      final moduleId = entry.key;
      final moduleTasks = entry.value;
      final module = getModule(moduleId);

      if (module != null) {
        for (final task in moduleTasks) {
          if (task.dayOfWeek == dayOfWeek && task.time != null) {
            tasks.add(TaskWithModule(task: task, module: module));
          }
        }
      }
    }

    // Sort by time
    tasks.sort((a, b) {
      return a.task.time!.compareTo(b.task.time!);
    });

    return tasks;
  }

  // Get all assessments for a specific day
  List<AssessmentWithModule> getAssessmentsForDay(int dayOfWeek) {
    final weekStart = getWeekStartDate();
    final currentDate = weekStart.add(Duration(days: dayOfWeek - 1));
    final assessments = <AssessmentWithModule>[];

    for (final entry in assessmentsByModule.entries) {
      final moduleId = entry.key;
      final moduleAssessments = entry.value;
      final module = getModule(moduleId);

      if (module != null) {
        for (final assessment in moduleAssessments) {
          // Only show assessments that have a confirmed time
          if (assessment.time == null) continue;

          bool matchesDate = false;

          if (assessment.type == AssessmentType.weekly) {
            // Get all due dates for this weekly assessment
            final dueDates = assessment.getWeeklyDueDates(semester.startDate);

            // Check if any due date matches the current date
            for (final dueDate in dueDates) {
              if (dueDate.year == currentDate.year &&
                  dueDate.month == currentDate.month &&
                  dueDate.day == currentDate.day) {
                matchesDate = true;
                break;
              }
            }
          } else {
            // For non-weekly assessments, check if dueDate matches current date
            if (assessment.dueDate != null) {
              final dueDate = assessment.dueDate!;
              if (dueDate.year == currentDate.year &&
                  dueDate.month == currentDate.month &&
                  dueDate.day == currentDate.day) {
                matchesDate = true;
              }
            }
          }

          if (matchesDate) {
            assessments.add(AssessmentWithModule(assessment: assessment, module: module));
          }
        }
      }
    }

    // Sort by time
    assessments.sort((a, b) {
      return a.assessment.time!.compareTo(b.assessment.time!);
    });

    return assessments;
  }

  // Parse time string to minutes from midnight
  int parseTimeToMinutes(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (e) {
      return 0;
    }
  }

  // Calculate duration between start and end time in minutes
  int calculateDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return 60; // Default 1 hour

    final startMinutes = parseTimeToMinutes(startTime);
    final endMinutes = parseTimeToMinutes(endTime);
    return endMinutes - startMinutes;
  }

  // Get the earliest and latest times from all tasks and assessments
  (int startHour, int endHour) getTimeRange() {
    int earliestHour = 24;
    int latestEndMinutes = 0;

    // Check tasks
    for (final tasks in tasksByModule.values) {
      for (final task in tasks) {
        if (task.time != null) {
          final startMinutes = parseTimeToMinutes(task.time!);
          final startH = startMinutes ~/ 60;
          earliestHour = earliestHour < startH ? earliestHour : startH;

          if (task.endTime != null) {
            final endMinutes = parseTimeToMinutes(task.endTime!);
            latestEndMinutes = latestEndMinutes > endMinutes ? latestEndMinutes : endMinutes;
          } else {
            // If no end time, assume 1 hour duration
            final endMinutes = startMinutes + 60;
            latestEndMinutes = latestEndMinutes > endMinutes ? latestEndMinutes : endMinutes;
          }
        }
      }
    }

    // Check assessments
    for (final assessments in assessmentsByModule.values) {
      for (final assessment in assessments) {
        if (assessment.time != null) {
          final startMinutes = parseTimeToMinutes(assessment.time!);
          final startH = startMinutes ~/ 60;
          earliestHour = earliestHour < startH ? earliestHour : startH;

          // Assessments default to 1 hour duration
          final endMinutes = startMinutes + 60;
          latestEndMinutes = latestEndMinutes > endMinutes ? latestEndMinutes : endMinutes;
        }
      }
    }

    // Default range if no tasks or assessments: 9am to 5pm
    if (earliestHour == 24 && latestEndMinutes == 0) {
      return (9, 17);
    }

    // Calculate the last hour that contains event content
    // If event ends exactly on the hour (e.g., 17:00), don't include that hour
    int latestHour;
    if (latestEndMinutes % 60 == 0) {
      latestHour = latestEndMinutes ~/ 60;
    } else {
      latestHour = (latestEndMinutes / 60).ceil();
    }

    return (earliestHour, latestHour);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = getWeekStartDate();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']; // Only weekdays

    // Calculate dynamic time range based on actual events
    final timeRange = getTimeRange();
    final startHour = timeRange.$1;
    final endHour = timeRange.$2;
    final totalHours = endHour - startHour;

    // Calculate pixels per hour to fill 40% of screen height
    final maxHeight = MediaQuery.of(context).size.height * 0.4;
    final pixelsPerHour = maxHeight / totalHours;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDarkMode ? const Color(0xFF1E293B) : Colors.white);
    final headerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F9FF);
    final legendColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFAFAFA);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE0F2FE);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calendar header with days
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Time column header (empty space)
                const SizedBox(width: 60),
                // Day headers (Monday to Friday only)
                ...List.generate(5, (index) {
                  final date = weekStart.add(Duration(days: index));
                  final isToday = DateTime.now().day == date.day &&
                      DateTime.now().month == date.month &&
                      DateTime.now().year == date.year;

                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          days[index],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? const Color(0xFF0EA5E9)
                                : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF0EA5E9)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? Colors.white
                                    : (isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // Calendar grid with time slots (no scroll, fits exactly)
          LayoutBuilder(
            builder: (context, constraints) {
              // We need to calculate height multipliers here too for the time column
              // Get events from first day to calculate multipliers
              final firstDayTasks = getTasksForDay(1);
              final firstDayAssessments = getAssessmentsForDay(1);

              final allEvents = <_CalendarEvent>[];

              for (final taskWithModule in firstDayTasks) {
                final task = taskWithModule.task;
                if (task.time == null) continue;

                final taskMinutes = parseTimeToMinutes(task.time!);
                final duration = calculateDuration(task.time, task.endTime);
                final endMinutes = taskMinutes + duration;

                allEvents.add(_CalendarEvent(
                  startMinutes: taskMinutes,
                  endMinutes: endMinutes,
                  isTask: true,
                  taskWithModule: taskWithModule,
                ));
              }

              for (final assessmentWithModule in firstDayAssessments) {
                final assessment = assessmentWithModule.assessment;
                if (assessment.time == null) continue;

                final assessmentMinutes = parseTimeToMinutes(assessment.time!);
                final endMinutes = assessmentMinutes + 60;

                allEvents.add(_CalendarEvent(
                  startMinutes: assessmentMinutes,
                  endMinutes: endMinutes,
                  isTask: false,
                  assessmentWithModule: assessmentWithModule,
                ));
              }

              // Calculate multipliers - need to check ALL days for overlaps
              final hourMultipliers = <int, int>{};
              for (int hour = startHour; hour < endHour; hour++) {
                int maxMultiplier = 1;

                // Check each day
                for (int day = 1; day <= 5; day++) {
                  final dayTasks = getTasksForDay(day);
                  final dayAssessments = getAssessmentsForDay(day);

                  final dayEvents = <_CalendarEvent>[];

                  for (final taskWithModule in dayTasks) {
                    final task = taskWithModule.task;
                    if (task.time == null) continue;

                    final taskMinutes = parseTimeToMinutes(task.time!);
                    final duration = calculateDuration(task.time, task.endTime);
                    final endMinutes = taskMinutes + duration;

                    dayEvents.add(_CalendarEvent(
                      startMinutes: taskMinutes,
                      endMinutes: endMinutes,
                      isTask: true,
                      taskWithModule: taskWithModule,
                    ));
                  }

                  for (final assessmentWithModule in dayAssessments) {
                    final assessment = assessmentWithModule.assessment;
                    if (assessment.time == null) continue;

                    final assessmentMinutes = parseTimeToMinutes(assessment.time!);
                    final endMinutes = assessmentMinutes + 60;

                    dayEvents.add(_CalendarEvent(
                      startMinutes: assessmentMinutes,
                      endMinutes: endMinutes,
                      isTask: false,
                      assessmentWithModule: assessmentWithModule,
                    ));
                  }

                  final hourStart = hour * 60;
                  final hourEnd = (hour + 1) * 60;

                  int maxConcurrent = 0;
                  for (final event in dayEvents) {
                    if (event.startMinutes < hourEnd && event.endMinutes > hourStart) {
                      int concurrent = dayEvents.where((e) =>
                        e.startMinutes < event.endMinutes &&
                        e.endMinutes > event.startMinutes
                      ).length;
                      maxConcurrent = maxConcurrent > concurrent ? maxConcurrent : concurrent;
                    }
                  }

                  maxMultiplier = maxMultiplier > maxConcurrent ? maxMultiplier : maxConcurrent;
                }

                hourMultipliers[hour] = maxMultiplier > 0 ? maxMultiplier : 1;
              }

              // Calculate total height
              double totalHeight = 0;
              for (int h = startHour; h < endHour; h++) {
                totalHeight += pixelsPerHour * (hourMultipliers[h] ?? 1);
              }

              return SizedBox(
                height: totalHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time column
                    SizedBox(
                      width: 60,
                      height: totalHeight,
                      child: Column(
                        children: List.generate(totalHours, (index) {
                          final hour = startHour + index;
                          final multiplier = hourMultipliers[hour] ?? 1;
                          return Container(
                            height: pixelsPerHour * multiplier,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 8, top: 4),
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  // Day columns (Monday to Friday only)
                  ...List.generate(5, (index) {
                    final dayOfWeek = index + 1; // 1 = Monday
                    final tasksForDay = getTasksForDay(dayOfWeek);
                    final assessmentsForDay = getAssessmentsForDay(dayOfWeek);

                    // Separate assessments with and without time
                    final allDayAssessments = <AssessmentWithModule>[];
                    final timedAssessments = <AssessmentWithModule>[];

                    for (final assessmentWithModule in assessmentsForDay) {
                      final assessment = assessmentWithModule.assessment;
                      if (assessment.time != null) {
                        timedAssessments.add(assessmentWithModule);
                      } else {
                        allDayAssessments.add(assessmentWithModule);
                      }
                    }

                    // Create unified event list with tasks and assessments
                    final events = <_CalendarEvent>[];

                    // Add tasks
                    for (final taskWithModule in tasksForDay) {
                      final task = taskWithModule.task;
                      if (task.time == null) continue;

                      final taskMinutes = parseTimeToMinutes(task.time!);
                      final duration = calculateDuration(task.time, task.endTime);
                      final endMinutes = taskMinutes + duration;

                      events.add(_CalendarEvent(
                        startMinutes: taskMinutes,
                        endMinutes: endMinutes,
                        isTask: true,
                        taskWithModule: taskWithModule,
                      ));
                    }

                    // Add assessments
                    for (final assessmentWithModule in timedAssessments) {
                      final assessment = assessmentWithModule.assessment;
                      final assessmentMinutes = parseTimeToMinutes(assessment.time!);
                      final endMinutes = assessmentMinutes + 60; // Default 1 hour

                      events.add(_CalendarEvent(
                        startMinutes: assessmentMinutes,
                        endMinutes: endMinutes,
                        isTask: false,
                        assessmentWithModule: assessmentWithModule,
                      ));
                    }

                    // Calculate height multiplier for each hour based on overlaps
                    final hourMultipliers = <int, int>{};
                    for (int hour = startHour; hour < endHour; hour++) {
                      final hourStart = hour * 60;
                      final hourEnd = (hour + 1) * 60;

                      // Count events that overlap this hour
                      int maxConcurrent = 0;
                      for (final event in events) {
                        // Check if event overlaps with this hour
                        if (event.startMinutes < hourEnd && event.endMinutes > hourStart) {
                          // Count concurrent events at the start of this event
                          int concurrent = events.where((e) =>
                            e.startMinutes < event.endMinutes &&
                            e.endMinutes > event.startMinutes
                          ).length;
                          maxConcurrent = maxConcurrent > concurrent ? maxConcurrent : concurrent;
                        }
                      }
                      hourMultipliers[hour] = maxConcurrent > 0 ? maxConcurrent : 1;
                    }

                    // Build positioned widgets with adjusted positions
                    final allItems = <Widget>[];

                    for (final event in events) {
                      final startMinutes = startHour * 60;
                      final offsetMinutes = event.startMinutes - startMinutes;

                      if (offsetMinutes < 0) continue;

                      // Calculate position considering hour multipliers
                      double topPosition = 0;
                      final eventHour = event.startMinutes ~/ 60;

                      // Sum heights of all hours before this event's hour
                      for (int h = startHour; h < eventHour; h++) {
                        topPosition += pixelsPerHour * (hourMultipliers[h] ?? 1);
                      }

                      // Add partial hour offset
                      final minutesIntoHour = event.startMinutes % 60;
                      topPosition += (minutesIntoHour / 60) * pixelsPerHour * (hourMultipliers[eventHour] ?? 1);

                      final duration = event.endMinutes - event.startMinutes;
                      final height = (duration / 60) * pixelsPerHour * (hourMultipliers[eventHour] ?? 1);

                      // Find which position in stack (0 = first, 1 = second, etc.)
                      final overlappingEvents = events.where((e) =>
                        e.startMinutes < event.endMinutes &&
                        e.endMinutes > event.startMinutes
                      ).toList();
                      overlappingEvents.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
                      final stackPosition = overlappingEvents.indexOf(event);
                      final totalInStack = overlappingEvents.length;

                      final itemHeight = (height - 4) / totalInStack;
                      final itemTop = topPosition + (stackPosition * itemHeight);

                      if (event.isTask) {
                        allItems.add(Positioned(
                          top: itemTop,
                          left: 4,
                          right: 4,
                          child: _TimetableTaskBox(
                            task: event.taskWithModule!.task,
                            module: event.taskWithModule!.module,
                            height: itemHeight,
                            weekNumber: currentWeek,
                            getTaskColor: getTaskColor,
                            getTaskTypeName: getTaskTypeName,
                          ),
                        ));
                      } else {
                        allItems.add(Positioned(
                          top: itemTop,
                          left: 4,
                          right: 4,
                          child: _TimetableAssessmentBox(
                            assessment: event.assessmentWithModule!.assessment,
                            module: event.assessmentWithModule!.module,
                            height: itemHeight,
                            weekNumber: currentWeek,
                          ),
                        ));
                      }
                    }

                    return Expanded(
                      child: Column(
                        children: [
                          // All-day assessments section (at the top)
                          if (allDayAssessments.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
                                border: Border(
                                  left: BorderSide(
                                    color: borderColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                  right: index == 4
                                      ? BorderSide(
                                          color: borderColor.withOpacity(0.5),
                                          width: 1,
                                        )
                                      : BorderSide.none,
                                  bottom: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: allDayAssessments.map((assessmentWithModule) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: _AllDayAssessmentChip(
                                      assessment: assessmentWithModule.assessment,
                                      module: assessmentWithModule.module,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          // Timetable section
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: borderColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                  right: index == 4
                                      ? BorderSide(
                                          color: borderColor.withOpacity(0.5),
                                          width: 1,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Hour lines
                                  ...List.generate(totalHours, (hourIndex) {
                                    double lineTop = 0;
                                    final hour = startHour + hourIndex;
                                    for (int h = startHour; h < hour; h++) {
                                      lineTop += pixelsPerHour * (hourMultipliers[h] ?? 1);
                                    }

                                    return Positioned(
                                      top: lineTop,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1,
                                        color: borderColor.withOpacity(0.3),
                                      ),
                                    );
                                  }),
                                  ...allItems,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
            },
          ),
          // Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: legendColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendItem(
                  color: const Color(0xFF3B82F6),
                  label: 'Lecture',
                ),
                _LegendItem(
                  color: const Color(0xFF10B981),
                  label: 'Lab/Tutorial',
                ),
                _LegendItem(
                  color: const Color(0xFFEF4444),
                  label: 'Assignment',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class TaskWithModule {
  final RecurringTask task;
  final Module module;

  TaskWithModule({
    required this.task,
    required this.module,
  });
}

class AssessmentWithModule {
  final Assessment assessment;
  final Module module;

  AssessmentWithModule({
    required this.assessment,
    required this.module,
  });
}

// Timetable assessment box (red) with checkbox
class _TimetableAssessmentBox extends ConsumerWidget {
  final Assessment assessment;
  final Module module;
  final double height;
  final int weekNumber;

  const _TimetableAssessmentBox({
    required this.assessment,
    required this.module,
    required this.height,
    required this.weekNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final completionsAsync = ref.watch(
        taskCompletionsProvider((moduleId: module.id, weekNumber: weekNumber)));

    return completionsAsync.when(
      data: (completions) {
        final completion = completions.firstWhere(
          (c) => c.taskId == assessment.id,
          orElse: () => TaskCompletion(
            id: '',
            moduleId: module.id,
            taskId: assessment.id,
            weekNumber: weekNumber,
            status: TaskStatus.notStarted,
          ),
        );

        final isCompleted = completion.status == TaskStatus.complete;

        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(isCompleted ? 0.3 : 0.15), // Red color
            borderRadius: BorderRadius.circular(6),
            border: const Border(
              left: BorderSide(
                color: Color(0xFFEF4444), // Red
                width: 3,
              ),
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // Assessment content
                Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        assessment.time!,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        module.code.isNotEmpty ? module.code : module.name,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        assessment.type.toString().split('.').last[0].toUpperCase() +
                            assessment.type.toString().split('.').last.substring(1),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              // Circular checkbox centered vertically on the right
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final user = ref.read(currentUserProvider);
                      if (user == null) return;

                      final repository = ref.read(firestoreRepositoryProvider);
                      final newStatus = !isCompleted
                          ? TaskStatus.complete
                          : TaskStatus.notStarted;

                      final now = DateTime.now();

                      final newCompletion = TaskCompletion(
                        id: completion.id,
                        moduleId: module.id,
                        taskId: assessment.id,
                        weekNumber: weekNumber,
                        status: newStatus,
                        completedAt: newStatus == TaskStatus.complete ? now : null,
                      );

                      await repository.upsertTaskCompletion(
                        user.uid,
                        module.id,
                        newCompletion,
                      );
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? const Color(0xFFEF4444) : Colors.white,
                        border: Border.all(
                          color: const Color(0xFFEF4444),
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      },
      loading: () => Container(
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: const Border(
            left: BorderSide(
              color: Color(0xFFEF4444),
              width: 3,
            ),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: const Border(
            left: BorderSide(
              color: Color(0xFFEF4444),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// Timetable task box with checkbox
class _TimetableTaskBox extends ConsumerWidget {
  final RecurringTask task;
  final Module module;
  final double height;
  final int weekNumber;
  final Color Function(RecurringTaskType) getTaskColor;
  final String Function(RecurringTaskType) getTaskTypeName;

  const _TimetableTaskBox({
    required this.task,
    required this.module,
    required this.height,
    required this.weekNumber,
    required this.getTaskColor,
    required this.getTaskTypeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final completionsAsync = ref.watch(
        taskCompletionsProvider((moduleId: module.id, weekNumber: weekNumber)));

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
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: getTaskColor(task.type).withOpacity(isCompleted ? 0.3 : 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: getTaskColor(task.type),
                width: 3,
              ),
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // Task content
                Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${task.time!}${task.endTime != null ? " - ${task.endTime}" : ""}',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: getTaskColor(task.type),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        module.code.isNotEmpty ? module.code : module.name,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        getTaskTypeName(task.type),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.location != null && height > 80) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 7,
                              color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                task.location!,
                                style: GoogleFonts.inter(
                                  fontSize: 7,
                                  color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              // Circular checkbox centered vertically on the right
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final user = ref.read(currentUserProvider);
                      if (user == null) return;

                      final repository = ref.read(firestoreRepositoryProvider);
                      final newStatus = !isCompleted
                          ? TaskStatus.complete
                          : TaskStatus.notStarted;

                      final now = DateTime.now();

                      final newCompletion = TaskCompletion(
                        id: completion.id,
                        moduleId: module.id,
                        taskId: task.id,
                        weekNumber: weekNumber,
                        status: newStatus,
                        completedAt: newStatus == TaskStatus.complete ? now : null,
                      );

                      await repository.upsertTaskCompletion(
                        user.uid,
                        module.id,
                        newCompletion,
                      );

                      // If completing a parent task, complete all its subtasks
                      if (newStatus == TaskStatus.complete) {
                        final allTasksAsync = ref.read(recurringTasksProvider(module.id));
                        final allTasks = allTasksAsync.value;

                        if (allTasks != null) {
                          final subtasks = allTasks.where((t) => t.parentTaskId == task.id).toList();

                          for (final subtask in subtasks) {
                            final subtaskCompletion = completions.firstWhere(
                              (c) => c.taskId == subtask.id,
                              orElse: () => TaskCompletion(
                                id: '',
                                moduleId: module.id,
                                taskId: subtask.id,
                                weekNumber: weekNumber,
                                status: TaskStatus.notStarted,
                              ),
                            );

                            final newSubCompletion = TaskCompletion(
                              id: subtaskCompletion.id,
                              moduleId: module.id,
                              taskId: subtask.id,
                              weekNumber: weekNumber,
                              status: TaskStatus.complete,
                              completedAt: now,
                            );

                            await repository.upsertTaskCompletion(
                              user.uid,
                              module.id,
                              newSubCompletion,
                            );
                          }
                        }
                      }
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? getTaskColor(task.type)
                            : Colors.white,
                        border: Border.all(
                          color: getTaskColor(task.type),
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      },
      loading: () => Container(
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: getTaskColor(task.type).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: getTaskColor(task.type),
              width: 3,
            ),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: getTaskColor(task.type).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: getTaskColor(task.type),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for all-day assessments (no specific time)
class _AllDayAssessmentChip extends StatelessWidget {
  final Assessment assessment;
  final Module module;

  const _AllDayAssessmentChip({
    required this.assessment,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              assessment.name,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for unified calendar events
class _CalendarEvent {
  final int startMinutes;
  final int endMinutes;
  final bool isTask;
  final TaskWithModule? taskWithModule;
  final AssessmentWithModule? assessmentWithModule;

  _CalendarEvent({
    required this.startMinutes,
    required this.endMinutes,
    required this.isTask,
    this.taskWithModule,
    this.assessmentWithModule,
  });
}
