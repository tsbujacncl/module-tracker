import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';

class WeeklyCalendar extends ConsumerStatefulWidget {
  final Semester? semester;
  final int currentWeek;
  final List<Module> modules;
  final Map<String, List<RecurringTask>> tasksByModule;
  final Map<String, List<Assessment>> assessmentsByModule;
  final DateTime? weekStartDate;
  final double dragOffset;
  final bool isSwipeable;

  const WeeklyCalendar({
    super.key,
    this.semester,
    required this.currentWeek,
    required this.modules,
    required this.tasksByModule,
    required this.assessmentsByModule,
    this.weekStartDate,
    this.dragOffset = 0.0,
    this.isSwipeable = false,
  });

  @override
  ConsumerState<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends ConsumerState<WeeklyCalendar> {
  // Track selected events during drag
  final Set<String> _selectedEventIds = {};
  bool _isDragging = false;
  bool _isCompleting = true; // true = completing, false = uncompleting
  final Map<String, TaskStatus> _temporaryCompletions = {}; // For instant visual feedback
  String? _firstTouchedEventId; // Track first box touched, waiting for drag confirmation
  TaskStatus? _firstTouchedStatus;

  // Get the week start date (Monday)
  DateTime getWeekStartDate() {
    // If weekStartDate is provided, use it
    if (widget.weekStartDate != null) {
      return widget.weekStartDate!;
    }

    // If semester is provided, calculate from semester start
    if (widget.semester != null) {
      return widget.semester!.startDate.add(Duration(days: (widget.currentWeek - 1) * 7));
    }

    // Otherwise, use current week's Monday
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  // Get color for task type
  Color getTaskColor(RecurringTaskType type) {
    final preferences = ref.watch(userPreferencesProvider);

    switch (type) {
      case RecurringTaskType.lecture:
        return preferences.customLectureColor ?? const Color(0xFF1565C0); // Dark Blue
      case RecurringTaskType.lab:
      case RecurringTaskType.tutorial:
        return preferences.customLabTutorialColor ?? const Color(0xFF4CAF50); // Green for labs and tutorials
      case RecurringTaskType.flashcards:
      case RecurringTaskType.custom:
        return const Color(0xFF8B5CF6); // Purple for custom tasks
    }
  }

  // Get color for assessments
  Color getAssessmentColor() {
    final preferences = ref.watch(userPreferencesProvider);
    return preferences.customAssignmentColor ?? const Color(0xFFF44336); // Red
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
      return widget.modules.firstWhere((m) => m.id == moduleId);
    } catch (e) {
      return null;
    }
  }

  // Get all tasks for a specific day
  List<TaskWithModule> getTasksForDay(int dayOfWeek) {
    final tasks = <TaskWithModule>[];

    for (final entry in widget.tasksByModule.entries) {
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

    // If no semester, no assessments to show
    if (widget.semester == null) return assessments;

    for (final entry in widget.assessmentsByModule.entries) {
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
            final dueDates = assessment.getWeeklyDueDates(widget.semester!.startDate);

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
    int earliestHour = 24;  // Start with impossibly late hour
    int latestEndMinutes = 0;  // Start with impossibly early time

    // Check tasks
    for (final tasks in widget.tasksByModule.values) {
      for (final task in tasks) {
        if (task.time != null) {
          final startMinutes = parseTimeToMinutes(task.time!);
          final startH = startMinutes ~/ 60;
          earliestHour = math.min(earliestHour, startH);

          if (task.endTime != null) {
            final endMinutes = parseTimeToMinutes(task.endTime!);
            latestEndMinutes = math.max(latestEndMinutes, endMinutes);
          } else {
            // If no end time, assume 1 hour duration
            final endMinutes = startMinutes + 60;
            latestEndMinutes = math.max(latestEndMinutes, endMinutes);
          }
        }
      }
    }

    // Check assessments
    for (final assessments in widget.assessmentsByModule.values) {
      for (final assessment in assessments) {
        if (assessment.time != null) {
          final startMinutes = parseTimeToMinutes(assessment.time!);
          final startH = startMinutes ~/ 60;
          earliestHour = math.min(earliestHour, startH);

          // Assessments default to 1 hour duration
          final endMinutes = startMinutes + 60;
          latestEndMinutes = math.max(latestEndMinutes, endMinutes);
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

    // Debug: Print the calculated range
    print('DEBUG CALENDAR: Time range calculated - Start: ${earliestHour}:00, End: ${latestHour}:00');

    return (earliestHour, latestHour);
  }

  // Helper to build day headers for a specific week
  Widget _buildDayHeaders(DateTime weekStartForHeaders, BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: List.generate(5, (index) {
        final date = weekStartForHeaders.add(Duration(days: index));
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
    );
  }

  // Helper to build empty day columns (for prev/next weeks during swipe)
  List<Widget> _buildDayColumnsForWeek(
    DateTime weekStartForColumns,
    int startHour,
    int endHour,
    int totalHours,
    double pixelsPerHour,
    bool isDarkMode,
    Color borderColor,
  ) {
    // Calculate total height
    double totalHeight = pixelsPerHour * totalHours;

    return List.generate(5, (index) {
      return Expanded(
        child: Container(
          height: totalHeight,
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
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = getWeekStartDate();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']; // Only weekdays

    // Calculate dynamic time range based on actual events
    final timeRange = getTimeRange();
    final startHour = timeRange.$1;
    final endHour = timeRange.$2;
    final totalHours = endHour - startHour;

    // Calculate pixels per hour to fill screen height (more on narrow screens)
    final screenWidth = MediaQuery.of(context).size.width;
    final heightRatio = screenWidth < 400 ? 0.40 : 0.38;
    final maxHeight = MediaQuery.of(context).size.height * heightRatio;
    final pixelsPerHour = maxHeight / totalHours;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDarkMode ? const Color(0xFF1E293B) : Colors.white);
    final headerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F9FF);
    final legendColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFAFAFA);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE0F2FE);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onPanStart: (details) {
        // Drag is now confirmed - activate first touched box if exists
        if (!_isDragging) {
          setState(() {
            _isDragging = true;
          });
          // Prevent parent scroll while dragging
          ref.read(isDraggingCheckboxProvider.notifier).state = true;

          // Now select the first box that was touched
          if (_firstTouchedEventId != null && _firstTouchedStatus != null) {
            selectEvent(_firstTouchedEventId!, _firstTouchedStatus!);
            _firstTouchedEventId = null;
            _firstTouchedStatus = null;
          }
        }
      },
      onPanUpdate: (details) {
        if (_isDragging) {
          // Hit detection will be handled by individual event widgets via MouseRegion
        }
      },
      onPanEnd: (details) {
        if (_isDragging && _selectedEventIds.length >= 2) {
          // Events are already completed immediately as dragged over
          if (mounted) {
            final action = _isCompleting ? 'Completed' : 'Uncompleted';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$action ${_selectedEventIds.length} events'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        setState(() {
          _isDragging = false;
          _selectedEventIds.clear();
          // DON'T clear _temporaryCompletions - let automatic cleanup handle it when provider updates
          _firstTouchedEventId = null;
          _firstTouchedStatus = null;
        });
        // Re-enable parent scroll
        ref.read(isDraggingCheckboxProvider.notifier).state = false;
      },
      onPanCancel: () {
        setState(() {
          _isDragging = false;
          _selectedEventIds.clear();
          // DON'T clear _temporaryCompletions - let automatic cleanup handle it when provider updates
          _firstTouchedEventId = null;
          _firstTouchedStatus = null;
        });
        // Re-enable parent scroll
        ref.read(isDraggingCheckboxProvider.notifier).state = false;
      },
      child: Container(
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: legendColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Time column header (empty space) - FIXED
                const SizedBox(width: 32),
                // Day headers - SWIPEABLE or STATIC
                if (widget.isSwipeable)
                  Expanded(
                    child: SizedBox(
                      height: 60, // Fixed height for header
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: 0,
                          maxWidth: double.infinity,
                          child: Transform.translate(
                          offset: Offset(widget.dragOffset - (screenWidth - 32), 0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Previous week headers
                              SizedBox(
                                width: screenWidth - 32,
                                child: _buildDayHeaders(
                                  weekStart.subtract(const Duration(days: 7)),
                                  context,
                                ),
                              ),
                              // Current week headers
                              SizedBox(
                                width: screenWidth - 32,
                                child: _buildDayHeaders(weekStart, context),
                              ),
                              // Next week headers
                              SizedBox(
                                width: screenWidth - 32,
                                child: _buildDayHeaders(
                                  weekStart.add(const Duration(days: 7)),
                                  context,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(child: _buildDayHeaders(weekStart, context)),
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
                child: Stack(
                  children: [
                    // Day columns - SWIPEABLE (will be clipped and translated)
                    Positioned(
                      left: 32, // Leave space for time column
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: ClipRect(
                        child: widget.isSwipeable
                            ? OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: 0,
                                maxWidth: double.infinity,
                                child: Transform.translate(
                                  offset: Offset(widget.dragOffset - (screenWidth - 32), 0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Previous week placeholder
                                      SizedBox(
                                        width: screenWidth - 32,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: _buildDayColumnsForWeek(
                                            weekStart.subtract(const Duration(days: 7)),
                                            startHour,
                                            endHour,
                                            totalHours,
                                            pixelsPerHour,
                                            isDarkMode,
                                            borderColor,
                                          ),
                                        ),
                                      ),
                                      // Current week (actual data)
                                      SizedBox(
                                        width: screenWidth - 32,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: List.generate(5, (index) {
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
                          left: 2,
                          right: 2,
                          child: _TimetableTaskBox(
                            task: event.taskWithModule!.task,
                            module: event.taskWithModule!.module,
                            height: itemHeight,
                            weekNumber: widget.currentWeek,
                            dayOfWeek: dayOfWeek,
                            semester: widget.semester!,
                            getTaskColor: getTaskColor,
                            getTaskTypeName: getTaskTypeName,
                            onTouchDown: onTouchDown,
                            onSelectEvent: selectEvent,
                            isEventSelected: isEventSelected,
                            getTemporaryStatus: getTemporaryStatus,
                          ),
                        ));
                      } else {
                        allItems.add(Positioned(
                          top: itemTop,
                          left: 2,
                          right: 2,
                          child: _TimetableAssessmentBox(
                            assessment: event.assessmentWithModule!.assessment,
                            module: event.assessmentWithModule!.module,
                            height: itemHeight,
                            weekNumber: widget.currentWeek,
                            dayOfWeek: dayOfWeek,
                            semester: widget.semester!,
                            onTouchDown: onTouchDown,
                            onSelectEvent: selectEvent,
                            isEventSelected: isEventSelected,
                            getTemporaryStatus: getTemporaryStatus,
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
                                        ),
                                      ),
                                      // Next week placeholder
                                      SizedBox(
                                        width: screenWidth - 32,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: _buildDayColumnsForWeek(
                                            weekStart.add(const Duration(days: 7)),
                                            startHour,
                                            endHour,
                                            totalHours,
                                            pixelsPerHour,
                                            isDarkMode,
                                            borderColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(5, (index) {
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
                                        left: 2,
                                        right: 2,
                                        child: _TimetableTaskBox(
                                          task: event.taskWithModule!.task,
                                          module: event.taskWithModule!.module,
                                          height: itemHeight,
                                          weekNumber: widget.currentWeek,
                                          dayOfWeek: dayOfWeek,
                                          semester: widget.semester!,
                                          getTaskColor: getTaskColor,
                                          getTaskTypeName: getTaskTypeName,
                                          onTouchDown: onTouchDown,
                                          onSelectEvent: selectEvent,
                                          isEventSelected: isEventSelected,
                                          getTemporaryStatus: getTemporaryStatus,
                                        ),
                                      ));
                                    } else {
                                      allItems.add(Positioned(
                                        top: itemTop,
                                        left: 2,
                                        right: 2,
                                        child: _TimetableAssessmentBox(
                                          assessment: event.assessmentWithModule!.assessment,
                                          module: event.assessmentWithModule!.module,
                                          height: itemHeight,
                                          weekNumber: widget.currentWeek,
                                          dayOfWeek: dayOfWeek,
                                          semester: widget.semester!,
                                          onTouchDown: onTouchDown,
                                          onSelectEvent: selectEvent,
                                          isEventSelected: isEventSelected,
                                          getTemporaryStatus: getTemporaryStatus,
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
                                                // Hour separators
                                                ...List.generate(totalHours, (hourIndex) {
                                                  double topPosition = 0;
                                                  for (int h = startHour; h < startHour + hourIndex; h++) {
                                                    topPosition += pixelsPerHour * (hourMultipliers[h] ?? 1);
                                                  }
                                                  return Positioned(
                                                    top: topPosition,
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
                              ),
                      ),
                    ),
                    // Time column - FIXED (always on top, not affected by swipe)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: 32,
                        height: totalHeight,
                        child: Column(
                          children: List.generate(totalHours, (index) {
                            final hour = startHour + index;
                            final multiplier = hourMultipliers[hour] ?? 1;
                            return Container(
                              height: pixelsPerHour * multiplier,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 4, top: 4),
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Legend
          Container(
            padding: const EdgeInsets.all(8),
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
                  color: ref.watch(userPreferencesProvider).customLectureColor ?? const Color(0xFF1565C0),
                  label: 'Lecture',
                  onTap: () => _showColorPicker(context, 'Lecture'),
                ),
                _LegendItem(
                  color: ref.watch(userPreferencesProvider).customLabTutorialColor ?? const Color(0xFF4CAF50),
                  label: 'Lab/Tutorial',
                  onTap: () => _showColorPicker(context, 'Lab/Tutorial'),
                ),
                _LegendItem(
                  color: ref.watch(userPreferencesProvider).customAssignmentColor ?? const Color(0xFFF44336),
                  label: 'Assignment',
                  onTap: () => _showColorPicker(context, 'Assignment'),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  // Method to complete a single event immediately (as soon as it's touched)
  Future<void> _completeEventImmediately(String eventId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repository = ref.read(firestoreRepositoryProvider);
    final now = DateTime.now();
    final targetStatus = _isCompleting ? TaskStatus.complete : TaskStatus.notStarted;

    // Event ID format: "task_moduleId_taskId" or "assessment_moduleId_assessmentId"
    final parts = eventId.split('_');
    if (parts.length != 3) return;

    final type = parts[0];
    final moduleId = parts[1];
    final itemId = parts[2];

    final newCompletion = TaskCompletion(
      id: '',
      moduleId: moduleId,
      taskId: itemId,
      weekNumber: widget.currentWeek,
      status: targetStatus,
      completedAt: targetStatus == TaskStatus.complete ? now : null,
    );

    // Fire and forget - don't await to keep UI responsive
    repository.upsertTaskCompletion(
      user.uid,
      moduleId,
      newCompletion,
    );
  }

  // Called when first touching a box (before drag confirmed)
  void onTouchDown(String eventId, TaskStatus currentStatus) {
    if (!_isDragging) {
      _firstTouchedEventId = eventId;
      _firstTouchedStatus = currentStatus;
    }
  }

  // Method to select event when dragged over (only called during active drag)
  void selectEvent(String eventId, TaskStatus currentStatus) {
    // Only select during active drag
    if (!_isDragging) return;

    // Skip if already selected
    if (_selectedEventIds.contains(eventId)) return;

    setState(() {
      // If this is the first event, determine if we're completing or uncompleting
      if (_selectedEventIds.isEmpty) {
        _isCompleting = currentStatus != TaskStatus.complete;
      }

      _selectedEventIds.add(eventId);

      // Set temporary completion status for instant visual feedback
      _temporaryCompletions[eventId] = _isCompleting ? TaskStatus.complete : TaskStatus.notStarted;
    });

    // Immediately update database (don't wait for drag release)
    _completeEventImmediately(eventId);
  }

  // Check if event is selected
  bool isEventSelected(String eventId) {
    return _isDragging && _selectedEventIds.contains(eventId);
  }

  // Get temporary completion status for instant visual feedback
  // Also cleans up if database has caught up
  TaskStatus? getTemporaryStatus(String eventId, TaskStatus dbStatus) {
    final tempStatus = _temporaryCompletions[eventId];

    // If database has caught up to temporary status, remove from temp map
    if (tempStatus != null && tempStatus == dbStatus) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _temporaryCompletions.remove(eventId);
          });
        }
      });
    }

    return tempStatus;
  }

  // Show color picker dialog
  void _showColorPicker(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        type: type,
        onColorSelected: (color) {
          if (type == 'Lecture') {
            ref.read(userPreferencesProvider.notifier).setLectureColor(color);
          } else if (type == 'Lab/Tutorial') {
            ref.read(userPreferencesProvider.notifier).setLabTutorialColor(color);
          } else if (type == 'Assignment') {
            ref.read(userPreferencesProvider.notifier).setAssignmentColor(color);
          }
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _LegendItem({
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
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
        ),
      ),
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
  final int dayOfWeek;
  final Semester semester;
  final Function(String, TaskStatus) onTouchDown;
  final Function(String, TaskStatus) onSelectEvent;
  final bool Function(String) isEventSelected;
  final TaskStatus? Function(String, TaskStatus) getTemporaryStatus;

  const _TimetableAssessmentBox({
    required this.assessment,
    required this.module,
    required this.height,
    required this.weekNumber,
    required this.dayOfWeek,
    required this.semester,
    required this.onTouchDown,
    required this.onSelectEvent,
    required this.isEventSelected,
    required this.getTemporaryStatus,
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

        final eventId = 'assessment_${module.id}_${assessment.id}';
        final temporaryStatus = getTemporaryStatus(eventId, completion.status);
        final currentStatus = temporaryStatus ?? completion.status;
        final isCompleted = currentStatus == TaskStatus.complete;

        return Listener(
          onPointerDown: (_) => onTouchDown(eventId, currentStatus),
          child: MouseRegion(
            onEnter: (_) => onSelectEvent(eventId, currentStatus),
            child: GestureDetector(
              onTap: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);

              // Simple 2-state toggle by default
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
            onLongPress: () {
              // Calculate the date for this assessment based on day of week
              final weekStart = semester.startDate.add(Duration(days: (weekNumber - 1) * 7));
              final assessmentDate = weekStart.add(Duration(days: dayOfWeek - 1));

              showDialog(
                context: context,
                builder: (context) => _AssessmentDetailsDialog(
                  assessment: assessment,
                  module: module,
                  completion: completion,
                  weekNumber: weekNumber,
                  date: assessmentDate,
                ),
              );
            },
            child: Container(
              height: height,
              padding: const EdgeInsets.all(4),
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
            child: Stack(
              children: [
                // Assessment content - full width
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      module.code.isNotEmpty ? module.code : module.name,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assessment.type.toString().split('.').last[0].toUpperCase() +
                          assessment.type.toString().split('.').last.substring(1),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
                // Circular checkbox at right center (visual indicator only)
                Positioned(
                right: 4,
                top: height / 2 - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentStatus == TaskStatus.complete
                        ? const Color(0xFFEF4444)
                        : currentStatus == TaskStatus.inProgress
                            ? Colors.orange
                            : Colors.white,
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 2,
                    ),
                  ),
                  child: currentStatus == TaskStatus.complete
                      ? const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        )
                      : currentStatus == TaskStatus.inProgress
                          ? const Icon(
                              Icons.more_horiz,
                              size: 10,
                              color: Colors.white,
                            )
                          : null,
                ),
              ),
            ],
          ),
        ),
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
  final int dayOfWeek;
  final Semester semester;
  final Color Function(RecurringTaskType) getTaskColor;
  final String Function(RecurringTaskType) getTaskTypeName;
  final Function(String, TaskStatus) onTouchDown;
  final Function(String, TaskStatus) onSelectEvent;
  final bool Function(String) isEventSelected;
  final TaskStatus? Function(String, TaskStatus) getTemporaryStatus;

  const _TimetableTaskBox({
    required this.task,
    required this.module,
    required this.height,
    required this.weekNumber,
    required this.dayOfWeek,
    required this.semester,
    required this.getTaskColor,
    required this.getTaskTypeName,
    required this.onTouchDown,
    required this.onSelectEvent,
    required this.isEventSelected,
    required this.getTemporaryStatus,
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

        final eventId = 'task_${module.id}_${task.id}';
        final temporaryStatus = getTemporaryStatus(eventId, completion.status);
        final currentStatus = temporaryStatus ?? completion.status;
        final isCompleted = currentStatus == TaskStatus.complete;

        return Listener(
          onPointerDown: (_) => onTouchDown(eventId, currentStatus),
          child: MouseRegion(
            onEnter: (_) => onSelectEvent(eventId, currentStatus),
            child: GestureDetector(
              onTap: () async {
            final user = ref.read(currentUserProvider);
            if (user == null) return;

            final repository = ref.read(firestoreRepositoryProvider);

            // Simple 2-state toggle by default
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
          onLongPress: () {
            // Calculate the date for this task based on day of week
            final weekStart = semester.startDate.add(Duration(days: (weekNumber - 1) * 7));
            final taskDate = weekStart.add(Duration(days: dayOfWeek - 1));

            showDialog(
              context: context,
              builder: (context) => _TaskDetailsDialog(
                task: task,
                module: module,
                completion: completion,
                completions: completions,
                weekNumber: weekNumber,
                getTaskColor: getTaskColor,
                getTaskTypeName: getTaskTypeName,
                date: taskDate,
              ),
            );
          },
          child: Container(
              height: height,
              padding: const EdgeInsets.all(4),
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
            child: Stack(
              children: [
                // Task content - full width
                Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    module.code.isNotEmpty ? module.code : module.name,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    getTaskTypeName(task.type),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
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
              // Circular checkbox at right center (visual indicator only)
              Positioned(
                right: 4,
                top: height / 2 - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentStatus == TaskStatus.complete
                        ? getTaskColor(task.type)
                        : currentStatus == TaskStatus.inProgress
                            ? Colors.orange
                            : Colors.white,
                    border: Border.all(
                      color: getTaskColor(task.type),
                      width: 2,
                    ),
                  ),
                  child: currentStatus == TaskStatus.complete
                      ? const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        )
                      : currentStatus == TaskStatus.inProgress
                          ? const Icon(
                              Icons.more_horiz,
                              size: 10,
                              color: Colors.white,
                            )
                          : null,
                ),
              ),
            ],
          ),
        ),
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

// Helper widget for displaying detail rows in popup dialog
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Assessment details dialog
class _AssessmentDetailsDialog extends ConsumerStatefulWidget {
  final Assessment assessment;
  final Module module;
  final TaskCompletion completion;
  final int weekNumber;
  final DateTime date;

  const _AssessmentDetailsDialog({
    required this.assessment,
    required this.module,
    required this.completion,
    required this.weekNumber,
    required this.date,
  });

  @override
  ConsumerState<_AssessmentDetailsDialog> createState() => _AssessmentDetailsDialogState();
}

class _AssessmentDetailsDialogState extends ConsumerState<_AssessmentDetailsDialog> {
  late TaskStatus currentStatus;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.completion.status;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.module.name.isNotEmpty)
            Text(
              widget.module.name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          if (widget.module.code.isNotEmpty)
            Text(
              widget.module.code,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.calendar_today,
            label: 'Date',
            value: '${_getWeekdayName(widget.date.weekday)} ${widget.date.day}${_getDaySuffix(widget.date.day)} ${_getMonthName(widget.date.month)} ${widget.date.year}',
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.schedule,
            label: 'Time',
            value: widget.assessment.time!,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.assignment,
            label: 'Type',
            value: widget.assessment.type.toString().split('.').last[0].toUpperCase() +
                widget.assessment.type.toString().split('.').last.substring(1),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.info_outline,
            label: 'Name',
            value: widget.assessment.name,
          ),
          if (widget.assessment.dueDate != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.event,
              label: 'Due Date',
              value: '${widget.assessment.dueDate!.day}/${widget.assessment.dueDate!.month}/${widget.assessment.dueDate!.year}',
            ),
          ],
          if (widget.assessment.description != null && widget.assessment.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.notes,
              label: 'Description',
              value: widget.assessment.description!,
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);

              // Cycle through statuses: notStarted -> complete -> notStarted
              TaskStatus newStatus;
              if (currentStatus == TaskStatus.notStarted) {
                newStatus = TaskStatus.complete;
              } else if (currentStatus == TaskStatus.inProgress) {
                newStatus = TaskStatus.complete;
              } else {
                newStatus = TaskStatus.notStarted;
              }

              final now = DateTime.now();

              final newCompletion = TaskCompletion(
                id: widget.completion.id,
                moduleId: widget.module.id,
                taskId: widget.assessment.id,
                weekNumber: widget.weekNumber,
                status: newStatus,
                completedAt: newStatus == TaskStatus.complete ? now : null,
              );

              await repository.upsertTaskCompletion(
                user.uid,
                widget.module.id,
                newCompletion,
              );

              setState(() {
                currentStatus = newStatus;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentStatus == TaskStatus.complete
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFF0EA5E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    currentStatus == TaskStatus.complete
                        ? Icons.check_circle
                        : currentStatus == TaskStatus.inProgress
                            ? Icons.timelapse
                            : Icons.radio_button_unchecked,
                    color: currentStatus == TaskStatus.complete
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0EA5E9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentStatus == TaskStatus.complete
                        ? 'Completed'
                        : currentStatus == TaskStatus.inProgress
                            ? 'In Progress'
                            : 'Not Started',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Delete Assessment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Are you sure you want to delete "${widget.assessment.name}"?',
                  style: GoogleFonts.inter(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (result == true) {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);
              await repository.deleteAssessment(
                user.uid,
                widget.module.id,
                widget.assessment.id,
              );
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await showDialog(
              context: context,
              builder: (context) => _EditAssessmentDialog(
                assessment: widget.assessment,
                module: widget.module,
              ),
            );
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// Edit Assessment Dialog
class _EditAssessmentDialog extends ConsumerStatefulWidget {
  final Assessment assessment;
  final Module module;

  const _EditAssessmentDialog({
    required this.assessment,
    required this.module,
  });

  @override
  ConsumerState<_EditAssessmentDialog> createState() => _EditAssessmentDialogState();
}

class _EditAssessmentDialogState extends ConsumerState<_EditAssessmentDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TimeOfDay? _time;
  late DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.assessment.name);
    _descriptionController = TextEditingController(text: widget.assessment.description);
    _dueDate = widget.assessment.dueDate;

    if (widget.assessment.time != null) {
      final parts = widget.assessment.time!.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      _time = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Assessment',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: GoogleFonts.inter(),
                prefixIcon: const Icon(Icons.assignment),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Due Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Due Date',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                _dueDate != null
                    ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                    : 'Not set',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
            ),
            // Time
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                'Time',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                _time != null ? _formatTimeOfDay(_time!) : 'Not set',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _time ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _time = time);
                }
              },
            ),
            const SizedBox(height: 8),
            // Description
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: GoogleFonts.inter(),
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final user = ref.read(currentUserProvider);
            if (user == null) return;

            final repository = ref.read(firestoreRepositoryProvider);
            final selectedSemester = ref.read(selectedSemesterProvider);
            if (selectedSemester == null) return;

            final updatedData = {
              'name': _nameController.text,
              'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
              'dueDate': _dueDate?.toIso8601String(),
              'time': _time != null ? _formatTimeOfDay(_time!) : null,
            };

            await repository.updateAssessment(
              user.uid,
              selectedSemester.id,
              widget.module.id,
              widget.assessment.id,
              updatedData,
            );

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Task details dialog
class _TaskDetailsDialog extends ConsumerStatefulWidget {
  final RecurringTask task;
  final Module module;
  final TaskCompletion completion;
  final List<TaskCompletion> completions;
  final int weekNumber;
  final Color Function(RecurringTaskType) getTaskColor;
  final String Function(RecurringTaskType) getTaskTypeName;
  final DateTime date;

  const _TaskDetailsDialog({
    required this.task,
    required this.module,
    required this.completion,
    required this.completions,
    required this.weekNumber,
    required this.getTaskColor,
    required this.getTaskTypeName,
    required this.date,
  });

  @override
  ConsumerState<_TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends ConsumerState<_TaskDetailsDialog> {
  late TaskStatus currentStatus;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.completion.status;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.module.name.isNotEmpty)
            Text(
              widget.module.name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          if (widget.module.code.isNotEmpty)
            Text(
              widget.module.code,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.calendar_today,
            label: 'Date',
            value: '${_getWeekdayName(widget.date.weekday)} ${widget.date.day}${_getDaySuffix(widget.date.day)} ${_getMonthName(widget.date.month)} ${widget.date.year}',
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.schedule,
            label: 'Time',
            value: '${widget.task.time!}${widget.task.endTime != null ? " - ${widget.task.endTime}" : ""}',
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.class_,
            label: 'Type',
            value: widget.getTaskTypeName(widget.task.type),
          ),
          if (widget.task.location != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.location_on,
              label: 'Location',
              value: widget.task.location!,
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);

              // Cycle through statuses: notStarted -> complete -> notStarted
              TaskStatus newStatus;
              if (currentStatus == TaskStatus.notStarted) {
                newStatus = TaskStatus.complete;
              } else if (currentStatus == TaskStatus.inProgress) {
                newStatus = TaskStatus.complete;
              } else {
                newStatus = TaskStatus.notStarted;
              }

              final now = DateTime.now();

              final newCompletion = TaskCompletion(
                id: widget.completion.id,
                moduleId: widget.module.id,
                taskId: widget.task.id,
                weekNumber: widget.weekNumber,
                status: newStatus,
                completedAt: newStatus == TaskStatus.complete ? now : null,
              );

              await repository.upsertTaskCompletion(
                user.uid,
                widget.module.id,
                newCompletion,
              );

              // If completing a parent task, complete all its subtasks
              if (newStatus == TaskStatus.complete) {
                final allTasksAsync = ref.read(recurringTasksProvider(widget.module.id));
                final allTasks = allTasksAsync.value;

                if (allTasks != null) {
                  final subtasks = allTasks.where((t) => t.parentTaskId == widget.task.id).toList();

                  for (final subtask in subtasks) {
                    final subtaskCompletion = widget.completions.firstWhere(
                      (c) => c.taskId == subtask.id,
                      orElse: () => TaskCompletion(
                        id: '',
                        moduleId: widget.module.id,
                        taskId: subtask.id,
                        weekNumber: widget.weekNumber,
                        status: TaskStatus.notStarted,
                      ),
                    );

                    final newSubCompletion = TaskCompletion(
                      id: subtaskCompletion.id,
                      moduleId: widget.module.id,
                      taskId: subtask.id,
                      weekNumber: widget.weekNumber,
                      status: TaskStatus.complete,
                      completedAt: now,
                    );

                    await repository.upsertTaskCompletion(
                      user.uid,
                      widget.module.id,
                      newSubCompletion,
                    );
                  }
                }
              }

              setState(() {
                currentStatus = newStatus;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentStatus == TaskStatus.complete
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFF0EA5E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    currentStatus == TaskStatus.complete
                        ? Icons.check_circle
                        : currentStatus == TaskStatus.inProgress
                            ? Icons.timelapse
                            : Icons.radio_button_unchecked,
                    color: currentStatus == TaskStatus.complete
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0EA5E9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentStatus == TaskStatus.complete
                        ? 'Completed'
                        : currentStatus == TaskStatus.inProgress
                            ? 'In Progress'
                            : 'Not Started',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Delete Task',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Are you sure you want to delete this ${widget.getTaskTypeName(widget.task.type).toLowerCase()}?',
                  style: GoogleFonts.inter(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (result == true) {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);
              await repository.deleteRecurringTask(
                user.uid,
                widget.module.id,
                widget.task.id,
              );
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await showDialog(
              context: context,
              builder: (context) => _EditTaskDialog(
                task: widget.task,
                module: widget.module,
                getTaskTypeName: widget.getTaskTypeName,
              ),
            );
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// Edit Task Dialog
class _EditTaskDialog extends ConsumerStatefulWidget {
  final RecurringTask task;
  final Module module;
  final String Function(RecurringTaskType) getTaskTypeName;

  const _EditTaskDialog({
    required this.task,
    required this.module,
    required this.getTaskTypeName,
  });

  @override
  ConsumerState<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends ConsumerState<_EditTaskDialog> {
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();

    if (widget.task.time != null) {
      final parts = widget.task.time!.split(':');
      _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      _startTime = null;
    }

    if (widget.task.endTime != null) {
      final parts = widget.task.endTime!.split(':');
      _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      _endTime = null;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit ${widget.getTaskTypeName(widget.task.type)}',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start Time
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                'Start Time',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                _startTime != null ? _formatTimeOfDay(_startTime!) : 'Not set',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _startTime = time);
                }
              },
            ),
            // End Time
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_filled),
              title: Text(
                'End Time',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                _endTime != null ? _formatTimeOfDay(_endTime!) : 'Not set',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _endTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _endTime = time);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final user = ref.read(currentUserProvider);
            if (user == null) return;

            final repository = ref.read(firestoreRepositoryProvider);

            final updatedTask = widget.task.copyWith(
              time: _startTime != null ? _formatTimeOfDay(_startTime!) : null,
              endTime: _endTime != null ? _formatTimeOfDay(_endTime!) : null,
            );

            await repository.updateRecurringTask(
              user.uid,
              widget.module.id,
              widget.task.id,
              updatedTask,
            );

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Helper function to get weekday name
String _getWeekdayName(int weekday) {
  switch (weekday) {
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
      return '';
  }
}

// Helper function to get month name
String _getMonthName(int month) {
  switch (month) {
    case 1:
      return 'January';
    case 2:
      return 'February';
    case 3:
      return 'March';
    case 4:
      return 'April';
    case 5:
      return 'May';
    case 6:
      return 'June';
    case 7:
      return 'July';
    case 8:
      return 'August';
    case 9:
      return 'September';
    case 10:
      return 'October';
    case 11:
      return 'November';
    case 12:
      return 'December';
    default:
      return '';
  }
}

// Helper function to get day suffix (st, nd, rd, th)
String _getDaySuffix(int day) {
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

// Color picker dialog
class _ColorPickerDialog extends StatelessWidget {
  final String type;
  final Function(Color) onColorSelected;

  const _ColorPickerDialog({
    required this.type,
    required this.onColorSelected,
  });

  static final List<Color> availableColors = [
    const Color(0xFFF44336), // Red
    const Color(0xFFFF9800), // Orange
    const Color(0xFFFFEB3B), // Yellow
    const Color(0xFF4CAF50), // Green
    const Color(0xFF03A9F4), // Light Blue
    const Color(0xFF1565C0), // Dark Blue
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFE91E63), // Pink
    const Color(0xFF795548), // Brown
    const Color(0xFF9E9E9E), // Grey
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Choose Colour for $type',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // First row (5 colors)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: availableColors.sublist(0, 5).map((color) {
                return InkWell(
                  onTap: () {
                    onColorSelected(color);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Second row (5 colors)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: availableColors.sublist(5, 10).map((color) {
                return InkWell(
                  onTap: () {
                    onColorSelected(color);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(),
          ),
        ),
      ],
    );
  }
}
