import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';

class ModuleCard extends ConsumerWidget {
  final Module module;
  final int weekNumber;

  const ModuleCard({
    super.key,
    required this.module,
    required this.weekNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // TODO: Show module options
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tasks list
            recurringTasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
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

                    return Column(
                      children: tasks.map((task) {
                        final completion = completionMap[task.id];
                        final status = completion?.status ?? TaskStatus.notStarted;

                        return _TaskItem(
                          taskName: task.name,
                          status: status,
                          onStatusChanged: (newStatus) async {
                            final user = ref.read(currentUserProvider);
                            if (user == null) return;

                            final repository = ref.read(firestoreRepositoryProvider);
                            final newCompletion = TaskCompletion(
                              id: completion?.id ?? '',
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
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
            // Assessments for this week
            const SizedBox(height: 8),
            assessmentsAsync.when(
              data: (assessments) {
                final weekAssessments =
                    assessments.where((a) => a.weekNumber == weekNumber).toList();

                if (weekAssessments.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      'Due This Week:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...weekAssessments.map((assessment) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.assignment,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${assessment.name} (${assessment.weighting}%)',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String taskName;
  final TaskStatus status;
  final Function(TaskStatus) onStatusChanged;

  const _TaskItem({
    required this.taskName,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Cycle through statuses
        final nextStatus = switch (status) {
          TaskStatus.notStarted => TaskStatus.inProgress,
          TaskStatus.inProgress => TaskStatus.complete,
          TaskStatus.complete => TaskStatus.notStarted,
        };
        onStatusChanged(nextStatus);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _StatusIcon(status: status),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                taskName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: status == TaskStatus.complete
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
          Icons.pending,
          color: Colors.orange,
        ),
      TaskStatus.complete => const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
    };
  }
}