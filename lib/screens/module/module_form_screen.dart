import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:module_tracker/screens/semester/semester_setup_screen.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:module_tracker/services/app_logger.dart';

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
  final String? scrollToTaskId;
  final String? scrollToAssessmentId;

  const ModuleFormScreen({
    super.key,
    this.semesterId,
    this.existingModule,
    this.scrollToTaskId,
    this.scrollToAssessmentId,
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
  final _scrollController = ScrollController();
  bool _isLoading = false;
  String? _selectedSemesterId;
  Semester? _cachedSemester; // Cache the semester to avoid Firestore race conditions

  final List<_RecurringTaskInput> _recurringTasks = [];
  final List<_AssessmentInput> _assessments = [];

  // Track which event to scroll to and highlight
  String? _highlightedEventId;
  bool _isHighlighted = false;

  // Track schedule overlaps
  List<_ScheduleOverlap> _scheduleOverlaps = [];

  // Track initial state for unsaved changes detection
  String _initialName = '';
  String _initialCode = '';
  String _initialCredits = '';
  String? _initialSelectedSemesterId;
  int _initialRecurringTasksCount = 0;
  int _initialAssessmentsCount = 0;
  List<String> _initialRecurringTasksData = []; // Serialized task data
  List<String> _initialAssessmentsData = []; // Serialized assessment data

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
    } else {
      // Store initial state for new module
      _storeInitialState();
      // Add default schedule and assessment for new modules
      _recurringTasks.add(_RecurringTaskInput());
      _assessments.add(_AssessmentInput());
    }

    // Schedule scroll and highlight after frame is built
    if (widget.scrollToTaskId != null || widget.scrollToAssessmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAndHighlightEvent();
      });
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
            ..originalId = task.id  // Store original Firestore ID
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
            ..originalId = assessment.id  // Store original Firestore ID
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

      AppLogger.debug('Loaded ${_recurringTasks.length} existing tasks and ${_assessments.length} assessments');
    } catch (e) {
      AppLogger.error('Error loading existing data', error: e);
    } finally {
      // Store initial state after loading
      _storeInitialState();
    }
  }

  void _storeInitialState() {
    _initialName = _nameController.text;
    _initialCode = _codeController.text;
    _initialCredits = _creditsController.text;
    _initialSelectedSemesterId = _selectedSemesterId;
    _initialRecurringTasksCount = _recurringTasks.length;
    _initialAssessmentsCount = _assessments.length;

    // Store serialized task and assessment data for deep comparison
    _initialRecurringTasksData = _recurringTasks.map((task) => _serializeTask(task)).toList();
    _initialAssessmentsData = _assessments.map((assessment) => _serializeAssessment(assessment)).toList();
  }

  // Serialize a recurring task to a string for comparison
  String _serializeTask(_RecurringTaskInput task) {
    final customTasksData = task.customTasks.map((ct) => '${ct.name}|${ct.type.toString()}').join(',');
    return '${task.name}|${task.type.toString()}|${task.dayOfWeek}|${task.time}|${task.endTime}|${task.location}|[$customTasksData]';
  }

  // Serialize an assessment to a string for comparison
  String _serializeAssessment(_AssessmentInput assessment) {
    return '${assessment.name}|${assessment.type.toString()}|${assessment.dueDate?.toIso8601String()}|${assessment.weighting}|${assessment.description}|${assessment.startWeek}|${assessment.endWeek}|${assessment.dayOfWeek}|${assessment.submitTiming?.toString()}|${assessment.time}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _creditsController.dispose();
    _nameFocusNode.dispose();
    _codeFocusNode.dispose();
    _creditsFocusNode.dispose();
    _scrollController.dispose();
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

  // Scroll to and highlight the event specified by widget parameters
  void _scrollToAndHighlightEvent() {
    // Find the target event
    int? targetIndex;
    bool isTask = false;

    if (widget.scrollToTaskId != null) {
      targetIndex = _recurringTasks.indexWhere((t) => t.originalId == widget.scrollToTaskId);
      isTask = true;
    } else if (widget.scrollToAssessmentId != null) {
      targetIndex = _assessments.indexWhere((a) => a.originalId == widget.scrollToAssessmentId);
      isTask = false;
    }

    // If event not found, return
    if (targetIndex == null || targetIndex == -1) {
      AppLogger.debug('Event not found for scrolling');
      return;
    }

    // Calculate approximate scroll position
    // Module info section + Schedule header ~= 800px
    // Each card ~= 250px average
    final double moduleInfoHeight = 800.0;
    final double scheduleHeaderHeight = 100.0;
    final double cardHeight = 250.0;

    double scrollOffset = moduleInfoHeight;

    if (isTask) {
      // Scroll to task in Schedule section
      scrollOffset += scheduleHeaderHeight + (targetIndex * cardHeight);
    } else {
      // Scroll to assessment in Assignments section
      // Add all tasks + assignments header
      scrollOffset += scheduleHeaderHeight;
      scrollOffset += (_recurringTasks.length * cardHeight);
      scrollOffset += 100.0; // Assignments header
      scrollOffset += (targetIndex * cardHeight);
    }

    // Perform the scroll animation
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        // After scrolling, set highlight state
        setState(() {
          _highlightedEventId = isTask
              ? _recurringTasks[targetIndex!].id
              : _assessments[targetIndex!].id;
          _isHighlighted = true;
        });

        // Remove highlight after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isHighlighted = false;
            });
          }
        });

        // Clear highlighted ID after animation completes
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() {
              _highlightedEventId = null;
            });
          }
        });
      });
    }
  }

  // Check if there are unsaved changes
  bool get _hasUnsavedChanges {
    // Only check for unsaved changes in edit mode
    // For new modules, we don't want to block them from leaving
    if (widget.existingModule == null) return false;

    // Check basic fields
    if (_nameController.text != _initialName ||
        _codeController.text != _initialCode ||
        _creditsController.text != _initialCredits ||
        _selectedSemesterId != _initialSelectedSemesterId) {
      return true;
    }

    // Check if number of tasks or assessments changed
    if (_recurringTasks.length != _initialRecurringTasksCount ||
        _assessments.length != _initialAssessmentsCount) {
      return true;
    }

    // Deep comparison: check if task content changed
    final currentTasksData = _recurringTasks.map((task) => _serializeTask(task)).toList();
    if (currentTasksData.length != _initialRecurringTasksData.length) return true;
    for (int i = 0; i < currentTasksData.length; i++) {
      if (currentTasksData[i] != _initialRecurringTasksData[i]) {
        return true;
      }
    }

    // Deep comparison: check if assessment content changed
    final currentAssessmentsData = _assessments.map((assessment) => _serializeAssessment(assessment)).toList();
    if (currentAssessmentsData.length != _initialAssessmentsData.length) return true;
    for (int i = 0; i < currentAssessmentsData.length; i++) {
      if (currentAssessmentsData[i] != _initialAssessmentsData[i]) {
        return true;
      }
    }

    return false;
  }

  // Check if save button should be enabled
  bool get _canSave {
    // For new modules, always allow saving (unless loading)
    if (widget.existingModule == null) return true;

    // For existing modules, only allow if there are unsaved changes
    return _hasUnsavedChanges;
  }

  // Helper to parse time string to minutes
  int _parseTimeToMinutes(String? time) {
    if (time == null || time.isEmpty) return 0;
    try {
      final parts = time.split(':');
      if (parts.length != 2) return 0;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (e) {
      return 0;
    }
  }

  // Check for schedule overlaps
  Future<void> _checkScheduleOverlaps() async {
    if (_selectedSemesterId == null) {
      setState(() => _scheduleOverlaps = []);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _scheduleOverlaps = []);
      return;
    }

    final repository = ref.read(firestoreRepositoryProvider);
    final overlaps = <_ScheduleOverlap>[];

    // Get all modules in the semester (excluding current module if editing)
    final allModules = await repository.getModulesBySemester(
      user.uid,
      _selectedSemesterId!,
      activeOnly: true,
    ).first;

    // Get all tasks from other modules
    final otherModuleTasks = <RecurringTask>[];
    for (final module in allModules) {
      // Skip current module if editing
      if (widget.existingModule != null && module.id == widget.existingModule!.id) {
        continue;
      }
      final tasks = await repository.getRecurringTasks(user.uid, module.id).first;
      otherModuleTasks.addAll(tasks.where((t) => t.time != null && t.parentTaskId == null));
    }

    // Check each current task against all other tasks
    for (final currentTask in _recurringTasks) {
      if (currentTask.time == null || currentTask.time!.isEmpty || currentTask.dayOfWeek == null) {
        continue;
      }

      final currentStart = _parseTimeToMinutes(currentTask.time);
      final currentEnd = _parseTimeToMinutes(currentTask.endTime ?? currentTask.time);

      // Ensure end time is after start time
      if (currentEnd <= currentStart) continue;

      // Check against other tasks
      for (final otherTask in otherModuleTasks) {
        if (otherTask.dayOfWeek != currentTask.dayOfWeek) continue;

        final otherStart = _parseTimeToMinutes(otherTask.time);
        final otherEnd = _parseTimeToMinutes(otherTask.endTime ?? otherTask.time);

        // Check if times overlap: (A.start < B.end) AND (A.end > B.start)
        if (currentStart < otherEnd && currentEnd > otherStart) {
          final otherModule = allModules.firstWhere((m) => m.id == otherTask.moduleId);
          overlaps.add(_ScheduleOverlap(
            taskInput: currentTask,
            conflictingTask: otherTask,
            conflictingModule: otherModule,
          ));
        }
      }

      // Also check against other tasks in the current form
      for (int i = 0; i < _recurringTasks.length; i++) {
        final otherTask = _recurringTasks[i];
        if (otherTask.id == currentTask.id) continue;
        if (otherTask.time == null || otherTask.time!.isEmpty || otherTask.dayOfWeek == null) {
          continue;
        }
        if (otherTask.dayOfWeek != currentTask.dayOfWeek) continue;

        final otherStart = _parseTimeToMinutes(otherTask.time);
        final otherEnd = _parseTimeToMinutes(otherTask.endTime ?? otherTask.time);

        if (currentStart < otherEnd && currentEnd > otherStart) {
          overlaps.add(_ScheduleOverlap(
            taskInput: currentTask,
            conflictingTaskInput: otherTask,
            conflictingModule: null,
          ));
        }
      }
    }

    setState(() => _scheduleOverlaps = overlaps);
  }

  // Show unsaved changes dialog
  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Unsaved Changes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have unsaved changes. What would you like to do?',
          style: GoogleFonts.inter(
            fontSize: 14,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: 110,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 110,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: Text(
                'Discard',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 110,
            child: FilledButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _saveModule();
              },
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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

    AppLogger.debug('Creating module with semesterId: $_selectedSemesterId');

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
      AppLogger.debug('Checking cached semester: ${_cachedSemester?.id ?? "null"}');

      if (semester == null) {
        AppLogger.debug('No cached semester, fetching from Firestore with userId: ${user.uid}, semesterId: $_selectedSemesterId');
        semester = await repository.getSemester(user.uid, _selectedSemesterId!);
        AppLogger.debug('Semester fetch result: ${semester?.id ?? "null"}');

        if (semester == null) {
          throw Exception('Semester not found in database. The semester may still be syncing. Please wait a moment and try again.');
        }
      } else {
        AppLogger.debug('Using cached semester: ${semester.id}');
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
        AppLogger.debug('Module updated with ID: $moduleId');

        // Delete all existing recurring tasks before creating new ones
        final existingTasks = await repository.getRecurringTasks(user.uid, moduleId).first;
        for (final task in existingTasks) {
          await repository.deleteRecurringTask(user.uid, moduleId, task.id);
        }
        AppLogger.debug('Deleted ${existingTasks.length} existing tasks');

        // Delete all existing assessments before creating new ones
        final existingAssessments = await repository.getAssessments(user.uid, moduleId).first;
        for (final assessment in existingAssessments) {
          await repository.deleteAssessment(user.uid, moduleId, assessment.id);
        }
        AppLogger.debug('Deleted ${existingAssessments.length} existing assessments');
      } else {
        // Create new module with timeout
        moduleId = await repository.createModule(user.uid, module).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Module creation timed out. Please check your internet connection and Firestore security rules.');
          },
        );
        AppLogger.debug('Module created with ID: $moduleId');
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
        AppLogger.debug('Module ${isUpdate ? "update" : "creation"} successful, navigating back');
        setState(() => _isLoading = false);
        _cachedSemester = null; // Clear cache after successful creation

        // Invalidate providers to refresh data - enhanced for immediate refresh
        ref.invalidate(currentSemesterModulesProvider);
        ref.invalidate(allCurrentSemesterTasksProvider);
        ref.invalidate(selectedSemesterModulesProvider);
        ref.invalidate(allSelectedSemesterTasksProvider);
        if (moduleId.isNotEmpty) {
          ref.invalidate(recurringTasksProvider(moduleId));
          ref.invalidate(assessmentsProvider(moduleId));
        }

        // Increased delay to ensure Firestore listener emits updated data
        await Future.delayed(const Duration(milliseconds: 400));

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
      AppLogger.error('Error creating module', error: e);
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
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_hasUnsavedChanges) {
          final shouldPop = await _showUnsavedChangesDialog();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: GradientHeader(
            title: widget.existingModule != null ? 'Edit Module' : 'Create Module',
          ),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Module Information Header
            Text(
              'Module Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Single Unified Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Module Overview Section
                    Text(
                      'Module Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Use single row layout for wider screens (>600px)
                        if (constraints.maxWidth > 600) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                flex: 5, // 50%
                                child: TextFormField(
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
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                flex: 3, // 30%
                                child: TextFormField(
                                  controller: _codeController,
                                  focusNode: _codeFocusNode,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Module Code',
                                    hintText: 'e.g., CS101',
                                    border: OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_creditsFocusNode);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a module code';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                flex: 2, // 20%
                                child: TextFormField(
                                  controller: _creditsController,
                                  focusNode: _creditsFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Credits',
                                    hintText: 'e.g., 15',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                              ),
                            ],
                          );
                        } else {
                          // Use vertical stack for mobile
                          return Column(
                            children: [
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
                                  labelText: 'Module Code',
                                  hintText: 'e.g., CS101',
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_creditsFocusNode);
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a module code';
                                  }
                                  return null;
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
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    // Semester Section
                    _SemesterSelectionField(
                      selectedSemesterId: _selectedSemesterId,
                      onSemesterSelected: (semesterId) {
                        setState(() {
                          _selectedSemesterId = semesterId;
                          _cachedSemester = null; // Clear cache when selecting existing semester
                        });
                      },
                      onCreateSemester: () async {
                        // Navigate to SemesterSetupScreen
                        final semesterId = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SemesterSetupScreen(),
                          ),
                        );
                        // Auto-select the newly created semester
                        if (mounted && semesterId != null) {
                          setState(() {
                            _selectedSemesterId = semesterId;
                            _cachedSemester = null; // Clear cache to force reload with new semester
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
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
            // Schedule overlap warning banner
            if (_scheduleOverlaps.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule Conflicts Detected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._scheduleOverlaps.map((overlap) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${overlap.dayName} ${overlap.timeRange}: overlaps with ${overlap.conflictDescription}',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                      ),
                    )),
                  ],
                ),
              ),
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
                final isHighlighted = _isHighlighted && _highlightedEventId == task.id;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isHighlighted
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: _RecurringTaskCard(
                    key: ObjectKey(task),
                    task: task,
                    onRemove: () => _removeRecurringTask(index),
                    onChanged: () {
                      setState(() {});
                      // Check for overlaps whenever schedule changes
                      _checkScheduleOverlaps();
                    },
                  ),
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
                              fontSize: 16,
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
                final isHighlighted = _isHighlighted && _highlightedEventId == assessment.id;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isHighlighted
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: _AssessmentCard(
                    key: ObjectKey(assessment),
                    assessment: assessment,
                    onRemove: () => _removeAssessment(index),
                    onChanged: () => setState(() {}),
                  ),
                );
              }),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 300,
                child: FilledButton(
                  onPressed: (_isLoading || !_canSave) ? null : _saveModule,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existingModule != null
                              ? (_canSave ? 'Update Module' : 'No Changes')
                              : 'Create Module',
                        ),
                ),
              ),
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RecurringTaskInput {
  static int _counter = 0;
  final String id;
  String? originalId; // Store the original Firestore ID for scrolling/highlighting
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
              ? const Color(0xFF60A5FA)
              : const Color(0xFF34D399),
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
                          ? const Color(0xFF60A5FA).withOpacity(0.1)
                          : const Color(0xFF34D399).withOpacity(0.1),
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
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF34D399),
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
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF34D399),
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
                          color: isSelected ? const Color(0xFF34D399) : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          // Only automatically set end time to 1 hour later if it's not already set
                          if (widget.task.endTime == null || widget.task.endTime!.isEmpty) {
                            final endTime = TimeOfDay(
                              hour: (picked.hour + 1) % 24,
                              minute: picked.minute,
                            );
                            widget.task.endTime = _formatTimeOfDay(endTime);
                          }
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
          ],
        ),
      ),
    );
  }
}

