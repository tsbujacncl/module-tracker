import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/utils/celebration_helper.dart';
import 'package:module_tracker/widgets/module_selection_dialog.dart';

class ModuleCard extends ConsumerStatefulWidget {
  final Module module;
  final int weekNumber;
  final int totalModules;
  final bool isMobileStacked;

  const ModuleCard({
    super.key,
    required this.module,
    required this.weekNumber,
    this.totalModules = 1,
    this.isMobileStacked = false,
  });

  @override
  ConsumerState<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends ConsumerState<ModuleCard> with SingleTickerProviderStateMixin {
  // Track selected tasks during drag
  final Set<String> _selectedTaskIds = {};
  bool _isDragging = false;
  bool _isCompleting = true;
  final Map<String, TaskStatus> _temporaryCompletions = {};
  String? _firstTouchedTaskId;
  TaskStatus? _firstTouchedStatus;

  // Track expanded weeks
  final Map<int, bool> _expandedWeeks = {};

  // Track tasks that are fading out after completion
  final Map<String, DateTime> _completedTaskTimestamps = {};
  final Set<String> _fadingOutTaskIds = {};
  final Map<String, double> _fadeOpacities = {};

  void onTouchDown(String taskId, TaskStatus currentStatus) {
    if (!_isDragging) {
      _firstTouchedTaskId = taskId;
      _firstTouchedStatus = currentStatus;
    }
  }

  void selectTask(String taskId, TaskStatus currentStatus) {
    if (!_isDragging) return;
    if (_selectedTaskIds.contains(taskId)) return;

    setState(() {
      if (_selectedTaskIds.isEmpty) {
        _isCompleting = currentStatus != TaskStatus.complete;
      }
      _selectedTaskIds.add(taskId);
      _temporaryCompletions[taskId] = _isCompleting ? TaskStatus.complete : TaskStatus.notStarted;
    });

    _completeTaskImmediately(taskId);
  }

  void updateTemporaryStatus(String taskId, TaskStatus newStatus) {
    setState(() {
      _temporaryCompletions[taskId] = newStatus;
    });
  }

  Future<void> _completeTaskImmediately(String taskId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repository = ref.read(firestoreRepositoryProvider);
    final now = DateTime.now();
    final targetStatus = _isCompleting ? TaskStatus.complete : TaskStatus.notStarted;

    final newCompletion = TaskCompletion(
      id: '',
      moduleId: widget.module.id,
      taskId: taskId,
      weekNumber: widget.weekNumber,
      status: targetStatus,
      completedAt: targetStatus == TaskStatus.complete ? now : null,
    );

    // Fire and forget - don't await
    repository.upsertTaskCompletion(user.uid, widget.module.id, newCompletion);
  }

  TaskStatus? getTemporaryStatus(String taskId, TaskStatus dbStatus) {
    final tempStatus = _temporaryCompletions[taskId];

    // If database has caught up to temporary status, remove from temp map
    if (tempStatus != null && tempStatus == dbStatus) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _temporaryCompletions.remove(taskId);
          });
        }
      });
    }

    return tempStatus;
  }

  // Handle task completion with fade-out animation
  void handleTaskCompletedWithFade(String taskId) {
    setState(() {
      _completedTaskTimestamps[taskId] = DateTime.now();
      _fadeOpacities[taskId] = 1.0;
    });

    // After 2 seconds, start fade out
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _fadingOutTaskIds.add(taskId);
      });

      // Animate opacity to 0 over 500ms
      _animateFadeOut(taskId);

      // After fade completes, remove from display
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _completedTaskTimestamps.remove(taskId);
          _fadingOutTaskIds.remove(taskId);
          _fadeOpacities.remove(taskId);
        });
      });
    });
  }

  void _animateFadeOut(String taskId) {
    const steps = 10;
    const stepDuration = Duration(milliseconds: 50);

    for (int i = 0; i < steps; i++) {
      Future.delayed(stepDuration * i, () {
        if (!mounted || !_fadingOutTaskIds.contains(taskId)) return;
        setState(() {
          _fadeOpacities[taskId] = 1.0 - (i + 1) / steps;
        });
      });
    }
  }

  // Check if task should be hidden (completed and past fade delay)
  bool shouldShowTask(String taskId, TaskStatus status) {
    if (status != TaskStatus.complete) return true;
    if (!_completedTaskTimestamps.containsKey(taskId)) return true;

    final completedTime = _completedTaskTimestamps[taskId]!;
    final elapsed = DateTime.now().difference(completedTime);

    // Hide after 2.5 seconds (2 second display + 0.5 second fade)
    return elapsed.inMilliseconds < 2500;
  }

  // Get opacity for fading task
  double getTaskOpacity(String taskId) {
    return _fadeOpacities[taskId] ?? 1.0;
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

  // Helper function to format date as "Mon 6th", "Tue 7th", etc.
  String formatTaskDate(DateTime date) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayOfWeek = dayNames[date.weekday - 1];
    final day = date.day;

    String getOrdinalSuffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1: return 'st';
        case 2: return 'nd';
        case 3: return 'rd';
        default: return 'th';
      }
    }

    return '$dayOfWeek $day${getOrdinalSuffix(day)}';
  }

  // Get ordinal suffix for a day number
  String getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // Generate smart task name with date or occurrence count
  String generateTaskName(
    RecurringTask task,
    List<RecurringTask> allTasks,
    DateTime semesterStartDate,
    int weekNumber,
  ) {
    // For custom tasks with names, just use the name
    if (task.type == RecurringTaskType.custom ||
        task.type == RecurringTaskType.flashcards) {
      return task.name;
    }

    // For scheduled tasks (lecture, lab, tutorial), group by type
    final tasksOfSameType = allTasks
        .where(
          (t) =>
              t.type == task.type && t.time != null && t.parentTaskId == null,
        ) // Only scheduled items, not custom subtasks
        .toList();

    // Sort by day of week and time
    tasksOfSameType.sort((a, b) {
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      return (a.time ?? '').compareTo(b.time ?? '');
    });

    // final totalOfType = tasksOfSameType.length;
    final typeName = getTaskTypeName(task.type);

    // Calculate the actual date for this task in this week
    final weekStartDate = semesterStartDate.add(Duration(days: (weekNumber - 1) * 7));
    final taskDate = weekStartDate.add(Duration(days: task.dayOfWeek - 1));

    // Format: "Lecture (Mon 29th)"
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayOfWeek = dayNames[taskDate.weekday - 1];
    final day = taskDate.day;

    return '$typeName ($dayOfWeek $day${getOrdinalSuffix(day)})';
  }

  // Get all assessments that are due in the given week
  List<Assessment> getAssessmentsForWeek(
    List<Assessment> allAssessments,
    DateTime semesterStartDate,
    int weekNumber,
  ) {
    final assessments = <Assessment>[];

    for (final assessment in allAssessments) {
      if (assessment.type == AssessmentType.weekly) {
        // Get all due dates for this weekly assessment
        final dueDates = assessment.getWeeklyDueDates(semesterStartDate);

        // Check if any due date falls in the current week
        for (int i = 0; i < dueDates.length; i++) {
          final dueDate = dueDates[i];
          final weekStart = semesterStartDate.add(
            Duration(days: (weekNumber - 1) * 7),
          );
          final weekEnd = weekStart.add(const Duration(days: 7));

          if (dueDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              dueDate.isBefore(weekEnd)) {
            assessments.add(assessment);
            break;
          }
        }
      } else {
        // For non-weekly assessments, check if weekNumber matches
        if (assessment.weekNumber == weekNumber) {
          assessments.add(assessment);
        }
      }
    }

    return assessments;
  }

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(currentSemesterProvider);
    final recurringTasksAsync = ref.watch(recurringTasksProvider(widget.module.id));
    final assessmentsAsync = ref.watch(assessmentsProvider(widget.module.id));
    final completionsAsync = ref.watch(
      taskCompletionsProvider((moduleId: widget.module.id, weekNumber: widget.weekNumber)),
    );

    // Calculate responsive scale factor based on screen width and module count
    final screenWidth = MediaQuery.of(context).size.width;
    final baseScaleFactor = screenWidth < 400
        ? 0.75
        : screenWidth < 600
        ? 0.9
        : 1.0;

    // Additional scaling based on number of modules
    // Only apply on desktop when modules share horizontal space
    final moduleCountScale = widget.isMobileStacked
        ? 1.0 // No extra scaling needed - full width on mobile
        : widget.totalModules <= 2
        ? 1.0
        : widget.totalModules == 3
        ? 0.90
        : widget.totalModules == 4
        ? 0.80
        : 0.70;

    final scaleFactor = baseScaleFactor * moduleCountScale;

    // Adjust padding based on layout mode
    final cardPadding = widget.isMobileStacked
        ? 12.0 // More padding when full width on mobile
        : screenWidth < 400
        ? 4.0
        : 16.0 * scaleFactor;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Module header
                  Padding(
                    padding: EdgeInsets.only(right: 40 * scaleFactor),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          widget.module.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.fontSize ??
                                        22) *
                                    scaleFactor,
                              ),
                        ),
                        if (widget.module.code.isNotEmpty)
                          Text(
                            widget.module.code,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.fontSize ??
                                          14) *
                                      scaleFactor,
                                ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * scaleFactor),
                  // Tasks list (recurring tasks + weekly assessments)
                  recurringTasksAsync.when(
                    data: (tasks) {
                      return assessmentsAsync.when(
                        data: (assessments) {
                          // Get all assessments for this week
                          final weekAssessments = semester != null
                              ? getAssessmentsForWeek(
                                  assessments,
                                  semester.startDate,
                                  widget.weekNumber,
                                )
                              : <Assessment>[];

                          if (tasks.isEmpty && weekAssessments.isEmpty) {
                            return Text(
                              'No tasks for this week',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                    fontSize:
                                        (Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.fontSize ??
                                            14) *
                                        scaleFactor,
                                  ),
                            );
                          }

                          return completionsAsync.when(
                            data: (completions) {
                              final completionMap = {
                                for (var c in completions) c.taskId: c,
                              };

                              // Sort tasks chronologically: by day of week, then by time
                              final sortedTasks = List<RecurringTask>.from(
                                tasks,
                              );
                              sortedTasks.sort((a, b) {
                                // First by day of week
                                final dayCompare = a.dayOfWeek.compareTo(
                                  b.dayOfWeek,
                                );
                                if (dayCompare != 0) return dayCompare;

                                // Then by time (null times go last)
                                if (a.time == null && b.time == null) return 0;
                                if (a.time == null) return 1;
                                if (b.time == null) return -1;
                                return a.time!.compareTo(b.time!);
                              });

                              // Separate parent tasks and subtasks
                              final parentTasks = sortedTasks
                                  .where((t) => t.parentTaskId == null)
                                  .toList();
                              final subtasksByParent =
                                  <String, List<RecurringTask>>{};

                              for (var task in sortedTasks) {
                                if (task.parentTaskId != null) {
                                  subtasksByParent
                                      .putIfAbsent(task.parentTaskId!, () => [])
                                      .add(task);
                                }
                              }

                              return GestureDetector(
                                behavior: HitTestBehavior.deferToChild,
                                onPanStart: (details) {
                                  if (!_isDragging) {
                                    setState(() {
                                      _isDragging = true;
                                    });
                                    // Prevent parent scroll while dragging
                                    ref.read(isDraggingCheckboxProvider.notifier).state = true;
                                    // Now select the first task that was touched
                                    if (_firstTouchedTaskId != null && _firstTouchedStatus != null) {
                                      selectTask(_firstTouchedTaskId!, _firstTouchedStatus!);
                                      _firstTouchedTaskId = null;
                                      _firstTouchedStatus = null;
                                    }
                                  }
                                },
                                onPanEnd: (details) async {
                                  setState(() {
                                    _isDragging = false;
                                    _selectedTaskIds.clear();
                                    // DON'T clear _temporaryCompletions - let automatic cleanup handle it
                                    _firstTouchedTaskId = null;
                                    _firstTouchedStatus = null;
                                  });
                                  // Re-enable parent scroll
                                  ref.read(isDraggingCheckboxProvider.notifier).state = false;

                                  // Check for weekly completion celebration after drag completes
                                  if (context.mounted) {
                                    await checkAndShowWeeklyCelebration(context, ref, widget.weekNumber);
                                  }
                                },
                                onPanCancel: () {
                                  setState(() {
                                    _isDragging = false;
                                    _selectedTaskIds.clear();
                                    _firstTouchedTaskId = null;
                                    _firstTouchedStatus = null;
                                  });
                                  // Re-enable parent scroll
                                  ref.read(isDraggingCheckboxProvider.notifier).state = false;
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Recurring tasks
                                    ...parentTasks.expand((task) {
                                    final completion = completionMap[task.id];
                                    final status =
                                        completion?.status ??
                                        TaskStatus.notStarted;

                                    // Generate smart task name
                                    final displayName = generateTaskName(
                                      task,
                                      tasks,
                                      semester!.startDate,
                                      widget.weekNumber,
                                    );

                                    final subtasks =
                                        subtasksByParent[task.id] ?? [];

                                    return [
                                      _TaskItem(
                                        taskName: displayName,
                                        taskId: task.id,
                                        status: status,
                                        completedAt: completion?.completedAt,
                                        scaleFactor: scaleFactor,
                                        onTouchDown: onTouchDown,
                                        onSelectTask: selectTask,
                                        getTemporaryStatus: getTemporaryStatus,
                                        onUpdateTemporaryStatus: updateTemporaryStatus,
                                        onStatusChanged: (newStatus) async {
                                          final user = ref.read(
                                            currentUserProvider,
                                          );
                                          if (user == null) return;

                                          final repository = ref.read(
                                            firestoreRepositoryProvider,
                                          );
                                          final now = DateTime.now();

                                          // Update parent task
                                          final newCompletion = TaskCompletion(
                                            id: completion?.id ?? '',
                                            moduleId: widget.module.id,
                                            taskId: task.id,
                                            weekNumber: widget.weekNumber,
                                            status: newStatus,
                                            completedAt:
                                                newStatus == TaskStatus.complete
                                                ? now
                                                : null,
                                          );

                                          // Update parent task
                                          await repository.upsertTaskCompletion(
                                            user.uid,
                                            widget.module.id,
                                            newCompletion,
                                          );

                                          // If parent is completed, complete all subtasks
                                          if (newStatus ==
                                                  TaskStatus.complete &&
                                              subtasks.isNotEmpty) {
                                            for (final subtask in subtasks) {
                                              final subCompletion =
                                                  completionMap[subtask.id];
                                              final newSubCompletion =
                                                  TaskCompletion(
                                                    id: subCompletion?.id ?? '',
                                                    moduleId: widget.module.id,
                                                    taskId: subtask.id,
                                                    weekNumber: widget.weekNumber,
                                                    status: TaskStatus.complete,
                                                    completedAt: now,
                                                  );
                                              await repository
                                                  .upsertTaskCompletion(
                                                    user.uid,
                                                    widget.module.id,
                                                    newSubCompletion,
                                                  );
                                            }
                                          }

                                          // Check for weekly completion celebration
                                          if (newStatus == TaskStatus.complete && context.mounted) {
                                            await checkAndShowWeeklyCelebration(context, ref, widget.weekNumber);
                                          }
                                        },
                                      ),
                                      // Add subtasks with indentation
                                      ...subtasks.map((subtask) {
                                        final subCompletion =
                                            completionMap[subtask.id];
                                        final subStatus =
                                            subCompletion?.status ??
                                            TaskStatus.notStarted;

                                        return _TaskItem(
                                          taskName: subtask.name,
                                          taskId: subtask.id,
                                          status: subStatus,
                                          completedAt:
                                              subCompletion?.completedAt,
                                          isSubtask: true,
                                          scaleFactor: scaleFactor,
                                          onTouchDown: onTouchDown,
                                          onSelectTask: selectTask,
                                          getTemporaryStatus: getTemporaryStatus,
                                          onUpdateTemporaryStatus: updateTemporaryStatus,
                                          onStatusChanged: (newStatus) async {
                                            final user = ref.read(
                                              currentUserProvider,
                                            );
                                            if (user == null) return;

                                            final repository = ref.read(
                                              firestoreRepositoryProvider,
                                            );
                                            final newCompletion =
                                                TaskCompletion(
                                                  id: subCompletion?.id ?? '',
                                                  moduleId: widget.module.id,
                                                  taskId: subtask.id,
                                                  weekNumber: widget.weekNumber,
                                                  status: newStatus,
                                                  completedAt:
                                                      newStatus ==
                                                          TaskStatus.complete
                                                      ? DateTime.now()
                                                      : null,
                                                );

                                            // Update subtask
                                            await repository
                                                .upsertTaskCompletion(
                                                  user.uid,
                                                  widget.module.id,
                                                  newCompletion,
                                                );

                                            // Check for weekly completion celebration
                                            if (newStatus == TaskStatus.complete && context.mounted) {
                                              await checkAndShowWeeklyCelebration(context, ref, widget.weekNumber);
                                            }
                                          },
                                        );
                                      }),
                                    ];
                                  }),
                                  // All assessments (weekly and non-weekly)
                                  ...weekAssessments.map((assessment) {
                                    final completion =
                                        completionMap[assessment.id];
                                    final status =
                                        completion?.status ??
                                        TaskStatus.notStarted;

                                    // Calculate the due date for this assessment in this week
                                    String dueDateStr = '';
                                    if (assessment.dueDate != null) {
                                      final dueDate = assessment.dueDate!;
                                      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                      final dayOfWeek = dayNames[dueDate.weekday - 1];
                                      final day = dueDate.day;
                                      dueDateStr = ' ($dayOfWeek $day${getOrdinalSuffix(day)})';
                                    } else if (assessment.type == AssessmentType.weekly &&
                                               assessment.dayOfWeek != null) {
                                      // For weekly assessments, calculate based on week
                                      final weekStartDate = semester!.startDate.add(
                                        Duration(days: (widget.weekNumber - 1) * 7),
                                      );
                                      DateTime dueDate;
                                      if (assessment.submitTiming == SubmitTiming.startOfNextWeek) {
                                        final nextWeekStart = weekStartDate.add(const Duration(days: 7));
                                        dueDate = nextWeekStart.add(Duration(days: assessment.dayOfWeek! - 1));
                                      } else {
                                        dueDate = weekStartDate.add(Duration(days: assessment.dayOfWeek! - 1));
                                      }
                                      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                      final dayOfWeek = dayNames[dueDate.weekday - 1];
                                      final day = dueDate.day;
                                      dueDateStr = ' ($dayOfWeek $day${getOrdinalSuffix(day)})';
                                    }

                                    return _TaskItem(
                                      taskName: '${assessment.name}$dueDateStr',
                                      taskId: assessment.id,
                                      status: status,
                                      completedAt: completion?.completedAt,
                                      isAssessment: true,
                                      scaleFactor: scaleFactor,
                                      onTouchDown: onTouchDown,
                                      onSelectTask: selectTask,
                                      getTemporaryStatus: getTemporaryStatus,
                                      onUpdateTemporaryStatus: updateTemporaryStatus,
                                      onStatusChanged: (newStatus) async {
                                        final user = ref.read(
                                          currentUserProvider,
                                        );
                                        if (user == null) return;

                                        final repository = ref.read(
                                          firestoreRepositoryProvider,
                                        );
                                        final newCompletion = TaskCompletion(
                                          id: completion?.id ?? '',
                                          moduleId: widget.module.id,
                                          taskId: assessment.id,
                                          weekNumber: widget.weekNumber,
                                          status: newStatus,
                                          completedAt:
                                              newStatus == TaskStatus.complete
                                              ? DateTime.now()
                                              : null,
                                        );

                                        // Update assessment
                                        await repository.upsertTaskCompletion(
                                          user.uid,
                                          widget.module.id,
                                          newCompletion,
                                        );

                                        // Check for weekly completion celebration
                                        if (newStatus == TaskStatus.complete && context.mounted) {
                                          await checkAndShowWeeklyCelebration(context, ref, widget.weekNumber);
                                        }
                                      },
                                    );
                                  }),
                                ],
                              ),
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (error, stack) => Text('Error: $error'),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (error, stack) => Text('Error: $error'),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => Text('Error: $error'),
                  ),

                  // Outstanding Tasks Section - Interactive with Checkboxes
                  if (semester != null) ...[
                    recurringTasksAsync.when(
                      data: (tasks) {
                        return assessmentsAsync.when(
                          data: (assessments) {
                            // Collect outstanding tasks from previous weeks with their completion data
                            final outstandingTasksData = <Map<String, dynamic>>[];

                            for (int week = 1; week < widget.weekNumber; week++) {
                              final prevWeekCompletionsAsync = ref.watch(
                                taskCompletionsProvider((moduleId: widget.module.id, weekNumber: week)),
                              );

                              prevWeekCompletionsAsync.whenData((prevCompletions) {
                                final prevCompletionMap = {for (var c in prevCompletions) c.taskId: c};

                                // Get assessments for previous week
                                final prevWeekAssessments = getAssessmentsForWeek(
                                  assessments,
                                  semester.startDate,
                                  week,
                                );

                                // Check recurring tasks - add date to name
                                for (final task in tasks) {
                                  final completion = prevCompletionMap[task.id];
                                  if (completion?.status != TaskStatus.complete) {
                                    // Generate task name with date
                                    final taskNameWithDate = generateTaskName(
                                      task,
                                      tasks,
                                      semester.startDate,
                                      week,
                                    );

                                    outstandingTasksData.add({
                                      'week': week,
                                      'taskId': task.id,
                                      'name': taskNameWithDate,
                                      'isAssessment': false,
                                      'completion': completion,
                                      'status': completion?.status ?? TaskStatus.notStarted,
                                    });
                                  }
                                }

                                // Check assessments - add date to name
                                for (final assessment in prevWeekAssessments) {
                                  final completion = prevCompletionMap[assessment.id];
                                  if (completion?.status != TaskStatus.complete) {
                                    // Calculate the due date for this assessment
                                    String dueDateStr = '';
                                    if (assessment.dueDate != null) {
                                      dueDateStr = ' (${formatTaskDate(assessment.dueDate!)})';
                                    } else if (assessment.type == AssessmentType.weekly &&
                                               assessment.dayOfWeek != null) {
                                      // For weekly assessments, calculate based on week
                                      final weekStartDate = semester.startDate.add(
                                        Duration(days: (week - 1) * 7),
                                      );
                                      DateTime dueDate;
                                      if (assessment.submitTiming == SubmitTiming.startOfNextWeek) {
                                        final nextWeekStart = weekStartDate.add(const Duration(days: 7));
                                        dueDate = nextWeekStart.add(Duration(days: assessment.dayOfWeek! - 1));
                                      } else {
                                        dueDate = weekStartDate.add(Duration(days: assessment.dayOfWeek! - 1));
                                      }
                                      dueDateStr = ' (${formatTaskDate(dueDate)})';
                                    }

                                    outstandingTasksData.add({
                                      'week': week,
                                      'taskId': assessment.id,
                                      'name': '${assessment.name}$dueDateStr',
                                      'isAssessment': true,
                                      'completion': completion,
                                      'status': completion?.status ?? TaskStatus.notStarted,
                                    });
                                  }
                                }
                              });
                            }

                            if (outstandingTasksData.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            // Filter out tasks that should be hidden (completed and faded out)
                            final visibleTasks = outstandingTasksData.where((taskData) {
                              final taskId = taskData['taskId'] as String;
                              final status = taskData['status'] as TaskStatus;
                              return shouldShowTask(taskId, status);
                            }).toList();

                            if (visibleTasks.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 16 * scaleFactor),

                                // Warning badge
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16 * scaleFactor,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                    SizedBox(width: 6 * scaleFactor),
                                    Text(
                                      '${visibleTasks.length} outstanding from previous weeks',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 13) * scaleFactor,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8 * scaleFactor),

                                // Interactive task list with checkboxes
                                GestureDetector(
                                  behavior: HitTestBehavior.deferToChild,
                                  onPanStart: (details) {
                                    if (!_isDragging) {
                                      setState(() {
                                        _isDragging = true;
                                      });
                                      ref.read(isDraggingCheckboxProvider.notifier).state = true;
                                      if (_firstTouchedTaskId != null && _firstTouchedStatus != null) {
                                        selectTask(_firstTouchedTaskId!, _firstTouchedStatus!);
                                        _firstTouchedTaskId = null;
                                        _firstTouchedStatus = null;
                                      }
                                    }
                                  },
                                  onPanEnd: (details) async {
                                    setState(() {
                                      _isDragging = false;
                                      _selectedTaskIds.clear();
                                      _firstTouchedTaskId = null;
                                      _firstTouchedStatus = null;
                                    });
                                    ref.read(isDraggingCheckboxProvider.notifier).state = false;
                                  },
                                  onPanCancel: () {
                                    setState(() {
                                      _isDragging = false;
                                      _selectedTaskIds.clear();
                                      _firstTouchedTaskId = null;
                                      _firstTouchedStatus = null;
                                    });
                                    ref.read(isDraggingCheckboxProvider.notifier).state = false;
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: visibleTasks.map((taskData) {
                                      final weekNumber = taskData['week'] as int;
                                      final taskId = taskData['taskId'] as String;
                                      final taskName = taskData['name'] as String;
                                      final isAssessment = taskData['isAssessment'] as bool;
                                      final completion = taskData['completion'] as TaskCompletion?;
                                      final status = taskData['status'] as TaskStatus;

                                      return Opacity(
                                        opacity: getTaskOpacity(taskId),
                                        child: _TaskItem(
                                          taskName: '$taskName - Week $weekNumber',
                                          taskId: taskId,
                                          status: status,
                                          completedAt: completion?.completedAt,
                                          isAssessment: isAssessment,
                                          scaleFactor: scaleFactor,
                                          onTouchDown: onTouchDown,
                                          onSelectTask: selectTask,
                                          getTemporaryStatus: getTemporaryStatus,
                                          onUpdateTemporaryStatus: updateTemporaryStatus,
                                          onStatusChanged: (newStatus) async {
                                            final user = ref.read(currentUserProvider);
                                            if (user == null) return;

                                            // Trigger fade-out animation if completing
                                            if (newStatus == TaskStatus.complete) {
                                              handleTaskCompletedWithFade(taskId);
                                            }

                                            final repository = ref.read(firestoreRepositoryProvider);
                                            final newCompletion = TaskCompletion(
                                              id: completion?.id ?? '',
                                              moduleId: widget.module.id,
                                              taskId: taskId,
                                              weekNumber: weekNumber,
                                              status: newStatus,
                                              completedAt: newStatus == TaskStatus.complete
                                                  ? DateTime.now()
                                                  : null,
                                            );

                                            await repository.upsertTaskCompletion(
                                              user.uid,
                                              widget.module.id,
                                              newCompletion,
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],

                  // Assignments Due Section - with Checkboxes and Borders
                  assessmentsAsync.when(
                    data: (allAssessments) {
                      final now = DateTime.now();

                      // Filter: Only show assessments within 21 days (3 weeks), not completed this week, AND not due this week
                      final upcomingAssessments = allAssessments
                          .where((a) {
                            if (a.dueDate == null) return false;
                            final daysUntilDue = a.dueDate!.difference(now).inDays;
                            // Exclude assessments due in the current week
                            if (a.weekNumber == widget.weekNumber) return false;
                            return a.dueDate!.isAfter(now) && daysUntilDue <= 21;
                          })
                          .toList()
                        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

                      if (upcomingAssessments.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return completionsAsync.when(
                        data: (completions) {
                          final completionMap = {for (var c in completions) c.taskId: c};

                          // Filter out completed assessments and those that should be hidden
                          final visibleAssessments = upcomingAssessments.where((assessment) {
                            final completion = completionMap[assessment.id];
                            final status = completion?.status ?? TaskStatus.notStarted;
                            return shouldShowTask(assessment.id, status);
                          }).toList();

                          if (visibleAssessments.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 16 * scaleFactor),

                              // Section header
                              Text(
                                'Assignments Due',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * scaleFactor,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 12 * scaleFactor),

                              // Assessment items with bordered containers
                              ...visibleAssessments.map((assessment) {
                                final completion = completionMap[assessment.id];
                                final status = completion?.status ?? TaskStatus.notStarted;
                                final daysUntilDue = assessment.dueDate!.difference(now).inDays;

                                // Determine urgency color
                                Color borderColor;
                                String timeText;

                                if (daysUntilDue <= 3) {
                                  borderColor = const Color(0xFFEF4444); // Red
                                  timeText = daysUntilDue == 0
                                      ? 'Today'
                                      : daysUntilDue == 1
                                          ? 'Tomorrow'
                                          : '$daysUntilDue days';
                                } else if (daysUntilDue <= 7) {
                                  borderColor = const Color(0xFFF59E0B); // Orange
                                  timeText = '$daysUntilDue days';
                                } else {
                                  borderColor = const Color(0xFF64748B); // Grey
                                  timeText = '$daysUntilDue days';
                                }

                                // Get assessment type name
                                String typeName;
                                switch (assessment.type) {
                                  case AssessmentType.weekly:
                                    typeName = 'Weekly';
                                    break;
                                  case AssessmentType.exam:
                                    typeName = 'Exam';
                                    break;
                                  case AssessmentType.coursework:
                                    typeName = 'Coursework';
                                    break;
                                }

                                return Opacity(
                                  opacity: getTaskOpacity(assessment.id),
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 8 * scaleFactor),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Checkbox on left (outside border)
                                        GestureDetector(
                                          onTap: () async {
                                            final user = ref.read(currentUserProvider);
                                            if (user == null) return;

                                            final newStatus = status == TaskStatus.complete
                                                ? TaskStatus.notStarted
                                                : TaskStatus.complete;

                                            // Trigger fade-out if completing
                                            if (newStatus == TaskStatus.complete) {
                                              handleTaskCompletedWithFade(assessment.id);
                                            }

                                            // Update temporary status for instant feedback
                                            updateTemporaryStatus(assessment.id, newStatus);

                                            final repository = ref.read(firestoreRepositoryProvider);
                                            final newCompletion = TaskCompletion(
                                              id: completion?.id ?? '',
                                              moduleId: widget.module.id,
                                              taskId: assessment.id,
                                              weekNumber: widget.weekNumber,
                                              status: newStatus,
                                              completedAt: newStatus == TaskStatus.complete
                                                  ? DateTime.now()
                                                  : null,
                                            );

                                            await repository.upsertTaskCompletion(
                                              user.uid,
                                              widget.module.id,
                                              newCompletion,
                                            );
                                          },
                                          child: _StatusIcon(
                                            status: getTemporaryStatus(assessment.id, status) ?? status,
                                            scaleFactor: scaleFactor,
                                          ),
                                        ),
                                        SizedBox(width: 12 * scaleFactor),

                                        // Bordered content container
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10 * scaleFactor,
                                              vertical: 8 * scaleFactor,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: borderColor, width: 1.5),
                                              borderRadius: BorderRadius.circular(6 * scaleFactor),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Assignment name
                                                Text(
                                                  assessment.name,
                                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                    fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) * scaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF1E293B),
                                                  ),
                                                ),
                                                SizedBox(height: 6 * scaleFactor),
                                                // Two labels in a row
                                                Row(
                                                  children: [
                                                    // Type label
                                                    Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 6 * scaleFactor,
                                                        vertical: 2 * scaleFactor,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: borderColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4 * scaleFactor),
                                                      ),
                                                      child: Text(
                                                        typeName,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 11) * scaleFactor,
                                                          color: borderColor,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 6 * scaleFactor),
                                                    // Due label
                                                    Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 6 * scaleFactor,
                                                        vertical: 2 * scaleFactor,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: borderColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4 * scaleFactor),
                                                      ),
                                                      child: Text(
                                                        timeText,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 11) * scaleFactor,
                                                          color: borderColor,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              // Position menu button in top right corner
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                        final RenderBox button =
                            context.findRenderObject() as RenderBox;
                        final RenderBox overlay =
                            Navigator.of(
                                  context,
                                ).overlay!.context.findRenderObject()
                                as RenderBox;
                        final RelativeRect position = RelativeRect.fromRect(
                          Rect.fromPoints(
                            button.localToGlobal(
                              Offset.zero,
                              ancestor: overlay,
                            ),
                            button.localToGlobal(
                              button.size.bottomRight(Offset.zero),
                              ancestor: overlay,
                            ),
                          ),
                          Offset.zero & overlay.size,
                        );

                        showMenu<String>(
                          context: context,
                          position: position,
                          items: [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 12),
                                  Text('Edit Module'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 20, color: Color(0xFF0EA5E9)),
                                  SizedBox(width: 12),
                                  Text('Share Module'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(Icons.archive_outlined, size: 20),
                                  SizedBox(width: 12),
                                  Text('Archive Module'),
                                ],
                              ),
                            ),
                          ],
                        ).then((value) {
                          if (value == 'share') {
                            // Show module selection dialog
                            showDialog(
                              context: context,
                              builder: (context) => ModuleSelectionDialog(
                                preSelectedModule: widget.module,
                                semesterId: widget.module.semesterId,
                              ),
                            );
                          } else if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ModuleFormScreen(
                                  existingModule: widget.module,
                                  semesterId: widget.module.semesterId,
                                ),
                              ),
                            );
                          } else if (value == 'archive') {
                            _showArchiveDialog(context, ref);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.more_vert, size: 28 * scaleFactor),
                      ),
                    ),
                  ),
                ),
            ],
        ),
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Module'),
        content: Text('Are you sure you want to archive "${widget.module.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);
              await repository.toggleModuleArchive(user.uid, widget.module.id, false);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Module archived'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}

class _TaskItem extends ConsumerStatefulWidget {
  final String taskName;
  final String taskId;
  final TaskStatus status;
  final Function(TaskStatus) onStatusChanged;
  final bool isSubtask;
  final bool isAssessment;
  final DateTime? completedAt;
  final double scaleFactor;
  final Function(String, TaskStatus)? onTouchDown;
  final Function(String, TaskStatus)? onSelectTask;
  final TaskStatus? Function(String, TaskStatus)? getTemporaryStatus;
  final Function(String, TaskStatus)? onUpdateTemporaryStatus;

  const _TaskItem({
    required this.taskName,
    required this.taskId,
    required this.status,
    required this.onStatusChanged,
    this.isSubtask = false,
    this.isAssessment = false,
    this.completedAt,
    this.scaleFactor = 1.0,
    this.onTouchDown,
    this.onSelectTask,
    this.getTemporaryStatus,
    this.onUpdateTemporaryStatus,
  });

  @override
  ConsumerState<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends ConsumerState<_TaskItem> {
  DateTime? _lastTapTime;
  static const _doubleTapWindow = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(userPreferencesProvider);

    // Use temporary status if available, otherwise use the actual status
    final temporaryStatus = widget.getTemporaryStatus?.call(widget.taskId, widget.status);
    final currentStatus = temporaryStatus ?? widget.status;

    final taskContent = Row(
      children: [
        _StatusIcon(status: currentStatus, scaleFactor: widget.scaleFactor),
        SizedBox(width: 12 * widget.scaleFactor),
        Expanded(
          child: Text(
            widget.taskName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize:
                  (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) *
                  widget.scaleFactor,
              color: widget.isAssessment
                  ? (currentStatus == TaskStatus.complete
                      ? Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6)
                      : const Color(0xFFB91C1C)) // Dark red for assessments
                  : null,
            ),
          ),
        ),
      ],
    );

    return Listener(
      onPointerDown: (_) => widget.onTouchDown?.call(widget.taskId, currentStatus),
      child: MouseRegion(
        onEnter: (_) => widget.onSelectTask?.call(widget.taskId, currentStatus),
        child: GestureDetector(
          onTap: () {
            final now = DateTime.now();
            final isDoubleTap =
                _lastTapTime != null &&
                now.difference(_lastTapTime!) < _doubleTapWindow;

            // Only allow double tap if 3-state mode is enabled
            final effectiveDoubleTap =
                isDoubleTap && preferences.enableThreeStateTaskToggle;

            final nextStatus = _getNextStatus(effectiveDoubleTap, currentStatus);
            _lastTapTime = now;

            // Immediately update temporary status for instant feedback
            widget.onUpdateTemporaryStatus?.call(widget.taskId, nextStatus);

            // Then trigger database update
            widget.onStatusChanged(nextStatus);
          },
          child: Container(
            margin: EdgeInsets.only(
              left: widget.isSubtask ? 32.0 * widget.scaleFactor : 0.0,
              top: 4 * widget.scaleFactor,
              bottom: 4 * widget.scaleFactor,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isAssessment ? 8 * widget.scaleFactor : 0,
              vertical: widget.isAssessment ? 8 * widget.scaleFactor : 4 * widget.scaleFactor,
            ),
            decoration: widget.isAssessment
                ? BoxDecoration(
                    color: const Color(0xFFB91C1C).withOpacity(0.08), // Light red background
                    borderRadius: BorderRadius.circular(8 * widget.scaleFactor),
                    border: Border.all(
                      color: const Color(0xFFB91C1C).withOpacity(0.2),
                      width: 1,
                    ),
                  )
                : null,
            child: taskContent,
          ),
        ),
      ),
    );
  }

  TaskStatus _getNextStatus(bool isDoubleTap, TaskStatus currentStatus) {
    if (!isDoubleTap) {
      // Single tap: if complete, go to empty; otherwise go to complete
      if (currentStatus == TaskStatus.complete) {
        return TaskStatus.notStarted;
      }
      return TaskStatus.complete;
    }

    // Double tap cycles through states (only when 3-state mode is enabled)
    switch (currentStatus) {
      case TaskStatus.notStarted:
        return TaskStatus.inProgress;

      case TaskStatus.inProgress:
        // In Progress -> Complete -> Empty
        return TaskStatus.notStarted;

      case TaskStatus.complete:
        // Complete -> Empty -> In Progress
        return TaskStatus.inProgress;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final TaskStatus status;
  final double scaleFactor;

  const _StatusIcon({required this.status, this.scaleFactor = 1.0});

  @override
  Widget build(BuildContext context) {
    final iconSize = 24.0 * scaleFactor;
    return switch (status) {
      TaskStatus.notStarted => Icon(
        Icons.radio_button_unchecked,
        color: Colors.grey[400],
        size: iconSize,
      ),
      TaskStatus.inProgress => Icon(
        Icons.circle,
        color: Colors.orange,
        size: iconSize,
      ),
      TaskStatus.complete => Icon(
        Icons.check_circle,
        color: Colors.green,
        size: iconSize,
      ),
    };
  }
}

// Semester Overview Section Widget
class _SemesterOverviewSection extends ConsumerWidget {
  final Semester semester;
  final Module module;
  final int weekNumber;
  final double scaleFactor;
  final bool isExpanded;
  final Map<int, bool> expandedWeeks;
  final VoidCallback onToggleExpansion;
  final Function(int) onToggleWeek;

  const _SemesterOverviewSection({
    required this.semester,
    required this.module,
    required this.weekNumber,
    required this.scaleFactor,
    required this.isExpanded,
    required this.expandedWeeks,
    required this.onToggleExpansion,
    required this.onToggleWeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringTasksAsync = ref.watch(recurringTasksProvider(module.id));
    final assessmentsAsync = ref.watch(assessmentsProvider(module.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (clickable to expand/collapse)
        InkWell(
          onTap: onToggleExpansion,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 18 * scaleFactor,
                color: const Color(0xFF0EA5E9),
              ),
              SizedBox(width: 6 * scaleFactor),
              Expanded(
                child: Text(
                  'Semester Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * scaleFactor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scaleFactor,
                  vertical: 4 * scaleFactor,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4 * scaleFactor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? 'Collapse' : 'Expand',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                        color: const Color(0xFF0EA5E9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4 * scaleFactor),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16 * scaleFactor,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8 * scaleFactor),
        // Content (collapsed or expanded)
        recurringTasksAsync.when(
          data: (tasks) {
            return assessmentsAsync.when(
              data: (assessments) {
                // Build a list to collect all week completion data
                final weekCompletionsList = <AsyncValue<List<TaskCompletion>>>[];

                // Watch all week providers at once
                for (int week = 1; week <= semester.numberOfWeeks; week++) {
                  weekCompletionsList.add(
                    ref.watch(taskCompletionsProvider((moduleId: module.id, weekNumber: week))),
                  );
                }

                // Check if any data is still loading
                final isAnyLoading = weekCompletionsList.any((async) => async.isLoading);
                if (isAnyLoading) {
                  return const SizedBox.shrink();
                }

                // Calculate completion for each week
                final weekCompletions = <int, Map<String, dynamic>>{};
                int fullyCompleteWeeks = 0;
                int overdueTasksCount = 0;

                for (int week = 1; week <= semester.numberOfWeeks; week++) {
                  final completionsAsync = weekCompletionsList[week - 1];

                  completionsAsync.whenData((completions) {
                    final completionMap = {for (var c in completions) c.taskId: c};

                    // Add assessments for this week
                    final weekAssessments = _getAssessmentsForWeek(
                      assessments,
                      semester.startDate,
                      week,
                    );

                    // Build set of valid task IDs for this week
                    final validTaskIds = <String>{
                      ...tasks.map((t) => t.id),
                      ...weekAssessments.map((a) => a.id),
                    };

                    // Count only tasks that are in our valid task list
                    final completedTasks = completions
                        .where((c) => validTaskIds.contains(c.taskId) && c.status == TaskStatus.complete)
                        .length;

                    final totalTasks = validTaskIds.length;

                    weekCompletions[week] = {
                      'total': totalTasks,
                      'completed': completedTasks,
                      'completions': completionMap,
                    };

                    // Calculate stats for past weeks
                    if (week < weekNumber) {
                      if (completedTasks == totalTasks && totalTasks > 0) {
                        fullyCompleteWeeks++;
                      } else {
                        overdueTasksCount += (totalTasks - completedTasks);
                      }
                    }
                  });
                }

                // Collect outstanding tasks
                final outstandingTasks = <Map<String, dynamic>>[];
                for (int week = 1; week < weekNumber; week++) {
                  final weekData = weekCompletions[week];
                  if (weekData != null) {
                    final completionMap = weekData['completions'] as Map<String, TaskCompletion>;

                    // Check recurring tasks
                    for (final task in tasks) {
                      final completion = completionMap[task.id];
                      if (completion?.status != TaskStatus.complete) {
                        outstandingTasks.add({
                          'week': week,
                          'name': task.name,
                          'isAssessment': false,
                        });
                      }
                    }

                    // Check assessments for this week
                    final weekAssessments = _getAssessmentsForWeek(assessments, semester.startDate, week);
                    for (final assessment in weekAssessments) {
                      final completion = completionMap[assessment.id];
                      if (completion?.status != TaskStatus.complete) {
                        outstandingTasks.add({
                          'week': week,
                          'name': assessment.name,
                          'isAssessment': true,
                        });
                      }
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats (always visible)
                    Text(
                      'Complete: $fullyCompleteWeeks/${weekNumber - 1} weeks' +
                          (overdueTasksCount > 0 ? ' | ⚠️ $overdueTasksCount overdue' : ''),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                        color: overdueTasksCount > 0
                            ? const Color(0xFFF59E0B)
                            : Colors.grey[600],
                      ),
                    ),

                    // Collapsed view: show outstanding tasks
                    if (!isExpanded && outstandingTasks.isNotEmpty) ...[
                      SizedBox(height: 12 * scaleFactor),
                      Text(
                        'Outstanding Tasks:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * scaleFactor,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      SizedBox(height: 6 * scaleFactor),
                      ...outstandingTasks.take(5).map((task) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 4 * scaleFactor, left: 4 * scaleFactor),
                          child: Row(
                            children: [
                              Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 14 * scaleFactor,
                                  color: task['isAssessment']
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                              SizedBox(width: 8 * scaleFactor),
                              Expanded(
                                child: Text(
                                  'Week ${task['week']}: ${task['name']}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                                    color: task['isAssessment']
                                        ? const Color(0xFFB91C1C)
                                        : Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (outstandingTasks.length > 5)
                        Padding(
                          padding: EdgeInsets.only(left: 16 * scaleFactor, top: 4 * scaleFactor),
                          child: Text(
                            '...and ${outstandingTasks.length - 5} more',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],

                    // Collapsed view: show "all caught up" if no overdue
                    if (!isExpanded && outstandingTasks.isEmpty && weekNumber > 1) ...[
                      SizedBox(height: 8 * scaleFactor),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16 * scaleFactor,
                            color: const Color(0xFF10B981),
                          ),
                          SizedBox(width: 6 * scaleFactor),
                          Text(
                            'All caught up!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Expanded view: show full week list
                    if (isExpanded) ...[
                      SizedBox(height: 8 * scaleFactor),
                      ...List.generate(semester.numberOfWeeks, (index) {
                        final week = index + 1;
                        return _WeekDetailRow(
                          week: week,
                          currentWeek: weekNumber,
                          semester: semester,
                          module: module,
                          tasks: tasks,
                          assessments: assessments,
                          scaleFactor: scaleFactor,
                          isExpanded: expandedWeeks[week] ?? false,
                          onToggle: () => onToggleWeek(week),
                          weekCompletions: weekCompletions[week],
                        );
                      }),
                    ],
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  List<Assessment> _getAssessmentsForWeek(
    List<Assessment> allAssessments,
    DateTime semesterStartDate,
    int weekNumber,
  ) {
    final assessments = <Assessment>[];

    for (final assessment in allAssessments) {
      if (assessment.type == AssessmentType.weekly) {
        final dueDates = assessment.getWeeklyDueDates(semesterStartDate);
        for (final dueDate in dueDates) {
          final weekStart = semesterStartDate.add(Duration(days: (weekNumber - 1) * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          if (dueDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              dueDate.isBefore(weekEnd)) {
            assessments.add(assessment);
            break;
          }
        }
      } else {
        if (assessment.weekNumber == weekNumber) {
          assessments.add(assessment);
        }
      }
    }

    return assessments;
  }
}

// Individual Week Detail Row
class _WeekDetailRow extends ConsumerWidget {
  final int week;
  final int currentWeek;
  final Semester semester;
  final Module module;
  final List<RecurringTask> tasks;
  final List<Assessment> assessments;
  final double scaleFactor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Map<String, dynamic>? weekCompletions;

  const _WeekDetailRow({
    required this.week,
    required this.currentWeek,
    required this.semester,
    required this.module,
    required this.tasks,
    required this.assessments,
    required this.scaleFactor,
    required this.isExpanded,
    required this.onToggle,
    this.weekCompletions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = weekCompletions?['total'] ?? 0;
    final completed = weekCompletions?['completed'] ?? 0;
    final completionMap = weekCompletions?['completions'] as Map<String, TaskCompletion>? ?? {};

    String statusSymbol;
    Color statusColor;

    if (week > currentWeek) {
      statusSymbol = '';
      statusColor = Colors.grey[400]!;
    } else if (week == currentWeek) {
      statusSymbol = ''; // Current week, no special symbol
      statusColor = const Color(0xFF0EA5E9);
    } else if (total > 0 && completed == total) {
      statusSymbol = ' ✓';
      statusColor = const Color(0xFF10B981);
    } else {
      statusSymbol = ' ⚠️'; // Overdue
      statusColor = const Color(0xFFF59E0B);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4 * scaleFactor),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18 * scaleFactor,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4 * scaleFactor),
                Text(
                  'Week $week$statusSymbol',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * scaleFactor,
                    color: week == currentWeek ? statusColor : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: week == currentWeek ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (total > 0 && week <= currentWeek) ...[
                  SizedBox(width: 8 * scaleFactor),
                  Text(
                    '($completed/$total)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          Padding(
            padding: EdgeInsets.only(left: 28 * scaleFactor, bottom: 8 * scaleFactor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show tasks for this week
                ...tasks.map((task) {
                  final completion = completionMap[task.id];
                  final status = completion?.status ?? TaskStatus.notStarted;
                  final statusIcon = status == TaskStatus.complete
                      ? '✓'
                      : status == TaskStatus.inProgress
                          ? '○'
                          : '✗';
                  final iconColor = status == TaskStatus.complete
                      ? const Color(0xFF10B981)
                      : status == TaskStatus.inProgress
                          ? Colors.orange
                          : Colors.grey;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 4 * scaleFactor),
                    child: Row(
                      children: [
                        Text(
                          statusIcon,
                          style: TextStyle(
                            fontSize: 12 * scaleFactor,
                            color: iconColor,
                          ),
                        ),
                        SizedBox(width: 8 * scaleFactor),
                        Expanded(
                          child: Text(
                            task.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Show assessments for this week
                ...assessments.where((a) => a.weekNumber == week).map((assessment) {
                  final completion = completionMap[assessment.id];
                  final status = completion?.status ?? TaskStatus.notStarted;
                  final statusIcon = status == TaskStatus.complete ? '✓' : '✗';
                  final iconColor = status == TaskStatus.complete
                      ? const Color(0xFF10B981)
                      : const Color(0xFFB91C1C);

                  return Padding(
                    padding: EdgeInsets.only(bottom: 4 * scaleFactor),
                    child: Row(
                      children: [
                        Text(
                          statusIcon,
                          style: TextStyle(
                            fontSize: 12 * scaleFactor,
                            color: iconColor,
                          ),
                        ),
                        SizedBox(width: 8 * scaleFactor),
                        Expanded(
                          child: Text(
                            assessment.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
                              color: const Color(0xFFB91C1C),
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
        ],
      ],
    );
  }
}
