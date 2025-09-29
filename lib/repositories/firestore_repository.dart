import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/task_completion.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== SEMESTER OPERATIONS ==========

  /// Get user's semesters
  Stream<List<Semester>> getUserSemesters(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Semester.fromFirestore(doc)).toList());
  }

  /// Get a specific semester
  Future<Semester?> getSemester(String userId, String semesterId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .doc(semesterId)
        .get();

    if (!doc.exists) return null;
    return Semester.fromFirestore(doc);
  }

  /// Create a new semester
  Future<String> createSemester(String userId, Semester semester) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .add(semester.toFirestore());
    return docRef.id;
  }

  /// Update semester
  Future<void> updateSemester(
      String userId, String semesterId, Semester semester) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .doc(semesterId)
        .update(semester.toFirestore());
  }

  // ========== MODULE OPERATIONS ==========

  /// Get all modules for a user
  Stream<List<Module>> getUserModules(String userId, {bool? activeOnly}) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .orderBy('createdAt', descending: false);

    if (activeOnly == true) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Module.fromFirestore(doc)).toList());
  }

  /// Get modules for a specific semester
  Stream<List<Module>> getModulesBySemester(
      String userId, String semesterId, {bool? activeOnly}) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .where('semesterId', isEqualTo: semesterId);

    if (activeOnly == true) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Module.fromFirestore(doc)).toList());
  }

  /// Create a new module
  Future<String> createModule(String userId, Module module) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .add(module.toFirestore());
    return docRef.id;
  }

  /// Update module
  Future<void> updateModule(
      String userId, String moduleId, Module module) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .update(module.toFirestore());
  }

  /// Archive/unarchive module
  Future<void> toggleModuleArchive(
      String userId, String moduleId, bool isActive) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .update({'isActive': isActive});
  }

  // ========== RECURRING TASK OPERATIONS ==========

  /// Get recurring tasks for a module
  Stream<List<RecurringTask>> getRecurringTasks(
      String userId, String moduleId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringTask.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Create recurring task
  Future<String> createRecurringTask(
      String userId, String moduleId, RecurringTask task) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .add(task.toFirestore());
    return docRef.id;
  }

  /// Delete recurring task
  Future<void> deleteRecurringTask(
      String userId, String moduleId, String taskId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .doc(taskId)
        .delete();
  }

  // ========== ASSESSMENT OPERATIONS ==========

  /// Get assessments for a module
  Stream<List<Assessment>> getAssessments(String userId, String moduleId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Assessment.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Create assessment
  Future<String> createAssessment(
      String userId, String moduleId, Assessment assessment) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .add(assessment.toFirestore());
    return docRef.id;
  }

  /// Update assessment
  Future<void> updateAssessment(
      String userId, String moduleId, String assessmentId, Assessment assessment) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .doc(assessmentId)
        .update(assessment.toFirestore());
  }

  /// Delete assessment
  Future<void> deleteAssessment(
      String userId, String moduleId, String assessmentId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .doc(assessmentId)
        .delete();
  }

  // ========== TASK COMPLETION OPERATIONS ==========

  /// Get task completions for a module and week
  Stream<List<TaskCompletion>> getTaskCompletions(
      String userId, String moduleId, int weekNumber) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .where('weekNumber', isEqualTo: weekNumber)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskCompletion.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Get all task completions for a module
  Stream<List<TaskCompletion>> getAllTaskCompletions(
      String userId, String moduleId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskCompletion.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Create or update task completion
  Future<void> upsertTaskCompletion(
      String userId, String moduleId, TaskCompletion completion) async {
    // Try to find existing completion
    final existingQuery = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .where('taskId', isEqualTo: completion.taskId)
        .where('weekNumber', isEqualTo: completion.weekNumber)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      // Update existing
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(moduleId)
          .collection('taskCompletions')
          .doc(existingQuery.docs.first.id)
          .update(completion.toFirestore());
    } else {
      // Create new
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(moduleId)
          .collection('taskCompletions')
          .add(completion.toFirestore());
    }
  }

  /// Batch create task completions for a week
  Future<void> createWeeklyTaskCompletions(
      String userId, String moduleId, List<TaskCompletion> completions) async {
    final batch = _firestore.batch();

    for (final completion in completions) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(moduleId)
          .collection('taskCompletions')
          .doc();
      batch.set(docRef, completion.toFirestore());
    }

    await batch.commit();
  }
}