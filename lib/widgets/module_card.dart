import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';

class ModuleCard extends ConsumerWidget {
  final Module module;
  final int weekNumber;

  const ModuleCard({
    super.key,
    required this.module,
    required this.weekNumber,
  });

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

  // Generate smart task name with occurrence count
  String generateTaskName(RecurringTask task, List<RecurringTask> allTasks) {
    // For custom tasks with names, just use the name
    if (task.type == RecurringTaskType.custom || task.type == RecurringTaskType.flashcards) {
      return task.name;
    }

    // For scheduled tasks (lecture, lab, tutorial), group by type
    final tasksOfSameType = allTasks
        .where((t) =>
            t.type == task.type &&
            t.time != null &&
            t.parentTaskId == null) // Only scheduled items, not custom subtasks
        .toList();

    // Sort by day of week and time
    tasksOfSameType.sort((a, b) {
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      return (a.time ?? '').compareTo(b.time ?? '');
    });

    // Find the index of this task (1-based)
    final index = tasksOfSameType.indexWhere((t) =>
        t.id == task.id ||
        (t.dayOfWeek == task.dayOfWeek && t.time == task.time));

    final occurrenceNumber = index + 1;
    final totalOfType = tasksOfSameType.length;

    final typeName = getTaskTypeName(task.type);

    // If only one of this type, just show type
    if (totalOfType == 1) {
      return typeName;
    }

    // If multiple, show occurrence number
    return '$typeName ($occurrenceNumber)';
  }

