import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';

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

class _ModuleCardState extends ConsumerState<ModuleCard> {
  // Track selected tasks during drag
  final Set<String> _selectedTaskIds = {};
  bool _isDragging = false;
  bool _isCompleting = true;
  final Map<String, TaskStatus> _temporaryCompletions = {};
  String? _firstTouchedTaskId;
  TaskStatus? _firstTouchedStatus;

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

    final totalOfType = tasksOfSameType.length;
    final typeName = getTaskTypeName(task.type);

    // If only one of this type, just show type
    if (totalOfType == 1) {
      return typeName;
    }

    // If 2 or more, show date instead of occurrence number
    final weekStartDate = semesterStartDate.add(Duration(days: (weekNumber - 1) * 7));
    final taskDate = weekStartDate.add(Duration(days: task.dayOfWeek - 1));

    return '$typeName (${formatTaskDate(taskDate)})';
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
                  // Module header with fixed height for alignment
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 75 * scaleFactor),
                    child: Padding(
                      padding: EdgeInsets.only(right: 8 * scaleFactor),
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
                          Text(
                            'Week ${widget.weekNumber}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
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
                  ),
                  SizedBox(height: 16 * scaleFactor),
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
                                    // Now select the first task that was touched
                                    if (_firstTouchedTaskId != null && _firstTouchedStatus != null) {
                                      selectTask(_firstTouchedTaskId!, _firstTouchedStatus!);
                                      _firstTouchedTaskId = null;
                                      _firstTouchedStatus = null;
                                    }
                                  }
                                },
                                onPanEnd: (details) {
                                  setState(() {
                                    _isDragging = false;
                                    _selectedTaskIds.clear();
                                    // DON'T clear _temporaryCompletions - let automatic cleanup handle it
                                    _firstTouchedTaskId = null;
                                    _firstTouchedStatus = null;
                                  });
                                },
                                onPanCancel: () {
                                  setState(() {
                                    _isDragging = false;
                                    _selectedTaskIds.clear();
                                    _firstTouchedTaskId = null;
                                    _firstTouchedStatus = null;
                                  });
                                },
                                child: Column(
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

                                            await repository
                                                .upsertTaskCompletion(
                                                  user.uid,
                                                  widget.module.id,
                                                  newCompletion,
                                                );
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

                                    return _TaskItem(
                                      taskName: assessment.name,
                                      taskId: assessment.id,
                                      status: status,
                                      completedAt: completion?.completedAt,
                                      scaleFactor: scaleFactor,
                                      onTouchDown: onTouchDown,
                                      onSelectTask: selectTask,
                                      getTemporaryStatus: getTemporaryStatus,
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

                                        await repository.upsertTaskCompletion(
                                          user.uid,
                                          widget.module.id,
                                          newCompletion,
                                        );
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
                ],
              ),
              // Position menu button in top right corner
              Positioned(
                top: 0,
                right: 0,
                child: Transform.translate(
                  offset: const Offset(8, -8),
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
                          if (value == 'edit') {
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
                        child: Icon(Icons.more_vert, size: 16 * scaleFactor),
                      ),
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
  final DateTime? completedAt;
  final double scaleFactor;
  final Function(String, TaskStatus)? onTouchDown;
  final Function(String, TaskStatus)? onSelectTask;
  final TaskStatus? Function(String, TaskStatus)? getTemporaryStatus;

  const _TaskItem({
    required this.taskName,
    required this.taskId,
    required this.status,
    required this.onStatusChanged,
    this.isSubtask = false,
    this.completedAt,
    this.scaleFactor = 1.0,
    this.onTouchDown,
    this.onSelectTask,
    this.getTemporaryStatus,
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

    return Listener(
      onPointerDown: (_) => widget.onTouchDown?.call(widget.taskId, currentStatus),
      child: MouseRegion(
        onEnter: (_) => widget.onSelectTask?.call(widget.taskId, currentStatus),
        child: InkWell(
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
            widget.onStatusChanged(nextStatus);
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.isSubtask ? 32.0 * widget.scaleFactor : 0.0,
              top: 8 * widget.scaleFactor,
              bottom: 8 * widget.scaleFactor,
            ),
            child: Row(
              children: [
                _StatusIcon(status: currentStatus, scaleFactor: widget.scaleFactor),
                SizedBox(width: 12 * widget.scaleFactor),
                Expanded(
                  child: Text(
                    widget.taskName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: currentStatus == TaskStatus.complete
                          ? TextDecoration.lineThrough
                          : null,
                      fontSize:
                          (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) *
                          widget.scaleFactor,
                    ),
                  ),
                ),
              ],
            ),
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