class _AssessmentInput {
  static int _counter = 0;
  final String id;
  String? originalId; // Store the original Firestore ID for scrolling/highlighting
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
                return const Color(0xFFA78BFA);
              case AssessmentType.exam:
                return const Color(0xFFF87171);
              case AssessmentType.weekly:
                return const Color(0xFF60A5FA);
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
                            return const Color(0xFFA78BFA).withOpacity(0.1);
                          case AssessmentType.exam:
                            return const Color(0xFFF87171).withOpacity(0.1);
                          case AssessmentType.weekly:
                            return const Color(0xFF60A5FA).withOpacity(0.1);
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
                                return const Color(0xFFA78BFA);
                              case AssessmentType.exam:
                                return const Color(0xFFF87171);
                              case AssessmentType.weekly:
                                return const Color(0xFF60A5FA);
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
                                    return const Color(0xFFA78BFA);
                                  case AssessmentType.exam:
                                    return const Color(0xFFF87171);
                                  case AssessmentType.weekly:
                                    return const Color(0xFF60A5FA);
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Semesters yet. Tap on \'+ Create New\' to make one',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...sortedSemesters.asMap().entries.map((entry) {
                final index = entry.key;
                final semester = entry.value;
                final isSelected = selectedSemesterId == semester.id;
                return Column(
                  children: [
                    if (index > 0) const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => onSemesterSelected(semester.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: semester.id,
                                groupValue: selectedSemesterId,
                                onChanged: (value) {
                                  if (value != null) onSemesterSelected(value);
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      semester.name,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatDate(semester.startDate)} - ${_formatDate(semester.endDate)}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
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
                              _ScaleOnHoverIconButton(
                                onPressed: () async {
                                  final RenderBox button =
                                      context.findRenderObject() as RenderBox;
                                  final RenderBox overlay =
                                      Navigator.of(context).overlay!.context.findRenderObject()
                                          as RenderBox;
                                  final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

                                  final value = await showMenu<String>(
                                    context: context,
                                    position: RelativeRect.fromLTRB(
                                      buttonPosition.dx,
                                      buttonPosition.dy + button.size.height,
                                      overlay.size.width - buttonPosition.dx - button.size.width,
                                      overlay.size.height - buttonPosition.dy - button.size.height,
                                    ),
                                    items: const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('Edit Semester'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'assignments',
                                        child: Row(
                                          children: [
                                            Icon(Icons.assessment_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('View Assignments'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );

                                  if (value == 'edit' && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SemesterSetupScreen(
                                          semesterToEdit: semester,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'assignments' && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AssignmentsScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: const Icon(Icons.more_vert, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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

// Model for schedule overlap conflicts
class _ScheduleOverlap {
  final _RecurringTaskInput taskInput;
  final RecurringTask? conflictingTask; // From another module
  final _RecurringTaskInput? conflictingTaskInput; // From same form
  final Module? conflictingModule;

  _ScheduleOverlap({
    required this.taskInput,
    this.conflictingTask,
    this.conflictingTaskInput,
    this.conflictingModule,
  });

  String get dayName {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[taskInput.dayOfWeek ?? 1];
  }

  String get timeRange {
    return '${taskInput.time ?? ''} - ${taskInput.endTime ?? ''}';
  }

  String get conflictDescription {
    if (conflictingTask != null && conflictingModule != null) {
      return '${conflictingModule!.code} ${conflictingTask!.type.toString().split('.').last}';
    } else if (conflictingTaskInput != null) {
      return 'Another ${conflictingTaskInput!.type.toString().split('.').last} in this module';
    }
    return 'Unknown conflict';
  }
}

// Reusable widget for scale-on-hover effect (no grey circle)
class _ScaleOnHoverIconButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _ScaleOnHoverIconButton({
    required this.child,
    required this.onPressed,
  });

  @override
  State<_ScaleOnHoverIconButton> createState() => _ScaleOnHoverIconButtonState();
}

class _ScaleOnHoverIconButtonState extends State<_ScaleOnHoverIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isHovering ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: widget.child,
        ),
      ),
    );
  }
}