  // Get all assessments that are due in the given week
  List<Assessment> getAssessmentsForWeek(List<Assessment> allAssessments, DateTime semesterStartDate, int weekNumber) {
    final assessments = <Assessment>[];

    for (final assessment in allAssessments) {
      if (assessment.type == AssessmentType.weekly) {
        // Get all due dates for this weekly assessment
        final dueDates = assessment.getWeeklyDueDates(semesterStartDate);

        // Check if any due date falls in the current week
        for (int i = 0; i < dueDates.length; i++) {
          final dueDate = dueDates[i];
          final weekStart = semesterStartDate.add(Duration(days: (weekNumber - 1) * 7));
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
  Widget build(BuildContext context, WidgetRef ref) {
    final semester = ref.watch(currentSemesterProvider);
    final recurringTasksAsync = ref.watch(recurringTasksProvider(module.id));
    final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
    final completionsAsync = ref.watch(
        taskCompletionsProvider((moduleId: module.id, weekNumber: weekNumber)));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (module.code.isNotEmpty)
                        Text(
                          module.code,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      Text(
                        'Week $weekNumber',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ModuleFormScreen(
                            existingModule: module,
                            semesterId: module.semesterId,
                          ),
                        ),
                      );
                    } else if (value == 'archive') {
                      _showArchiveDialog(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tasks list (recurring tasks + weekly assessments)
            recurringTasksAsync.when(
              data: (tasks) {
                return assessmentsAsync.when(
                  data: (assessments) {
                    // Get all assessments for this week
                    final weekAssessments = semester != null
                        ? getAssessmentsForWeek(assessments, semester.startDate, weekNumber)
                        : <Assessment>[];

                    if (tasks.isEmpty && weekAssessments.isEmpty) {
                      return Text(
                        'No tasks for this week',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                      );
                    }

                    return completionsAsync.when(
                      data: (completions) {
                        final completionMap = {
                          for (var c in completions) c.taskId: c
                        };

                        // Sort tasks chronologically: by day of week, then by time
                        final sortedTasks = List<RecurringTask>.from(tasks);
                        sortedTasks.sort((a, b) {
                          // First by day of week
                          final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
                          if (dayCompare != 0) return dayCompare;

                          // Then by time (null times go last)
                          if (a.time == null && b.time == null) return 0;
                          if (a.time == null) return 1;
                          if (b.time == null) return -1;
                          return a.time!.compareTo(b.time!);
                        });

                        // Separate parent tasks and subtasks
                        final parentTasks = sortedTasks.where((t) => t.parentTaskId == null).toList();
                        final subtasksByParent = <String, List<RecurringTask>>{};

                        for (var task in sortedTasks) {
                          if (task.parentTaskId != null) {
                            subtasksByParent.putIfAbsent(task.parentTaskId!, () => []).add(task);
                          }
                        }

                        return Column(
                          children: [
                            // Recurring tasks
                            ...parentTasks.expand((task) {
                              final completion = completionMap[task.id];
                              final status = completion?.status ?? TaskStatus.notStarted;

                              // Generate smart task name
                              final displayName = generateTaskName(task, tasks);

                              final subtasks = subtasksByParent[task.id] ?? [];

                              return [
                                _TaskItem(
                                  taskName: displayName,
                                  status: status,
                                  completedAt: completion?.completedAt,
                                  onStatusChanged: (newStatus) async {
                                    final user = ref.read(currentUserProvider);
                                    if (user == null) return;

                                    final repository = ref.read(firestoreRepositoryProvider);
                                    final now = DateTime.now();

                                    // Update parent task
                                    final newCompletion = TaskCompletion(
                                      id: completion?.id ?? '',
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

                                    // If parent is completed, complete all subtasks
                                    if (newStatus == TaskStatus.complete && subtasks.isNotEmpty) {
                                      for (final subtask in subtasks) {
                                        final subCompletion = completionMap[subtask.id];
                                        final newSubCompletion = TaskCompletion(
                                          id: subCompletion?.id ?? '',
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
                                  },
                                ),
                                // Add subtasks with indentation
                                ...subtasks.map((subtask) {
                                  final subCompletion = completionMap[subtask.id];
                                  final subStatus = subCompletion?.status ?? TaskStatus.notStarted;

                                  return _TaskItem(
                                    taskName: subtask.name,
                                    status: subStatus,
                                    completedAt: subCompletion?.completedAt,
                                    isSubtask: true,
                                    onStatusChanged: (newStatus) async {
                                      final user = ref.read(currentUserProvider);
                                      if (user == null) return;

                                      final repository = ref.read(firestoreRepositoryProvider);
                                      final newCompletion = TaskCompletion(
                                        id: subCompletion?.id ?? '',
                                        moduleId: module.id,
                                        taskId: subtask.id,
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
                                  );
                                }),
                              ];
                            }),
                            // All assessments (weekly and non-weekly)
                            ...weekAssessments.map((assessment) {
                              final completion = completionMap[assessment.id];
                              final status = completion?.status ?? TaskStatus.notStarted;

                              return _TaskItem(
                                taskName: assessment.name,
                                status: status,
                                completedAt: completion?.completedAt,
                                onStatusChanged: (newStatus) async {
                                  final user = ref.read(currentUserProvider);
                                  if (user == null) return;

                                  final repository = ref.read(firestoreRepositoryProvider);
                                  final newCompletion = TaskCompletion(
                                    id: completion?.id ?? '',
                                    moduleId: module.id,
                                    taskId: assessment.id,
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
                              );
                            }),
                          ],
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
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Module'),
        content: Text('Are you sure you want to archive "${module.name}"?'),
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
              await repository.toggleModuleArchive(user.uid, module.id, false);

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

class _TaskItem extends StatefulWidget {
  final String taskName;
  final TaskStatus status;
  final Function(TaskStatus) onStatusChanged;
  final bool isSubtask;
  final DateTime? completedAt;

  const _TaskItem({
    required this.taskName,
    required this.status,
    required this.onStatusChanged,
    this.isSubtask = false,
    this.completedAt,
  });

  @override
  State<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<_TaskItem> {
  DateTime? _lastTapTime;
  static const _doubleTapWindow = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final now = DateTime.now();
        final isDoubleTap = _lastTapTime != null &&
            now.difference(_lastTapTime!) < _doubleTapWindow;

        final nextStatus = _getNextStatus(isDoubleTap);
        _lastTapTime = now;
        widget.onStatusChanged(nextStatus);
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.isSubtask ? 32.0 : 0.0,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            _StatusIcon(status: widget.status),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.taskName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: widget.status == TaskStatus.complete
                          ? TextDecoration.lineThrough
                          : null,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TaskStatus _getNextStatus(bool isDoubleTap) {
    if (!isDoubleTap) {
      // Single tap: if complete, go to empty; otherwise go to complete
      if (widget.status == TaskStatus.complete) {
        return TaskStatus.notStarted;
      }
      return TaskStatus.complete;
    }

    // Double tap cycles through states
    switch (widget.status) {
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

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TaskStatus.notStarted => Icon(
          Icons.radio_button_unchecked,
          color: Colors.grey[400],
        ),
      TaskStatus.inProgress => const Icon(
          Icons.circle,
          color: Colors.orange,
        ),
      TaskStatus.complete => const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
    };
  }
}