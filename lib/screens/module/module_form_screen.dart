import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/utils/date_utils.dart' as utils;

class ModuleFormScreen extends ConsumerStatefulWidget {
  final String semesterId;
  final Module? existingModule;

  const ModuleFormScreen({
    super.key,
    required this.semesterId,
    this.existingModule,
  });

  @override
  ConsumerState<ModuleFormScreen> createState() => _ModuleFormScreenState();
}

class _ModuleFormScreenState extends ConsumerState<ModuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  final List<_RecurringTaskInput> _recurringTasks = [];
  final List<_AssessmentInput> _assessments = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingModule != null) {
      _nameController.text = widget.existingModule!.name;
      _codeController.text = widget.existingModule!.code;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _addRecurringTask() {
    setState(() {
      _recurringTasks.add(_RecurringTaskInput());
    });
  }

  void _removeRecurringTask(int index) {
    setState(() {
      _recurringTasks.removeAt(index);
    });
  }

  void _addAssessment() {
    setState(() {
      _assessments.add(_AssessmentInput());
    });
  }

  void _removeAssessment(int index) {
    setState(() {
      _assessments.removeAt(index);
    });
  }

  double get totalWeighting {
    return _assessments.fold(0, (sum, a) => sum + (a.weighting ?? 0));
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate assessments
    if (_assessments.isNotEmpty) {
      if ((totalWeighting - 100).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assessment weightings must total 100% (currently ${totalWeighting.toStringAsFixed(1)}%)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not logged in');

      final repository = ref.read(firestoreRepositoryProvider);
      final semester = ref.read(currentSemesterProvider);
      if (semester == null) throw Exception('No active semester');

      // Create module
      final module = Module(
        id: widget.existingModule?.id ?? '',
        userId: user.uid,
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        semesterId: widget.semesterId,
        isActive: true,
        createdAt: widget.existingModule?.createdAt ?? DateTime.now(),
      );

      final moduleId = widget.existingModule != null
          ? module.id
          : await repository.createModule(user.uid, module);

      // Create recurring tasks
      for (final taskInput in _recurringTasks) {
        if (taskInput.name.isEmpty) continue;

        final task = RecurringTask(
          id: '',
          moduleId: moduleId,
          type: taskInput.type,
          dayOfWeek: taskInput.dayOfWeek,
          time: taskInput.time,
          name: taskInput.name,
        );

        await repository.createRecurringTask(user.uid, moduleId, task);
      }

      // Create assessments
      for (final assessmentInput in _assessments) {
        if (assessmentInput.name.isEmpty || assessmentInput.dueDate == null) continue;

        final weekNumber = utils.DateUtils.getWeekNumber(
          assessmentInput.dueDate!,
          semester.startDate,
        );

        final assessment = Assessment(
          id: '',
          moduleId: moduleId,
          name: assessmentInput.name,
          type: assessmentInput.type,
          dueDate: assessmentInput.dueDate!,
          weighting: assessmentInput.weighting ?? 0,
          weekNumber: weekNumber,
        );

        await repository.createAssessment(user.uid, moduleId, assessment);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Module created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.existingModule != null ? 'Edit Module' : 'Create Module'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Basic Info
            Text(
              'Module Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Module Name',
                hintText: 'e.g., Computer Science',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a module name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Module Code (Optional)',
                hintText: 'e.g., CS101',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            // Recurring Tasks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Tasks',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addRecurringTask,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recurringTasks.isEmpty)
              Text(
                'No weekly tasks added',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              )
            else
              ..._recurringTasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                return _RecurringTaskCard(
                  task: task,
                  onRemove: () => _removeRecurringTask(index),
                  onChanged: () => setState(() {}),
                );
              }),
            const SizedBox(height: 32),
            // Assessments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assessments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_assessments.isNotEmpty)
                      Text(
                        'Total: ${totalWeighting.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: (totalWeighting - 100).abs() < 0.01
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addAssessment,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_assessments.isEmpty)
              Text(
                'No assessments added',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              )
            else
              ..._assessments.asMap().entries.map((entry) {
                final index = entry.key;
                final assessment = entry.value;
                return _AssessmentCard(
                  assessment: assessment,
                  onRemove: () => _removeAssessment(index),
                  onChanged: () => setState(() {}),
                );
              }),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _saveModule,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.existingModule != null
                      ? 'Update Module'
                      : 'Create Module'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTaskInput {
  String name = '';
  RecurringTaskType type = RecurringTaskType.lecture;
  int dayOfWeek = 1; // Monday
  String? time;
}

class _RecurringTaskCard extends StatelessWidget {
  final _RecurringTaskInput task;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _RecurringTaskCard({
    required this.task,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: task.name,
                    decoration: const InputDecoration(
                      labelText: 'Task Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      task.name = value;
                      onChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurringTaskType>(
              initialValue: task.type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: RecurringTaskType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  task.type = value;
                  onChanged();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentInput {
  String name = '';
  AssessmentType type = AssessmentType.coursework;
  DateTime? dueDate;
  double? weighting;
}

class _AssessmentCard extends StatelessWidget {
  final _AssessmentInput assessment;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _AssessmentCard({
    required this.assessment,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: assessment.name,
                    decoration: const InputDecoration(
                      labelText: 'Assessment Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      assessment.name = value;
                      onChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AssessmentType>(
                    initialValue: assessment.type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: AssessmentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        assessment.type = value;
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: assessment.weighting?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Weighting %',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      assessment.weighting = double.tryParse(value);
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(
                assessment.dueDate != null
                    ? '${assessment.dueDate!.day}/${assessment.dueDate!.month}/${assessment.dueDate!.year}'
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: assessment.dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  assessment.dueDate = picked;
                  onChanged();
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}