import 'package:hive_flutter/hive_flutter.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:uuid/uuid.dart';

class LocalRepository {
  static const String _semestersBox = 'semesters';
  static const String _modulesBox = 'modules';
  static const String _tasksBox = 'tasks';
  static const String _assessmentsBox = 'assessments';
  static const String _completionsBox = 'completions';

  final _uuid = const Uuid();

  // ========== SEMESTER OPERATIONS ==========

  /// Get user's semesters
  Stream<List<Semester>> getUserSemesters(String userId) async* {
    final box = await Hive.openBox<Map>(_semestersBox);

    // Emit initial data
    final semesters = box.values
        .where((item) => item['userId'] == userId)
        .map((item) => Semester.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    yield semesters;

    // Listen for changes
    await for (final _ in box.watch()) {
      final updatedSemesters = box.values
          .where((item) => item['userId'] == userId)
          .map((item) => Semester.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

      yield updatedSemesters;
    }
  }

  /// Get a specific semester
  Future<Semester?> getSemester(String userId, String semesterId) async {
    final box = await Hive.openBox<Map>(_semestersBox);
    final item = box.get(semesterId);
    if (item == null) return null;
    return Semester.fromMap(Map<String, dynamic>.from(item));
  }

  /// Create a new semester
  Future<String> createSemester(String userId, Semester semester) async {
    final box = await Hive.openBox<Map>(_semestersBox);
    final id = semester.id.isEmpty ? _uuid.v4() : semester.id;
    final semesterWithId = semester.copyWith(id: id);

    await box.put(id, {
      ...semesterWithId.toMap(),
      'userId': userId,
    });

    return id;
  }

  /// Update semester
  Future<void> updateSemester(
      String userId, String semesterId, Map<String, dynamic> data) async {
    final box = await Hive.openBox<Map>(_semestersBox);
    final existing = box.get(semesterId) as Map?;
    if (existing != null) {
      await box.put(semesterId, {
        ...Map<String, dynamic>.from(existing),
        ...data,
        'userId': userId,
      });
    }
  }

  // ========== MODULE OPERATIONS ==========

  /// Get all modules for a user
  Stream<List<Module>> getUserModules(String userId, {bool? activeOnly}) async* {
    final box = await Hive.openBox<Map>(_modulesBox);

    List<Module> _getModules() {
      var modules = box.values
          .where((item) => item['userId'] == userId)
          .map((item) => Module.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (activeOnly == true) {
        modules = modules.where((m) => m.isActive).toList();
      }

      modules.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return modules;
    }

    yield _getModules();

    await for (final _ in box.watch()) {
      yield _getModules();
    }
  }

  /// Get modules for a specific semester
  Stream<List<Module>> getModulesBySemester(
      String userId, String semesterId, {bool? activeOnly}) async* {
    final box = await Hive.openBox<Map>(_modulesBox);

    List<Module> _getModules() {
      var modules = box.values
          .where((item) =>
              item['userId'] == userId &&
              item['semesterId'] == semesterId)
          .map((item) => Module.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (activeOnly == true) {
        modules = modules.where((m) => m.isActive).toList();
      }

      return modules;
    }

    yield _getModules();

    await for (final _ in box.watch()) {
      yield _getModules();
    }
  }

  /// Create a new module
  Future<String> createModule(String userId, Module module) async {
    final box = await Hive.openBox<Map>(_modulesBox);
    final id = module.id.isEmpty ? _uuid.v4() : module.id;
    final moduleWithId = module.copyWith(id: id);

    await box.put(id, moduleWithId.toMap());
    return id;
  }

  /// Update module
  Future<void> updateModule(
      String userId, String moduleId, Module module) async {
    final box = await Hive.openBox<Map>(_modulesBox);
    await box.put(moduleId, module.toMap());
  }

  /// Archive/unarchive module
  Future<void> toggleModuleArchive(
      String userId, String moduleId, bool isActive) async {
    final box = await Hive.openBox<Map>(_modulesBox);
    final item = box.get(moduleId);
    if (item != null) {
      final module = Module.fromMap(Map<String, dynamic>.from(item));
      await box.put(moduleId, module.copyWith(isActive: isActive).toMap());
    }
  }

  // ========== RECURRING TASK OPERATIONS ==========

  /// Get recurring tasks for a module
  Stream<List<RecurringTask>> getRecurringTasks(
      String userId, String moduleId) async* {
    final box = await Hive.openBox<Map>(_tasksBox);

    List<RecurringTask> _getTasks() {
      return box.values
          .where((item) => item['moduleId'] == moduleId)
          .map((item) => RecurringTask.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    yield _getTasks();

    await for (final _ in box.watch()) {
      yield _getTasks();
    }
  }

  /// Create recurring task
  Future<String> createRecurringTask(
      String userId, String moduleId, RecurringTask task) async {
    final box = await Hive.openBox<Map>(_tasksBox);
    final id = task.id.isEmpty ? _uuid.v4() : task.id;
    final taskWithId = task.copyWith(id: id);

    await box.put(id, taskWithId.toMap());
    return id;
  }

  /// Delete recurring task
  Future<void> deleteRecurringTask(
      String userId, String moduleId, String taskId) async {
    final box = await Hive.openBox<Map>(_tasksBox);
    await box.delete(taskId);
  }

  // ========== ASSESSMENT OPERATIONS ==========

  /// Get assessments for a module
  Stream<List<Assessment>> getAssessments(String userId, String moduleId) async* {
    final box = await Hive.openBox<Map>(_assessmentsBox);

    List<Assessment> _getAssessments() {
      return box.values
          .where((item) => item['moduleId'] == moduleId)
          .map((item) => Assessment.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1; // Put TBC assessments at the end
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
    }

    yield _getAssessments();

    await for (final _ in box.watch()) {
      yield _getAssessments();
    }
  }

  /// Create assessment
  Future<String> createAssessment(
      String userId, String moduleId, Assessment assessment) async {
    final box = await Hive.openBox<Map>(_assessmentsBox);
    final id = assessment.id.isEmpty ? _uuid.v4() : assessment.id;
    final assessmentWithId = assessment.copyWith(id: id);

    await box.put(id, assessmentWithId.toMap());
    return id;
  }

  /// Update assessment
  Future<void> updateAssessment(
      String userId, String semesterId, String moduleId, String assessmentId, Map<String, dynamic> data) async {
    final box = await Hive.openBox<Map>(_assessmentsBox);
    final existing = box.get(assessmentId) as Map?;
    if (existing != null) {
      await box.put(assessmentId, {
        ...Map<String, dynamic>.from(existing),
        ...data,
      });
    }
  }

  /// Delete assessment
  Future<void> deleteAssessment(
      String userId, String moduleId, String assessmentId) async {
    final box = await Hive.openBox<Map>(_assessmentsBox);
    await box.delete(assessmentId);
  }

  // ========== TASK COMPLETION OPERATIONS ==========

  /// Get task completions for a module and week
  Stream<List<TaskCompletion>> getTaskCompletions(
      String userId, String moduleId, int weekNumber) async* {
    final box = await Hive.openBox<Map>(_completionsBox);

    List<TaskCompletion> _getCompletions() {
      return box.values
          .where((item) =>
              item['moduleId'] == moduleId &&
              item['weekNumber'] == weekNumber)
          .map((item) => TaskCompletion.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    yield _getCompletions();

    await for (final _ in box.watch()) {
      yield _getCompletions();
    }
  }

  /// Get all task completions for a module
  Stream<List<TaskCompletion>> getAllTaskCompletions(
      String userId, String moduleId) async* {
    final box = await Hive.openBox<Map>(_completionsBox);

    List<TaskCompletion> _getCompletions() {
      return box.values
          .where((item) => item['moduleId'] == moduleId)
          .map((item) => TaskCompletion.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    yield _getCompletions();

    await for (final _ in box.watch()) {
      yield _getCompletions();
    }
  }

  /// Create or update task completion
  Future<void> upsertTaskCompletion(
      String userId, String moduleId, TaskCompletion completion) async {
    final box = await Hive.openBox<Map>(_completionsBox);

    // Find existing completion
    final existing = box.values.firstWhere(
      (item) =>
          item['taskId'] == completion.taskId &&
          item['weekNumber'] == completion.weekNumber,
      orElse: () => <String, dynamic>{},
    );

    final id = existing.isNotEmpty
        ? box.keys.firstWhere((key) => box.get(key) == existing)
        : _uuid.v4();

    final completionWithId = completion.id.isEmpty
        ? completion.copyWith(id: id as String)
        : completion;

    await box.put(id, completionWithId.toMap());
  }

  /// Batch create task completions for a week
  Future<void> createWeeklyTaskCompletions(
      String userId, String moduleId, List<TaskCompletion> completions) async {
    final box = await Hive.openBox<Map>(_completionsBox);

    for (final completion in completions) {
      final id = completion.id.isEmpty ? _uuid.v4() : completion.id;
      final completionWithId = completion.copyWith(id: id);
      await box.put(id, completionWithId.toMap());
    }
  }
}
