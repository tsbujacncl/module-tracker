import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/utils/date_utils.dart' as utils;
import 'package:module_tracker/utils/date_picker_utils.dart';

// Provider to get all unique custom task names from all modules
final customTaskNamesProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repository = ref.watch(firestoreRepositoryProvider);
  final modules = await repository.getUserModules(user.uid).first;

  final taskNames = <String>{};
  for (final module in modules) {
    final tasks = await repository.getRecurringTasks(user.uid, module.id).first;
    for (final task in tasks) {
      if (task.parentTaskId != null && task.name.isNotEmpty) {
        taskNames.add(task.name);
      }
    }
  }

  return taskNames.toList()..sort();
});

class ModuleFormScreen extends ConsumerStatefulWidget {
  final String? semesterId;
  final Module? existingModule;

  const ModuleFormScreen({
    super.key,
    this.semesterId,
    this.existingModule,
  });

  @override
  ConsumerState<ModuleFormScreen> createState() => _ModuleFormScreenState();
}

class _ModuleFormScreenState extends ConsumerState<ModuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _creditsController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _creditsFocusNode = FocusNode();
  bool _isLoading = false;
  String? _selectedSemesterId;
  Semester? _cachedSemester; // Cache the semester to avoid Firestore race conditions

  final List<_RecurringTaskInput> _recurringTasks = [];
  final List<_AssessmentInput> _assessments = [];

  @override
  void initState() {
    super.initState();
    _selectedSemesterId = widget.semesterId;
    if (widget.existingModule != null) {
      _nameController.text = widget.existingModule!.name;
      _codeController.text = widget.existingModule!.code;
      _creditsController.text = widget.existingModule!.credits.toString();
      _selectedSemesterId = widget.existingModule!.semesterId;
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    if (widget.existingModule == null) return;

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final repository = ref.read(firestoreRepositoryProvider);

      // Load recurring tasks
      final tasks = await repository.getRecurringTasks(user.uid, widget.existingModule!.id).first;

      // Group tasks by parent (scheduled items have no parent, custom tasks have parentTaskId)
      final scheduledTasks = tasks.where((t) => t.parentTaskId == null && t.time != null).toList();
      final customTasksMap = <String, List<RecurringTask>>{};

      for (final task in tasks.where((t) => t.parentTaskId != null)) {
        customTasksMap.putIfAbsent(task.parentTaskId!, () => []).add(task);
      }

      // Load assessments
      final assessments = await repository.getAssessments(user.uid, widget.existingModule!.id).first;

      // Convert to input format
      setState(() {
        _recurringTasks.clear();
        for (final task in scheduledTasks) {
          final input = _RecurringTaskInput()
            ..name = task.name
            ..type = task.type
            ..dayOfWeek = task.dayOfWeek
            ..time = task.time
            ..endTime = task.endTime
            ..location = task.location;

          // Add custom tasks for this scheduled item
          if (customTasksMap.containsKey(task.id)) {
            for (final customTask in customTasksMap[task.id]!) {
              input.customTasks.add(_CustomTaskInput()
                ..name = customTask.name
                ..type = customTask.type);
            }
          }

          _recurringTasks.add(input);
        }

        // Load assessments
        _assessments.clear();
        for (final assessment in assessments) {
          _assessments.add(_AssessmentInput()
            ..name = assessment.name
            ..type = assessment.type
            ..dueDate = assessment.dueDate
            ..weighting = assessment.weighting
            ..description = assessment.description
            ..startWeek = assessment.startWeek
            ..endWeek = assessment.endWeek
            ..dayOfWeek = assessment.dayOfWeek
            ..submitTiming = assessment.submitTiming
            ..time = assessment.time);
        }
      });

      print('DEBUG: Loaded ${_recurringTasks.length} existing tasks and ${_assessments.length} assessments');
    } catch (e) {
      print('DEBUG: Error loading existing data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _creditsController.dispose();
    _nameFocusNode.dispose();
    _codeFocusNode.dispose();
    _creditsFocusNode.dispose();
    super.dispose();
  }

  void _addRecurringTask() {
    setState(() {
      // Add to top of list (stack behavior)
      _recurringTasks.insert(0, _RecurringTaskInput());
    });
  }

  void _removeRecurringTask(int index) {
    setState(() {
      _recurringTasks.removeAt(index);
    });
  }

  void _addAssessment() {
    setState(() {
      // Add to top of list (stack behavior)
      _assessments.insert(0, _AssessmentInput());
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

  Future<Semester?> _showCreateSemesterDialog() async {
    try {
      final result = await showDialog<Semester?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _CreateSemesterDialog(),
      );

      print('DEBUG: Dialog returned result: ${result?.id ?? "null"}');
      return result;
    } catch (e) {
      print('DEBUG: Error in dialog: $e');
      return null;
    }
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate semester selection
    if (_selectedSemesterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a semester'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('DEBUG: Creating module with semesterId: $_selectedSemesterId');

    // Validate assessments - only check if total exceeds 100%
    if (_assessments.isNotEmpty) {
      if (totalWeighting > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assessment weightings cannot exceed 100% (currently ${totalWeighting.toStringAsFixed(1)}%)'),
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

      // Use cached semester if available, otherwise fetch from Firestore
      Semester? semester = _cachedSemester;
      print('DEBUG: Checking cached semester: ${_cachedSemester?.id ?? "null"}');

      if (semester == null) {
        print('DEBUG: No cached semester, fetching from Firestore with userId: ${user.uid}, semesterId: $_selectedSemesterId');
        semester = await repository.getSemester(user.uid, _selectedSemesterId!);
        print('DEBUG: Semester fetch result: ${semester?.id ?? "null"}');

        if (semester == null) {
          throw Exception('Semester not found in database. The semester may still be syncing. Please wait a moment and try again.');
        }
      } else {
        print('DEBUG: Using cached semester: ${semester.id}');
      }

      // Create or update module
      final module = Module(
        id: widget.existingModule?.id ?? '',
        userId: user.uid,
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        semesterId: _selectedSemesterId!,
        isActive: true,
        createdAt: widget.existingModule?.createdAt ?? DateTime.now(),
        credits: int.tryParse(_creditsController.text) ?? 0,
      );

      String moduleId;
      if (widget.existingModule != null) {
        // Update existing module
        await repository.updateModule(user.uid, module.id, module);
        moduleId = module.id;
        print('DEBUG: Module updated with ID: $moduleId');

        // Delete all existing recurring tasks before creating new ones
        final existingTasks = await repository.getRecurringTasks(user.uid, moduleId).first;
        for (final task in existingTasks) {
          await repository.deleteRecurringTask(user.uid, moduleId, task.id);
        }
        print('DEBUG: Deleted ${existingTasks.length} existing tasks');

        // Delete all existing assessments before creating new ones
        final existingAssessments = await repository.getAssessments(user.uid, moduleId).first;
        for (final assessment in existingAssessments) {
          await repository.deleteAssessment(user.uid, moduleId, assessment.id);
        }
        print('DEBUG: Deleted ${existingAssessments.length} existing assessments');
      } else {
        // Create new module with timeout
        moduleId = await repository.createModule(user.uid, module).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Module creation timed out. Please check your internet connection and Firestore security rules.');
          },
        );
        print('DEBUG: Module created with ID: $moduleId');
      }

      // Sort recurring tasks by day of week (Monday to Sunday)
      _recurringTasks.sort((a, b) {
        if (a.dayOfWeek == null && b.dayOfWeek == null) return 0;
        if (a.dayOfWeek == null) return 1;
        if (b.dayOfWeek == null) return -1;
        return a.dayOfWeek!.compareTo(b.dayOfWeek!);
      });

      // Sort assessments by due date (earliest first)
      _assessments.sort((a, b) {
        // Handle null dates - put them at the end
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      // Create recurring tasks (lectures/labs/tutorials)
      for (final taskInput in _recurringTasks) {
        // Skip if time or day is not provided for scheduled items
        if (taskInput.time == null || taskInput.time!.isEmpty || taskInput.dayOfWeek == null) continue;

        // Create the main scheduled item (lecture/lab/tutorial)
        final task = RecurringTask(
          id: '',
          moduleId: moduleId,
          type: taskInput.type,
          dayOfWeek: taskInput.dayOfWeek!,
          time: taskInput.time,
          endTime: taskInput.endTime,
          name: taskInput.type.toString().split('.').last, // Use type as name
          location: taskInput.location,
        );

        final taskId = await repository.createRecurringTask(user.uid, moduleId, task);

        // Create custom tasks linked to this scheduled item
        for (final customTask in taskInput.customTasks) {
          if (customTask.name.isEmpty) continue;

          final linkedTask = RecurringTask(
            id: '',
            moduleId: moduleId,
            type: customTask.type,
            dayOfWeek: taskInput.dayOfWeek!, // Same day as parent
            time: null, // No specific time
            name: customTask.name,
            parentTaskId: taskId, // Link to parent
          );

          await repository.createRecurringTask(user.uid, moduleId, linkedTask);
        }
      }

      // Create assessments
      for (final assessmentInput in _assessments) {
        if (assessmentInput.name.isEmpty) continue;

        final weekNumber = assessmentInput.dueDate != null
            ? utils.DateUtils.getWeekNumber(
                assessmentInput.dueDate!,
                semester.startDate,
              )
            : null;

        final assessment = Assessment(
          id: '',
          moduleId: moduleId,
          name: assessmentInput.name,
          type: assessmentInput.type,
          dueDate: assessmentInput.dueDate,
          weighting: assessmentInput.weighting ?? 0,
          weekNumber: weekNumber,
          description: assessmentInput.description?.isEmpty ?? true ? null : assessmentInput.description,
          startWeek: assessmentInput.startWeek,
          endWeek: assessmentInput.endWeek,
          dayOfWeek: assessmentInput.dayOfWeek,
          submitTiming: assessmentInput.submitTiming,
          time: assessmentInput.time,
          showInCalendar: true,
        );

        await repository.createAssessment(user.uid, moduleId, assessment);
      }

      if (mounted) {
        final isUpdate = widget.existingModule != null;
        print('DEBUG: Module ${isUpdate ? "update" : "creation"} successful, navigating back');
        setState(() => _isLoading = false);
        _cachedSemester = null; // Clear cache after successful creation

        // Invalidate providers to refresh data
        ref.invalidate(currentSemesterModulesProvider);
        ref.invalidate(allCurrentSemesterTasksProvider);

        // Small delay to ensure UI updates before navigation
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isUpdate ? 'Module updated successfully!' : 'Module created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Error creating module: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Basic Info
            Text(
              'Module Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Module Name',
                hintText: 'e.g., Computer Science',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_codeFocusNode);
              },
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
              focusNode: _codeFocusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Module Code (Optional)',
                hintText: 'e.g., CS101',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_creditsFocusNode);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _creditsController,
              focusNode: _creditsFocusNode,
              decoration: const InputDecoration(
                labelText: 'Credits',
                hintText: 'e.g., 15',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the number of credits';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Semester Selection
            _SemesterSelectionField(
              selectedSemesterId: _selectedSemesterId,
              onSemesterSelected: (semesterId) {
                setState(() {
                  _selectedSemesterId = semesterId;
                  _cachedSemester = null; // Clear cache when selecting existing semester
                });
              },
              onCreateSemester: () async {
                try {
                  final newSemester = await _showCreateSemesterDialog();
                  if (newSemester != null && mounted) {
                    print('DEBUG FORM: New semester received from dialog: ${newSemester.id}');
                    setState(() {
                      _selectedSemesterId = newSemester.id;
                      _cachedSemester = newSemester; // Cache the newly created semester
                    });
                    print('DEBUG FORM: Cached semester set: ${_cachedSemester?.id}');
                  } else {
                    print('DEBUG FORM: Dialog returned null or widget unmounted');
                  }
                } catch (e) {
                  print('DEBUG FORM: Error creating semester: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create semester: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 32),
            // Recurring Tasks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Add lectures, labs, and tutorials',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addRecurringTask,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recurringTasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No schedule added yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the + button to add lectures, labs, or tutorials',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._recurringTasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                return _RecurringTaskCard(
                  key: ObjectKey(task),
                  task: task,
                  onRemove: () => _removeRecurringTask(index),
                  onChanged: () => setState(() {}),
                );
              }),
            const SizedBox(height: 32),
            // Assignments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignments',
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
                  key: ObjectKey(assessment),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTaskInput {
  static int _counter = 0;
  final String id;
  String name = '';
  RecurringTaskType type = RecurringTaskType.lecture;
  int? dayOfWeek; // No default - user must select
  String? time;
  String? endTime;
  String? location;
  List<_CustomTaskInput> customTasks = []; // Tasks associated with this scheduled item

  _RecurringTaskInput() : id = 'task_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}

class _CustomTaskInput {
  String name = '';
  RecurringTaskType type = RecurringTaskType.flashcards;
}

class _RecurringTaskCard extends StatefulWidget {
  final _RecurringTaskInput task;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _RecurringTaskCard({
    super.key,
    required this.task,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_RecurringTaskCard> createState() => _RecurringTaskCardState();
}

class _RecurringTaskCardState extends State<_RecurringTaskCard> {
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<String> _getCurrentFormTaskNames() {
    // Get all custom task names from the current form's recurring tasks
    final names = <String>{};
    for (final customTask in widget.task.customTasks) {
      if (customTask.name.isNotEmpty) {
        names.add(customTask.name);
      }
    }
    return names.toList();
  }

  // Parse time string (e.g., "09:00") to TimeOfDay
  TimeOfDay? _parseTimeOfDay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return null;
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Invalid format, return null
    }
    return null;
  }

  // Format TimeOfDay to string (e.g., "09:00")
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.task.type == RecurringTaskType.lecture
              ? const Color(0xFF3B82F6)
              : const Color(0xFF10B981),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and delete
            Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.task.type == RecurringTaskType.lecture
                          ? const Color(0xFF3B82F6).withOpacity(0.1)
                          : const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.task.type == RecurringTaskType.lecture
                              ? Icons.school
                              : Icons.science,
                          size: 16,
                          color: widget.task.type == RecurringTaskType.lecture
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                          ),
                          child: DropdownButton<RecurringTaskType>(
                            value: widget.task.type,
                            underline: const SizedBox(),
                            isDense: true,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).cardColor,
                            focusColor: Colors.transparent,
                            items: [
                              RecurringTaskType.lecture,
                              RecurringTaskType.lab,
                              RecurringTaskType.tutorial,
                            ].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type.toString().split('.').last.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: type == RecurringTaskType.lecture
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => widget.task.type = value);
                                widget.onChanged();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Day selector
            Row(
              children: List.generate(7, (index) {
                final dayOfWeek = index + 1;
                final isSelected = widget.task.dayOfWeek == dayOfWeek;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index < 6 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => widget.task.dayOfWeek = dayOfWeek);
                        widget.onChanged();
                      },
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF10B981) : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            days[index],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Time inputs
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _parseTimeOfDay(widget.task.time) ?? const TimeOfDay(hour: 9, minute: 0),
                        builder: (BuildContext context, Widget? child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          widget.task.time = _formatTimeOfDay(picked);
                          // Automatically set end time to 1 hour later
                          final endTime = TimeOfDay(
                            hour: (picked.hour + 1) % 24,
                            minute: picked.minute,
                          );
                          widget.task.endTime = _formatTimeOfDay(endTime);
                          widget.onChanged();
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        (widget.task.time?.isNotEmpty ?? false) ? widget.task.time! : 'Select time',
                        style: TextStyle(
                          color: (widget.task.time?.isNotEmpty ?? false) ? null : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _parseTimeOfDay(widget.task.endTime) ?? const TimeOfDay(hour: 10, minute: 0),
                        builder: (BuildContext context, Widget? child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          widget.task.endTime = _formatTimeOfDay(picked);
                          widget.onChanged();
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        widget.task.endTime?.isNotEmpty == true ? widget.task.endTime! : 'Select time',
                        style: TextStyle(
                          color: widget.task.endTime?.isNotEmpty == true ? null : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Custom tasks section
            Row(
              children: [
                Text(
                  'Related Tasks',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.task.customTasks.add(_CustomTaskInput());
                    });
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Task'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...widget.task.customTasks.asMap().entries.map((entry) {
              final index = entry.key;
              final customTask = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CustomTaskAutocomplete(
                        initialValue: customTask.name,
                        currentFormTaskNames: _getCurrentFormTaskNames(),
                        onChanged: (value) {
                          customTask.name = value;
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          widget.task.customTasks.removeAt(index);
                        });
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AssessmentInput {
  static int _counter = 0;
  final String id;
  String name = '';
  AssessmentType type = AssessmentType.coursework;
  DateTime? dueDate;
  double? weighting;
  String? description;
  int? startWeek;
  int? endWeek;
  int? dayOfWeek;
  SubmitTiming? submitTiming;
  String? time;

  _AssessmentInput() : id = 'assessment_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}

class _AssessmentCard extends StatefulWidget {
  final _AssessmentInput assessment;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _AssessmentCard({
    super.key,
    required this.assessment,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends State<_AssessmentCard> {
  late TextEditingController _nameController;
  late TextEditingController _weightingController;
  late TextEditingController _startWeekController;
  late TextEditingController _endWeekController;
  late TextEditingController _descriptionController;
  late TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.assessment.name);
    _weightingController = TextEditingController(text: widget.assessment.weighting?.toString() ?? '');
    _startWeekController = TextEditingController(text: widget.assessment.startWeek?.toString() ?? '');
    _endWeekController = TextEditingController(text: widget.assessment.endWeek?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.assessment.description ?? '');
    _timeController = TextEditingController(text: widget.assessment.time ?? '');
  }

  @override
  void didUpdateWidget(_AssessmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assessment != oldWidget.assessment) {
      _nameController.text = widget.assessment.name;
      _weightingController.text = widget.assessment.weighting?.toString() ?? '';
      _startWeekController.text = widget.assessment.startWeek?.toString() ?? '';
      _endWeekController.text = widget.assessment.endWeek?.toString() ?? '';
      _descriptionController.text = widget.assessment.description ?? '';
      _timeController.text = widget.assessment.time ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightingController.dispose();
    _startWeekController.dispose();
    _endWeekController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // Parse time string (e.g., "09:00") to TimeOfDay
  TimeOfDay? _parseTimeOfDay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return null;
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Invalid format, return null
    }
    return null;
  }

  // Format TimeOfDay to string (e.g., "09:00")
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: () {
            switch (widget.assessment.type) {
              case AssessmentType.coursework:
                return const Color(0xFF8B5CF6);
              case AssessmentType.exam:
                return const Color(0xFFEF4444);
              case AssessmentType.weekly:
                return const Color(0xFF3B82F6);
            }
          }(),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and delete
            Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: () {
                        switch (widget.assessment.type) {
                          case AssessmentType.coursework:
                            return const Color(0xFF8B5CF6).withOpacity(0.1);
                          case AssessmentType.exam:
                            return const Color(0xFFEF4444).withOpacity(0.1);
                          case AssessmentType.weekly:
                            return const Color(0xFF3B82F6).withOpacity(0.1);
                        }
                      }(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.assessment.type == AssessmentType.exam
                              ? Icons.assignment
                              : widget.assessment.type == AssessmentType.weekly
                                  ? Icons.event_repeat
                                  : Icons.book,
                          size: 16,
                          color: () {
                            switch (widget.assessment.type) {
                              case AssessmentType.coursework:
                                return const Color(0xFF8B5CF6);
                              case AssessmentType.exam:
                                return const Color(0xFFEF4444);
                              case AssessmentType.weekly:
                                return const Color(0xFF3B82F6);
                            }
                          }(),
                        ),
                        const SizedBox(width: 6),
                        Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                          ),
                          child: DropdownButton<AssessmentType>(
                            value: widget.assessment.type,
                            underline: const SizedBox(),
                            isDense: true,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).cardColor,
                            focusColor: Colors.transparent,
                            items: AssessmentType.values.map((type) {
                              final typeName = type.toString().split('.').last;
                              final capitalizedName = typeName[0].toUpperCase() + typeName.substring(1);
                              Color getColor() {
                                switch (type) {
                                  case AssessmentType.coursework:
                                    return const Color(0xFF8B5CF6);
                                  case AssessmentType.exam:
                                    return const Color(0xFFEF4444);
                                  case AssessmentType.weekly:
                                    return const Color(0xFF3B82F6);
                                }
                              }
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  capitalizedName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: getColor(),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  widget.assessment.type = value;
                                  // Clear week range if switching away from weekly
                                  if (value != AssessmentType.weekly) {
                                    widget.assessment.startWeek = null;
                                    widget.assessment.endWeek = null;
                                    widget.assessment.dayOfWeek = null;
                                    widget.assessment.submitTiming = null;
                                  } else {
                                    // Set defaults when switching to weekly
                                    widget.assessment.submitTiming ??= SubmitTiming.startOfNextWeek;
                                    widget.assessment.dayOfWeek ??= 1; // Default to Monday
                                  }
                                });
                                widget.onChanged();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Assessment Name and Weighting on same line
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      widget.assessment.name = value;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightingController,
                    decoration: const InputDecoration(
                      labelText: 'Weight %',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      widget.assessment.weighting = double.tryParse(value);
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            if (widget.assessment.type == AssessmentType.weekly) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startWeekController,
                      decoration: const InputDecoration(
                        labelText: 'Start Week',
                        hintText: 'e.g., 1',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        widget.assessment.startWeek = int.tryParse(value);
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endWeekController,
                      decoration: const InputDecoration(
                        labelText: 'End Week',
                        hintText: 'e.g., 10',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        widget.assessment.endWeek = int.tryParse(value);
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: widget.assessment.dayOfWeek,
                decoration: InputDecoration(
                  labelText: 'Day of Week',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                  DropdownMenuItem(value: 7, child: Text('Sunday')),
                ],
                onChanged: (value) {
                  setState(() {
                    widget.assessment.dayOfWeek = value;
                  });
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SubmitTiming>(
                value: widget.assessment.submitTiming,
                decoration: InputDecoration(
                  labelText: 'When Due',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                    value: SubmitTiming.startOfNextWeek,
                    child: Text('Start of Following Week'),
                  ),
                  DropdownMenuItem(
                    value: SubmitTiming.endOfCurrentWeek,
                    child: Text('End of Current Week'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    widget.assessment.submitTiming = value;
                  });
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: 'e.g., 17:00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
                onChanged: (value) {
                  widget.assessment.time = value;
                  widget.onChanged();
                },
              ),
            ],
            // Only show Due Date field for non-weekly assessments
            if (widget.assessment.type != AssessmentType.weekly) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(
                        widget.assessment.dueDate != null
                            ? '${widget.assessment.dueDate!.day}/${widget.assessment.dueDate!.month}/${widget.assessment.dueDate!.year}'
                            : 'TBC',
                        style: TextStyle(
                          color: widget.assessment.dueDate != null ? null : Colors.grey[600],
                          fontStyle: widget.assessment.dueDate != null ? null : FontStyle.italic,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showMondayFirstDatePicker(
                          context: context,
                          initialDate: widget.assessment.dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            widget.assessment.dueDate = picked;
                          });
                          widget.onChanged();
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  if (widget.assessment.dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          widget.assessment.dueDate = null;
                        });
                        widget.onChanged();
                      },
                      tooltip: 'Clear date',
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _parseTimeOfDay(widget.assessment.time) ?? const TimeOfDay(hour: 17, minute: 0),
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            widget.assessment.time = _formatTimeOfDay(picked);
                            widget.onChanged();
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          widget.assessment.time?.isNotEmpty == true ? widget.assessment.time! : '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., Written, 2 hours. Covers all lecture content.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              onChanged: (value) {
                widget.assessment.description = value;
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Semester Selection Field Widget
class _SemesterSelectionField extends ConsumerWidget {
  final String? selectedSemesterId;
  final Function(String) onSemesterSelected;
  final VoidCallback onCreateSemester;

  const _SemesterSelectionField({
    required this.selectedSemesterId,
    required this.onSemesterSelected,
    required this.onCreateSemester,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semestersAsync = ref.watch(semestersProvider);

    return semestersAsync.when(
      data: (semesters) {
        // Sort semesters chronologically by start date (oldest first)
        final sortedSemesters = [...semesters]
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Semester',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onCreateSemester,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (semesters.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('No semesters yet. Create one to continue.'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sortedSemesters.map((semester) {
                final isSelected = selectedSemesterId == semester.id;
                return Card(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: InkWell(
                    onTap: () => onSemesterSelected(semester.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: semester.id,
                            groupValue: selectedSemesterId,
                            onChanged: (value) {
                              if (value != null) onSemesterSelected(value);
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  semester.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(semester.startDate)} - ${_formatDate(semester.endDate)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (semester.readingWeekStart != null)
                                  Text(
                                    'Reading Week: ${_formatDate(semester.readingWeekStart!)} - ${_formatDate(semester.readingWeekEnd!)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                if (semester.examPeriodStart != null)
                                  Text(
                                    'Exams: ${_formatDate(semester.examPeriodStart!)} - ${_formatDate(semester.examPeriodEnd!)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.red[700],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error loading semesters: $error'),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Create Semester Dialog
class _CreateSemesterDialog extends ConsumerStatefulWidget {
  const _CreateSemesterDialog();

  @override
  ConsumerState<_CreateSemesterDialog> createState() => _CreateSemesterDialogState();
}

class _CreateSemesterDialogState extends ConsumerState<_CreateSemesterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _examPeriodStart;
  DateTime? _examPeriodEnd;
  DateTime? _readingWeekStart;
  DateTime? _readingWeekEnd;
  bool _hasReadingWeek = false;
  bool _hasExamPeriod = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get numberOfWeeks {
    if (_startDate == null || _endDate == null) return 0;
    return utils.DateUtils.calculateWeeksBetween(_startDate!, _endDate!);
  }

  Future<void> _createSemester() async {
    print('DEBUG: Create semester button pressed');

    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Form validation failed');
      return;
    }

    if (_startDate == null || _endDate == null) {
      print('DEBUG: Start or end date is null');
      return;
    }

    if (_hasReadingWeek && (_readingWeekStart == null || _readingWeekEnd == null)) {
      print('DEBUG: Reading week dates missing');
      return;
    }

    if (_hasExamPeriod && (_examPeriodStart == null || _examPeriodEnd == null)) {
      print('DEBUG: Exam period dates missing');
      return;
    }

    print('DEBUG: Setting loading state to true');
    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        print('DEBUG: User is null');
        throw Exception('User not logged in');
      }

      print('DEBUG: User ID: ${user.uid}');
      final repository = ref.read(firestoreRepositoryProvider);

      final semester = Semester(
        id: '',
        name: _nameController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        numberOfWeeks: numberOfWeeks,
        examPeriodStart: _hasExamPeriod ? _examPeriodStart : null,
        examPeriodEnd: _hasExamPeriod ? _examPeriodEnd : null,
        readingWeekStart: _hasReadingWeek ? _readingWeekStart : null,
        readingWeekEnd: _hasReadingWeek ? _readingWeekEnd : null,
        createdAt: DateTime.now(),
      );

      print('DEBUG: Creating semester: ${semester.name}');
      final semesterId = await repository.createSemester(user.uid, semester);
      print('DEBUG: Semester created with ID: $semesterId');

      // Wait a bit longer to ensure Firestore has synced the write
      await Future.delayed(const Duration(milliseconds: 500));

      final createdSemester = semester.copyWith(id: semesterId);
      print('DEBUG: Semester object created with ID: ${createdSemester.id}, closing dialog');

      if (mounted) {
        print('DEBUG: About to close dialog with semester: ${createdSemester.id}');
        Navigator.of(context).pop(createdSemester);
        print('DEBUG: Dialog closed successfully');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error creating semester: $e');
      print('DEBUG: Stack trace: $stackTrace');

      if (mounted) {
        // Return error message as a string by popping with a special error object
        Navigator.of(context).pop(); // Just close the dialog, error is logged
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Semester',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Semester Name',
                        hintText: 'e.g., Semester 1 2024/25',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a semester name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Semester Duration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _DateTile(
                      title: 'Start Date (Monday)',
                      date: _startDate,
                      onTap: () async {
                        final picked = await showMondayFirstDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _startDate = utils.DateUtils.getMonday(picked));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _DateTile(
                      title: 'End Date (Sunday)',
                      date: _endDate,
                      onTap: () async {
                        final picked = await showMondayFirstDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate?.add(const Duration(days: 84)) ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _endDate = utils.DateUtils.getSunday(picked));
                        }
                      },
                    ),
                    if (_startDate != null && _endDate != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Total Weeks: $numberOfWeeks',
                            style: Theme.of(context).textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Has Reading Week'),
                      value: _hasReadingWeek,
                      onChanged: (value) {
                        setState(() => _hasReadingWeek = value);
                      },
                    ),
                    if (_hasReadingWeek) ...[
                      const SizedBox(height: 12),
                      _DateTile(
                        title: 'Reading Week Start',
                        date: _readingWeekStart,
                        onTap: () async {
                          final picked = await showMondayFirstDatePicker(
                            context: context,
                            initialDate: _readingWeekStart ?? _startDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2020),
                            lastDate: _endDate ?? DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _readingWeekStart = utils.DateUtils.getMonday(picked));
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _DateTile(
                        title: 'Reading Week End',
                        date: _readingWeekEnd,
                        onTap: () async {
                          final picked = await showMondayFirstDatePicker(
                            context: context,
                            initialDate: _readingWeekEnd ?? _readingWeekStart ?? _startDate ?? DateTime.now(),
                            firstDate: _readingWeekStart ?? _startDate ?? DateTime(2020),
                            lastDate: _endDate ?? DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _readingWeekEnd = utils.DateUtils.getSunday(picked));
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Has Exam Period'),
                      value: _hasExamPeriod,
                      onChanged: (value) {
                        setState(() => _hasExamPeriod = value);
                      },
                    ),
                    if (_hasExamPeriod) ...[
                      const SizedBox(height: 12),
                      _DateTile(
                        title: 'Exam Period Start',
                        date: _examPeriodStart,
                        onTap: () async {
                          final picked = await showMondayFirstDatePicker(
                            context: context,
                            initialDate: _examPeriodStart ?? _endDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _examPeriodStart = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _DateTile(
                        title: 'Exam Period End',
                        date: _examPeriodEnd,
                        onTap: () async {
                          final picked = await showMondayFirstDatePicker(
                            context: context,
                            initialDate: _examPeriodEnd ?? _examPeriodStart ?? _endDate ?? DateTime.now(),
                            firstDate: _examPeriodStart ?? _startDate ?? DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _examPeriodEnd = picked);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _createSemester,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Semester'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Date Tile Widget
class _DateTile extends StatelessWidget {
  final String title;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateTile({
    required this.title,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Not selected',
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}

// Custom Task Autocomplete Widget
class _CustomTaskAutocomplete extends ConsumerStatefulWidget {
  final String initialValue;
  final List<String> currentFormTaskNames;
  final Function(String) onChanged;

  const _CustomTaskAutocomplete({
    required this.initialValue,
    required this.currentFormTaskNames,
    required this.onChanged,
  });

  @override
  ConsumerState<_CustomTaskAutocomplete> createState() => _CustomTaskAutocompleteState();
}

class _CustomTaskAutocompleteState extends ConsumerState<_CustomTaskAutocomplete> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskNamesAsync = ref.watch(customTaskNamesProvider);

    return taskNamesAsync.when(
      data: (savedTaskNames) {
        // Combine saved task names with current form task names
        final allTaskNames = <String>{
          ...savedTaskNames,
          ...widget.currentFormTaskNames,
        }.toList()..sort();

        return Autocomplete<String>(
          initialValue: TextEditingValue(text: widget.initialValue),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return allTaskNames;
            }
            return allTaskNames.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            widget.onChanged(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // Sync the controller with our internal controller
            if (controller.text != _controller.text) {
              _controller.text = controller.text;
            }

            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'e.g., Make flashcards',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                widget.onChanged(value);
              },
            );
          },
        );
      },
      loading: () => TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'e.g., Make flashcards',
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (value) {
          widget.onChanged(value);
        },
      ),
      error: (_, __) => TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'e.g., Make flashcards',
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (value) {
          widget.onChanged(value);
        },
      ),
    );
  }
}